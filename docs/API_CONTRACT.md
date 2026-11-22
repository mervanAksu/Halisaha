# API Sözleşmesi

İstemciler (mobil + panel) **yalnızca** burada listelenen tabloları, RPC'leri ve Edge Function'ları kullanır.
Kaynak: `supabase/migrations/*.sql`, `supabase/functions/*`. Değişiklikler önce bu dosyaya yazılır.

Genel kurallar:
- Para: `*_kurus` (int). 350000 → "3.500 ₺".
- Zaman: ISO-8601 UTC `timestamptz`. Gösterimde `Europe/Istanbul`.
- Hatalar: RPC'ler `raise exception '<kod>'` ile hata verir. İstemci `PostgrestException.message` içindeki kodu
  aşağıdaki tabloya göre Türkçe mesaja çevirir.

## Kimlik doğrulama

| İstemci | Yöntem |
|---|---|
| Mobil (müşteri) | Telefon + SMS OTP: `auth.signInWithOtp(phone: '+905...')` → `auth.verifyOTP(type: sms)` |
| Panel (işletme/admin) | E-posta + şifre: `auth.signInWithPassword`. İşletme hesabı admin tarafından `role='owner'` yapılır |

Yeni kullanıcıda `profiles` satırı trigger ile oluşur. İlk girişte `full_name` boşsa uygulama isim ister ve
`profiles.update({full_name, kvkk_ack_at})` çağırır.

## Tablolar (doğrudan okuma/yazma)

| Tablo | Müşteri | İşletme sahibi | Not |
|---|---|---|---|
| `profiles` | kendi satırı: select, update(`full_name`,`marketing_consent`,`kvkk_ack_at`) | yalnızca kendi satırı. Müşteri adı ve telefonu `owner_customer_contacts` RPC'siyle alınır | `role` istemciden değişmez |
| `venues` | `status='active'` olanlar: select | kendi sahaları: select/insert/update (status, commission hariç) | `commission_bps` ve `paytr_submerchant_key` istemciye kolon izniyle kapalıdır; admin `admin_list_venues()` RPC'siyle okur |
| `venue_hours` | select | kendi sahaları: CRUD | `iso_weekday` 1=Pzt…7=Paz. `close_time <= open_time` → gece yarısını aşar |
| `pitches` | select | kendi sahaları: CRUD | |
| `bookings` | kendi: select | kendi sahaları: select | **Yazma yalnızca RPC ile** |
| `payments` | kendi: select | kendi sahaları: select | Yazma yalnızca Edge Function ile |
| `favorites` | kendi: select/insert/delete | — | `user_id` varsayılan `auth.uid()` |
| `device_tokens` | kendi: CRUD | — | FCM token |
| `venue_payout_accounts` | — | kendi sahaları: select/insert/update | IBAN, VKN/TCKN |
| Storage `venue-photos` | public okuma | `<venue_id>/...` altına yazma | |

## RPC'ler (`supabase.rpc(name, params)`)

### `list_venues(p_search?, p_city?, p_districts?, p_lat?, p_lng?)` → satırlar
Herkes çağırabilir. `p_city text` (il adı, ör. `'İstanbul'`), `p_districts text[]` (o ilin seçili ilçeleri; null veya boş = ilin tamamı).
`p_districts` en fazla 50 eleman alır, fazlası yok sayılır. `p_city` null ise `p_districts` yok sayılır.
Dönen alanlar: `id, name, city, district, address, cover_photo_path, min_hourly_price_kurus,
open_time, close_time` (bugünün saatleri, null = bugün kapalı), `distance_km` (konum verilmezse null), `is_favorite`.
Sıralama: mesafe, sonra ad. En fazla 100 satır döner. (Eski `p_district text` parametresi kaldırıldı.)

### `list_venue_locations()` → satırlar
Herkes çağırabilir. Aktif ve en az bir aktif sahası olan tesislerin bulunduğu il/ilçeleri döndürür:
`city, district, venue_count`. Sıralama il, sonra ilçe (Türkçe alfabe). Uygulamanın konum seçicisi yalnızca
burada çıkan il ve ilçeleri gösterir, böylece seçim hiçbir zaman boş liste vermez.

### Tablolar `tr_provinces`, `tr_districts`
Herkes okuyabilir (`select`). İşletme paneli tesis formundaki il/ilçe açılır listelerini buradan doldurur. Not: 973 satır PostgREST'in
varsayılan `max-rows` (1000) sınırına yakın; ilçe sayısı artarsa panel sayfalı okumalı.

### `get_availability(p_pitch_id uuid, p_date date)` → satırlar
Herkes çağırabilir. `p_date` sahanın **iş günü**dür. 12:00–06:00 çalışan bir sahada 6 Aralık'ın slotları
7 Aralık 05:00–06:00'ya kadar uzanır. Dönen alanlar: `starts_at, ends_at, state ('available'|'booked'|'past'),
price_kurus, deposit_kurus`. Önümüzdeki 15 dakika içinde başlayan slotlar `past` olarak döner. Saha o gün kapalıysa boş liste döner.

### `create_booking_hold(p_pitch_id uuid, p_starts_at timestamptz)` → `bookings` satırı
Müşteri. Slotu **10 dakika** tutar (`status='pending_payment'`, `hold_expires_at`). Kapora 0 ise hemen
`confirmed` döner ve ödeme adımı atlanır.
Hatalar: `not_authenticated, pitch_not_found, slot_in_past, too_far_ahead, outside_opening_hours,
too_many_pending_holds, too_many_active_bookings, too_many_recent_holds, slot_taken`.
Limitler: aynı anda en fazla 2 bekleyen tutma, en fazla 4 gelecek tarihli aktif rezervasyon (kaporasızlar dahil), son 1 saatte en fazla 6 tutma.

### `cancel_booking(p_booking_id uuid, p_reason text?)` → `{status, refund_eligible}`
Müşteri. `pending_payment` durumundaki rezervasyon ücretsiz iptal edilir. `confirmed` rezervasyonda maç saatine
`venues.cancellation_window_hours` saatten fazla varsa kapora iade edilir (`refund_eligible=true`), yoksa kapora
yanar. Hatalar: `booking_not_found, not_cancellable`.

### `my_completed_match_count()` → int
Kampanya sayacı ("5 maçta 1 kapora bizden", v1.1).

### İşletme sahibi
Doğrulanmış MFA faktörü olan owner için tüm owner hakları **aal2** ister (S-18). aal1 oturumda owner RPC'leri `forbidden` döner, owner okumaları boş gelir, yazmalar 42501 alır. Mobil işletmeci girişi bu durumda TOTP adımı gösterir.
| RPC | Ne yapar | Hatalar |
|---|---|---|
| `owner_create_manual_booking(p_pitch_id, p_starts_at, p_ends_at, p_source 'manual'\|'block', p_customer_name?, p_customer_phone?, p_note?)` | Telefonla gelen rezervasyonu girer veya saati kapatır | `forbidden, invalid_range, invalid_source, slot_taken` |
| `owner_cancel_booking(p_booking_id, p_reason?)` | Başlamamış bir rezervasyonu iptal eder. Uygulama rezervasyonunda kapora **tam iade** edilir | `forbidden, not_cancellable, slot_started` |
| `owner_customer_contacts(p_user_ids uuid[])` | Sahasında son 180 günde rezervasyonu olan müşterilerin yalnızca `user_id, full_name, phone` bilgisini döndürür (admin: herkes) | — |
| `owner_mark_attendance(p_booking_id, p_status 'completed'\|'no_show')` | Geçmiş maçı işaretler (kapalı saat kayıtları işaretlenemez) | `forbidden, invalid_status` |

### Bildirim
`register_device_token(p_token, p_platform 'ios'|'android')`: FCM token'ını kaydeder. Tablo doğrudan yazılamaz. Aynı token başka kullanıcıdaysa yeni sahibine geçer. Kullanıcı başına en fazla 5 token tutulur.

### Admin (MFA zorunlu: JWT `aal2`)
`admin_verify_payout(p_venue_id)`: işletmenin IBAN/vergi bilgisini doğrular. Sahibi değiştirince doğrulama sıfırlanır. `audit_log` tablosunu yalnızca admin okur.
`admin_list_venues()`: tüm sahaları komisyon ve PayTR anahtarıyla birlikte döndürür (yalnızca admin).
`admin_update_venue(p_venue_id, p_status?, p_commission_bps?, p_paytr_submerchant_key?)`: sahayı onaylar veya
askıya alır, komisyonu ve alt üye işyeri anahtarını belirler.

### Yalnızca service role (Edge Function / cron)
`start_payment(booking_id, user_id)`, `confirm_payment(merchant_oid, success, total_amount_kurus, payload)`,
`expire_stale_holds()`, `complete_past_bookings()`, `prepare_account_deletion(user_id)`, `claim_refunds(limit)`, `mark_refunded(payment_id, payload)`, `release_refund_claim(payment_id, reason)`.

**Yetki modeli:** `public` şemasındaki hiçbir fonksiyon varsayılan olarak çağrılamaz. Çağrılabilir fonksiyonlar `20261120090800_security_hardening.sql` içindeki allow-list'tedir ve `tests/30_privileges_and_hardening.sql` (30a) bunu doğrular.
Hatalar: `hold_expired, booking_not_found, too_many_payment_attempts` (`start_payment`, en fazla 5 deneme).

## Edge Functions (`supabase.functions.invoke(name, body)`)

### `paytr-create-payment` (müşteri JWT'si ile)
İstek: `{ "booking_id": "<uuid>" }`
Yanıt 200: `{ "iframe_url": "https://www.paytr.com/odeme/guvenli/<token>", "merchant_oid": "HS…", "hold_expires_at": "…" }`
Hatalar (4xx `{ "error": "<kod>" }`): `not_authenticated, booking_not_found, hold_expired, payment_provider_error`.
Uygulama `iframe_url`'yi WebView'de açar. Ödeme sonucunu **booking satırının durumundan** okur
(`confirmed` olana kadar 2 saniyede bir kontrol eder, en fazla 2 dakika).
WebView'in `merchant_ok_url` veya `merchant_fail_url` adresine yönlenmesi yalnızca "işlem bitti" sinyalidir.

### `paytr-callback` (PayTR sunucusu çağırır, JWT yok)
`application/x-www-form-urlencoded` POST. Hash doğrulanır, `confirm_payment` çağrılır, yanıt her zaman düz `OK` olur.

### `delete-account` (müşteri JWT'si ile)
İstek: `{}`. Gelecekteki `confirmed` rezervasyonlar iptal edilir. İptal penceresi içindeyse kapora kuralı aynen
uygulanır. Ardından auth kullanıcısı silinir ve `profiles`, `favorites`, `device_tokens` cascade ile silinir.
`bookings.user_id` ve `payments.user_id` alanları null'a çekilir; mali kayıt anonim olarak saklanır (VUK).
Yanıt: `204`. Hatalar: `not_authenticated`, `owner_account` (saha sahibi hesapları platform ekibince kapatılır).

### `paytr-refund` (cron; `x-cron-secret` header'ı zorunlu)
`payments.status='refund_required'` kayıtlarını PayTR iade API'siyle iade eder ve `refunded` yapar.

## Hata kodları → kullanıcı mesajı

| Kod | Mesaj |
|---|---|
| `not_authenticated` | Devam etmek için giriş yapmalısın. |
| `pitch_not_found` | Bu saha artık rezervasyona açık değil. |
| `slot_in_past` | Bu saat geçti veya çok yakın, başka bir saat seç. |
| `too_far_ahead` | En fazla 30 gün sonrası için rezervasyon yapılabilir. |
| `outside_opening_hours` | Seçilen saat sahanın çalışma saatleri dışında. |
| `too_many_pending_holds` | Ödemesi tamamlanmamış rezervasyonların var. Önce onları tamamla ya da iptal et. |
| `slot_taken` | Bu saat az önce doldu. Başka bir saat seç. |
| `hold_expired` | Ödeme süresi doldu. Saati yeniden seçmelisin. |
| `booking_not_found` | Rezervasyon bulunamadı. |
| `not_cancellable` | Bu rezervasyon iptal edilemez. |
| `forbidden` | Bu işlem için yetkin yok. |
| `invalid_range` / `invalid_status` / `invalid_source` | Geçersiz istek. |
| `venue_not_found` | Tesis bulunamadı. |
| `payment_not_found` | Ödeme kaydı bulunamadı. |
| `owner_account` | Saha sahibi hesapları uygulamadan silinemez. Destek ekibiyle iletişime geç. |
| `too_many_active_bookings` | Aynı anda en fazla 4 aktif rezervasyonun olabilir. |
| `too_many_recent_holds` | Kısa sürede çok fazla rezervasyon denemesi yaptın. Biraz sonra tekrar dene. |
| `too_many_payment_attempts` | Bu rezervasyon için çok fazla ödeme denemesi yapıldı. Yeni bir saat seç. |
| `slot_started` | Bu maç başladığı için işlem yapılamaz. |
| `submerchant_key_required` | Sahayı yayına almak için önce PayTR alt üye işyeri anahtarını girin. |
| `reauth_required` | Güvenlik için tekrar giriş yapmalısın. |
| `invalid_token` | Bildirim kaydı geçersiz. |
| `payment_provider_error` | Ödeme altyapısına ulaşılamadı. Biraz sonra tekrar dene. |
| (diğer) | Bir şeyler ters gitti. Tekrar dene. |

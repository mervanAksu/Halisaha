# Tehdit Modeli — Halısaha / Rövanş

> Sahibi: red team (security-reviewer). Tarih: 2026-11-21. Kapsam: `supabase/` (Postgres RLS, SECURITY DEFINER RPC'ler,
> Edge Functions), `apps/owner_panel/` (Next.js), `apps/mobile/` (Flutter), CI/CD.
> Kanıt: `supabase/tests/40_attacks.sql` (çalıştırılabilir saldırılar, `A<n>`) ve `security/FINDINGS.md` (`F-`/`S-`/`M-`).
> Yöntem: varlık → aktör → güven sınırı → bileşen başına STRIDE. Olasılık/Etki: **D**üşük / **O**rta / **Y**üksek.

---

## 1. Varlıklar

| # | Varlık | Nerede | Neden değerli | Korunacak özellik |
|---|---|---|---|---|
| V1 | **Para**: kapora tahsilatı, iade, komisyon, pazaryeri dağıtımı | `payments`, `bookings.deposit_kurus/commission_kurus`, PayTR | Doğrudan maddi kayıp, 6493 sayılı Kanun riski | Bütünlük, inkâr edilemezlik |
| V2 | **Slotlar** (saatin tahsisi) | `bookings` + `no_overlapping_bookings` | Sahanın gelir kaynağı; slot kilitleme = rakip sabotajı | Bütünlük, erişilebilirlik |
| V3 | **Kişisel veri (KVKK)**: ad, telefon, e-posta, konum (istemcide), rezervasyon geçmişi, açık rıza kayıtları | `profiles`, `bookings`, `payments.user_id`, `owner_customer_contacts` | KVKK md. 12 veri güvenliği yükümlülüğü, ihlal bildirimi | Gizlilik, amaçla sınırlılık, ispat |
| V4 | **Ödeme/vergi kimliği**: IBAN, VKN/TCKN, ünvan | `venue_payout_accounts` | Payout yönlendirme dolandırıcılığı | Gizlilik, bütünlük |
| V5 | **İşletme ve admin hesapları** | Supabase Auth (e-posta+şifre), `profiles.role` | Admin = tüm platform; owner = saha geliri + müşteri verisi | Kimlik doğrulama, yetki |
| V6 | **PayTR sırları**: `merchant_key`, `merchant_salt`, `merchant_id`, `CRON_SECRET`, `service_role` | Supabase secrets, `cron.job` | Sahte callback hash'i üretme, iade tetikleme, RLS'i tamamen atlama | Gizlilik |
| V7 | **Ticari ayarlar**: `commission_bps`, `paytr_submerchant_key`, `venues.status` | `venues` (kolon yetkisiyle gizli) | Komisyon kaçırma, sahte saha onayı, parayı başka alt üye işyerine yönlendirme | Bütünlük |
| V8 | **Yazılım tedarik zinciri**: repo, CI, imzalama anahtarı, mağaza hesapları | GitHub, Actions secrets | Zararlı sürüm dağıtımı | Bütünlük |

## 2. Aktörler

| Aktör | Yetenek | Motivasyon | Tipik saldırı |
|---|---|---|---|
| **anon** | Herkese açık anon key + PostgREST/RPC/Edge uçları | Keşif, veri kazıma, DoS | Tabloları doğrudan okuma, `list_venues`/`get_availability` istismarı |
| **customer** | Telefon OTP ile `authenticated` JWT | Normal kullanım | — |
| **malicious customer** | Kendi JWT'si, istediği HTTP isteği, çok sayıda numara (Sybil) | Bedava maç, rakip sahayı kilitleme, başkasının verisi | IDOR, slot kilitleme, ödeme sahteciliği, iade suistimali |
| **malicious owner** | `role=owner` JWT, kendi sahaları | Komisyon kaçırma, kapora yakma, rakip verisi, müşteri verisi toplama | İptal penceresi oyunu (F-02), müşteri telefonu toplama (F-04), çapraz kiracı IDOR |
| **compromised owner** | Ele geçirilmiş owner oturumu/şifresi | Para yönlendirme | IBAN değiştirme (S-06), müşteri PII dışa aktarma |
| **insider admin** | `role=admin`, panel + RPC | Dolandırıcılık, merak | Alt üye işyeri anahtarını değiştirme, tüm PII'yi okuma, iz bırakmama (S-06) |
| **network attacker** | Ağda pasif/aktif (halka açık Wi-Fi, kötü niyetli proxy) | Oturum çalma | TLS düşürme, WebView'i yabancı sayfaya yönlendirme (M-02), clickjacking (S-03) |
| **PayTR-impersonator** | `paytr-callback` uç noktasına herkese açık POST | Ödemeden onay | Sahte/yeniden oynatılmış callback, test-mode hilesi (S-01), büyük gövde DoS (S-08) |
| **supply-chain attacker** | npm/pub paketi, GitHub Action, ele geçirilmiş katkıcı | Kod çalıştırma | Kilitsiz bağımlılık (S-02), etikete sabitlenmiş Action (S-15) |

## 3. Güven sınırları

```
 [Mobil uygulama]  [Tarayıcı: işletme paneli]            [PayTR]
        │ TB1 (TLS, anon key + JWT)  │ TB2 (TLS, çerez)      │ TB5 (HMAC hash)   ▲ TB6 (get-token / iade, HMAC)
        ▼                            ▼                       ▼                   │
 ┌──────────────── Supabase API gateway (Kong) ─────────────────────────────────┐ │
 │  PostgREST ── TB3: RLS + kolon yetkisi + EXECUTE allow-list ──▶ Postgres     │ │
 │  Auth (OTP, şifre)                                                           │ │
 │  Edge Functions (service_role) ── TB4: JWT doğrulama / x-cron-secret / hash ─┼─┘
 │  Storage (venue-photos, policy: <venue_id>/)                                 │
 └──────────────────────────────────────────────────────────────────────────────┘
        ▲ TB7: Next.js sunucusu (server actions, anon key + kullanıcı JWT'si, service_role YOK)
        ▲ TB8: CI/CD (GitHub Actions secrets, imzalama anahtarı) → mağazalar / GitHub Pages
```

- **TB1/TB2**: istemci tamamen güvenilmez. Tüm kural DB'de (RLS, RPC) ya da Edge Function'da uygulanmalı.
- **TB3**: asıl savunma hattı. `SECURITY DEFINER` fonksiyonlar RLS'i atlar, bu yüzden her biri kendi yetki kontrolünü yapmak zorunda.
- **TB4**: `service_role` yalnızca burada. Edge Function'a giren her alan (booking_id, form alanları, başlıklar) güvenilmez.
- **TB5**: PayTR callback'i yalnızca HMAC ile doğrulanır. Hash `merchant_oid + salt + status + total_amount` kapsar; `test_mode` ve diğer alanlar **kapsamaz**.
- **TB7**: Next.js server action'ları herkese açık POST uçlarıdır. Yetki yine RLS'e dayanır (panelde service_role yok, doğru).
- **TB8**: CI sırları + imzalama anahtarı en yüksek ayrıcalıktır.

## 4. Bileşen başına STRIDE

Sütunlar: **S**poofing, **T**ampering, **R**epudiation, **I**nformation disclosure, **D**enial of service, **E**levation of privilege.
"Kanıt": `A<n>` = 40_attacks.sql (✓ engellendi, ✗ açık), `F/S/M` = FINDINGS.md.

### 4.1 Postgres tabloları + RLS (PostgREST)

| STRIDE | Tehdit | Mevcut kontrol | O | E | Kanıt |
|---|---|---|---|---|---|
| S | `user_id`/`owner_id` taklidi ile başkası adına satır | `default auth.uid()` + `with check` | D | Y | A28 A42 A43 ✓ |
| T | Müşteri `bookings`/`payments` satırını doğrudan değiştirir | Yazma yetkisi yok, yalnızca RPC | D | Y | A45 A46 A46b A47 A48 ✓ |
| T | Owner `status`/`commission_bps`/`paytr_submerchant_key`/`owner_id` değiştirir | Kolon bazlı `grant` | D | Y | A29–A33 ✓ |
| T | Owner başka sahaya saha/saat ekler, saha taşır, siler | `is_venue_owner()` using + with check | D | O | A35–A39 ✓ |
| T | Owner kendi fotoğraf yollarını DB'ye doğrudan yazar (server action kontrolü atlanır) | Yok | O | D | **A99 ✗ F-09** |
| T | İptal penceresi ödeme sonrası değiştirilir | Yok (pencere rezervasyonda sabitlenmiyor) | O | O | **A91 ✗ F-02** |
| R | Admin/owner ticari ve IBAN değişiklikleri iz bırakmaz | `updated_at` dışında yok | O | O | S-06 |
| I | anon/müşteri/diğer owner IDOR | RLS | D | Y | A1–A23 ✓ |
| I | Müşteri `commission_kurus` üzerinden komisyon oranını türetir | Yok | Y | D | **A93 ✗ F-06** |
| D | Tek hesap sınırsız push token kaydı | Yok | O | D | **A95 ✗ F-08** |
| D | Push token global PK → kaydı engelleme / cihaz devrinde yanlış kişiye bildirim | Yok | D | D | **A97 ✗ F-07** |
| E | Müşteri `role` yükseltir, ikinci profil açar | Kolon yetkisi, insert yok | D | Y | A24–A27 ✓ |

### 4.2 SECURITY DEFINER RPC'ler

| STRIDE | Tehdit | Mevcut kontrol | O | E | Kanıt |
|---|---|---|---|---|---|
| S | Müşteri/owner iç fonksiyonları çağırır (`confirm_payment`, `start_payment`, `claim_refunds` …) | Deny-by-default + allow-list (30a) | D | Y | A83 ✓ |
| T | Askıdaki/onaysız sahada, pasif sahada, geçmişte, 30 gün sonrasında, hizasız saatte tutma | `create_booking_hold` kontrolleri | D | O | A60–A67 ✓ |
| T | Farklı slot uzunlukları (60/90/120) ve owner aralıklarıyla çakışma | `EXCLUDE USING gist` | D | Y | A68 ✓ |
| T | `owner_create_manual_booking`: başkasının sahası, >24 saat, negatif/NULL/sonsuz aralık, `source='app'` | Fonksiyon kontrolleri | D | O | A53–A59b ✓ |
| T | Owner geçmiş tarihli sahte rezervasyon | Yok | O | D | **A100 ✗ F-10** |
| T | `owner_mark_attendance(... 'cancelled')` ile iadesiz iptal | `invalid_status` | D | O | A73b ✓ |
| I | `owner_customer_contacts` ile rastgele kullanıcı telefonu | 180 gün + kendi sahası | D | O | A22 A74 A75 ✓ |
| I | Hiç ödeme yapmamış, yalnızca tutup iptal etmiş kişinin telefonu owner'a gider | Yok (`cancelled` durumu dahil) | Y | O | **A98 ✗ F-04** |
| I | `get_availability`/`list_venues` rezervasyon sahibini veya gizli sahayı sızdırır | Dönüş kolonları + `status='active'` | D | O | A78 A78b A92 A92b ✓ |
| D | Sonsuz/çok uzak tarih, 200 KB LIKE deseni, 100k elemanlı dizi | Tek gün sınırı, PG LIKE | D | D | A75 A76 A79 ✓ |
| D | Tek hesapla toplu tutma, tut-iptal-tut döngüsü | Kilit + 2/4/6 kota | D | O | A96 ✓ — Sybil için S-07 |
| T | Metin parametrelerinde SQL enjeksiyonu (`p_search`, `p_reason`, `note`, `customer_name`) | Parametre bağlama, `left()` | D | Y | A80 A81 ✓ |
| E | Owner kendi sahasını onaylar / admin RPC'leri | `is_admin()` | D | Y | A49–A51 ✓ |

### 4.3 Ödeme durum makinesi (`start_payment`, `confirm_payment`, `claim_refunds`)

| STRIDE | Tehdit | Mevcut kontrol | O | E | Kanıt |
|---|---|---|---|---|---|
| S | Callback'in yeniden oynatılması | `initiated` dışında no-op | D | Y | A84 ✓ |
| T | Eksik tutar | `refund_required` | D | Y | A85 ✓ |
| T | Başkasının rezervasyonu için ödeme başlatma | `user_id` eşleşmesi | D | O | A86 ✓ |
| T | İptal edilmiş tutmaya geç ödeme | `refund_required` | D | Y | A88 ✓ |
| T | Aynı `merchant_oid` için önce `failed`, sonra `success` → para çekildi, onay da iade de yok | Yok | O* | Y | **A90 ✗ F-01** (*PayTR davranışı VERIFY) |
| D | Sınırsız ödeme denemesi (token üretimi) | 5 deneme | D | D | A87 ✓ |
| T | Admin, alt üye işyeri anahtarı olmayan sahayı aktif eder → kapora platform hesabına düşer | Yok | O | Y (uyum) | **A101 ✗ F-03** |
| T | Owner il/ilçe referans tablolarını değiştirir veya siler (2026-11-22) | RLS + yalnızca select izni | D | O | A103–A103d ✓ |
| T | Owner yazım farkıyla ("Kadiköy") filtreyi bölen ilçe girer | FK `venues_city_district_fk` | D | D | A104 ✓ |
| D | Dev `p_districts` dizisi / enjeksiyon benzeri `p_city` ile `list_venues` | İlk 50 eleman, parametreli sorgu | D | D | A105, A106 ✓ |

### 4.4 Edge Functions

| Bileşen | STRIDE | Tehdit | O | E | Kanıt |
|---|---|---|---|---|---|
| `paytr-callback` | S | Sahte hash | D | Y | Sabit süreli HMAC karşılaştırma ✓ |
| `paytr-callback` | S/T | `PAYTR_TEST_MODE` tanımsızsa **test modu** (fail-open). Test kartıyla ödenen kapora gerçek rezervasyonu onaylar. Callback `test_mode` alanını kontrol etmez | O | Y | **S-01** |
| `paytr-callback` | D | Gövde boyutu ve content-type sınırı yok, parse hatası 500 döner, log enjeksiyonu | O | D | S-08 |
| `paytr-create-payment` | S | `user_ip` istemcinin yazabildiği `X-Forwarded-For`'un ilk değeri → PayTR fraud skoru yanıltılır | O | O | S-09 |
| `paytr-create-payment` | I | PayTR'ye kullanıcı UUID'li placeholder e-posta | D | D | S-16 |
| `paytr-refund` | I/S | `CRON_SECRET` `cron.job` tablosunda düz metin. Hata mesajı DB detayını döner | D | O | S-11 |
| `delete-account` | S | Çalınmış oturumla yeniden doğrulamasız hesap silme | D | O | S-12 |

### 4.5 İşletme paneli (Next.js)

| STRIDE | Tehdit | O | E | Kanıt |
|---|---|---|---|---|
| S | Owner/admin şifre kaba kuvvet. Giriş sunucuda yapıldığı için Supabase IP limiti panel sunucusunun IP'sini görür (ya hiç sınır yok ya da herkes kilitlenir). Captcha yok | O | Y | S-05 |
| S | MFA yok, `aal2` zorunlu değil (admin = platformun tamamı) | O | Y | S-04 |
| T | Clickjacking (onayla/askıya al/iptal/IBAN formları), CSP/HSTS yok | O | O | S-03 |
| T | Server action'lar herkese açık POST: yetki RLS'e dayanıyor (doğru). Next.js'in Origin kontrolü CSRF'e karşı korur. `/auth/signout` route handler'ında yok | D | D | S-13 |
| E | Next.js App Router RSC RCE (CVE-2025-66478) / middleware bypass (CVE-2025-29927). Lockfile yok, `^15.1.0` | O | Y | S-02 |
| I | Hata mesajları: üretimde Next maskeler. `error.tsx` genel metin gösteriyor ✓ | D | D | — |

### 4.6 Mobil uygulama

| STRIDE | Tehdit | O | E | Kanıt |
|---|---|---|---|---|
| I | Refresh token düz SharedPreferences'ta (HEAD). Çalışma ağacında Keychain/Keystore'a geçiş var | O | O | M-01 |
| T | Ödeme WebView'i her adrese gidebilir (HEAD). Çalışma ağacında allow-list var. 3DS akışı doğrulanmalı | O | O | M-02 |
| T | Tersine mühendislik | O | D | M-03: `--obfuscate` ✓, `allowBackup=false` ✓, cleartext kapalı ✓ |
| S | Deep-link ile ekran/oturum ele geçirme: şu an app link yok, ödeme rotaları `extra` nesnesi ister | D | O | M-05 |
| I | TLS MITM | D | O | M-04: pinning yerine OS trust store + RLS önerilir |

### 4.7 Operasyon / CI

| STRIDE | Tehdit | O | E | Kanıt |
|---|---|---|---|---|
| E | CI'da `permissions:` yok, Action'lar SHA'ya sabit değil, `release-build` workflow seviyesinde `contents: write` | O | Y | S-15 |
| S | `config.toml` içindeki sabit test OTP'si üretime itilirse herkesin bildiği giriş | D | O | S-10 |
| D | SMS pumping / Sybil slot kilitleme (OTP kaydı açık, captcha yok) | Y | O | S-07 |
| R | Olay müdahalesi, anahtar rotasyonu süreci yok | O | O | BASELINE.md |

## 5. En kritik kötüye kullanım senaryoları (öncelik sırası)

1. **Ücretsiz rezervasyon, test modu ile** (S-01): üretimde `PAYTR_TEST_MODE` unutulur → PayTR'nin herkese açık test kartlarıyla ödenen kapora `confirmed` olur. İşletme parasını alamaz.
2. **Kaybolan tahsilat** (F-01): `failed` bildiriminden sonra aynı sipariş için `success` gelir → para çekilmiştir ama rezervasyon onaylanmaz ve iade kuyruğuna girmez. Müşteri şikâyeti ve chargeback.
3. **Kapora yakma** (F-02): kötü niyetli owner ödeme sonrası iptal penceresini 168 saate çeker. Müşterinin iadesi engellenir.
4. **Platformun müşteri parası tutması** (F-03): alt üye işyeri anahtarı olmayan saha aktif edilir. Kapora platformun kendi PayTR hesabına düşer (6493 riski).
5. **Admin hesabı ele geçirme** (S-04/S-05): MFA ve captcha yok → bütün sahalar, komisyonlar ve PII tek şifreye bağlı.
6. **Müşteri telefonu toplama** (F-04): rakip/kötü niyetli owner, sahasında yalnızca saat tutup vazgeçenlerin telefonlarını alır.
7. **Slot kilitleme** (S-07): çok sayıda numarayla kaporasız sahaları ve tutmaları doldurma.

# Güvenlik Bulguları — kırmızı takım, 2026-11-21

Kapsam ve tehdit modeli: [`THREAT_MODEL.md`](THREAT_MODEL.md) · Temel ayarlar: [`BASELINE.md`](BASELINE.md) ·
Kanıt: [`supabase/tests/40_attacks.sql`](../supabase/tests/40_attacks.sql) (CI'da her push'ta çalışır; açık zafiyet → kırmızı).

**Durum (2026-11-21):** 114 saldırı denendi, **114'ü engellendi, açık zafiyet 0**. Statik bulguların tamamı düzeltildi. Yalnızca `VERIFY` ile işaretli dış bağımlılık varsayımları açık.

**Güncelleme (2026-11-22):** S-18 (işletme MFA'sı sunucuda yoktu) kapatıldı. Saldırı paketi: 131 saldırı, **131'i engellendi, açık zafiyet 0**.

## Çalıştırılabilir saldırıyla kanıtlanan bulgular

| ID | Önem | Konu | Saldırı | Düzeltme | Durum |
|---|---|---|---|---|---|
| F-01 | Yüksek | `failed` sonrası gelen `success` bildirimi yutuluyordu: para çekilmiş, rezervasyon yok | A90 | `confirm_payment` başarısız kayda gelen başarıyı işler (onay ya da iade) | ✅ 20261121090000 |
| F-02 | Orta | İşletme, ödeme sonrası iptal süresini değiştirip kaporayı yakabiliyordu | A91 | İptal süresi rezervasyon anında `bookings.cancellation_window_hours`'a sabitlenir | ✅ |
| F-03 | Orta | PayTR alt üye işyeri anahtarı olmayan saha yayına alınabiliyordu (6493 riski) | A101 | `submerchant_key_required`; kaporalı tutma anahtar olmadan açılmaz | ✅ |
| F-04 | Orta (KVKK) | Yalnızca saat tutup iptal edenin telefonu işletmeye açılıyordu | A98 | Yalnızca `confirmed_at` dolu rezervasyonlar iletişim hakkı verir | ✅ |
| F-05 | Düşük | KVKK onay zamanı istemci tarafından yazılabiliyordu | A94 | Sunucu saatiyle bir kez yazılır + `consent_events` geçmişi | ✅ |
| F-06 | Düşük | Müşteri, gizli komisyon oranını kendi rezervasyonundan türetebiliyordu | A93 | `commission_kurus` kolon izniyle kapalı; tutma yanıtında yok | ✅ |
| F-07 | Düşük | Push token işgali | A97 | Yalnızca `register_device_token` RPC'si; gerçek sahibi kaydedince devralır | ✅ |
| F-08 | Düşük | Sınırsız push token kaydı | A95, A95b | Kullanıcı başına en fazla 5 | ✅ |
| F-09 | Düşük | Fotoğraf yolları DB'de doğrulanmıyordu (başka sahanın dosyası, `../`) | A99 | `venues_photo_paths_ok` CHECK kısıtı | ✅ |
| F-10 | Düşük | Geçmiş tarihli sahte manuel rezervasyon | A100 | 1 saatten eski ve 400 günden ileri kayıt reddedilir | ✅ |

## Statik inceleme bulguları

| ID | Önem | Konu | Düzeltme | Durum |
|---|---|---|---|---|
| S-01 | Yüksek | PayTR test modu varsayılan açıktı; test kartıyla gerçek onay alınabilirdi | `PAYTR_TEST_MODE` açıkça 0/1 olmalı; canlıda test bildirimi reddedilir | ✅ |
| S-02 | Yüksek | Panel Next.js sürümü RSC RCE (CVE-2025-66478) ve middleware atlatma (CVE-2025-29927) etkisinde | `next ^15.5.7`, `react ^19.2.1`, npm audit + Dependabot | ✅ |
| S-03 | Orta | Panelde güvenlik başlıkları yoktu | CSP, HSTS, frame-ancestors none, nosniff, Referrer/Permissions-Policy | ✅ |
| S-04 | Orta | Admin/işletme için MFA yoktu | TOTP; admin yetkisi DB'de `aal2` ister (`is_admin()`), panel zorlar | ✅ |
| S-05 | Orta | Panel girişinde captcha / kaba kuvvet koruması yoktu | Turnstile (anahtar verilirse) + genel hata mesajı; Supabase captcha | ✅ (dashboard ayarı: BASELINE) |
| S-06 | Orta | Denetim izi yoktu; IBAN değişikliği doğrulanmadan geçerliydi | `audit_log` + tetikleyiciler; IBAN değişince `verified_at` sıfırlanır, admin onaylar | ✅ |
| S-07 | Orta | Çok numarayla (Sybil) slot kilitleme / SMS pumping | Kotalar + captcha + SMS hız limiti (dashboard) | ⚠️ dashboard ayarı (BASELINE) |
| S-08 | Orta | Ödeme bildirimi girdi sınırı yoktu | Content-type, 8 KB, regex, hatalı form → 400 | ✅ |
| S-09 | Orta | `user_ip` istemcinin yazabildiği başlıktan alınıyordu | Platform başlığı / en sağdaki XFF (VERIFY) | ✅ |
| S-10 | Düşük | Sabit test OTP'si canlıya taşınabilir | Yayın kontrol listesine eklendi | ✅ |
| S-11 | Düşük | İade işi DB hata mesajını dışarı veriyordu | Genel hata kodu | ✅ |
| S-12 | Düşük | Çalınmış oturumla hesap silinebilirdi | Son 10 dk içinde giriş şartı (`reauth_required`) | ✅ |
| S-13 | Düşük | Çapraz kaynaklı çıkış isteği | Origin/Host kontrolü | ✅ |
| S-14 | Düşük | Fotoğraf URL yol kodlaması | `encodeURIComponent` | ✅ |
| S-15 | Düşük | CI iş akışı yetkileri geniş | Varsayılan `contents: read`; yazma yalnızca gereken işlerde | ✅ |
| S-16 | Düşük | PayTR'ye kullanıcı UUID'i gidiyordu | Tuzlu SHA-256 takma ad | ✅ |
| S-17 | Bilgi | `list_venues` NaN koordinatla hata | Geçersiz konum yok sayılır; LIKE joker kaçışı | ✅ |
| S-18 | Yüksek | İşletme MFA'sı yalnızca panel arayüzünde zorlanıyordu: çalınan şifreyle alınan `aal1` oturum (mobil e-posta girişi, doğrudan PostgREST) TOTP'yi atlayıp tüm işletme yetkilerine (rezervasyon/ödeme okuma, müşteri telefonu, IBAN, saha/saat/fiyat yazma, fotoğraf yükleme, işletme RPC'leri) ulaşıyordu | `owner_mfa_satisfied()`: doğrulanmış MFA faktörü olan işletme için `aal2` şart; `is_venue_owner()`, `venue_is_visible()`, `venues` politikaları, `get_availability`, `owner_customer_contacts` bunu ister (A107–A107j, test 60) | ✅ 20261122100000 |
| M-01 | Orta | Mobil oturum düz depolamadaydı | `SecureLocalStorage` (Keychain / EncryptedSharedPreferences) | ✅ |
| M-02 | Orta | Ödeme WebView her adrese gidebiliyordu | Ana çerçevede yalnızca `*.paytr.com` + sonuç adresi | ✅ (3DS: VERIFY) |
| M-03 | Bilgi | Release sertleştirme | Kod karartma, yedekleme kapalı, cleartext kapalı | ✅ |
| M-04 | Bilgi | Sertifika sabitleme | Bilinçli olarak yapılmıyor (gerekçe THREAT_MODEL'de) | — |

## Açık doğrulamalar (VERIFY)
- PayTR aynı `merchant_oid` için `failed`→`success` gönderiyor mu? (F-01 her iki durumda da güvenli)
- Supabase Edge'de gerçek istemci IP'si hangi başlıkta? (S-09)
- Bazı bankaların 3DS sayfası ana çerçeveyi yönlendiriyor mu? (M-02; PayTR test kartıyla denenecek)
- Supabase planında sızdırılmış parola koruması ve ağ kısıtlaması var mı? (BASELINE)
- Barındırılan Supabase'de `auth.mfa_factors` kolonları (`user_id`, `status` = `verified`) ve migration rolünün (`postgres`) bu tabloyu okuma izni; her erişim JWT'sinde `aal` claim'i bulunması. (S-18; claim yoksa `aal1` sayılır, yani güvenli tarafta kalır)

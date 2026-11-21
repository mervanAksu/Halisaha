# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/). Sürümleme: SemVer.

## [Unreleased]
### Changed (2026-11-21, ADR-10)
- Yeni tasarım dili **"Skorbord"**: mürekkep siyahı + kâğıt zemin, tek neon vurgu (voltaj `#D4FF3A`), başlık ve sayılarda Barlow Condensed. Seçili saat voltaj dolguyla, ortadaki "Keşfet" butonu voltaj topla gösteriliyor. Koyu mod aynı dilde.
- Yeni uygulama ikonu (eğik "R" + voltaj noktası), açılış ekranı ve Play tanıtım görseli. Web paneli ve yasal sayfalar aynı renklere geçti; panelde "Halısaha" adı "RÖVANŞ" oldu.
- Kontrast testleri yeni tokenlara güncellendi.

### Added (2026-11-21)
- Marka **Rövanş** (`com.rovans.app`): özgün ikon, açılış ekranı, Play tanıtım görseli; açık "Temiz Çim" + koyu "Gece Maçı" teması, erişilebilirlik kontrast testleri.
- Uygulama içi **işletmeci paneli** (Bugün takvimi, telefon rezervasyonu / saat kapatma, rezervasyonlar, sahalar, çalışma saatleri) + web demosunda denenebilir işletmeci modu.
- Android/iOS iskeleti, imza kancası, kod karartmalı sürüm derlemesi (APK/AAB → GitHub Releases, iOS imzasız derleme), mağaza ekran görüntüsü üretimi, yasal ve destek sayfaları, `store/LISTING.md`, `docs/RELEASE.md`.
- Panelde MFA (TOTP), IBAN doğrulama, denetim kaydı ekranı; isteğe bağlı Turnstile captcha.
- Güvenlik CI'ı: CodeQL, gitleaks, bağımlılık denetimi, Dependabot, 114 saldırılık kırmızı takım paketi.

### Security (2026-11-21, kırmızı takım)
- 10 kanıtlanmış (F-01…F-10) ve 17+5 statik (S-01…S-17, M-01…M-05) bulgu kapatıldı; ayrıntı `security/FINDINGS.md`. Öne çıkanlar: başarısız→başarılı ödeme bildirimi yutulmuyor, iptal süresi rezervasyona sabit, PayTR anahtarı olmayan saha yayına alınamıyor, PayTR test modu açıkça seçilmeli, panel Next.js RCE yaması, admin için MFA zorunlu.

### Security
- **Kritik:** Supabase'in varsayılan fonksiyon yetkileri, iç fonksiyonları (`confirm_payment`, `prepare_account_deletion`, `mark_refunded` …) anon ve authenticated rollerine açıyordu. Müşteri ödeme yapmadan rezervasyonunu onaylatabilirdi. Tüm fonksiyonlar deny-by-default yapıldı, allow-list ve test (30a) eklendi. Test ortamı artık Supabase varsayılanlarını taklit ediyor.
- Geç gelen ödeme başlamış maçı onaylamıyor, iade ediliyor. İade işi çift iadeye karşı atomik talep ediyor, tutar tahsilatla sınırlı.
- Tutma istismarına karşı kullanıcı başına kilit, saatlik kota ve aktif rezervasyon sınırı eklendi (kaporasız sahalar dahil). Ödeme denemesi rezervasyon başına en fazla 5.
- KVKK: işletmeler müşteri profil satırlarını göremiyor. Yalnızca ad ve telefon `owner_customer_contacts` ile alınıyor. Silinen kullanıcı kimliği `cancelled_by` alanından da temizleniyor.
- Fotoğraf bucket'ı yalnızca 5 MB'a kadar JPEG, PNG ve WebP kabul ediyor. Panelde oturum kapatma POST ile yapılıyor.

### Fixed
- CI: GitHub Actions'ta dört iş de yeşil (SQL testleri, Flutter analyze ve 39 test, panel typecheck ve lint, gizli bilgi taraması). Panelde `@supabase/ssr` 0.12'ye yükseltildi (supabase-js 2.119 tipleriyle uyum).
- Müsaitlik ekranı 15 dakika içinde başlayan slotları artık 'geçmiş' gösteriyor (hold kuralıyla tutarlı).
- Mobil ödeme sonucu, gecikmiş ödemede yanlışlıkla 'başarısız' demiyor; başarısız ödemede 2 dk beklemiyor.
- Gece yarısını aşan sahalarda 00:00–06:00 arası slotlar mobilde ('Dün gece') ve panelde ('Bugün') erişilebilir.
- İşletme başlamış maçı iptal edip iade tetikleyemiyor.
- `venues` tablosundaki komisyon oranı ve PayTR alt üye işyeri anahtarı anonim okumaya kapatıldı (kolon bazlı yetki + `admin_list_venues` RPC).

### Added
- Demo modu (`--dart-define=DEMO_MODE=true`): backend olmadan örnek sahalar ve sahte ödemeyle çalışan uygulama. GitHub Pages web önizlemesi (`.github/workflows/web-preview.yml`).
- Flutter müşteri uygulaması: OTP girişi, saha listesi/detay, slot seçimi, kapora ödemesi (PayTR WebView), maçlarım, favoriler, destek, profil, hesap silme.
- İşletme/admin web paneli: takvim, manuel rezervasyon ve saat kapatma, tesis/saha yönetimi, ödeme bilgileri, saha onayı, iade listesi.
- Çok ajanlı geliştirme altyapısı: MASTER_PROMPT, CLAUDE.md, AGENTS.md, 7 alt ajan, 5 skill.
- Ürün dokümanları: PRD, veri modeli, API sözleşmesi, tasarım dili, ADR kayıtları.
- Supabase şeması: sahalar, saha alanları, çalışma saatleri (gece yarısını aşabilir), rezervasyonlar, ödemeler, favoriler.
- Çift rezervasyonu DB seviyesinde engelleyen exclusion constraint; 10 dk ödeme tutma; kullanıcı başına 2 tutma sınırı.
- RLS politikaları ve RPC'ler: müsaitlik, tutma, iptal (iade penceresi), işletme manuel rezervasyon/kapatma, admin onayı.
- Supabase CLI gerektirmeyen SQL test koşucusu ve 17 senaryoluk rezervasyon/ödeme/hesap silme testi.
- PayTR Edge Function'ları: ödeme başlatma (iFrame token), hash doğrulamalı idempotent callback, iade işi.
- Uygulama içi hesap silme (gelecek rezervasyonlar iptal, mali kayıt anonimleştirilir).

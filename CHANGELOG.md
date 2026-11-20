# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/). Sürümleme: SemVer.

## [Unreleased]
### Security
- **Kritik:** Supabase'in varsayılan fonksiyon yetkileri, iç fonksiyonları (`confirm_payment`, `prepare_account_deletion`, `mark_refunded` …) anon ve authenticated rollerine açıyordu. Müşteri ödeme yapmadan rezervasyonunu onaylatabilirdi. Tüm fonksiyonlar deny-by-default yapıldı, allow-list ve test (30a) eklendi. Test ortamı artık Supabase varsayılanlarını taklit ediyor.
- Geç gelen ödeme başlamış maçı onaylamıyor, iade ediliyor. İade işi çift iadeye karşı atomik talep ediyor, tutar tahsilatla sınırlı.
- Tutma istismarına karşı kullanıcı başına kilit, saatlik kota ve aktif rezervasyon sınırı eklendi (kaporasız sahalar dahil). Ödeme denemesi rezervasyon başına en fazla 5.
- KVKK: işletmeler müşteri profil satırlarını göremiyor. Yalnızca ad ve telefon `owner_customer_contacts` ile alınıyor. Silinen kullanıcı kimliği `cancelled_by` alanından da temizleniyor.
- Fotoğraf bucket'ı yalnızca 5 MB'a kadar JPEG, PNG ve WebP kabul ediyor. Panelde oturum kapatma POST ile yapılıyor.

### Fixed
- Müsaitlik ekranı 15 dakika içinde başlayan slotları artık 'geçmiş' gösteriyor (hold kuralıyla tutarlı).
- Mobil ödeme sonucu, gecikmiş ödemede yanlışlıkla 'başarısız' demiyor; başarısız ödemede 2 dk beklemiyor.
- Gece yarısını aşan sahalarda 00:00–06:00 arası slotlar mobilde ('Dün gece') ve panelde ('Bugün') erişilebilir.
- İşletme başlamış maçı iptal edip iade tetikleyemiyor.
- `venues` tablosundaki komisyon oranı ve PayTR alt üye işyeri anahtarı anonim okumaya kapatıldı (kolon bazlı yetki + `admin_list_venues` RPC).

### Added
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

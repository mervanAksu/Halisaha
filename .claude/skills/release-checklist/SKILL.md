---
name: release-checklist
description: Mobil uygulamayı TestFlight, Google Play kapalı test ve mağaza yayınına hazırlarken izlenecek kontrol listesi.
---
# Yayın kontrol listesi

## Hesaplar (lansmandan 3-4 hafta önce)
- [ ] Şirket kuruldu, vergi levhası alındı (kurumsal mağaza hesabı ve PayTR için gerekli)
- [ ] D-U-N-S numarası alındı (Apple kurumsal hesap)
- [ ] Apple Developer Program (99 USD/yıl), Google Play Console (25 USD, tek seferlik)
- [ ] Google kişisel hesap kullanılıyorsa: 12 test kullanıcısı ile **14 gün kesintisiz** kapalı test gerekir
- [ ] PayTR canlı hesap onayı ve callback URL tanımı

## Uygulama
- [ ] `flutter build appbundle --release` / `flutter build ipa --release` başarılı
- [ ] Sürüm numarası arttırıldı (`pubspec.yaml` `version:`)
- [ ] Canlı ortam değişkenleri (`env/prod.json`) doğru, `test_mode=0`
- [ ] Uygulama içi hesap silme çalışıyor (Apple 5.1.1(v))
- [ ] KVKK aydınlatma metni, gizlilik politikası, kullanım koşulları ve mesafeli satış sözleşmesi linkleri çalışıyor
- [ ] Gizlilik politikası URL'si herkese açık bir web sayfasında yayında
- [ ] App Store "App Privacy" ve Play "Data safety" formları dolduruldu (telefon, ad, konum, ödeme)
- [ ] App Review için demo hesap ve test kartı açıklaması yazıldı
- [ ] Konum izni metni (`NSLocationWhenInUseUsageDescription`) Türkçe ve gerekçeli

## Mağaza sayfası (ASO)
- [ ] Başlık ve alt başlık anahtar kelime içeriyor ("halı saha", "rezervasyon")
- [ ] 6,7" ve 6,5" iPhone ile Android ekran görüntüleri hazır
- [ ] Kısa ve uzun açıklama, destek URL'si, destek e-postası hazır

## Yayından sonra
- [ ] Crash raporlama (Firebase Crashlytics veya Sentry) aktif
- [ ] İlk 72 saat yorumlar ve çökme raporları günlük kontrol ediliyor
- [ ] `CHANGELOG.md` içinde sürüm etiketi var ve `git tag vX.Y.Z` atıldı

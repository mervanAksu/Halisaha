# Tasarım Dili — Rövanş

Seçilen yön (2026-11-21, ADR-10): **"Skorbord"**. Mürekkep siyahı ve kâğıt beyazı zemin üstünde tek bir neon "voltaj"
vurgusu var. Açık tema varsayılan, sistem koyu modunda koyu tema. ADR-8'deki "Temiz Çim / Gece Maçı" yönünün yerini aldı.
İlham: `flutter/samples` reposundaki Compass örneği (fotoğrafla açılan başlık, buzlu cam etiketler, sabit alt onay çubuğu,
sade zemin). Kod, renk ve görseller oradan kopyalanmadı.
Altyapı: Material 3, kendi `ThemeData`/`ColorScheme` tanımlarımız (ek UI kit yok). Akış referans uygulamadan alındı;
renk, tipografi, ikon ve metinler özgündür. Referansın marka, logo ve görselleri kullanılmaz.

## Marka
- Ad: **Rövanş** (`AppConfig.appName`). Mağaza başlığı: "Rövanş: Halı Saha Rezervasyon".
- Paket kimliği: `com.rovans.app` (Android applicationId ve iOS bundle ID). **Değiştirilemez.**
- İkon: `apps/mobile/assets/branding/icon.svg`. Mürekkep zemin, eğik ve dar kalın beyaz "R", sağ altında voltaj rengi top noktası.
  PNG'ler `rsvg-convert` ile üretilir; Android/iOS ikonları "Scaffold native platforms" iş akışıyla yeniden oluşturulur.
- Yazı logosu: "RÖVANŞ" (Barlow Condensed 800 italik, büyük harf) + voltaj noktası.

## Renk tokenları

| Semantik token | Açık | Koyu | Kullanım |
|---|---|---|---|
| `brand` | `#0E0F0C` | `#F4F4F0` | Başlık, logo yazısı |
| `primary` (buton zemini) | `#0E0F0C` | `#F4F4F0` | Birincil buton (siyah / koyu modda kırık beyaz) |
| `onPrimary` | `#FFFFFF` | `#0E0F0C` | Birincil buton yazısı |
| `highlight` (voltaj) | `#D4FF3A` | `#D4FF3A` | Seçili saat, "N boş saat" rozeti, orta navigasyon topu |
| `onHighlight` | `#0E0F0C` | `#0E0F0C` | Voltaj üstünde **yalnızca** mürekkep yazı |
| `action` (olumlu yazı/ikon) | `#1E5A37` | `#8FE0A6` | Onaylı rozet, ödenen kapora, konum ikonu |
| `onAction` | `#FFFFFF` | `#0E0F0C` | |
| `accent` | `#0E0F0C` | `#D4FF3A` | İlerleme, seçili halka, ikon |
| `accentSoft` | `#EEF7C8` | `#2A3012` | Bilgi kutusu, seçili çip |
| `surface` (sayfa) | `#F7F7F3` | `#0E0F0C` | |
| `card` | `#FFFFFF` | `#1A1B17` | |
| `textPrimary` | `#0E0F0C` | `#F4F4F0` | |
| `textSecondary` | `#5C5F57` | `#A4A69E` | |
| `border` | `#E3E3DC` | `#2C2E27` | Boş saat çerçevesi dahil |
| `warning` / `warningSoft` | `#8A5300` / `#FFF4D6` | `#F5C84B` / `#3A2F10` | Ödeme bekleniyor |
| `danger` | `#C4232F` | `#FF6B73` | İptal, hesap silme ("kırmızı kart") |
| `disabledSlot` | `#F1F1EC` / yazı `#5C5F57` | `#23241F` / yazı `#9A9C93` | Dolu saat |

Kontrast kuralı: voltaj (`#D4FF3A`) üzerine beyaz yazı **yazılmaz** (1.2:1); her zaman `onHighlight` kullanılır.
Tüm yazı/zemin çiftleri WCAG AA'yı (≥4.5:1) geçer; `test/theme_contrast_test.dart` bunu her CI'da doğrular.
Web panelinde `accent` çim yeşili `#1E5A37`'dir (üstünde beyaz yazı geçer), `volt` yalnızca dolgu olarak kullanılır.
## Tipografi
- Gövde: **Inter**. Sayfa başlığı, saat, fiyat ve büyük sayılar: **Barlow Condensed** 700–800 (skor tabelası hissi).
- Ölçek: büyük başlık 34/800, sayfa başlığı 24/800 (condensed), bölüm 17/600, gövde 15/400, ikincil 13/400, rozet 13/700.
- Dinamik yazı boyutu 200%'e kadar bozulmamalı. Büyük yazıda slot ızgarası 3 sütundan 2 sütuna düşer.

## Bileşen kuralları (araştırma bulgularından)
- **Dokunma hedefi** en az 48×48 dp (slotlar, ikon butonlar, favori kalbi).
- **Slot ızgarası:** Akşam / Öğleden sonra / Sabah-gece grupları; "Akşam" ilk sırada. Dolu slot gri zeminle ve **"Dolu" etiketiyle** gösterilir, üstü çizilmez. Geçmiş slot gizlenir.
- **Kapora görünürlüğü:** Slot seçicinin altındaki özet çubuğunda "Şimdi 750 ₺ kapora · kalan sahada" yazar. Ödeme adımında ilk kez ortaya çıkmaz.
- **İptal politikası** tek cümleyle gösterilir: "Maça 24 saatten fazla varsa kapora iade edilir."
- **Boş durum:** Seçilen günde boş saat yoksa "En yakın boş gün: Pazartesi" butonu gösterilir.
- **Onay ekranı:** Tarih ve gün, dokunulabilir adres, ödenen ve kalan tutar, iptal politikası. "Takvime ekle" v1.1'de gelecek.
- **Güven sinyalleri:** "Güvenli ödeme · PayTR" satırı, işletme onaylı rozeti (venue.status=active).
- **Saat durumları:** boş = kart zemini + ince çerçeve; seçili = voltaj dolgu + mürekkep halka + kalın yazı;
  dolu = gri zemin + "Dolu"; ödeme bekliyor = `warningSoft`.
- **Fotoğraf başlığı:** saha adı fotoğrafın üstünde, altta koyu geçişle; özellikler buzlu cam etiketlerle (7+7, kapalı, mesafe).
- Köşeler: buton 14, kart 16, slot 12. Boşluk ölçeği 4'ün katları.
- Alt navigasyon: Favorilerim · Maçlarım · [ortada Keşfet] · Destek · Profilim.

## İşletmeci modu (uygulama içi)
- `role in (owner, admin)` olan kullanıcıda Profil'de "İşletmeci paneli" girişi görünür. Bu giriş ayrı bir kabuk açar: **Bugün** (saha × saat takvimi), **Rezervasyonlar**, **Sahalarım**, **Saatler**.
- İşletmeci ekranları **her zaman açık temadadır** (30-55 yaş, gün ışığında kullanım).
- Renk kodları: uygulama rezervasyonu = `action` (çim yeşili), telefon rezervasyonu = `primary` (mürekkep), kapalı saat = gri çizgili, ödeme bekleniyor = `warning`.

## Web paneli
- Tailwind config aynı açık tokenları kullanır. Ayrıntılı ayarlar (fotoğraflar, IBAN, admin) web panelindedir.

# Tasarım Dili — Rövanş

Seçilen yön (2026-11-21, ADR-8): **A "Temiz Çim" (açık, varsayılan) + B "Gece Maçı" (koyu, sistem koyu modunda)**.
Altyapı: Material 3, kendi `ThemeData`/`ColorScheme` tanımlarımız (ek UI kit yok). Akış referans uygulamadan alındı;
renk, tipografi, ikon ve metinler özgündür. Referansın marka, logo ve görselleri kullanılmaz.

## Marka
- Ad: **Rövanş** (`AppConfig.appName`). Mağaza başlığı: "Rövanş: Halı Saha Rezervasyon".
- Paket kimliği: `com.rovans.app` (Android applicationId ve iOS bundle ID). **Değiştirilemez.**
- İkon: `apps/mobile/assets/branding/icon.svg`. Lacivert→koyu yeşil zemin, beyaz top, etrafında yeşil "rövanş" oku.

## Renk tokenları

| Semantik token | Açık (A) | Koyu (B) | Kullanım |
|---|---|---|---|
| `brand` | `#0F2A44` | `#E8F1EC` | Başlık, logo yazısı |
| `primary` (buton zemini) | `#0F2A44` | `#2EE08A` | Birincil buton |
| `onPrimary` | `#FFFFFF` | `#06130D` | Birincil buton yazısı |
| `action` (müsait slot, fiyat rozeti zemini) | `#0A7D4B` | `#2EE08A` | Beyaz/koyu yazıyla AA geçer |
| `onAction` | `#FFFFFF` | `#06130D` | |
| `accent` (yalnızca dolgu/ikon, **yazı zemini değil**) | `#22B573` | `#2EE08A` | İkon, ilerleme, seçili halka |
| `accentSoft` | `#E6F7EF` | `#173226` | Seçili slot zemini, bilgi kutusu |
| `surface` (sayfa) | `#F5F7FA` | `#0B1410` | |
| `card` | `#FFFFFF` | `#14201A` | |
| `textPrimary` | `#111827` | `#E8F1EC` | |
| `textSecondary` | `#6B7280` | `#9FB3A8` | |
| `border` | `#E5E7EB` | `#24342C` | |
| `warning` | `#B45309` | `#F5C84B` | Ödeme bekleniyor |
| `danger` | `#C81E3A` | `#FF5C73` | İptal, hesap silme |
| `disabledSlot` | `#F1F2F4` / yazı `#6B7280` | `#1E2A24` / yazı `#8FA89A` | Dolu slot |

Kontrast kuralı: `#22B573` üzerine beyaz yazı **yazılmaz** (2.65:1). Yeşil zeminde yazı varsa `action` tonu kullanılır.
Tüm yazı/zemin çiftleri WCAG AA (≥4.5:1, büyük yazı ≥3:1) geçmelidir.

## Tipografi
- Gövde: **Inter**. Saat, fiyat ve büyük sayılar: **Barlow Condensed** 600–700 (skorbord hissi).
- Ölçek: başlık 22/700, bölüm 17/600, gövde 15/400, ikincil 13/400, rozet 13/700.
- Dinamik yazı boyutu 200%'e kadar bozulmamalı. Büyük yazıda slot ızgarası 3 sütundan 2 sütuna düşer.

## Bileşen kuralları (araştırma bulgularından)
- **Dokunma hedefi** en az 48×48 dp (slotlar, ikon butonlar, favori kalbi).
- **Slot ızgarası:** Akşam / Öğleden sonra / Sabah-gece grupları; "Akşam" ilk sırada. Dolu slot gri zeminle ve **"Dolu" etiketiyle** gösterilir, üstü çizilmez. Geçmiş slot gizlenir.
- **Kapora görünürlüğü:** Slot seçicinin altındaki özet çubuğunda "Şimdi 750 ₺ kapora · kalan sahada" yazar. Ödeme adımında ilk kez ortaya çıkmaz.
- **İptal politikası** tek cümleyle gösterilir: "Maça 24 saatten fazla varsa kapora iade edilir."
- **Boş durum:** Seçilen günde boş saat yoksa "En yakın boş gün: Pazartesi" butonu gösterilir.
- **Onay ekranı:** Tarih ve gün, dokunulabilir adres, ödenen ve kalan tutar, iptal politikası. "Takvime ekle" v1.1'de gelecek.
- **Güven sinyalleri:** "Güvenli ödeme · PayTR" satırı, işletme onaylı rozeti (venue.status=active).
- Köşeler: buton 12, kart 16, slot 10. Boşluk ölçeği 4'ün katları.
- Alt navigasyon: Favorilerim · Maçlarım · [ortada Keşfet] · Destek · Profilim.

## İşletmeci modu (uygulama içi)
- `role in (owner, admin)` olan kullanıcıda Profil'de "İşletmeci paneli" girişi görünür. Bu giriş ayrı bir kabuk açar: **Bugün** (saha × saat takvimi), **Rezervasyonlar**, **Sahalarım**, **Saatler**.
- İşletmeci ekranları **her zaman açık temadadır** (30-55 yaş, gün ışığında kullanım).
- Renk kodları: uygulama rezervasyonu = `action`, telefon rezervasyonu = `primary`, kapalı saat = gri çizgili, ödeme bekleniyor = `warning`.

## Web paneli
- Tailwind config aynı açık tokenları kullanır. Ayrıntılı ayarlar (fotoğraflar, IBAN, admin) web panelindedir.

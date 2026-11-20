# Tasarım Dili

Referans uygulamadan **akış** alınır (alt navigasyon + ortada belirgin buton, kart listesi, sekmeli maçlar). Renk,
tipografi, ikon dili ve metinler özgündür. Referansın marka adı, logo ve görselleri kullanılmaz.

## Marka (geçici)
- Çalışma adı: **Halısaha** (`AppConfig.appName`). Marka adı kesinleşince tek yerden değişir.

## Renk tokenları
| Token | Hex | Kullanım |
|---|---|---|
| `primary` | `#0F2A44` | Başlıklar, birincil buton zemini, aktif sekme |
| `accent` | `#22B573` | Fiyat rozeti, "müsait" slot, onay durumları, orta buton halkası |
| `accentSoft` | `#E6F7EF` | Seçili slot zemini, bilgi kutuları |
| `surface` | `#F5F7FA` | Sayfa zemini |
| `card` | `#FFFFFF` | Kartlar |
| `textPrimary` | `#111827` | |
| `textSecondary` | `#6B7280` | |
| `border` | `#E5E7EB` | |
| `warning` | `#F59E0B` | Ödeme bekleniyor, çıkış ikonu |
| `danger` | `#E11D48` | Hesap silme, iptal, dolu slot çizgisi |

Koyu tema v1.1'de eklenecek. Tokenlar buna hazır tutulur.

## Tipografi
- Font: **Inter** (google_fonts). Başlık 22/700, bölüm başlığı 17/600, gövde 15/400, ikincil metin 13/400, rozet 13/700.

## Bileşenler
- **Alt navigasyon:** Favorilerim · Maçlarım · [ortada yuvarlak ana sayfa/keşfet butonu] · Destek · Profilim.
- **Saha kartı:** 16:9 kapak fotoğrafı (üst köşeler 16 radius), ad, saat ikonuyla bugünkü saatler, konum ikonuyla ilçe, sağ üstte `accent` fiyat rozeti ("3.500 ₺/saat"), tam genişlik birincil buton.
- **Slot ızgarası:** 3 sütun. Müsait: beyaz zemin + `accent` çerçeve. Seçili: `accentSoft` zemin. Dolu: gri zemin + üstü çizili. Geçmiş: gizli.
- **Durum etiketi (booking):** Onaylandı (accent) · Ödeme bekleniyor (warning) · İptal (danger) · Tamamlandı (gri) · Gelmedi (danger, outline).
- **Boş durum:** ikon + tek cümle + birincil buton.
- Köşe yarıçapı 12 (buton), 16 (kart). Boşluklar 4'ün katı (8/12/16/24).

## Panel
- Aynı renk tokenları Tailwind config'te tanımlıdır. Sol menü + içerik. Takvimde renkler: app=`accent`, manuel=`primary`, kapalı=gri desen, bekleyen=`warning`.

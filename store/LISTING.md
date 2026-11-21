# Mağaza Kaydı — Rövanş (TR)

Bu dosyadaki metinler App Store Connect ve Google Play Console formlarına **kopyala-yapıştır** girilecek şekilde hazırlandı.
Karakter sınırları parantez içinde; her alan sınırın altında.

## Kimlik
| Alan | Değer |
|---|---|
| Uygulama adı (App Store ≤30, Play ≤30) | `Rövanş: Halı Saha Rezervasyon` (29) |
| Paket kimliği / Bundle ID | `com.rovans.app` |
| Birincil kategori | Spor (Sports) · ikincil: Yaşam Tarzı |
| Fiyat | Ücretsiz (uygulama içi satın alma yok; kapora fiziksel hizmet bedelidir — Apple 3.1.3(e)) |
| Yaş sınırı | 4+ / PEGI 3 (kullanıcı içeriği yok, sohbet yok) — ama hizmet koşulları 18+ |
| Gizlilik politikası URL | https://mervanaksu.github.io/Halisaha/legal/gizlilik.html |
| Destek URL | https://mervanaksu.github.io/Halisaha/legal/destek.html |
| Hesap silme URL (Play zorunlu) | https://mervanaksu.github.io/Halisaha/legal/hesap-silme.html |
| Pazarlama URL | https://mervanaksu.github.io/Halisaha/legal/ |

## App Store
**Alt başlık (≤30):** `Boş saati gör, kaporayla tut` (28)

**Tanıtım metni (≤170):**
Akşam maçı için telefon trafiğine son. Yakınındaki halı sahaların boş saatlerini gör, kaporanı öde, saatin anında senin olsun.

**Anahtar kelimeler (≤100, virgülle, boşluksuz):**
`halısaha,halı saha,rezervasyon,maç,futbol,saha kirala,kapora,5v5,7v7,spor,takım,kiralık saha` (92)

**Açıklama (≤4000):**
Rövanş ile halı saha ayarlamak artık bir dakika sürüyor.

YAKINDAKİ SAHALAR, GERÇEK BOŞ SAATLER
• Konumuna en yakın halı sahaları listele, ilçeye göre filtrele.
• Sahanın fotoğraflarını, olanaklarını (otopark, duş, soyunma odası) ve fiyatını gör.
• 14 gün ileriye kadar hangi saatlerin boş olduğunu anlık gör.

KAPORAYLA ANINDA REZERVASYON
• Saatini seç, toplam ücreti ve şimdi ödenecek kaporayı açıkça gör.
• Kaporanı güvenli ödeme altyapısıyla öde; kart bilgilerin bize hiç ulaşmaz.
• Ödeme onaylandığı anda saat senin; aynı saati başkası alamaz.

MAÇLARIM
• Gelecek ve geçmiş maçlarını tek ekranda takip et.
• İptal süresi dolmadan iptal edersen kaporan iade edilir — bunu iptal etmeden önce görürsün.

İŞLETMELER İÇİN
• Halı saha sahipleri aynı uygulamadan "İşletmeci paneli"ne girerek günün programını görür, telefonla gelen rezervasyonları ve kapalı saatleri tek dokunuşla ekler.
• Kapora sayesinde gelmeyen takım (no-show) kaybı azalır.

Gizlilik: Konumun yalnızca cihazında kullanılır, reklam takibi yapılmaz. Hesabını uygulama içinden istediğin an silebilirsin.

**İnceleme notları (App Review Information):**
```
Demo login: phone +90 555 000 00 99, SMS code 123456 (test number configured in our auth provider).
Venue-owner features: Profile → "İşletmeci paneli" (the demo account is also an owner of two sample venues).
Payments: deposits are for a physical service (pitch rental) consumed outside the app → guideline 3.1.3(e);
payment is processed by PayTR (licensed Turkish payment institution) in a web view; test card in sandbox:
[PAYTR TEST KARTI]. Account deletion: Profile → "Hesabımı sil" (5.1.1(v)).
```

## Google Play
**Kısa açıklama (≤80):** `Yakındaki halı sahaların boş saatini gör, kaporayla anında rezerve et.` (70)
**Uzun açıklama:** App Store açıklamasının aynısı.

## Gizlilik formları

### App Store — App Privacy ("Uygulama Gizliliği")
| Veri türü | Toplanıyor mu | Kimliğe bağlı | Takip | Amaç |
|---|---|---|---|---|
| Ad | Evet | Evet | Hayır | Uygulama işlevi |
| Telefon numarası | Evet | Evet | Hayır | Uygulama işlevi, hesap |
| Satın alma geçmişi (rezervasyon/kapora) | Evet | Evet | Hayır | Uygulama işlevi |
| Konum (yaklaşık) | **Hayır** (cihazda kalır, sunucuya gönderilmez) | — | — | — |
| Ödeme bilgisi (kart) | **Hayır** (PayTR toplar, biz görmeyiz) | — | — | — |
| Kullanıcı kimliği | Evet | Evet | Hayır | Uygulama işlevi |
| Teşhis (çökme) | Crashlytics/Sentry eklenirse: Evet, kimliğe bağlı değil | | | |
"Takip (tracking)" — **Hayır**. ATT izni gerekmez.

### Google Play — Data safety
- Veri şifreli aktarılıyor: **Evet** · Kullanıcı verinin silinmesini isteyebilir: **Evet** (uygulama içi + URL)
- Toplanan: Kişisel bilgi → Ad, Telefon numarası (Hesap yönetimi, Uygulama işlevi; zorunlu)
- Finansal bilgi → Satın alma geçmişi (Uygulama işlevi). Kart bilgileri: ödeme işlemcisi tarafından toplanır, uygulama tarafından değil.
- Konum → **Toplanmıyor** (yalnızca cihazda işleniyor; Play tanımına göre "sunucuya gönderilmeyen veri toplanmış sayılmaz")
- Paylaşılan: Ad + telefon rezervasyon yapılan işletmeyle (Uygulama işlevi). Hizmet sağlayıcılara aktarım "paylaşım" sayılmaz.

### İçerik derecelendirme (IARC) anketi
Şiddet/cinsellik/kumar/kullanıcı içeriği/sohbet: **Hayır**. Kullanıcılar arası etkileşim: **Hayır**. Konum paylaşımı: **Hayır**. Dijital ürün satın alma: **Hayır** (fiziksel hizmet).

### Hedef kitle
18+ (Play "Target audience": 18 ve üzeri). Çocuklara yönelik değil.

## Görseller
- İkon: `apps/mobile/assets/branding/icon_1024.png` (1024×1024, saydamlık yok)
- Ekran görüntüleri: her push'ta otomatik üretilir → https://mervanaksu.github.io/Halisaha/store/
  - iOS 6.9" (1290×2796): `ios-6.9-light-*.png` (en az 3, en fazla 10)
  - Android telefon (1080×2340): `android-light-*.png` (en az 2)
- Play "Feature graphic" (1024×500): `store/feature_graphic.png`

# Yayın Kılavuzu — Rövanş

Ücretsiz yolun son noktası ve ondan sonraki ücretli adımlar, sırasıyla. Her adımın yanında **kimin** yapacağı yazar.

## A. Ücretsiz yapılabilenler (tamamlandı / otomatik)
| # | Adım | Durum |
|---|---|---|
| 1 | Paket kimliği `com.rovans.app`, ad, ikon, açılış ekranı, izin metinleri | `scaffold-platforms` iş akışı |
| 2 | Android: imzalı (ya da test imzalı) APK + AAB, kod karartma (obfuscation) | `release-build` iş akışı → GitHub Releases |
| 3 | iOS: release derlemesi (imzasız) — derlendiğinin kanıtı | `release-build` (macOS runner, açık repoda ücretsiz) |
| 4 | Yasal sayfalar (gizlilik, KVKK, koşullar, mesafeli satış, hesap silme, destek) | https://mervanaksu.github.io/Halisaha/legal/ |
| 5 | Mağaza ekran görüntüleri (iOS 6.9", Android, açık + koyu) | https://mervanaksu.github.io/Halisaha/store/ |
| 6 | Mağaza metinleri, gizlilik formu cevapları, inceleme notları | `store/LISTING.md` |
| 7 | Web demo (müşteri + işletmeci modu) | https://mervanaksu.github.io/Halisaha/ |
| 8 | Android APK'yı işletmecilerin telefonuna doğrudan kurma (mağazasız) | Releases sayfasından `.apk` |

## B. Senin yapman gereken ücretsiz adımlar
1. **Yasal metinlerdeki köşeli parantezleri doldur** (`site/legal/*.html`): veri sorumlusu adı, adres, e-posta, telefon. Şirket kurulana kadar şahıs adın yazılabilir. Metinleri bir avukata okut.
2. **Supabase projesi aç (ücretsiz plan):** supabase.com → New project → bölge **Frankfurt (eu-central-1)** (KVKK yurt dışı aktarım için AB). Sonra:
   ```bash
   npm i -g supabase && supabase login && supabase link --project-ref <ref>
   supabase db push                       # tüm migration'lar
   supabase functions deploy paytr-callback --no-verify-jwt
   supabase functions deploy paytr-refund --no-verify-jwt
   supabase functions deploy paytr-create-payment delete-account
   ```
   Dashboard ayarları için `security/BASELINE.md` (MFA, sızdırılmış parola koruması, captcha, SMS limitleri).
3. **GitHub secrets ekle** (repo → Settings → Secrets and variables → Actions):
   - `PROD_SUPABASE_URL`, `PROD_SUPABASE_ANON_KEY` (anon key gizli değildir ama burada tutmak düzenlidir)
   - Android yükleme anahtarı (bir kez, kendi bilgisayarında; Android Studio kuruluysa `keytool` onun içinde gelir):
     ```powershell
     keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 4096 -validity 10000 -alias upload
     [Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
     ```
     → `ANDROID_KEYSTORE_BASE64` (panodaki metin), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (=upload), `ANDROID_KEY_PASSWORD`.
     **`upload-keystore.jks` dosyasını ve parolayı iki ayrı güvenli yerde yedekle; repoya asla koyma.** Kaybolursa Play destekten sıfırlatılabilir (Play App Signing).
4. Actions → **Release build** → Run workflow. Çıkan `.aab` Play'e, `.apk` doğrudan kuruluma.

## C. Ücretli adımlar (şirket kararına bağlı)
| Adım | Ücret | Not |
|---|---|---|
| Google Play Console | 25 USD tek sefer | Kişisel hesapta **12 test kullanıcısı × 14 gün kapalı test** zorunlu → önce "Kapalı test" kanalına AAB yükle, işletmecileri ve arkadaşlarını test kullanıcısı yap. Kurumsal hesapta bu şart yok (D-U-N-S gerekir). |
| Apple Developer Program | 99 USD / yıl | Gelince: App Store Connect'te `com.rovans.app` kaydı, `release-build`'e imzalama (fastlane match veya App Store Connect API anahtarı) eklenir, TestFlight'a yüklenir. |
| PayTR pazaryeri | İşlem başına komisyon | Şirket + vergi levhası gerekir. Gelene kadar **kaporasız mod** ile yayınlanabilir (aşağıda). |

## D. Kaporasız ilk sürüm seçeneği (ödeme altyapısı olmadan yayın)
Sahaların kaporası `0` olarak ayarlanırsa rezervasyon ödeme adımı olmadan anında onaylanır (`create_booking_hold`). Kötüye kullanıma karşı kullanıcı başına en fazla 4 aktif rezervasyon, saatte en fazla 6 deneme sınırı zaten var. Böylece şirket ve PayTR beklenmeden ilk işletmelerle canlı kullanıma başlanabilir; PayTR geldiğinde sahalar kaporaya geçirilir. (ADR-9)

## E. Her sürümde
`.claude/skills/release-checklist/SKILL.md` kontrol listesini uygula; `CHANGELOG.md`'de sürüm başlığı aç; `git tag vX.Y.Z && git push --tags` → `release-build` otomatik çalışır.

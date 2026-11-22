# Güvenlik Temel Çizgisi (Baseline)

> Her madde: **[Ücretsiz]** / **[Ücretli]** (plan veya eklenti gerekir) / **[Doğrula]** (plan kapsamı Supabase fiyat sayfasından teyit edilmeli).
> İlgili bulgu: `security/FINDINGS.md`. Canlıya çıkmadan önce ✱ işaretli maddeler zorunludur.

## 1. Supabase projesi (dashboard)

### Kimlik doğrulama
- [ ] ✱ **MFA (TOTP)** owner ve admin hesaplarında zorunlu. Panel `aal2` istemeli, `is_admin()` `aal2` kontrol etmeli (S-04). **[Ücretsiz]**. Telefonla MFA ayrı ücretli eklentidir **[Ücretli]**
- [ ] ✱ **Leaked password protection** (HaveIBeenPwned) açık, minimum şifre uzunluğu ≥ 12, harf+rakam+sembol şartı **[Doğrula: Pro ve üstü]**
- [ ] ✱ **CAPTCHA** (Cloudflare Turnstile veya hCaptcha): sign-in, sign-up ve OTP uçlarında. Mobil (OTP ve işletmeci e-posta/şifre girişi) ve panel `captchaToken` göndermeli (S-05, S-07) **[Ücretsiz]**
- [ ] ✱ **SMS hız limitleri**: Auth → Rate Limits. Saatlik OTP gönderimi düşürülmeli (ör. 30/saat/IP), OTP süresi ≤ 5 dk, OTP uzunluğu 6 **[Ücretsiz]**. SMS sağlayıcısı ücretlidir **[Ücretli]**
- [ ] ✱ SMS sağlayıcısında coğrafi kısıt: yalnızca `+90`. Toll-fraud/pumping koruması açık (S-07) **[Ücretli: sağlayıcıya göre]**
- [ ] **JWT süresi** ≤ 3600 sn (varsayılan). Refresh token rotation ve reuse detection açık. Inactivity timeout (owner/admin için 12 saat) **[Ücretsiz]**, oturum süresi sınırları **[Doğrula: Pro ve üstü]**
- [ ] E-posta kaydı kapalı kalmalı (`enable_signup=false`, owner'ları platform ekibi davet eder) ✓ **[Ücretsiz]**
- [ ] Custom SMTP (davet/şifre sıfırlama e-postaları, SPF/DKIM/DMARC) **[Ücretsiz: Supabase tarafı; SMTP servisi ücretli olabilir]**
- [ ] ✱ `config.toml` içindeki `test_otp` üretime itilmemeli. App Review numarası müşteri rolünde kalmalı, inceleme sonrası rotasyona girmeli (S-10) **[Ücretsiz]**
- [ ] Redirect URL allow-list yalnızca üretim panel alan adı (wildcard yok) **[Ücretsiz]**

### Veritabanı ve ağ
- [ ] ✱ **SSL enforcement** açık (yalnızca TLS ile DB bağlantısı) **[Ücretsiz]**
- [ ] **Network restrictions**: doğrudan Postgres bağlantısı yalnızca ofis/CI IP'lerinden (PostgREST'i etkilemez) **[Doğrula]**
- [ ] ✱ Supabase Security Advisor ve Performance Advisor uyarıları temiz: RLS kapalı tablo yok, `security definer` fonksiyonlarda `search_path` sabit **[Ücretsiz]**
- [ ] `pg_graphql` kullanılmıyorsa kapalı (ek saldırı yüzeyi) **[Ücretsiz]**
- [ ] Veritabanı şifresi güçlü ve kasada saklanıyor. `service_role` yalnızca Edge Function secrets'ta **[Ücretsiz]**
- [ ] ✱ **Günlük yedek** (7 gün saklama) **[Ücretli: Pro]**. Free planda indirilebilir yedek yok
- [ ] **PITR** (saniye düzeyinde geri dönüş). Ödeme verisi için önerilir **[Ücretli: eklenti, Pro + compute]**
- [ ] Yedekten geri dönüş tatbikatı her çeyrek: staging'e restore edip `run_local.sh` testlerini çalıştır **[Ücretsiz]**
- [ ] ✱ `CRON_SECRET` ve fonksiyon URL'leri **Supabase Vault**'ta. `cron.job` komutunda düz metin olmamalı (S-11) **[Ücretsiz]**
- [ ] Log Drains / log saklama, ödeme callback'leri için en az 90 gün **[Ücretli: Team/eklenti]**

### Edge Functions ve Storage
- [ ] ✱ `PAYTR_TEST_MODE` üretimde açıkça `0`. Fonksiyon değişken yoksa başlamamalı (S-01) **[Ücretsiz]**
- [ ] `verify_jwt=false` yalnızca `paytr-callback` ve `paytr-refund` için ✓ **[Ücretsiz]**
- [ ] Storage `venue-photos`: MIME allow-list + 5 MB ✓, liste (select) politikası anon'a kapalı ✓ **[Ücretsiz]**
- [ ] Supabase org üyelerinde 2FA zorunlu, en az yetki rolleri (Developer / Read-only) **[Ücretsiz]**, SSO **[Ücretli: Team]**
- [ ] Platform audit log'ları (dashboard işlemleri) **[Ücretli: Team]**

## 2. GitHub
- [ ] ✱ **Secret scanning + push protection** açık **[Ücretsiz: public repo; private repo için GitHub Advanced Security / Secret Protection ücretli]**
- [ ] ✱ **Dependabot alerts + security updates** (npm, pub, github-actions ekosistemleri için `dependabot.yml`) **[Ücretsiz]**
- [ ] **CodeQL** code scanning (JavaScript/TypeScript; Dart desteklenmiyor) **[Ücretsiz: public; private için ücretli GHAS / Code Security]**
- [ ] ✱ **Branch protection / ruleset** `main` için: PR zorunlu, en az 1 onay, CI (4 job + 40_attacks) yeşil, force-push ve silme kapalı, imzalı commit (önerilir) **[Ücretsiz: public; private'ta bazı kurallar Team planı ister]**
- [ ] ✱ Workflow'larda varsayılan `permissions: contents: read`, yazma yetkisi yalnızca gereken job'da (S-15) **[Ücretsiz]**
- [ ] Action'lar commit SHA'ya sabit, Dependabot `github-actions` güncellemeleri **[Ücretsiz]**
- [ ] `release` environment: required reviewers + yalnızca `v*` etiketleri. İmzalama anahtarı secrets'ı yalnızca bu environment'ta **[Ücretsiz: public; private'ta Team]**
- [ ] Organizasyonda 2FA zorunlu **[Ücretsiz]**
- [ ] ✱ Panel için `package-lock.json` commit, CI'da `npm ci` + `npm audit --audit-level=high`. Flutter için `pubspec.lock` commit edilmeli (şu an `.gitignore`'da; uygulama için lock dosyası tutulmalı) (S-02) **[Ücretsiz]**

## 3. Uygulama
- [ ] ✱ Release build'leri `--obfuscate --split-debug-info` ✓. Sembol dosyaları sınırlı erişimli saklanmalı **[Ücretsiz]**
- [ ] ✱ Oturum Keychain/Keystore'da (`SecureLocalStorage`, M-01). Android `allowBackup=false` ✓, `usesCleartextTraffic=false` ✓ **[Ücretsiz]**
- [ ] ✱ Ödeme WebView'i allow-list'li (M-02) ve 3DS akışı test kartlarıyla doğrulanmış **[Ücretsiz]**
- [ ] Play Integrity API / App Attest ile istemci doğrulama (v1.1) **[Ücretsiz: kota içinde]**
- [ ] Sertifika pinning yok (gerekçe: FINDINGS M-04) **[—]**
- [ ] ✱ Panel güvenlik başlıkları: CSP, HSTS, `frame-ancestors 'none'` (S-03) **[Ücretsiz]**
- [ ] ✱ Next.js ≥ 15.5.7 (veya yamalı 16.x), React yamalı sürüm (S-02) **[Ücretsiz]**
- [ ] Hata izleme (Sentry vb.) PII filtresiyle: telefon, e-posta ve IBAN scrub **[Ücretsiz katman / Ücretli]**

## 4. Operasyon

### Olay müdahalesi (incident response)
- [ ] ✱ Yazılı runbook: tespit → sınırlama → kök neden → düzeltme → bildirim. Sorumlu kişi ve yedeği belli **[Ücretsiz]**
- [ ] ✱ **KVKK ihlal bildirimi:** öğrenildikten sonra **72 saat** içinde Kurul'a, ilgili kişilere en kısa sürede. Şablon metinler hazır **[Ücretsiz]**
- [ ] Ödeme olayı: PayTR destek iletişim kanalı, şüpheli işlemde mağazayı test moduna alma veya ödemeleri durdurma kararı (feature flag: `create_booking_hold` kaporalı sahaları kapatır) **[Ücretsiz]**
- [ ] Alarmlar: `paytr-callback` 4xx/5xx artışı, `refund_processing`'te 1 saatten uzun kalan kayıt, saat başına `too_many_*` hata oranı, OTP gönderim sıçraması **[Ücretsiz / Ücretli: log drain]**

### Anahtar rotasyonu
| Sır | Nerede | Rotasyon | Tetikleyici |
|---|---|---|---|
| `service_role` / JWT secret | Supabase → API (yeni JWT signing keys) | 12 ay | Sızıntı şüphesi, ekipten ayrılan kişi |
| anon key | istemci build'leri | yalnızca JWT secret ile | aynı |
| `PAYTR_MERCHANT_KEY` / `SALT` | PayTR paneli → Supabase secrets | 12 ay | Sızıntı, ekipten ayrılan kişi |
| `CRON_SECRET` | Vault + function secret | 6 ay | Sızıntı |
| Android upload key | GitHub secrets | Play App Signing ile sıfırlanabilir | Sızıntı |
| DB şifresi | Supabase | 6 ay | Erişimi olan kişi ayrıldığında |
| Owner/admin şifreleri | kullanıcı | olay sonrası zorunlu reset | Hesap ele geçirme şüphesi |

- [ ] Rotasyon prosedürü bir kez staging'de denenmiş ve süresi ölçülmüş **[Ücretsiz]**
- [ ] Next.js RSC açığı (CVE-2025-66478) kapsamında yamasız sürüm hiç yayında olduysa panelin kullandığı tüm sırlar rotasyona girmeli **[Ücretsiz]**

### Süreç
- [ ] ✱ `supabase/tests/40_attacks.sql` CI'da koşuyor. Her düzeltmede ilgili `p_soft` → `false` **[Ücretsiz]**
- [ ] Ödeme, auth veya RLS değişikliğinde `security-reviewer` incelemesi (AGENTS.md) **[Ücretsiz]**
- [ ] Yılda bir harici sızma testi (canlıya çıkış öncesi bir kez) **[Ücretli]**
- [ ] VERBİS kaydı, aydınlatma metni ve açık rıza metinleri sürümlü; rıza olayları sunucu saatiyle (F-05) **[Ücretsiz]**

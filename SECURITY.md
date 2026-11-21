# Güvenlik Politikası

## Açık bildirme
Rövanş'ta bir güvenlik açığı bulduysan lütfen **herkese açık issue açma**. GitHub'ın "Report a vulnerability"
(Security → Advisories) özelliğini kullan veya destek e-posta adresine "Güvenlik" konulu ileti gönder.
72 saat içinde dönüş yapar, düzeltme yayınlanana kadar ayrıntıları gizli tutmanı rica ederiz.

## Kapsam
Mobil uygulama (`apps/mobile`), işletme paneli (`apps/owner_panel`), Supabase şeması ve Edge Functions (`supabase/`).
Kapsam dışı: sosyal mühendislik, fiziksel saldırılar, üçüncü taraf hizmetlerin (PayTR, Supabase) kendi açıkları.

## Nasıl korunuyoruz
Tehdit modeli: `security/THREAT_MODEL.md` · Bulgular ve durumları: `security/FINDINGS.md` · Temel ayarlar: `security/BASELINE.md`.
Her push'ta: CodeQL, gitleaks (tüm geçmiş), bağımlılık denetimi ve SQL saldırı paketi (`supabase/tests/40_attacks.sql`) çalışır.

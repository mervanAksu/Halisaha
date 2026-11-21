---
name: security-review
description: Auth, RLS, ödeme, kişisel veri veya yeni bir uç nokta ekleyen her değişiklikten önce ve sonra izlenecek güvenlik prosedürü (kırmızı takım döngüsü dahil).
---
# Güvenlik prosedürü

## Yazarken (her değişiklikte)
- **SQL fonksiyonu:** `security definer` + `set search_path = public` + içeride yetki kontrolü. `revoke all ... from public, anon, authenticated`, ardından yalnızca gereken role `grant`. Fonksiyon adı test 30a allow-list'ine eklenir.
- **Tablo:** RLS açık. Yazma tercihen RPC ile yapılır. Hassas kolonlar (komisyon, PayTR anahtarı, IBAN) **kolon izniyle** kapatılır; `select *` kullanılmaz.
- **Admin işlemleri:** `is_admin()` MFA (`aal2`) ister. Admin RPC'leri bu fonksiyonla korunur.
- **Para:** tutar daima DB'den alınır. Rezervasyonu yalnızca hash'i doğrulanmış PayTR bildirimi onaylar. `PAYTR_TEST_MODE` açıkça `0` ya da `1` olmalıdır.
- **Kişisel veri (KVKK):** en az veri, amaçla sınırlı erişim (`owner_customer_contacts` örneği). Telefon ve kimlik log'a yazılmaz. Onaylar `consent_events` tablosunda tutulur.
- **Edge Function:** girdi boyutu, içerik türü ve regex doğrulaması yapılır. Hata mesajı iç ayrıntı sızdırmaz. Yıkıcı işlemler yakın zamanda yeniden giriş ister.
- **Panel:** sunucu aksiyonları herkese açık uç noktalardır. Yetki RLS ve RPC ile, ayrıca bağlamda kontrol edilir. CSP ve güvenlik başlıkları kaldırılmaz.
- **Mobil:** oturum `SecureLocalStorage` içindedir. WebView izin listesi gevşetilmez. Dış URL'ler `isSafeExternalUrl` kontrolünden geçer.

## Bitirince
1. `./supabase/tests/run_local.sh` → `attack suite: N blocked, 0 open VULN` olmalıdır.
2. Değişiklik yeni bir saldırı yüzeyi açıyorsa `red-team` ajanını çalıştır. Yeni saldırılar `40_attacks.sql`'e eklenir.
3. `security/FINDINGS.md` durumunu güncelle. Dashboard ayarı gerekiyorsa `security/BASELINE.md`'ye yaz.
4. CI'daki `Security` iş akışı (CodeQL, gitleaks, bağımlılık denetimi, saldırı paketi) yeşil olmalıdır.

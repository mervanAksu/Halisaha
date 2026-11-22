# CLAUDE.md — Orkestratör Talimatları

Bu repoda çalışan ana model **orkestratördür**. Görev tanımı: [`docs/MASTER_PROMPT.md`](docs/MASTER_PROMPT.md).
Ajan kadrosu ve iş bölümü: [`AGENTS.md`](AGENTS.md).

## Oturum başında oku

1. `docs/MASTER_PROMPT.md`: rol, değişmez kurallar ve "bitti" tanımı
2. `docs/PRD.md`: ürün kapsamı (v1 / v1.1 / sonrası)
3. `docs/DATA_MODEL.md` ve `docs/API_CONTRACT.md`: paylaşılan sözleşmeler
4. `docs/DECISIONS.md`: alınmış kararlar (tekrar tartışma, gerekirse yeni ADR ekle)
5. `CHANGELOG.md`: en son ne yapıldı

## Repo haritası

```
supabase/            → Postgres migrations, RLS, RPC, Edge Functions (sahibi: backend-engineer, payments-engineer)
security/            → tehdit modeli, bulgular, güvenlik temel ayarları (sahibi: red-team)
site/legal/          → yasal ve destek sayfaları (GitHub Pages)
store/               → mağaza metinleri, gizlilik formu cevapları, görseller
apps/mobile/         → Flutter müşteri uygulaması (sahibi: flutter-engineer)
apps/owner_panel/    → Next.js işletme paneli (sahibi: web-panel-engineer)
docs/                → sözleşmeler ve kararlar (sahibi: orkestratör + docs-keeper)
.claude/agents/      → alt ajan tanımları
.claude/skills/      → tekrar eden prosedürler (migration, flutter feature, PayTR, release, git)
```

## Orkestrasyon kuralları

- **Sözleşme önce gelir.** Bir alan birden çok katmanı etkiliyorsa (ör. `bookings` tablosuna yeni kolon)
  önce `docs/DATA_MODEL.md` ve `docs/API_CONTRACT.md` güncellenir, sonra ajanlara iş verilir.
- **Bir klasörün tek sahibi vardır.** Paralel çalışan ajanlar aynı dosyaya yazmaz.
- **Alt ajanlar commit atmaz.** Commit ve push orkestratörün işidir (`.claude/skills/git-workflow`).
- **İnceleme farklı modelle yapılır.** Kodu yazan model kendi kodunu onaylamaz (`qa-reviewer`, `security-reviewer`).
- **Model seçimi:** Mimari, ödeme ve güvenlik işleri en güçlü modelde (opus) yürür. Ekran ve bileşen
  üretimi sonnet'te, mekanik kontroller (lint, doküman tutarlılığı) haiku'da yapılır.
- Bir değişiklik bu dosyayı, `AGENTS.md`'yi veya bir skill'i geçersiz kılıyorsa, o dosya **aynı commit'te**
  güncellenir.

## Komutlar

```bash
# Backend (Supabase CLI gerekir)
supabase start                          # yerel stack
supabase db reset                       # migrations + seed
./supabase/tests/run_local.sh           # Supabase CLI olmadan saf Postgres 15+/16 ile SQL testleri
supabase functions serve                # edge functions

# Mobil
cd apps/mobile && flutter pub get && flutter analyze && flutter test
flutter run --dart-define-from-file=env/dev.json

# Panel
cd apps/owner_panel && npm ci && npm run typecheck && npm run lint && npm run dev
```

## Güvenlik kuralları (özet; ayrıntı: `.claude/skills/security-review`)
- Her push'ta `Security` iş akışı çalışır: CodeQL (yalnızca repo açıkken; gizli repoda ücretli), gitleaks, bağımlılık denetimi ve **saldırı paketi**. Açık `VULN` CI'ı kırmızıya düşürür.
- Admin yetkisi MFA (`aal2`) ister. Hassas kolonlar kolon izniyle kapalıdır. Yeni fonksiyon allow-list'e eklenmeden çağrılamaz.
- Auth, RLS, ödeme ya da kişisel veriye dokunan her işten sonra `red-team` ajanı çalıştırılır.
- İmza anahtarları ve repo secrets ajanlar tarafından oluşturulmaz veya yazılmaz; kullanıcı yapar (`docs/RELEASE.md`).

## Yapma

- `service_role` anahtarını istemci koduna koyma.
- Eski bir migration dosyasını düzenleme; her zaman yeni migration ekle.
- Kuruşu float ile hesaplama.
- Ödeme sonucunu istemciden gelen bilgiye göre onaylama.
- Referans uygulamanın markasını, görsellerini veya metinlerini kopyalama.
- Yeni bir SQL fonksiyonunu yalnızca `from public` ile kısıtlama. Supabase yeni fonksiyonları anon ve
  authenticated rollerine otomatik açar. Bu hata ilk incelemede kritik bir açık olarak yakalandı.

## Öğrenilenler (incelemelerden)
- 2026-11-20: Varsayılan fonksiyon yetkileri, müşterinin `confirm_payment` RPC'sini çağırıp ödeme yapmadan
  rezervasyon onaylatmasına izin veriyordu. Çözüm: migration 090800'daki allow-list ve test 30a.
- 2026-11-20: Geç gelen ödeme, başlamış bir maçı onaylayabiliyordu. Çözüm: `starts_at <= now()` → iade.
- 2026-11-20: Yazım ortamında paket indirilemiyorsa derleme doğrulaması CI'da yapılır; `gh run view --log-failed` ile hata okunup düzeltilir. CI yeşil olmadan iş "bitti" sayılmaz.
- 2026-11-21: Kırmızı takım (114 saldırı) 10 açık + 17 statik bulgu çıkardı; hepsi kapatıldı. Ders: "engellendi" testleri doğru hata koduyla doğrulanmalı (TESTBUG), aksi halde yanlış güven verir.
- 2026-11-21: Supabase `is_admin()` MFA ister; testlerde admin için `request.jwt.claims = {"aal":"aal2"}` ayarlanır.
- 2026-11-22: Owner MFA yalnızca panel arayüzünde zorlanıyordu; aal1 JWT tüm owner haklarına ulaşıyordu. Çözüm: `owner_mfa_satisfied()` ortak owner yardımcılarında (migration 100000, A107, test 60). Ders: arayüzde zorlanan güvenlik kuralı veritabanında da zorlanır.
- Bu tür dersler buraya kısa bir satır olarak eklenir ve ilgili skill dosyası da güncellenir.

# Halısaha

Halı saha işletmelerini oyuncularla buluşturan rezervasyon platformu. Oyuncu yakınındaki sahanın boş saatini seçer,
kapora öder ve saat ona tahsis edilir. İşletme takvimini web panelinden yönetir.

| Parça | Klasör | Teknoloji |
|---|---|---|
| Müşteri uygulaması | `apps/mobile` | Flutter |
| İşletme / admin paneli | `apps/owner_panel` | Next.js + TypeScript |
| Backend | `supabase/` | Postgres (RLS), Edge Functions (Deno), pg_cron |
| Ödeme | `supabase/functions/paytr-*` | PayTR iFrame + Pazaryeri |

## Başlangıç

```bash
# 1) Backend
supabase start && supabase db reset           # şema + örnek veri
./supabase/tests/run_local.sh                 # SQL testleri (Supabase CLI gerekmez, Postgres 15+ yeter)

# 2) Mobil
cd apps/mobile
cp env/example.json env/dev.json              # SUPABASE_URL, SUPABASE_ANON_KEY
flutter pub get && flutter run --dart-define-from-file=env/dev.json

# 3) Panel
cd apps/owner_panel
cp .env.example .env.local && npm ci && npm run dev
```

## Nasıl çalışıyoruz
Bu proje çok ajanlı bir yapıyla geliştirilir:
- [`docs/MASTER_PROMPT.md`](docs/MASTER_PROMPT.md): görev tanımı ve değişmez kurallar
- [`CLAUDE.md`](CLAUDE.md): orkestratör talimatları
- [`AGENTS.md`](AGENTS.md): ajan kadrosu ve iş akışı
- [`.claude/agents/`](.claude/agents), [`.claude/skills/`](.claude/skills): alt ajan tanımları ve tekrar eden prosedürler
- [`docs/`](docs): PRD, veri modeli, API sözleşmesi, tasarım dili, PayTR notları, kararlar

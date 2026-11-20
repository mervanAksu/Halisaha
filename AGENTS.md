# AGENTS.md — Ajan Kadrosu ve Çalışma Protokolü

Bu proje **üst ajan → alt ajan** modeliyle yürür. Üst ajan (orkestratör) planlar, sözleşmeleri yazar,
işi dağıtır, incelettirir ve commit atar. Alt ajanlar yalnızca kendi alanlarında kod yazar.

Bu dosya araçtan bağımsızdır (Claude Code, Codex, Cursor vb.). Claude Code için tanımlar
`.claude/agents/*.md` altındadır.

## Kadro

| Ajan | Model | Sahip olduğu alan | Ne zaman çağrılır |
|---|---|---|---|
| **orchestrator** (ana oturum) | opus | `docs/`, kök dosyalar, git | Her zaman: planlama, sözleşme, birleştirme |
| `backend-engineer` | opus | `supabase/migrations`, `supabase/tests`, `supabase/seed.sql` | Şema, RLS, RPC, cron |
| `payments-engineer` | opus | `supabase/functions/paytr-*`, `docs/PAYMENTS_PAYTR.md` | Ödeme, iade, alt üye işyeri, payout |
| `flutter-engineer` | sonnet | `apps/mobile/` | Müşteri uygulaması ekranları ve state |
| `web-panel-engineer` | sonnet | `apps/owner_panel/` | İşletme ve admin paneli |
| `qa-reviewer` | sonnet | yazmaz, rapor verir | Her özelliğin sonunda |
| `security-reviewer` | opus | yazmaz, rapor verir | Auth, RLS, ödeme, gizli bilgi değişikliklerinde |
| `docs-keeper` | haiku | `docs/`, `CHANGELOG.md` tutarlılığı | Her merge öncesi |

> Kural: inceleyen ajan, kodu yazan ajandan **farklı** bir model veya bağlamla çalışır.

## Akış

```
Kullanıcı isteği
   │
   ▼
orchestrator ── PRD ve MASTER_PROMPT'a göre yorumlar ── belirsizse kullanıcıya sorar
   │
   ├─▶ sözleşmeyi günceller (DATA_MODEL / API_CONTRACT / DESIGN)
   │
   ├─▶ paralel iş dağıtır:  backend-engineer │ payments-engineer │ flutter-engineer │ web-panel-engineer
   │                         (her biri yalnızca kendi klasörüne yazar, commit atmaz)
   │
   ├─▶ qa-reviewer (+ gerekiyorsa security-reviewer) → bulgu listesi
   │
   ├─▶ düzeltmeleri ilgili ajana geri verir
   │
   └─▶ docs-keeper → CHANGELOG + dokümanlar → orchestrator commit + push
```

## Görev verme şablonu (orkestratör → alt ajan)

Her görev şu başlıkları içerir:

```
GÖREV: <tek cümle>
BAĞLAM: <ilgili PRD maddesi, sözleşme dosyaları>
SAHİP OLDUĞUN KLASÖR: <yol>  (dışına yazma)
GİRDİ SÖZLEŞMESİ: <RPC imzaları, tablo kolonları, tasarım tokenları>
KABUL KRİTERLERİ: <madde madde, test edilebilir>
YAPMA: commit atma; başka klasöre yazma; sözleşmeyi tek taraflı değiştirme (gerekiyorsa raporda öner)
ÇIKTI: değişen dosyalar + doğrulayamadığın şeyler + sözleşme önerileri
```

## İnceleme raporu şablonu (reviewer → orkestratör)

```
KRİTİK  (merge engeller): dosya:satır — sorun — somut senaryo — öneri
ÖNEMLİ  (bu sprintte düzelt): …
KÜÇÜK   (opsiyonel): …
DOĞRULANAMAYAN: …
```

## Skill'ler (tekrarlanan prosedürler)

| Skill | Ne için |
|---|---|
| `.claude/skills/supabase-migration` | Yeni tablo, kolon veya RPC ekleme, RLS ve test yazma |
| `.claude/skills/flutter-feature` | Yeni ekran veya özellik ekleme (katmanlar, state, test) |
| `.claude/skills/paytr-integration` | PayTR token, callback, iade ve alt üye işyeri işlemleri |
| `.claude/skills/release-checklist` | TestFlight, Play kapalı test ve mağaza yayını |
| `.claude/skills/git-workflow` | Branch, commit formatı, CHANGELOG, push |

## Bu dosyayı güncelle

Yeni bir ajan veya skill eklendiğinde, bir alanın sahibi değiştiğinde ya da model ataması değiştiğinde bu
dosya ve `CLAUDE.md` aynı commit'te güncellenir.

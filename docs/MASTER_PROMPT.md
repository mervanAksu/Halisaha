# Ana Prompt (Master Prompt)

> Bu dosya projenin "görev tanımıdır". Orkestratör ajan (CLAUDE.md) her oturumun başında bunu okur,
> alt ajanlara iş verirken buradan alıntı yapar. Ürün yönü değiştiğinde **önce bu dosya** güncellenir.

---

## Rol

Sen, Türkiye pazarı için iki taraflı bir pazaryeri mobil uygulaması geliştiren kıdemli bir ürün mühendisliği
ekibinin **baş mühendisi ve orkestratörüsün**. Kodun tamamını tek başına yazmazsın; işi alt ajanlara
(`.claude/agents/`) böler, sözleşmeleri (veri modeli, API, tasarım dili) sen belirler, çıktılarını
incelettirir ve birleştirirsin.

## Ürün

**Halısaha** (çalışma adı; marka adı henüz kesin değil): halı saha işletmelerini oyuncularla buluşturan
aracı platform.

- Oyuncu konumuna yakın sahaları listeler, tarih ve saat seçer, **kapora** öder; ödeme onaylanınca saat
  ona tahsis edilir.
- Oyuncu gelecek ve geçmiş maçlarını görür, favori saha ekler, destek alır, hesabını silebilir.
- İşletme sahibi web panelinden saha, saat, fiyat, kapora ve iptal politikasını yönetir; telefonla gelen
  rezervasyonları da panele girer (çift rezervasyonu önlemenin tek yolu budur).
- Para akışı **pazaryeri modeli** ile işler: ödeme PayTR Pazaryeri altyapısından alınır, platform
  komisyonunu keser, kalan tutar alt üye işyerine (sahaya) PayTR üzerinden aktarılır.
  **Platform müşteri parasını kendi hesabında tutmaz** (6493 sayılı Kanun / ödeme kuruluşu lisansı riski).

## Teknoloji kararları (değiştirmek için `docs/DECISIONS.md`'ye ADR ekle)

| Katman | Seçim |
|---|---|
| Mobil | Flutter 3.x (Dart 3), Riverpod, go_router, supabase_flutter, webview_flutter |
| Backend | Supabase: Postgres 15+ (RLS zorunlu), Auth (telefon OTP), Storage, Edge Functions (Deno/TS), pg_cron |
| İşletme paneli | Next.js (App Router, TypeScript), @supabase/ssr, Tailwind CSS |
| Ödeme | PayTR iFrame API + Pazaryeri (alt üye işyeri) |
| Bildirim | Firebase Cloud Messaging (yalnızca push) |
| CI | GitHub Actions: flutter analyze/test, tsc/lint, SQL testleri |

## Değişmez kurallar (invariants)

1. **Çift rezervasyon imkânsız olmalı.** Bu kural veritabanı seviyesinde, `EXCLUDE USING gist`
   kısıtıyla korunur. Uygulama katmanındaki kontroller yalnızca kullanıcı deneyimi içindir.
2. **Saat yalnızca ödeme doğrulandıktan sonra kesinleşir.** Akış şöyledir: `pending_payment` (10 dk tutma)
   → PayTR callback hash doğrulaması → `confirmed`. İstemciden gelen "ödedim" bilgisine asla güvenilmez.
3. **Tüm tablolarda RLS açıktır.** İstemci yalnızca `anon`/`authenticated` rolüyle konuşur. `service_role`
   anahtarı yalnızca Edge Function içinde kullanılır, istemciye veya repoya girmez.
4. **Para birimi kuruş cinsinden tamsayıdır** (`*_kurus integer`). Float kullanılmaz.
5. **Zaman `timestamptz` ile UTC saklanır**, gösterimde `Europe/Istanbul` kullanılır. Gece yarısını aşan
   çalışma saatleri (ör. 12:00–06:00) desteklenir.
6. **KVKK:** Yalnızca gerekli kişisel veri toplanır. Aydınlatma metni ve açık rıza ayrı tutulur. Hesap silme
   uygulama içinden yapılabilir (Apple 5.1.1(v) kuralı).
7. **Gizli bilgi repoya girmez.** `.env*`, anahtarlar ve PayTR merchant bilgileri yalnızca ortam
   değişkenlerinde ve Supabase secrets içinde tutulur.
8. **Arayüz dili Türkçedir.** Kod, değişken adları ve commit mesajları İngilizcedir.
9. Referans uygulamanın marka adı, logosu, görselleri ve birebir tasarımı **kopyalanmaz**. Akış mantığı
   referans alınır, görsel dil özgündür (bkz. `docs/DESIGN.md`).

## Kalite çıtası ("bitti" tanımı)

Bir iş ancak şu koşullar sağlanınca bitmiş sayılır:

- Kod derleniyor ve linter temiz (`flutter analyze`, `tsc --noEmit`, `eslint`).
- İlgili testler yazıldı ve geçiyor. Rezervasyon ve ödeme mantığında test **zorunludur**.
- Şema değiştiyse yeni migration eklendi; eski migration düzenlenmedi.
- `docs/` altındaki ilgili dosya (DATA_MODEL, API_CONTRACT, DECISIONS) güncellendi.
- `qa-reviewer` ajanı inceledi. Ödeme, auth veya RLS değiştiyse `security-reviewer` de inceledi.
- Conventional Commits formatında commit atıldı ve `CHANGELOG.md` güncellendi.

## Çalışma döngüsü

1. **Anla:** İsteği PRD'ye ve bu prompta göre yorumla. Belirsizlik geri dönüşü pahalıysa kullanıcıya sor.
2. **Planla:** İşi bağımsız parçalara böl ve her parçanın sahibi olan ajanı seç (AGENTS.md).
3. **Sözleşmeyi önce yaz:** Şema, RPC imzaları ve ekran listesi gibi paylaşılan şeyleri koddan önce
   `docs/`'a yaz.
4. **Paralel uygula:** Birbirine dokunmayan parçaları alt ajanlara paralel ver. Her ajan yalnızca kendi
   klasörüne yazar.
5. **İncelet:** İşi yazmayan, farklı bir modelle çalışan inceleyici ajan kontrol eder.
6. **Birleştir ve kaydet:** Commit atar, push eder, CHANGELOG ve dokümanları günceller.
7. **Raporla:** Kullanıcıya ne yapıldığını, neyin doğrulanamadığını ve bir sonraki adımı kısaca bildir.

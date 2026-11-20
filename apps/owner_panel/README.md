# Halısaha İşletme Paneli

Next.js (App Router, TypeScript strict) + `@supabase/ssr` + Tailwind. İşletme sahipleri ve adminler içindir.
Yalnızca `anon` anahtarı ve kullanıcı JWT'si kullanılır; yetki RLS ve RPC ile sağlanır. `service_role` bu uygulamada **kullanılmaz**.

## Kurulum

```bash
cp .env.example .env.local     # NEXT_PUBLIC_SUPABASE_URL ve NEXT_PUBLIC_SUPABASE_ANON_KEY
npm ci
npm run dev                    # http://localhost:3000
npm run typecheck && npm run lint && npm run build
```

## Hesap açma

Panel hesabı Supabase Auth'ta e-posta + şifre ile oluşturulur, ardından rol atanır (SQL editörü / admin):

```sql
update public.profiles set role = 'owner' where email = 'isletme@ornek.com';  -- veya 'admin'
```

`customer` rolü giriş yapamaz; oturum kapatılır.

## Yapı

- `src/app/login`, `src/app/(panel)/*` — sayfalar (sunucu bileşenleri + server action).
- `src/actions/*` — server action'lar. Rezervasyon yazmaları yalnızca RPC (`owner_*`, `admin_update_venue`).
- `src/lib/database.types.ts` — ELLE YAZILDI; `supabase gen types typescript --local` ile yeniden üretilebilir.
- `src/lib/{errors,money,time,validation,calendar}.ts` — hata kodu çevirisi, kuruş/TL, İstanbul saati, doğrulama, takvim.
- Seçili tesis `?venue=<uuid>` parametresindedir; takvim günü `?date=YYYY-MM-DD`.
- Fotoğraflar tarayıcıdan `venue-photos/<venue_id>/<uuid>.<ext>` yoluna yüklenir; yollar `saveVenuePhotos` ile `venues` satırına yazılır.

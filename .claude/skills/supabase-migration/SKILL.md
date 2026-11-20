---
name: supabase-migration
description: Supabase'e yeni tablo, kolon, RLS politikası veya RPC eklerken izlenecek prosedür. Şemaya dokunan her işte kullan.
---
# Supabase migration prosedürü

1. **Sözleşmeyi kontrol et.** `docs/DATA_MODEL.md` ve `docs/API_CONTRACT.md` bu değişikliği içeriyor mu? İçermiyorsa önce orkestratöre öner.
2. **Yeni dosya aç.** Dosya adı `supabase/migrations/<YYYYMMDDHHMMSS>_<ne_yapiyor>.sql` olur. Eski dosyalar düzenlenmez.
3. **Tablo şablonu:**
   ```sql
   create table public.x (
     id uuid primary key default gen_random_uuid(),
     ...,
     created_at timestamptz not null default now()
   );
   alter table public.x enable row level security;
   create policy "x_select_own" on public.x for select using (user_id = auth.uid());
   ```
4. **Yazma işlemleri RPC ile yapılır:**
   ```sql
   create or replace function public.do_thing(p_id uuid)
   returns ... language plpgsql security definer set search_path = public as $$
   begin
     if auth.uid() is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
     -- yetki kontrolü, iş kuralı, insert/update
   end $$;
   revoke all on function public.do_thing(uuid) from public;
   grant execute on function public.do_thing(uuid) to authenticated;
   ```
5. **Hata kodları:** İstemcinin anlayacağı sabit mesajlar kullanılır (`slot_taken`, `outside_opening_hours`, `hold_expired` …). Bu kodlar `docs/API_CONTRACT.md` içindeki hata tablosunda listelenir.
6. **Test yaz:** `supabase/tests/NNN_<konu>.sql` dosyası oluştur. Test, `assert`/`raise exception` ile başarısızlığı göstermeli. `./supabase/tests/run_local.sh` ile çalıştır.
7. **Belgele:** `docs/DATA_MODEL.md` ve `docs/API_CONTRACT.md` dosyalarını güncelle.
8. Panel tiplerini yeniden üret: `supabase gen types typescript --local > apps/owner_panel/src/lib/database.types.ts`.

-- Row Level Security. Every table has RLS on. Clients talk as anon/authenticated only.
-- Writes that carry business rules (bookings, payments) go exclusively through RPCs (next migration).

-- Helpers ------------------------------------------------------------------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.is_venue_owner(p_venue_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.venues where id = p_venue_id and owner_id = auth.uid());
$$;

create or replace function public.venue_is_visible(p_venue_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.venues
    where id = p_venue_id and (status = 'active' or owner_id = auth.uid())
  ) or public.is_admin();
$$;

alter table public.profiles               enable row level security;
alter table public.venues                 enable row level security;
alter table public.venue_payout_accounts  enable row level security;
alter table public.venue_hours            enable row level security;
alter table public.pitches                enable row level security;
alter table public.bookings               enable row level security;
alter table public.payments               enable row level security;
alter table public.favorites              enable row level security;
alter table public.device_tokens          enable row level security;

-- Base privileges: start from nothing, grant what is needed.
revoke all on all tables in schema public from anon, authenticated;

-- profiles -----------------------------------------------------------------
grant select on public.profiles to authenticated;
grant update (full_name, marketing_consent, kvkk_ack_at) on public.profiles to authenticated;

create policy profiles_select_self on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
-- Owners can see name/phone of customers who booked at their venues (needed to contact them).
create policy profiles_select_customers_of_owner on public.profiles for select to authenticated
  using (exists (
    select 1 from public.bookings b
    join public.venues v on v.id = b.venue_id
    where b.user_id = profiles.id and v.owner_id = auth.uid()
  ));
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- venues -------------------------------------------------------------------
grant select on public.venues to anon, authenticated;
grant insert (name, description, city, district, address, lat, lng, phone, cover_photo_path, photo_paths, amenities, cancellation_window_hours)
  on public.venues to authenticated;
grant update (name, description, city, district, address, lat, lng, phone, cover_photo_path, photo_paths, amenities, cancellation_window_hours)
  on public.venues to authenticated;
-- status, commission_bps, paytr_submerchant_key are admin-only (set through RPC admin_update_venue).

create policy venues_select_public on public.venues for select to anon, authenticated
  using (status = 'active' or owner_id = auth.uid() or public.is_admin());
create policy venues_insert_owner on public.venues for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin'))
  );
create policy venues_update_owner on public.venues for update to authenticated
  using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());

-- owner_id defaults to the caller so the client never chooses it.
alter table public.venues alter column owner_id set default auth.uid();
grant insert (owner_id) on public.venues to authenticated; -- still constrained by policy above

-- venue_payout_accounts (owner + admin only) --------------------------------
grant select, insert, update on public.venue_payout_accounts to authenticated;
create policy payout_owner_all on public.venue_payout_accounts for all to authenticated
  using (public.is_venue_owner(venue_id) or public.is_admin())
  with check (public.is_venue_owner(venue_id) or public.is_admin());

-- venue_hours ----------------------------------------------------------------
grant select on public.venue_hours to anon, authenticated;
grant insert, update, delete on public.venue_hours to authenticated;
create policy venue_hours_select on public.venue_hours for select to anon, authenticated
  using (public.venue_is_visible(venue_id));
create policy venue_hours_write_owner on public.venue_hours for all to authenticated
  using (public.is_venue_owner(venue_id) or public.is_admin())
  with check (public.is_venue_owner(venue_id) or public.is_admin());

-- pitches ------------------------------------------------------------------
grant select on public.pitches to anon, authenticated;
grant insert, update, delete on public.pitches to authenticated;
create policy pitches_select on public.pitches for select to anon, authenticated
  using (public.venue_is_visible(venue_id));
create policy pitches_write_owner on public.pitches for all to authenticated
  using (public.is_venue_owner(venue_id) or public.is_admin())
  with check (public.is_venue_owner(venue_id) or public.is_admin());

-- bookings (read-only for clients; all writes via RPC) ---------------------
grant select on public.bookings to authenticated;
create policy bookings_select_own on public.bookings for select to authenticated
  using (user_id = auth.uid());
create policy bookings_select_owner on public.bookings for select to authenticated
  using (public.is_venue_owner(venue_id) or public.is_admin());

-- payments (read-only) ------------------------------------------------------
grant select on public.payments to authenticated;
create policy payments_select_own on public.payments for select to authenticated
  using (user_id = auth.uid());
create policy payments_select_owner on public.payments for select to authenticated
  using (exists (select 1 from public.bookings b where b.id = payments.booking_id
                 and (public.is_venue_owner(b.venue_id) or public.is_admin())));

-- favorites ----------------------------------------------------------------
grant select, insert, delete on public.favorites to authenticated;
create policy favorites_own on public.favorites for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
alter table public.favorites alter column user_id set default auth.uid();

-- device_tokens --------------------------------------------------------------
grant select, insert, update, delete on public.device_tokens to authenticated;
create policy device_tokens_own on public.device_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
alter table public.device_tokens alter column user_id set default auth.uid();

-- Storage: public bucket for venue photos; owners write under <venue_id>/... ----
-- (Executed only where the storage schema exists, i.e. on Supabase.)
do $$
begin
  if exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    insert into storage.buckets (id, name, public) values ('venue-photos', 'venue-photos', true)
      on conflict (id) do nothing;
    execute $p$
      create policy venue_photos_owner_write on storage.objects for all to authenticated
        using (bucket_id = 'venue-photos' and public.is_venue_owner(((storage.foldername(name))[1])::uuid))
        with check (bucket_id = 'venue-photos' and public.is_venue_owner(((storage.foldername(name))[1])::uuid))
    $p$;
  end if;
end $$;

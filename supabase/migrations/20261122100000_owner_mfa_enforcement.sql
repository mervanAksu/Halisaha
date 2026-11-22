-- S-18 (High): owner MFA was enforced only by the web panel UI. A stolen owner password + an aal1 JWT
-- (mobile e-mail login or direct PostgREST calls) reached every owner capability and bypassed TOTP.
-- From now on every owner capability requires `owner_mfa_satisfied()`:
--   aal2 session, OR the caller has no verified MFA factor (owners without TOTP keep working; the panel
--   still nudges them to enrol).
-- Customer access to their own rows and public reads of active venues/pitches/hours are unchanged.
-- Admin access already requires aal2 (is_admin(), 20261121090000).

-- ---------------------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------------------
-- security definer: clients cannot read auth.mfa_factors; the function only answers for auth.uid().
create or replace function public.owner_mfa_satisfied() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
      or not exists (select 1 from auth.mfa_factors f
                      where f.user_id = auth.uid() and f.status = 'verified');
$$;
revoke all on function public.owner_mfa_satisfied() from public, anon, authenticated;
-- Policies run as the caller; only authenticated-only policies reference it directly. Anon paths go through
-- security definer helpers (is_venue_owner, venue_is_visible), which call it as the definer.
grant execute on function public.owner_mfa_satisfied() to authenticated;

-- ---------------------------------------------------------------------------
-- Shared owner helpers (grants are preserved by create or replace)
-- ---------------------------------------------------------------------------
-- Used by: payout_owner_all, venue_hours_write_owner, pitches_write_owner, bookings_select_owner,
-- payments_select_owner, storage venue_photos_owner_write, owner_create_manual_booking,
-- owner_cancel_booking, owner_mark_attendance.
create or replace function public.is_venue_owner(p_venue_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.venues where id = p_venue_id and owner_id = auth.uid())
     and public.owner_mfa_satisfied();
$$;

-- Owners see their own non-active venues' pitches/hours only with MFA satisfied; active ones stay public.
create or replace function public.venue_is_visible(p_venue_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.venues
    where id = p_venue_id
      and (status = 'active' or (owner_id = auth.uid() and public.owner_mfa_satisfied()))
  ) or public.is_admin();
$$;

-- ---------------------------------------------------------------------------
-- venues: policies that inlined owner_id = auth.uid()
-- ---------------------------------------------------------------------------
drop policy if exists venues_select_public on public.venues;
create policy venues_select_public on public.venues for select to anon, authenticated
  using (status = 'active' or public.is_admin());
create policy venues_select_owner on public.venues for select to authenticated
  using (owner_id = auth.uid() and (select public.owner_mfa_satisfied()));

drop policy if exists venues_insert_owner on public.venues;
create policy venues_insert_owner on public.venues for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (select 1 from public.profiles where id = auth.uid() and role in ('owner', 'admin'))
    and (select public.owner_mfa_satisfied())
  );

drop policy if exists venues_update_owner on public.venues;
create policy venues_update_owner on public.venues for update to authenticated
  using ((owner_id = auth.uid() and (select public.owner_mfa_satisfied())) or public.is_admin())
  with check ((owner_id = auth.uid() and (select public.owner_mfa_satisfied())) or public.is_admin());

-- ---------------------------------------------------------------------------
-- RPCs that inlined owner_id = auth.uid()
-- ---------------------------------------------------------------------------
-- Same body as 20261120090800, owner preview of a non-active venue now needs MFA satisfied.
create or replace function public.get_availability(p_pitch_id uuid, p_date date)
returns table (starts_at timestamptz, ends_at timestamptz, state text, price_kurus integer, deposit_kurus integer)
language plpgsql stable security definer set search_path = public as $$
declare
  v_pitch public.pitches;
  v_hours public.venue_hours;
  v_open  timestamptz;
  v_close timestamptz;
  v_step  interval;
begin
  select p.* into v_pitch
    from public.pitches p join public.venues v on v.id = p.venue_id
   where p.id = p_pitch_id and p.is_active
     and (v.status = 'active' or (v.owner_id = auth.uid() and public.owner_mfa_satisfied()) or public.is_admin());
  if not found then raise exception 'pitch_not_found'; end if;

  select * into v_hours from public.venue_hours
   where venue_id = v_pitch.venue_id and iso_weekday = extract(isodow from p_date)::smallint;
  if not found then return; end if;

  v_open  := (p_date + v_hours.open_time)  at time zone 'Europe/Istanbul';
  v_close := (p_date + v_hours.close_time) at time zone 'Europe/Istanbul';
  if v_hours.close_time <= v_hours.open_time then v_close := v_close + interval '1 day'; end if;
  v_step := make_interval(mins => v_pitch.slot_minutes);

  return query
  select s.slot_start, s.slot_start + v_step,
         case
           when s.slot_start <= now() + interval '15 minutes' then 'past'
           when exists (
             select 1 from public.bookings b
              where b.pitch_id = p_pitch_id
                and tstzrange(b.starts_at, b.ends_at, '[)') && tstzrange(s.slot_start, s.slot_start + v_step, '[)')
                and (b.status = 'confirmed' or (b.status = 'pending_payment' and b.hold_expires_at > now()))
           ) then 'booked'
           else 'available'
         end,
         (v_pitch.hourly_price_kurus * v_pitch.slot_minutes / 60)::integer,
         v_pitch.deposit_kurus
    from generate_series(v_open, v_close - v_step, v_step) as s(slot_start)
   order by 1;
end $$;

-- Same body as 20261121090000 (F-04), owner branch now needs MFA satisfied.
create or replace function public.owner_customer_contacts(p_user_ids uuid[])
returns table (user_id uuid, full_name text, phone text)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.phone
    from public.profiles p
   where p.id = any (p_user_ids[1:500])
     and (
       public.is_admin()
       or (public.owner_mfa_satisfied() and exists (
         select 1 from public.bookings b join public.venues v on v.id = b.venue_id
          where b.user_id = p.id and v.owner_id = auth.uid()
            and b.confirmed_at is not null
            and b.starts_at > now() - interval '180 days'
       ))
     );
$$;

-- Storage (venue_photos_owner_write) calls public.is_venue_owner(): covered by the helper above.

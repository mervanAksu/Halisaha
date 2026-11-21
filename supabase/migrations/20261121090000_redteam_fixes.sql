-- Red-team fixes (security/FINDINGS.md, 2026-11-21). Each block names the finding it closes.

-- ---------------------------------------------------------------------------
-- Schema additions
-- ---------------------------------------------------------------------------
-- F-02: the cancellation window is fixed at booking time; F-04: when a booking became a real (paid/confirmed) one.
alter table public.bookings
  add column if not exists cancellation_window_hours integer check (cancellation_window_hours between 0 and 168),
  add column if not exists confirmed_at timestamptz;

update public.bookings b set confirmed_at = b.updated_at
 where confirmed_at is null
   and (b.status in ('confirmed', 'completed', 'no_show')
        or (b.status = 'cancelled' and exists (
              select 1 from public.payments p where p.booking_id = b.id
                 and p.status in ('succeeded', 'refund_required', 'refund_processing', 'refunded'))));

-- S-06: payout account changes must be verified by an admin before money is routed.
alter table public.venue_payout_accounts add column if not exists verified_at timestamptz;

-- F-09: photo paths must live under the venue's own folder, max 10, cover must be one of them.
alter table public.venues add constraint venues_photo_paths_ok check (
  cardinality(photo_paths) <= 10
  and (cover_photo_path is null or cover_photo_path = any (photo_paths))
  and array_to_string(photo_paths, '|') ~ ('^(' || id::text || '/[0-9a-f-]{36}\.(jpg|png|webp)(\||$))*$')
) not valid;
alter table public.venues validate constraint venues_photo_paths_ok;

-- ---------------------------------------------------------------------------
-- S-04: admin privileges require MFA (JWT aal2). Owners are nudged in the panel.
-- ---------------------------------------------------------------------------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
     and coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2';
$$;

-- ---------------------------------------------------------------------------
-- S-06: append-only audit log (admin read only).
-- ---------------------------------------------------------------------------
create table if not exists public.audit_log (
  id          bigint generated always as identity primary key,
  at          timestamptz not null default now(),
  actor       uuid default auth.uid(),
  table_name  text not null,
  row_id      text not null,
  action      text not null,
  diff        jsonb not null
);
alter table public.audit_log enable row level security;
revoke all on public.audit_log from anon, authenticated;
grant select on public.audit_log to authenticated;
create policy audit_log_admin_read on public.audit_log for select to authenticated using (public.is_admin());

create or replace function public.audit_venue_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_log (table_name, row_id, action, diff)
  values ('venues', new.id::text, tg_op, jsonb_build_object(
    'status', jsonb_build_array(old.status, new.status),
    'commission_bps', jsonb_build_array(old.commission_bps, new.commission_bps),
    'submerchant_changed', old.paytr_submerchant_key is distinct from new.paytr_submerchant_key,
    'cancellation_window_hours', jsonb_build_array(old.cancellation_window_hours, new.cancellation_window_hours)));
  return new;
end $$;
create trigger venues_audit
  after update of status, commission_bps, paytr_submerchant_key, cancellation_window_hours on public.venues
  for each row execute function public.audit_venue_change();

create or replace function public.audit_payout_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- Any change by a non-admin drops verification; only the last 4 IBAN digits are logged.
  if tg_op = 'INSERT' or (old.iban, old.tax_number, old.legal_name) is distinct from (new.iban, new.tax_number, new.legal_name) then
    if not public.is_admin() then new.verified_at := null; end if;
    insert into public.audit_log (table_name, row_id, action, diff)
    values ('venue_payout_accounts', new.venue_id::text, tg_op,
            jsonb_build_object('iban_last4', right(new.iban, 4),
                               'previous_iban_last4', case when tg_op = 'UPDATE' then right(old.iban, 4) end));
  end if;
  if tg_op = 'UPDATE' and new.verified_at is distinct from old.verified_at and not public.is_admin() then
    new.verified_at := old.verified_at;   -- owners cannot self-verify
  end if;
  if tg_op = 'INSERT' and not public.is_admin() then new.verified_at := null; end if;
  return new;
end $$;
create trigger payout_audit before insert or update on public.venue_payout_accounts
  for each row execute function public.audit_payout_change();

create or replace function public.admin_verify_payout(p_venue_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  update public.venue_payout_accounts set verified_at = now() where venue_id = p_venue_id;
  if not found then raise exception 'venue_not_found'; end if;
end $$;

-- ---------------------------------------------------------------------------
-- F-05: consent timestamps are server-set once; consent history is append-only.
-- ---------------------------------------------------------------------------
create table if not exists public.consent_events (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (kind in ('kvkk_ack', 'marketing')),
  granted    boolean not null,
  at         timestamptz not null default now()
);
alter table public.consent_events enable row level security;
revoke all on public.consent_events from anon, authenticated;
grant select on public.consent_events to authenticated;
create policy consent_events_own_read on public.consent_events for select to authenticated using (user_id = auth.uid());

create or replace function public.profiles_consent_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.kvkk_ack_at is distinct from old.kvkk_ack_at then
    new.kvkk_ack_at := case when old.kvkk_ack_at is null and new.kvkk_ack_at is not null then now() else old.kvkk_ack_at end;
    if old.kvkk_ack_at is null and new.kvkk_ack_at is not null then
      insert into public.consent_events (user_id, kind, granted) values (new.id, 'kvkk_ack', true);
    end if;
  end if;
  if new.marketing_consent is distinct from old.marketing_consent then
    insert into public.consent_events (user_id, kind, granted) values (new.id, 'marketing', new.marketing_consent);
  end if;
  return new;
end $$;
create trigger profiles_consent before update on public.profiles
  for each row execute function public.profiles_consent_guard();

-- ---------------------------------------------------------------------------
-- F-06: customers cannot read commission (column grants); hold no longer returns it.
-- ---------------------------------------------------------------------------
revoke select on public.bookings from authenticated;
grant select (id, pitch_id, venue_id, user_id, source, status, starts_at, ends_at, price_kurus, deposit_kurus,
              hold_expires_at, customer_name, customer_phone, note, cancelled_at, cancelled_by, cancel_reason,
              created_at, updated_at, cancellation_window_hours, confirmed_at)
  on public.bookings to authenticated;

-- ---------------------------------------------------------------------------
-- F-07 / F-08: device tokens only through an RPC; max 5 per user; token moves to the new owner.
-- ---------------------------------------------------------------------------
revoke insert, update on public.device_tokens from authenticated;
create or replace function public.register_device_token(p_token text, p_platform text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_platform not in ('ios', 'android') or p_token is null or char_length(p_token) not between 20 and 4096 then
    raise exception 'invalid_token';
  end if;
  insert into public.device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
  delete from public.device_tokens
   where user_id = auth.uid()
     and token in (select token from public.device_tokens where user_id = auth.uid()
                    order by updated_at desc offset 5);
end $$;

-- ---------------------------------------------------------------------------
-- Booking RPCs re-defined with the fixes.
-- ---------------------------------------------------------------------------
-- F-02, F-03, F-06: hold fixes window, requires sub-merchant for deposits, hides commission.
create or replace function public.create_booking_hold(p_pitch_id uuid, p_starts_at timestamptz)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := auth.uid();
  v_pitch   public.pitches;
  v_venue   public.venues;
  v_booking public.bookings;
  v_price   integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform pg_advisory_xact_lock(hashtext('hold:' || v_uid::text));

  select * into v_pitch from public.pitches where id = p_pitch_id and is_active;
  if not found then raise exception 'pitch_not_found'; end if;
  select * into v_venue from public.venues where id = v_pitch.venue_id and status = 'active';
  if not found then raise exception 'pitch_not_found'; end if;
  -- Deposits must flow through the PayTR marketplace split (6493): never to the platform's own account.
  if v_pitch.deposit_kurus > 0 and v_venue.paytr_submerchant_key is null then raise exception 'pitch_not_found'; end if;

  if p_starts_at <= now() + interval '15 minutes' then raise exception 'slot_in_past'; end if;
  if p_starts_at > now() + interval '30 days' then raise exception 'too_far_ahead'; end if;
  if not public._is_valid_slot(p_pitch_id, p_starts_at) then raise exception 'outside_opening_hours'; end if;

  perform public.expire_stale_holds();

  if (select count(*) from public.bookings where user_id = v_uid and status = 'pending_payment') >= 2 then
    raise exception 'too_many_pending_holds';
  end if;
  if (select count(*) from public.bookings where user_id = v_uid and source = 'app'
        and status in ('pending_payment', 'confirmed') and ends_at > now()) >= 4 then
    raise exception 'too_many_active_bookings';
  end if;
  if (select count(*) from public.bookings where user_id = v_uid and source = 'app'
        and created_at > now() - interval '1 hour') >= 6 then
    raise exception 'too_many_recent_holds';
  end if;

  v_price := (v_pitch.hourly_price_kurus * v_pitch.slot_minutes / 60)::integer;
  begin
    insert into public.bookings (pitch_id, venue_id, user_id, source, status, starts_at, ends_at,
                                 price_kurus, deposit_kurus, commission_kurus, hold_expires_at, cancellation_window_hours)
    values (v_pitch.id, v_venue.id, v_uid, 'app', 'pending_payment', p_starts_at,
            p_starts_at + make_interval(mins => v_pitch.slot_minutes),
            v_price, v_pitch.deposit_kurus,
            (v_pitch.deposit_kurus::bigint * v_venue.commission_bps / 10000)::integer,
            now() + interval '10 minutes', v_venue.cancellation_window_hours)
    returning * into v_booking;
  exception when exclusion_violation then
    raise exception 'slot_taken';
  end;

  if v_booking.deposit_kurus = 0 then
    update public.bookings set status = 'confirmed', hold_expires_at = null, confirmed_at = now()
     where id = v_booking.id returning * into v_booking;
  end if;
  v_booking.commission_kurus := null;
  return v_booking;
end $$;

-- F-01: a success that arrives after a recorded failure for the same merchant_oid means money was captured.
create or replace function public.confirm_payment(
  p_merchant_oid text, p_success boolean, p_total_amount_kurus integer, p_payload jsonb
) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_payment public.payments;
  v_booking public.bookings;
begin
  select * into v_payment from public.payments where merchant_oid = p_merchant_oid for update;
  if not found then raise exception 'payment_not_found'; end if;
  if v_payment.status <> 'initiated' and not (p_success and v_payment.status = 'failed') then
    return v_payment.status::text;
  end if;

  if not p_success then
    update public.payments set status = 'failed', provider_payload = p_payload,
           failed_reason = left(p_payload ->> 'failed_reason_msg', 300)
     where id = v_payment.id;
    return 'failed';
  end if;

  select * into v_booking from public.bookings where id = v_payment.booking_id for update;

  if p_total_amount_kurus < v_payment.amount_kurus
     or v_booking.status not in ('pending_payment', 'expired')
     or v_booking.starts_at <= now()
     or exists (select 1 from public.payments where booking_id = v_booking.id and status = 'succeeded') then
    update public.payments set status = 'refund_required', provider_payload = p_payload where id = v_payment.id;
    return 'refund_required';
  end if;

  begin
    update public.bookings set status = 'confirmed', hold_expires_at = null, confirmed_at = now()
     where id = v_booking.id;
  exception when exclusion_violation then
    update public.payments set status = 'refund_required', provider_payload = p_payload where id = v_payment.id;
    return 'refund_required';
  end;

  update public.payments set status = 'succeeded', provider_payload = p_payload where id = v_payment.id;
  return 'succeeded';
end $$;

-- F-02: refund eligibility uses the window that was in force when the customer booked.
create or replace function public.cancel_booking(p_booking_id uuid, p_reason text default null)
returns table (status public.booking_status, refund_eligible boolean)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_booking public.bookings;
  v_window  integer;
  v_refund  boolean := false;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found or v_booking.user_id is distinct from auth.uid() then raise exception 'booking_not_found'; end if;

  if v_booking.status = 'pending_payment' then
    update public.bookings set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid(),
           cancel_reason = left(p_reason, 300), hold_expires_at = null
     where id = v_booking.id;
    return query select 'cancelled'::public.booking_status, false;
    return;
  end if;

  if v_booking.status <> 'confirmed' or v_booking.starts_at <= now() then raise exception 'not_cancellable'; end if;

  v_window := coalesce(v_booking.cancellation_window_hours,
                       (select cancellation_window_hours from public.venues where id = v_booking.venue_id));
  v_refund := v_booking.starts_at - now() >= make_interval(hours => v_window);

  update public.bookings set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid(),
         cancel_reason = left(p_reason, 300)
   where id = v_booking.id;
  if v_refund then
    update public.payments set status = 'refund_required' where booking_id = v_booking.id and status = 'succeeded';
  end if;
  return query select 'cancelled'::public.booking_status, v_refund;
end $$;

create or replace function public.prepare_account_deletion(p_user_id uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_count integer := 0;
  r record;
begin
  if exists (select 1 from public.venues where owner_id = p_user_id) then raise exception 'owner_account'; end if;
  for r in
    select b.id, b.status, b.starts_at, coalesce(b.cancellation_window_hours, v.cancellation_window_hours) as win
      from public.bookings b join public.venues v on v.id = b.venue_id
     where b.user_id = p_user_id and b.status in ('pending_payment', 'confirmed') and b.starts_at > now()
     for update of b
  loop
    update public.bookings
       set status = 'cancelled', cancelled_at = now(), cancel_reason = 'account_deleted', hold_expires_at = null
     where id = r.id;
    if r.status = 'confirmed' and r.starts_at - now() >= make_interval(hours => r.win) then
      update public.payments set status = 'refund_required' where booking_id = r.id and status = 'succeeded';
    end if;
    v_count := v_count + 1;
  end loop;
  update public.bookings set note = null where user_id = p_user_id;
  update public.bookings set cancelled_by = null where cancelled_by = p_user_id;
  delete from public.consent_events where user_id = p_user_id;
  return v_count;
end $$;

-- F-04: only customers with a real (paid / confirmed) booking are reachable.
create or replace function public.owner_customer_contacts(p_user_ids uuid[])
returns table (user_id uuid, full_name text, phone text)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.phone
    from public.profiles p
   where p.id = any (p_user_ids[1:500])
     and (
       public.is_admin()
       or exists (
         select 1 from public.bookings b join public.venues v on v.id = b.venue_id
          where b.user_id = p.id and v.owner_id = auth.uid()
            and b.confirmed_at is not null
            and b.starts_at > now() - interval '180 days'
       )
     );
$$;

-- F-10: no back-dated (>1h) or far-future manual entries; manual entries count as confirmed.
create or replace function public.owner_create_manual_booking(
  p_pitch_id uuid, p_starts_at timestamptz, p_ends_at timestamptz,
  p_source public.booking_source default 'manual',
  p_customer_name text default null, p_customer_phone text default null, p_note text default null
) returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_pitch   public.pitches;
  v_booking public.bookings;
begin
  if p_source = 'app' then raise exception 'invalid_source'; end if;
  select * into v_pitch from public.pitches where id = p_pitch_id;
  if not found or not (public.is_venue_owner(v_pitch.venue_id) or public.is_admin()) then raise exception 'forbidden'; end if;
  if p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at
     or p_ends_at - p_starts_at > interval '24 hours' then
    raise exception 'invalid_range';
  end if;
  if p_starts_at < now() - interval '1 hour' then raise exception 'slot_in_past'; end if;
  if p_starts_at > now() + interval '400 days' then raise exception 'too_far_ahead'; end if;

  perform public.expire_stale_holds();
  begin
    insert into public.bookings (pitch_id, venue_id, user_id, source, status, starts_at, ends_at,
                                 price_kurus, customer_name, customer_phone, note, confirmed_at)
    values (v_pitch.id, v_pitch.venue_id, null, p_source, 'confirmed', p_starts_at, p_ends_at,
            case when p_source = 'manual'
                 then (v_pitch.hourly_price_kurus::bigint * extract(epoch from (p_ends_at - p_starts_at)) / 3600)::integer
                 else 0 end,
            left(p_customer_name, 80), left(p_customer_phone, 20), left(p_note, 500), now())
    returning * into v_booking;
  exception when exclusion_violation then
    raise exception 'slot_taken';
  end;
  return v_booking;
end $$;

-- F-03: a venue cannot go live without its PayTR sub-merchant key.
create or replace function public.admin_update_venue(
  p_venue_id uuid, p_status public.venue_status default null,
  p_commission_bps integer default null, p_paytr_submerchant_key text default null
) returns public.venues
language plpgsql security definer set search_path = public as $$
declare v_venue public.venues;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select * into v_venue from public.venues where id = p_venue_id for update;
  if not found then raise exception 'venue_not_found'; end if;
  if coalesce(p_status, v_venue.status) = 'active'
     and coalesce(nullif(btrim(p_paytr_submerchant_key), ''), v_venue.paytr_submerchant_key) is null then
    raise exception 'submerchant_key_required';
  end if;
  update public.venues set
         status = coalesce(p_status, status),
         commission_bps = coalesce(p_commission_bps, commission_bps),
         paytr_submerchant_key = coalesce(nullif(btrim(p_paytr_submerchant_key), ''), paytr_submerchant_key)
   where id = p_venue_id returning * into v_venue;
  return v_venue;
end $$;

-- S-17: invalid coordinates (NaN / out of range) are treated as "no location".
create or replace function public.list_venues(
  p_search text default null, p_district text default null,
  p_lat double precision default null, p_lng double precision default null
) returns table (
  id uuid, name text, district text, address text, cover_photo_path text,
  min_hourly_price_kurus integer, open_time time, close_time time,
  distance_km double precision, is_favorite boolean
)
language sql stable security definer set search_path = public as $$
  with loc as (
    select case when p_lat between -90 and 90 and p_lng between -180 and 180 then p_lat end as lat,
           case when p_lat between -90 and 90 and p_lng between -180 and 180 then p_lng end as lng
  )
  select v.id, v.name, v.district, v.address, v.cover_photo_path,
         (select min(p.hourly_price_kurus) from public.pitches p where p.venue_id = v.id and p.is_active),
         h.open_time, h.close_time,
         case when loc.lat is null or v.lat is null or v.lng is null then null
              else 6371 * 2 * asin(sqrt(
                     power(sin(radians(v.lat - loc.lat) / 2), 2)
                   + cos(radians(loc.lat)) * cos(radians(v.lat)) * power(sin(radians(v.lng - loc.lng) / 2), 2)))
         end,
         exists (select 1 from public.favorites f where f.venue_id = v.id and f.user_id = auth.uid())
    from public.venues v
    cross join loc
    left join public.venue_hours h
      on h.venue_id = v.id
     and h.iso_weekday = extract(isodow from (now() at time zone 'Europe/Istanbul'))::smallint
   where v.status = 'active'
     and exists (select 1 from public.pitches p where p.venue_id = v.id and p.is_active)
     and (p_district is null or v.district = p_district)
     and (p_search is null
          or v.name ilike '%' || replace(replace(replace(left(p_search, 80), '\', '\\'), '%', '\%'), '_', '\_') || '%'
          or v.district ilike '%' || replace(replace(replace(left(p_search, 80), '\', '\\'), '%', '\%'), '_', '\_') || '%')
   order by 9 nulls last, v.name
   limit 100;
$$;

-- ---------------------------------------------------------------------------
-- Privileges for new / redefined functions (deny by default, then allow-list).
-- ---------------------------------------------------------------------------
revoke all on function public.register_device_token(text, text), public.admin_verify_payout(uuid),
                       public.audit_venue_change(), public.audit_payout_change(), public.profiles_consent_guard()
  from public, anon, authenticated;
grant execute on function public.register_device_token(text, text), public.admin_verify_payout(uuid) to authenticated;

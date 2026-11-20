-- Security & correctness hardening after the independent review (security-reviewer + qa-reviewer).
--  SEC-K1  Supabase grants EXECUTE on every new public function to anon/authenticated by default;
--          `revoke ... from public` did not remove those grants → internal functions were callable.
--  SEC-Ö1  hold limit race + cancel/re-hold loop        → advisory lock, hourly quota, active cap
--  SEC-Ö2  zero-deposit pitches allowed unlimited free bookings → active cap covers confirmed too
--  SEC-Ö3  owners could read customers' full profile rows → RPC returning only name/phone
--  SEC-Ö4  refund job could double-refund                → claim with SKIP LOCKED, refund_processing
--  QA-K1   late payment could confirm a match that already started → refund instead
--  QA-Ö3   availability showed slots that the hold rejected (15-minute rule)
--  QA-K-1  owner cancel of a started match triggered a refund → slot_started
--  SEC-K-5 unlimited payment attempts per booking         → max 5
--  SEC-K-6 refund amount must not exceed what was charged
--  SEC-K-7 deleted user id lingered in bookings.cancelled_by

-- ---------------------------------------------------------------------------
-- Availability: anything starting within 15 minutes is 'past' (matches create_booking_hold).
-- ---------------------------------------------------------------------------
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
     and (v.status = 'active' or v.owner_id = auth.uid() or public.is_admin());
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

-- ---------------------------------------------------------------------------
-- Hold: serialised per user; quotas against slot locking.
-- ---------------------------------------------------------------------------
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

  -- One hold at a time per user: makes the quota checks below race-free.
  perform pg_advisory_xact_lock(hashtext('hold:' || v_uid::text));

  select * into v_pitch from public.pitches where id = p_pitch_id and is_active;
  if not found then raise exception 'pitch_not_found'; end if;
  select * into v_venue from public.venues where id = v_pitch.venue_id and status = 'active';
  if not found then raise exception 'pitch_not_found'; end if;

  if p_starts_at <= now() + interval '15 minutes' then raise exception 'slot_in_past'; end if;
  if p_starts_at > now() + interval '30 days' then raise exception 'too_far_ahead'; end if;
  if not public._is_valid_slot(p_pitch_id, p_starts_at) then raise exception 'outside_opening_hours'; end if;

  perform public.expire_stale_holds();

  if (select count(*) from public.bookings
       where user_id = v_uid and status = 'pending_payment') >= 2 then
    raise exception 'too_many_pending_holds';
  end if;
  -- Includes confirmed zero-deposit bookings, which skip payment entirely.
  if (select count(*) from public.bookings
       where user_id = v_uid and source = 'app' and status in ('pending_payment', 'confirmed') and ends_at > now()) >= 4 then
    raise exception 'too_many_active_bookings';
  end if;
  -- Stops the "hold → cancel → hold again" loop that keeps slots locked without paying.
  if (select count(*) from public.bookings
       where user_id = v_uid and source = 'app' and created_at > now() - interval '1 hour') >= 6 then
    raise exception 'too_many_recent_holds';
  end if;

  v_price := (v_pitch.hourly_price_kurus * v_pitch.slot_minutes / 60)::integer;

  begin
    insert into public.bookings (pitch_id, venue_id, user_id, source, status, starts_at, ends_at,
                                 price_kurus, deposit_kurus, commission_kurus, hold_expires_at)
    values (v_pitch.id, v_venue.id, v_uid, 'app', 'pending_payment', p_starts_at,
            p_starts_at + make_interval(mins => v_pitch.slot_minutes),
            v_price, v_pitch.deposit_kurus,
            (v_pitch.deposit_kurus::bigint * v_venue.commission_bps / 10000)::integer,
            now() + interval '10 minutes')
    returning * into v_booking;
  exception when exclusion_violation then
    raise exception 'slot_taken';
  end;

  if v_booking.deposit_kurus = 0 then
    update public.bookings set status = 'confirmed', hold_expires_at = null
     where id = v_booking.id returning * into v_booking;
  end if;
  return v_booking;
end $$;

-- ---------------------------------------------------------------------------
-- Payment attempts: at most 5 per booking.
-- ---------------------------------------------------------------------------
create or replace function public.start_payment(p_booking_id uuid, p_user_id uuid)
returns public.payments
language plpgsql security definer set search_path = public as $$
declare
  v_booking public.bookings;
  v_payment public.payments;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found or v_booking.user_id is distinct from p_user_id then raise exception 'booking_not_found'; end if;
  if v_booking.status <> 'pending_payment' or v_booking.hold_expires_at <= now() then
    raise exception 'hold_expired';
  end if;
  if (select count(*) from public.payments where booking_id = v_booking.id) >= 5 then
    raise exception 'too_many_payment_attempts';
  end if;

  insert into public.payments (booking_id, user_id, merchant_oid, amount_kurus)
  values (v_booking.id, p_user_id,
          'HS' || replace(v_booking.id::text, '-', '') || substr(encode(gen_random_bytes(2), 'hex'), 1, 4),
          v_booking.deposit_kurus)
  returning * into v_payment;
  return v_payment;
end $$;

-- ---------------------------------------------------------------------------
-- Callback: a late payment never confirms a match that has already started.
-- ---------------------------------------------------------------------------
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
  if v_payment.status <> 'initiated' then return v_payment.status::text; end if;

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
    update public.bookings set status = 'confirmed', hold_expires_at = null where id = v_booking.id;
  exception when exclusion_violation then
    update public.payments set status = 'refund_required', provider_payload = p_payload where id = v_payment.id;
    return 'refund_required';
  end;

  update public.payments set status = 'succeeded', provider_payload = p_payload where id = v_payment.id;
  return 'succeeded';
end $$;

-- ---------------------------------------------------------------------------
-- Owner cancel: not after kick-off (use "Gelmedi" instead).
-- ---------------------------------------------------------------------------
create or replace function public.owner_cancel_booking(p_booking_id uuid, p_reason text default null)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare v_booking public.bookings;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found or not (public.is_venue_owner(v_booking.venue_id) or public.is_admin()) then
    raise exception 'forbidden';
  end if;
  if v_booking.status not in ('pending_payment', 'confirmed') then raise exception 'not_cancellable'; end if;
  if v_booking.starts_at <= now() then raise exception 'slot_started'; end if;

  update public.bookings set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid(),
         cancel_reason = left(p_reason, 300), hold_expires_at = null
   where id = v_booking.id returning * into v_booking;
  update public.payments set status = 'refund_required'
   where booking_id = v_booking.id and status = 'succeeded';
  return v_booking;
end $$;

-- ---------------------------------------------------------------------------
-- Account deletion: also clear the user id from cancelled_by.
-- ---------------------------------------------------------------------------
create or replace function public.prepare_account_deletion(p_user_id uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_count integer := 0;
  r record;
begin
  if exists (select 1 from public.venues where owner_id = p_user_id) then
    raise exception 'owner_account';
  end if;
  for r in
    select b.id, b.status, b.starts_at, v.cancellation_window_hours
      from public.bookings b join public.venues v on v.id = b.venue_id
     where b.user_id = p_user_id and b.status in ('pending_payment', 'confirmed') and b.starts_at > now()
     for update of b
  loop
    update public.bookings
       set status = 'cancelled', cancelled_at = now(), cancel_reason = 'account_deleted', hold_expires_at = null
     where id = r.id;
    if r.status = 'confirmed' and r.starts_at - now() >= make_interval(hours => r.cancellation_window_hours) then
      update public.payments set status = 'refund_required' where booking_id = r.id and status = 'succeeded';
    end if;
    v_count := v_count + 1;
  end loop;
  update public.bookings set note = null where user_id = p_user_id;
  update public.bookings set cancelled_by = null where cancelled_by = p_user_id;
  return v_count;
end $$;

-- ---------------------------------------------------------------------------
-- KVKK data minimisation: owners get only name + phone of their own customers.
-- ---------------------------------------------------------------------------
drop policy if exists profiles_select_customers_of_owner on public.profiles;

create or replace function public.owner_customer_contacts(p_user_ids uuid[])
returns table (user_id uuid, full_name text, phone text)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.phone
    from public.profiles p
   where p.id = any (p_user_ids)
     and (
       public.is_admin()
       or exists (
         select 1 from public.bookings b join public.venues v on v.id = b.venue_id
          where b.user_id = p.id and v.owner_id = auth.uid()
            and b.status in ('confirmed', 'completed', 'no_show', 'cancelled')
            and b.starts_at > now() - interval '180 days'
       )
     );
$$;

-- ---------------------------------------------------------------------------
-- Refund job: claim rows atomically; never refund more than was charged.
-- ---------------------------------------------------------------------------
create or replace function public.claim_refunds(p_limit integer default 20)
returns table (payment_id uuid, merchant_oid text, refund_amount_kurus integer)
language plpgsql security definer set search_path = public as $$
begin
  return query
  with picked as (
    select p.id from public.payments p
     where p.status = 'refund_required'
     order by p.updated_at
     limit greatest(1, least(p_limit, 100))
     for update skip locked
  )
  update public.payments p
     set status = 'refund_processing'
    from picked
   where p.id = picked.id
  returning p.id, p.merchant_oid,
            least(p.amount_kurus,
                  coalesce(nullif(p.provider_payload ->> 'total_amount', '')::integer, p.amount_kurus));
end $$;

create or replace function public.mark_refunded(p_payment_id uuid, p_payload jsonb)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.payments
     set status = 'refunded',
         provider_payload = coalesce(provider_payload, '{}'::jsonb) || jsonb_build_object('refund', p_payload)
   where id = p_payment_id and status in ('refund_required', 'refund_processing');
end $$;

-- PayTR rejected the refund: put it back in the queue with the reason (an admin sees it in the panel).
create or replace function public.release_refund_claim(p_payment_id uuid, p_reason text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.payments
     set status = 'refund_required', failed_reason = left('refund: ' || coalesce(p_reason, 'unknown'), 300)
   where id = p_payment_id and status = 'refund_processing';
end $$;

-- ---------------------------------------------------------------------------
-- Storage: only images, max 5 MB (where the storage schema exists).
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'storage' and table_name = 'buckets' and column_name = 'allowed_mime_types') then
    update storage.buckets
       set allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'],
           file_size_limit = 5 * 1024 * 1024
     where id = 'venue-photos';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- SEC-K1: privilege lockdown. Deny by default, then allow-list.
-- ---------------------------------------------------------------------------
alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema public revoke all on functions from anon, authenticated;
alter default privileges in schema public revoke all on tables    from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;

revoke all on all functions in schema public from public, anon, authenticated;

-- Callable by anyone (read-only, no PII):
grant execute on function public.get_availability(uuid, date),
                          public.list_venues(text, text, double precision, double precision),
                          public.is_admin(), public.is_venue_owner(uuid), public.venue_is_visible(uuid)
  to anon, authenticated;
-- Signed-in users (each function checks auth.uid() / ownership itself):
grant execute on function public.create_booking_hold(uuid, timestamptz),
                          public.cancel_booking(uuid, text),
                          public.my_completed_match_count(),
                          public.owner_create_manual_booking(uuid, timestamptz, timestamptz, public.booking_source, text, text, text),
                          public.owner_cancel_booking(uuid, text),
                          public.owner_mark_attendance(uuid, public.booking_status),
                          public.owner_customer_contacts(uuid[]),
                          public.admin_update_venue(uuid, public.venue_status, integer, text),
                          public.admin_list_venues()
  to authenticated;
-- Server only (Edge Functions with the service role key, pg_cron):
grant execute on function public.start_payment(uuid, uuid),
                          public.confirm_payment(text, boolean, integer, jsonb),
                          public.expire_stale_holds(),
                          public.complete_past_bookings(),
                          public.prepare_account_deletion(uuid),
                          public.claim_refunds(integer),
                          public.mark_refunded(uuid, jsonb),
                          public.release_refund_claim(uuid, text)
  to service_role;

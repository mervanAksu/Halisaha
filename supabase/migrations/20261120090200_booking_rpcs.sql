-- Booking & payment RPCs. Error messages are stable codes listed in docs/API_CONTRACT.md.

-- ---------------------------------------------------------------------------
-- Internal: release holds whose time ran out (also run by pg_cron every minute).
-- ---------------------------------------------------------------------------
create or replace function public.expire_stale_holds() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  update public.bookings
     set status = 'expired'
   where status = 'pending_payment' and hold_expires_at <= now();
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.complete_past_bookings() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  update public.bookings set status = 'completed'
   where status = 'confirmed' and ends_at <= now();
  get diagnostics n = row_count;
  return n;
end $$;

-- ---------------------------------------------------------------------------
-- Slots of one pitch for one *business day* (venue-local). A business day that
-- closes after midnight (12:00 → 06:00) yields slots that end on the next date.
-- Returns every slot with a state; never exposes who booked.
-- ---------------------------------------------------------------------------
create or replace function public.get_availability(p_pitch_id uuid, p_date date)
returns table (starts_at timestamptz, ends_at timestamptz, state text, price_kurus integer, deposit_kurus integer)
language plpgsql stable security definer set search_path = public as $$
declare
  v_pitch   public.pitches;
  v_hours   public.venue_hours;
  v_open    timestamptz;
  v_close   timestamptz;
  v_step    interval;
begin
  select p.* into v_pitch
    from public.pitches p join public.venues v on v.id = p.venue_id
   where p.id = p_pitch_id and p.is_active
     and (v.status = 'active' or v.owner_id = auth.uid() or public.is_admin());
  if not found then
    raise exception 'pitch_not_found';
  end if;

  select * into v_hours from public.venue_hours
   where venue_id = v_pitch.venue_id and iso_weekday = extract(isodow from p_date)::smallint;
  if not found then
    return; -- closed that day
  end if;

  v_open  := (p_date + v_hours.open_time)  at time zone 'Europe/Istanbul';
  v_close := (p_date + v_hours.close_time) at time zone 'Europe/Istanbul';
  if v_hours.close_time <= v_hours.open_time then
    v_close := v_close + interval '1 day';
  end if;
  v_step := make_interval(mins => v_pitch.slot_minutes);

  return query
  select s.slot_start,
         s.slot_start + v_step,
         case
           when s.slot_start <= now() then 'past'
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

-- True when [p_start, p_start+slot) is one of the pitch's generated slots.
create or replace function public._is_valid_slot(p_pitch_id uuid, p_start timestamptz)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from (values ((p_start at time zone 'Europe/Istanbul')::date),
                   ((p_start at time zone 'Europe/Istanbul')::date - 1)) d(day),
           lateral public.get_availability(p_pitch_id, d.day) a
     where a.starts_at = p_start
  );
$$;

-- ---------------------------------------------------------------------------
-- Customer: hold a slot for 10 minutes while paying.
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
  v_active  integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_pitch from public.pitches where id = p_pitch_id and is_active;
  if not found then raise exception 'pitch_not_found'; end if;
  select * into v_venue from public.venues where id = v_pitch.venue_id and status = 'active';
  if not found then raise exception 'pitch_not_found'; end if;

  if p_starts_at <= now() + interval '15 minutes' then raise exception 'slot_in_past'; end if;
  if p_starts_at > now() + interval '30 days' then raise exception 'too_far_ahead'; end if;
  if not public._is_valid_slot(p_pitch_id, p_starts_at) then raise exception 'outside_opening_hours'; end if;

  perform public.expire_stale_holds();

  -- Anti-abuse: a user may hold at most 2 unpaid slots at a time.
  select count(*) into v_active from public.bookings
   where user_id = v_uid and status = 'pending_payment';
  if v_active >= 2 then raise exception 'too_many_pending_holds'; end if;

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

  -- A zero-deposit pitch needs no payment: confirm immediately.
  if v_booking.deposit_kurus = 0 then
    update public.bookings set status = 'confirmed', hold_expires_at = null
     where id = v_booking.id returning * into v_booking;
  end if;

  return v_booking;
end $$;

-- ---------------------------------------------------------------------------
-- Edge function (service role): register a payment attempt for a held booking.
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

  -- Merchant OID: 'HS' + booking id (no dashes) + 4 random hex chars (unique per attempt).
  insert into public.payments (booking_id, user_id, merchant_oid, amount_kurus)
  values (v_booking.id, p_user_id,
          'HS' || replace(v_booking.id::text, '-', '') || substr(encode(gen_random_bytes(2), 'hex'), 1, 4),
          v_booking.deposit_kurus)
  returning * into v_payment;
  return v_payment;
end $$;

-- ---------------------------------------------------------------------------
-- Edge function (service role): apply a hash-verified PayTR callback. Idempotent.
-- Returns the resulting payment status as text.
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

  -- Idempotency: only an 'initiated' payment can change state.
  if v_payment.status <> 'initiated' then
    return v_payment.status::text;
  end if;

  if not p_success then
    update public.payments set status = 'failed', provider_payload = p_payload,
           failed_reason = left(p_payload ->> 'failed_reason_msg', 300)
     where id = v_payment.id;
    return 'failed';  -- booking keeps its hold; the customer may retry until it expires
  end if;

  select * into v_booking from public.bookings where id = v_payment.booking_id for update;

  -- Amount mismatch or a booking that is no longer payable → money must go back.
  if p_total_amount_kurus < v_payment.amount_kurus
     or v_booking.status not in ('pending_payment', 'expired')
     or exists (select 1 from public.payments where booking_id = v_booking.id and status = 'succeeded') then
    update public.payments set status = 'refund_required', provider_payload = p_payload where id = v_payment.id;
    return 'refund_required';
  end if;

  -- Late payment after the hold expired: confirm only if nobody took the slot meanwhile.
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
-- Customer cancels. Deposit is refunded only before the venue's cancellation window.
-- ---------------------------------------------------------------------------
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

  if v_booking.status <> 'confirmed' then raise exception 'not_cancellable'; end if;
  if v_booking.starts_at <= now() then raise exception 'not_cancellable'; end if;

  select cancellation_window_hours into v_window from public.venues where id = v_booking.venue_id;
  v_refund := v_booking.starts_at - now() >= make_interval(hours => v_window);

  update public.bookings set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid(),
         cancel_reason = left(p_reason, 300)
   where id = v_booking.id;

  if v_refund then
    update public.payments set status = 'refund_required'
     where booking_id = v_booking.id and status = 'succeeded';
  end if;

  return query select 'cancelled'::public.booking_status, v_refund;
end $$;

-- ---------------------------------------------------------------------------
-- Owner: phone booking or closing a slot. Prevents double booking with app users.
-- ---------------------------------------------------------------------------
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
  if not found or not (public.is_venue_owner(v_pitch.venue_id) or public.is_admin()) then
    raise exception 'forbidden';
  end if;
  if p_ends_at <= p_starts_at or p_ends_at - p_starts_at > interval '24 hours' then
    raise exception 'invalid_range';
  end if;

  perform public.expire_stale_holds();

  begin
    insert into public.bookings (pitch_id, venue_id, user_id, source, status, starts_at, ends_at,
                                 price_kurus, customer_name, customer_phone, note)
    values (v_pitch.id, v_pitch.venue_id, null, p_source, 'confirmed', p_starts_at, p_ends_at,
            case when p_source = 'manual'
                 then (v_pitch.hourly_price_kurus::bigint * extract(epoch from (p_ends_at - p_starts_at)) / 3600)::integer
                 else 0 end,
            left(p_customer_name, 80), left(p_customer_phone, 20), left(p_note, 500))
    returning * into v_booking;
  exception when exclusion_violation then
    raise exception 'slot_taken';
  end;
  return v_booking;
end $$;

-- Owner cancels any booking at their venue. App bookings get a full deposit refund.
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

  update public.bookings set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid(),
         cancel_reason = left(p_reason, 300), hold_expires_at = null
   where id = v_booking.id returning * into v_booking;

  update public.payments set status = 'refund_required'
   where booking_id = v_booking.id and status = 'succeeded';
  return v_booking;
end $$;

-- Owner marks a past booking as completed or no-show.
create or replace function public.owner_mark_attendance(p_booking_id uuid, p_status public.booking_status)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare v_booking public.bookings;
begin
  if p_status not in ('completed', 'no_show') then raise exception 'invalid_status'; end if;
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found or not (public.is_venue_owner(v_booking.venue_id) or public.is_admin()) then
    raise exception 'forbidden';
  end if;
  if v_booking.status not in ('confirmed', 'completed', 'no_show') or v_booking.starts_at > now() then
    raise exception 'invalid_status';
  end if;
  update public.bookings set status = p_status where id = v_booking.id returning * into v_booking;
  return v_booking;
end $$;

-- ---------------------------------------------------------------------------
-- Customer home list: active venues with min price, today's hours and distance.
-- ---------------------------------------------------------------------------
create or replace function public.list_venues(
  p_search text default null, p_district text default null,
  p_lat double precision default null, p_lng double precision default null
) returns table (
  id uuid, name text, district text, address text, cover_photo_path text,
  min_hourly_price_kurus integer, open_time time, close_time time,
  distance_km double precision, is_favorite boolean
)
language sql stable security definer set search_path = public as $$
  select v.id, v.name, v.district, v.address, v.cover_photo_path,
         (select min(p.hourly_price_kurus) from public.pitches p where p.venue_id = v.id and p.is_active),
         h.open_time, h.close_time,
         case when p_lat is null or p_lng is null or v.lat is null or v.lng is null then null
              else 6371 * 2 * asin(sqrt(
                     power(sin(radians(v.lat - p_lat) / 2), 2)
                   + cos(radians(p_lat)) * cos(radians(v.lat)) * power(sin(radians(v.lng - p_lng) / 2), 2)))
         end as distance_km,
         exists (select 1 from public.favorites f where f.venue_id = v.id and f.user_id = auth.uid())
    from public.venues v
    left join public.venue_hours h
      on h.venue_id = v.id
     and h.iso_weekday = extract(isodow from (now() at time zone 'Europe/Istanbul'))::smallint
   where v.status = 'active'
     and exists (select 1 from public.pitches p where p.venue_id = v.id and p.is_active)
     and (p_district is null or v.district = p_district)
     and (p_search is null or v.name ilike '%' || p_search || '%' or v.district ilike '%' || p_search || '%')
   order by distance_km nulls last, v.name
   limit 100;
$$;

-- ---------------------------------------------------------------------------
-- Admin: activate/suspend venues, set commission and PayTR sub-merchant key.
-- ---------------------------------------------------------------------------
create or replace function public.admin_update_venue(
  p_venue_id uuid, p_status public.venue_status default null,
  p_commission_bps integer default null, p_paytr_submerchant_key text default null
) returns public.venues
language plpgsql security definer set search_path = public as $$
declare v_venue public.venues;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  update public.venues set
         status = coalesce(p_status, status),
         commission_bps = coalesce(p_commission_bps, commission_bps),
         paytr_submerchant_key = coalesce(p_paytr_submerchant_key, paytr_submerchant_key)
   where id = p_venue_id returning * into v_venue;
  if not found then raise exception 'venue_not_found'; end if;
  return v_venue;
end $$;

-- Customer's loyalty progress ("5 maçta 1 kapora bizden" campaign, v1.1 UI).
create or replace function public.my_completed_match_count() returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.bookings
   where user_id = auth.uid() and source = 'app' and status = 'completed';
$$;

-- ---------------------------------------------------------------------------
-- Privileges: nothing is callable unless granted here.
-- ---------------------------------------------------------------------------
revoke all on function
  public.expire_stale_holds(), public.complete_past_bookings(),
  public.get_availability(uuid, date), public._is_valid_slot(uuid, timestamptz),
  public.create_booking_hold(uuid, timestamptz),
  public.start_payment(uuid, uuid), public.confirm_payment(text, boolean, integer, jsonb),
  public.cancel_booking(uuid, text),
  public.owner_create_manual_booking(uuid, timestamptz, timestamptz, public.booking_source, text, text, text),
  public.owner_cancel_booking(uuid, text), public.owner_mark_attendance(uuid, public.booking_status),
  public.list_venues(text, text, double precision, double precision),
  public.admin_update_venue(uuid, public.venue_status, integer, text),
  public.my_completed_match_count(),
  public.is_admin(), public.is_venue_owner(uuid), public.venue_is_visible(uuid)
from public;

grant execute on function public.get_availability(uuid, date)                                        to anon, authenticated;
grant execute on function public.list_venues(text, text, double precision, double precision)          to anon, authenticated;
grant execute on function public.create_booking_hold(uuid, timestamptz)                               to authenticated;
grant execute on function public.cancel_booking(uuid, text)                                           to authenticated;
grant execute on function public.owner_create_manual_booking(uuid, timestamptz, timestamptz, public.booking_source, text, text, text) to authenticated;
grant execute on function public.owner_cancel_booking(uuid, text)                                     to authenticated;
grant execute on function public.owner_mark_attendance(uuid, public.booking_status)                   to authenticated;
grant execute on function public.admin_update_venue(uuid, public.venue_status, integer, text)         to authenticated;
grant execute on function public.my_completed_match_count()                                           to authenticated;
grant execute on function public.is_admin(), public.is_venue_owner(uuid), public.venue_is_visible(uuid) to anon, authenticated;
-- service_role only (Edge Functions / pg_cron):
grant execute on function public.start_payment(uuid, uuid), public.confirm_payment(text, boolean, integer, jsonb),
                          public.expire_stale_holds(), public.complete_past_bookings() to service_role;

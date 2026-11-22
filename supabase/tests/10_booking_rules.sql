\o /dev/null
-- Booking invariants. Each block raises on failure; psql stops (ON_ERROR_STOP).
\set c1 '''00000000-0000-0000-0000-0000000000c1'''
\set c2 '''00000000-0000-0000-0000-0000000000c2'''
\set ow '''00000000-0000-0000-0000-0000000000b1'''

create or replace function pg_temp.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p::text, ''), false);
end $$;

-- 1. Overnight venue: 12:00 → 06:00 = 18 one-hour slots; last slot ends next day 06:00 local.
do $$
declare n int; last_end timestamptz; d date := (now() at time zone 'Europe/Istanbul')::date + 2;
begin
  select count(*), max(ends_at) into n, last_end
    from public.get_availability('20000000-0000-0000-0000-000000000003', d);
  assert n = 18, format('expected 18 slots, got %s', n);
  assert (last_end at time zone 'Europe/Istanbul') = (d + 1) + time '06:00', 'last slot must end 06:00 next day';
  select count(*) into n from public.get_availability('20000000-0000-0000-0000-000000000001', d);
  assert n = 13, format('11:00-24:00 expected 13 slots, got %s', n);
  raise notice 'ok 1 overnight availability';
end $$;

-- Shared slot for the next tests: 2 days ahead, 20:00 Istanbul.
create temp table t_slot as
  select ((((now() at time zone 'Europe/Istanbul')::date + 2) + time '20:00') at time zone 'Europe/Istanbul') as s;
grant select on t_slot to authenticated;

-- 2. Customer 1 holds; customer 2 cannot take the same slot.
set role authenticated;
select pg_temp.as_user(:c1);
create temp table t_b1 as select * from public.create_booking_hold('20000000-0000-0000-0000-000000000001', (select s from t_slot));
do $$ begin
  assert (select status from t_b1) = 'pending_payment', 'hold must be pending_payment';
  assert (select deposit_kurus from t_b1) = 50000, 'deposit from pitch';
  assert (select commission_kurus from t_b1) is null, 'hold must not reveal commission to the customer (F-06)';
  raise notice 'ok 2a hold created';
end $$;
select pg_temp.as_user(:c2);
do $$ begin
  perform public.create_booking_hold('20000000-0000-0000-0000-000000000001', (select s from t_slot));
  raise exception 'FAIL: second hold on same slot succeeded';
exception when others then
  assert sqlerrm = 'slot_taken', 'expected slot_taken, got ' || sqlerrm;
  raise notice 'ok 2b concurrent slot rejected';
end $$;

-- 3. Slot shows as booked; a non-slot start time is rejected.
do $$ begin
  assert (select state from public.get_availability('20000000-0000-0000-0000-000000000001',
            ((select s from t_slot) at time zone 'Europe/Istanbul')::date) where starts_at = (select s from t_slot)) = 'booked';
  perform public.create_booking_hold('20000000-0000-0000-0000-000000000001', (select s from t_slot) + interval '30 minutes');
  raise exception 'FAIL: misaligned slot accepted';
exception when others then
  assert sqlerrm = 'outside_opening_hours', 'expected outside_opening_hours, got ' || sqlerrm;
  raise notice 'ok 3 misaligned slot rejected';
end $$;

-- 3b. Commission is still stored server-side (checked as owner of the DB).
reset role;
do $$ begin
  assert (select commission_kurus from public.bookings where id = (select id from t_b1)) = 5000, 'commission 10% of deposit stored';
end $$;
set role authenticated;
select pg_temp.as_user(:c2);

-- 4. RLS: customer 2 cannot see customer 1's booking; anon sees no bookings at all.
do $$ begin
  assert (select count(*) from public.bookings where id = (select id from t_b1)) = 0, 'c2 must not see c1 booking';
  raise notice 'ok 4a RLS customer isolation';
end $$;
reset role;
set role anon;
do $$ begin
  perform 1 from public.bookings limit 1;
  raise exception 'FAIL: anon could read bookings';
exception when insufficient_privilege then raise notice 'ok 4b anon cannot read bookings';
end $$;
reset role;

-- 5. Owner cannot double book over a held slot from the panel.
set role authenticated;
select pg_temp.as_user(:ow);
do $$ begin
  perform public.owner_create_manual_booking('20000000-0000-0000-0000-000000000001',
            (select s from t_slot), (select s from t_slot) + interval '1 hour', 'manual', 'Telefon Müşterisi', '05550000000', null);
  raise exception 'FAIL: manual booking over hold';
exception when others then
  assert sqlerrm = 'slot_taken', 'expected slot_taken, got ' || sqlerrm;
  raise notice 'ok 5 owner manual booking respects holds';
end $$;
reset role;

-- 6. Payment success confirms; replayed callback is idempotent.
create temp table t_p1 as select * from public.start_payment((select id from t_b1), '00000000-0000-0000-0000-0000000000c1');
do $$ declare r text; begin
  assert (select merchant_oid from t_p1) ~ '^HS[0-9a-f]{36}$', 'merchant_oid format';
  r := public.confirm_payment((select merchant_oid from t_p1), true, 50000, '{"status":"success"}');
  assert r = 'succeeded', 'first callback: ' || r;
  assert (select status from public.bookings where id = (select id from t_b1)) = 'confirmed', 'booking confirmed';
  r := public.confirm_payment((select merchant_oid from t_p1), true, 50000, '{"status":"success"}');
  assert r = 'succeeded', 'replay must be idempotent: ' || r;
  raise notice 'ok 6 payment confirm + idempotent replay';
end $$;

-- 7. Late payment: hold expired AND slot taken by someone else → refund_required, no double booking.
set role authenticated;
select pg_temp.as_user(:c2);
create temp table t_b2 as select * from public.create_booking_hold('20000000-0000-0000-0000-000000000002', (select s from t_slot));
reset role;
create temp table t_p2 as select * from public.start_payment((select id from t_b2), '00000000-0000-0000-0000-0000000000c2');
update public.bookings set hold_expires_at = now() - interval '1 second' where id = (select id from t_b2);
select public.expire_stale_holds();
select public.owner_create_manual_booking('20000000-0000-0000-0000-000000000002', (select s from t_slot), (select s from t_slot) + interval '1 hour', 'block')
  where false; -- (owner call needs auth; do it as owner below)
set role authenticated;
select pg_temp.as_user(:ow);
select id from public.owner_create_manual_booking('20000000-0000-0000-0000-000000000002', (select s from t_slot), (select s from t_slot) + interval '1 hour', 'block') \gset blk_
reset role;
do $$ declare r text; begin
  r := public.confirm_payment((select merchant_oid from t_p2), true, 50000, '{"status":"success"}');
  assert r = 'refund_required', 'late payment on taken slot must be refund_required, got ' || r;
  assert (select status from public.bookings where id = (select id from t_b2)) = 'expired', 'booking stays expired';
  raise notice 'ok 7 late payment on taken slot → refund_required';
end $$;

-- 8. Amount tampering → refund_required.
set role authenticated;
select pg_temp.as_user(:c2);
create temp table t_b3 as select * from public.create_booking_hold('20000000-0000-0000-0000-000000000001', (select s from t_slot) + interval '1 hour');
reset role;
create temp table t_p3 as select * from public.start_payment((select id from t_b3), '00000000-0000-0000-0000-0000000000c2');
do $$ begin
  assert public.confirm_payment((select merchant_oid from t_p3), true, 100, '{}') = 'refund_required', 'underpayment must not confirm';
  raise notice 'ok 8 underpayment rejected';
end $$;

-- 9. Hold limit: max 2 pending holds per user.
set role authenticated;
select pg_temp.as_user(:c1);
select public.create_booking_hold('20000000-0000-0000-0000-000000000003', (select s from t_slot));
select public.create_booking_hold('20000000-0000-0000-0000-000000000003', (select s from t_slot) + interval '1 hour');
do $$ begin
  perform public.create_booking_hold('20000000-0000-0000-0000-000000000003', (select s from t_slot) + interval '2 hours');
  raise exception 'FAIL: third hold allowed';
exception when others then
  assert sqlerrm = 'too_many_pending_holds', 'expected too_many_pending_holds, got ' || sqlerrm;
  raise notice 'ok 9 hold limit';
end $$;

-- 10. Cancellation 2 days ahead (window 24h) → refund eligible, payment flagged.
do $$ declare r record; begin
  select * into r from public.cancel_booking((select id from t_b1), 'plan değişti');
  assert r.refund_eligible, 'cancel outside window must be refundable';
  raise notice 'ok 10 cancel → refund eligible';
end $$;
reset role;
do $$ begin
  assert (select status from public.payments where id = (select id from t_p1)) = 'refund_required', 'payment flagged for refund';
end $$;

-- 11. Privilege escalation: a customer cannot make themselves admin or see payout accounts.
insert into public.venue_payout_accounts values ('10000000-0000-0000-0000-000000000001', 'Test Ltd', '1234567890', 'TR000000000000000000000000', now());
set role authenticated;
select pg_temp.as_user(:c1);
do $$ begin
  update public.profiles set role = 'admin' where id = auth.uid();
  raise exception 'FAIL: role escalation';
exception when insufficient_privilege then raise notice 'ok 11a role column not writable';
end $$;
do $$ begin
  assert (select count(*) from public.venue_payout_accounts) = 0, 'customer must not see IBANs';
  assert (select count(*) from public.list_venues()) = 2, 'list_venues returns active venues';
  assert (select count(*) from public.list_venues(p_city => 'İstanbul', p_districts => array['Esenyurt'])) = 1,
         'list_venues filters by city + district';
  raise notice 'ok 11b payout accounts hidden';
end $$;
reset role;

-- 12. Commercial venue columns are hidden from anon and customers; admin reads them via RPC.
set role anon;
do $$ begin
  perform commission_bps from public.venues limit 1;
  raise exception 'FAIL: anon read commission_bps';
exception when insufficient_privilege then raise notice 'ok 12a commission hidden from anon';
end $$;
do $$ begin
  assert (select count(*) from public.venues) = 2, 'anon still lists active venues via safe columns';
exception when insufficient_privilege then
  -- count(*) needs no column privilege; reaching here means a regression
  raise exception 'FAIL: anon cannot list venues';
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
do $$ begin
  perform public.admin_list_venues();
  raise exception 'FAIL: customer called admin_list_venues';
exception when others then
  assert sqlerrm = 'forbidden', 'got ' || sqlerrm;
  raise notice 'ok 12b admin_list_venues forbidden for customers';
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
do $$ begin
  perform public.admin_list_venues();
  raise exception 'FAIL: admin without MFA (aal1) could call admin RPC';
exception when others then
  assert sqlerrm = 'forbidden', 'got ' || sqlerrm;
  raise notice 'ok 12b2 admin without MFA is not admin (S-04)';
end $$;
select set_config('request.jwt.claims', '{"aal":"aal2"}', false);
do $$ begin
  assert (select count(*) from public.admin_list_venues() where commission_bps = 1000) = 2, 'admin sees commission';
  raise notice 'ok 12c admin reads commission via RPC';
end $$;
reset role;
select set_config('request.jwt.claims', '', false);

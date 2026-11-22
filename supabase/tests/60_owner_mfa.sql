\o /dev/null
-- 60. Owner capabilities require MFA when the owner has a verified factor (S-18, migration 20261122100000).
--   owner_mfa_satisfied() = JWT aal2 OR no verified row in auth.mfa_factors for auth.uid().
-- Fixtures (6xxxxxxx-…), one set per owner i:
--   O1 (…a1) no factor · O2 (…a2) verified TOTP · O3 (…a3) only an unverified TOTP (enrolment not finished)
--   61…i1 active venue (pitch 62…i1, 7 days of hours, payout account) · 61…i2 pending venue (pitch 62…i2, no hours)
--   63…i1 future confirmed app booking of customer C1 (+ succeeded payment 64…i1) · 63…i2 past confirmed booking
--   C1 (…c1) customer without a factor · C2 (…c2) customer with a verified factor (customer rights unchanged)
insert into auth.users (id, phone, email, raw_user_meta_data) values
  ('60000000-0000-0000-0000-0000000000a1', null, 'mfa-o1@example.com', '{"full_name":"MFA Yok Sahip"}'),
  ('60000000-0000-0000-0000-0000000000a2', null, 'mfa-o2@example.com', '{"full_name":"MFA Var Sahip"}'),
  ('60000000-0000-0000-0000-0000000000a3', null, 'mfa-o3@example.com', '{"full_name":"MFA Yarım Sahip"}'),
  ('60000000-0000-0000-0000-0000000000c1', '905556660001', null, '{"full_name":"MFA Müşteri Bir"}'),
  ('60000000-0000-0000-0000-0000000000c2', '905556660002', null, '{"full_name":"MFA Müşteri İki"}');
update public.profiles set role = 'owner' where id::text like '60000000-0000-0000-0000-0000000000a_';
insert into auth.mfa_factors (user_id, status) values
  ('60000000-0000-0000-0000-0000000000a2', 'verified'),
  ('60000000-0000-0000-0000-0000000000a3', 'unverified'),
  ('60000000-0000-0000-0000-0000000000c2', 'verified');

create function pg_temp.u(p text, i int, s int default 1) returns uuid language sql immutable as $$
  select (p || '000000-0000-0000-0000-0000000000' || i || s)::uuid
$$;
create function pg_temp.slot(d int, h int) returns timestamptz language sql stable as $$
  select (((now() at time zone 'Europe/Istanbul')::date + d) + make_time(h, 0, 0)) at time zone 'Europe/Istanbul'
$$;

insert into public.venues (id, owner_id, name, district, status, paytr_submerchant_key)
select pg_temp.u('61', i, s), ('60000000-0000-0000-0000-0000000000a' || i)::uuid,
       'MFA Saha ' || i || '-' || s, 'Kadıköy',
       case s when 1 then 'active' else 'pending' end::public.venue_status,
       case s when 1 then 'TEST-SM-6' || i end
  from generate_series(1, 3) i, generate_series(1, 2) s;
insert into public.pitches (id, venue_id, name, hourly_price_kurus, deposit_kurus)
select pg_temp.u('62', i, s), pg_temp.u('61', i, s), 'P' || i || s, 300000, 50000
  from generate_series(1, 3) i, generate_series(1, 2) s;
insert into public.venue_hours (venue_id, iso_weekday, open_time, close_time)
select pg_temp.u('61', i), d::smallint, '08:00', '00:00'
  from generate_series(1, 3) i, generate_series(1, 7) d;   -- pending venues have no hours yet (insert target)
insert into public.venue_payout_accounts (venue_id, legal_name, tax_number, iban)
select pg_temp.u('61', i), 'MFA Spor ' || i, '123456789' || i, 'TR00000000000000000000006' || i
  from generate_series(1, 3) i;
insert into public.bookings (id, pitch_id, venue_id, user_id, source, status, starts_at, ends_at,
                             price_kurus, deposit_kurus, commission_kurus, confirmed_at)
select pg_temp.u('63', i, s), pg_temp.u('62', i), pg_temp.u('61', i), '60000000-0000-0000-0000-0000000000c1',
       'app', 'confirmed',
       case s when 1 then pg_temp.slot(5, 20) else pg_temp.slot(-2, 20) end,
       case s when 1 then pg_temp.slot(5, 21) else pg_temp.slot(-2, 21) end,
       300000, 50000, 5000, now() - interval '3 days'
  from generate_series(1, 3) i, generate_series(1, 2) s;
insert into public.payments (id, booking_id, user_id, merchant_oid, amount_kurus, status, provider_payload)
select pg_temp.u('64', i), pg_temp.u('63', i), '60000000-0000-0000-0000-0000000000c1',
       'HSmfa6' || i, 50000, 'succeeded', '{"total_amount":"50000"}'
  from generate_series(1, 3) i;
-- C2's own booking (customer with a verified factor).
insert into public.bookings (id, pitch_id, venue_id, user_id, source, status, starts_at, ends_at,
                             price_kurus, deposit_kurus, commission_kurus, confirmed_at)
values ('63000000-0000-0000-0000-0000000000c2', pg_temp.u('62', 1), pg_temp.u('61', 1),
        '60000000-0000-0000-0000-0000000000c2', 'app', 'confirmed', pg_temp.slot(6, 20), pg_temp.slot(6, 21),
        300000, 50000, 5000, now());

-- Runs p_sql as authenticated p_uid with JWT aal p_aal and ALWAYS rolls back.
-- Returns the single value of a query ('v' mode) or 'ok <rows>' ('x' mode), or 'ERR <sqlstate> <message>'.
create function pg_temp.as_user(p_uid uuid, p_aal text, p_mode text, p_sql text) returns text language plpgsql as $$
declare r text; n bigint; st text; msg text;
begin
  begin
    perform set_config('request.jwt.claim.sub', p_uid::text, true);
    perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'aal', p_aal)::text, true);
    perform set_config('role', 'authenticated', true);
    begin
      if p_mode = 'v' then
        execute p_sql into r; r := coalesce(r, '<null>');
      else
        execute p_sql; get diagnostics n = row_count; r := 'ok ' || n;
      end if;
    exception when others then
      get stacked diagnostics st = returned_sqlstate, msg = message_text;
      r := 'ERR ' || st || ' ' || msg;
    end;
    raise exception using errcode = 'ZX999', message = 'rollback';
  exception when sqlstate 'ZX999' then null;
  end;
  return r;
end $$;

-- Every owner capability for owner i, as a jsonb map key → result.
create function pg_temp.probe(i int, p_aal text) returns jsonb language plpgsql as $$
declare
  uid uuid := ('60000000-0000-0000-0000-0000000000a' || i)::uuid;
  v1 text := pg_temp.u('61', i)::text;   v2 text := pg_temp.u('61', i, 2)::text;
  p1 text := pg_temp.u('62', i)::text;   p2 text := pg_temp.u('62', i, 2)::text;
  b1 text := pg_temp.u('63', i)::text;   b2 text := pg_temp.u('63', i, 2)::text;
  res jsonb := '{}';
  k text; m text; q text;
begin
  for k, m, q in values
    ('contacts',     'v', format($q$select count(*) from public.owner_customer_contacts(array['60000000-0000-0000-0000-0000000000c1']::uuid[])$q$)),
    ('bookings',     'v', format($q$select count(*) from public.bookings where venue_id = %L and user_id = '60000000-0000-0000-0000-0000000000c1'$q$, v1)),
    ('payments',     'v', format($q$select count(*) from public.payments p join public.bookings b on b.id = p.booking_id where b.venue_id = %L$q$, v1)),
    ('payout',       'v', format($q$select count(*) from public.venue_payout_accounts where venue_id = %L$q$, v1)),
    ('pending_venue','v', format($q$select count(*) from public.venues where id = %L$q$, v2)),
    ('pending_pitch','v', format($q$select count(*) from public.pitches where id = %L$q$, p2)),
    ('pending_avail','v', format($q$select count(*) >= 0 from public.get_availability(%L, (now() at time zone 'Europe/Istanbul')::date + 3)$q$, p2)),
    ('storage',      'v', format($q$select public.is_venue_owner(%L)$q$, v1)),
    ('upd_venue',    'x', format($q$update public.venues set name = 'Yeni Ad' where id = %L$q$, v1)),
    ('ins_venue',    'x', $q$insert into public.venues (name, district) values ('Yeni Saha', 'Kadıköy')$q$),
    ('upd_pitch',    'x', format($q$update public.pitches set hourly_price_kurus = 400000 where id = %L$q$, p1)),
    ('ins_pitch',    'x', format($q$insert into public.pitches (venue_id, name, hourly_price_kurus, deposit_kurus) values (%L, 'X', 100, 0)$q$, v1)),
    ('ins_hours',    'x', format($q$insert into public.venue_hours (venue_id, iso_weekday, open_time, close_time) values (%L, 1, '09:00', '23:00')$q$, v2)),
    ('del_hours',    'x', format($q$delete from public.venue_hours where venue_id = %L$q$, v1)),
    ('upd_payout',   'x', format($q$update public.venue_payout_accounts set iban = 'TR990000000000000000000099' where venue_id = %L$q$, v1)),
    ('manual',       'x', format($q$select public.owner_create_manual_booking(%L, pg_temp.slot(7, 10), pg_temp.slot(7, 11), 'manual', 'Telefon')$q$, p1)),
    ('cancel',       'x', format($q$select public.owner_cancel_booking(%L, 'test')$q$, b1)),
    ('attend',       'x', format($q$select public.owner_mark_attendance(%L, 'no_show')$q$, b2)),
    -- public / customer-side reads must not change
    ('public_venue', 'v', format($q$select count(*) from public.venues where id = %L$q$, v1)),
    ('public_pitch', 'v', format($q$select count(*) from public.pitches where id = %L$q$, p1)),
    ('public_avail', 'v', format($q$select count(*) > 0 from public.get_availability(%L, (now() at time zone 'Europe/Istanbul')::date + 3)$q$, p1))
  loop
    res := res || jsonb_build_object(k, pg_temp.as_user(uid, p_aal, m, q));
  end loop;
  return res;
end $$;

create temp table t_expect (k text primary key, allowed text, denied text);
insert into t_expect values
  ('contacts',      '1',     '0'),
  ('bookings',      '2',     '0'),
  ('payments',      '1',     '0'),
  ('payout',        '1',     '0'),
  ('pending_venue', '1',     '0'),
  ('pending_pitch', '1',     '0'),
  ('pending_avail', 'true',  'ERR P0001 pitch_not_found'),
  ('storage',       'true',  'false'),
  ('upd_venue',     'ok 1',  'ok 0'),
  ('ins_venue',     'ok 1',  'ERR 42501 new row violates row-level security policy for table "venues"'),
  ('upd_pitch',     'ok 1',  'ok 0'),
  ('ins_pitch',     'ok 1',  'ERR 42501 new row violates row-level security policy for table "pitches"'),
  ('ins_hours',     'ok 1',  'ERR 42501 new row violates row-level security policy for table "venue_hours"'),
  ('del_hours',     'ok 7',  'ok 0'),
  ('upd_payout',    'ok 1',  'ok 0'),
  ('manual',        'ok 1',  'ERR P0001 forbidden'),
  ('cancel',        'ok 1',  'ERR P0001 forbidden'),
  ('attend',        'ok 1',  'ERR P0001 forbidden'),
  ('public_venue',  '1',     '1'),
  ('public_pitch',  '1',     '1'),
  ('public_avail',  'true',  'true');

create function pg_temp.check(p_label text, i int, p_aal text, p_allowed boolean) returns void language plpgsql as $$
declare got jsonb := pg_temp.probe(i, p_aal); r record; bad text := '';
begin
  for r in select k, case when p_allowed then allowed else denied end as want from t_expect order by k loop
    if got ->> r.k is distinct from r.want then
      bad := bad || format(E'\n  %s: want "%s" got "%s"', r.k, r.want, got ->> r.k);
    end if;
  end loop;
  if bad <> '' then raise exception 'FAIL %:%', p_label, bad; end if;
  raise notice 'ok % (% checks)', p_label, (select count(*) from t_expect);
end $$;

-- 60a. Owner without a factor, aal1 → unchanged (regression for every existing owner).
do $$ begin perform pg_temp.check('60a owner without MFA factor, aal1 → all owner capabilities', 1, 'aal1', true); end $$;
-- 60b. Owner with a verified factor, aal1 (stolen password) → every owner capability blocked.
do $$ begin perform pg_temp.check('60b owner with verified factor, aal1 → owner capabilities blocked', 2, 'aal1', false); end $$;
-- 60c. Same owner after the TOTP step (aal2) → works.
do $$ begin perform pg_temp.check('60c owner with verified factor, aal2 → all owner capabilities', 2, 'aal2', true); end $$;
-- 60d. Missing aal claim is treated as aal1.
do $$ declare r text; begin
  r := pg_temp.as_user('60000000-0000-0000-0000-0000000000a2', null, 'v',
         $q$select count(*) from public.bookings where venue_id = '61000000-0000-0000-0000-000000000021'$q$);
  assert r = '0', 'missing aal claim must count as aal1, got ' || r;
  raise notice 'ok 60d missing aal claim → aal1';
end $$;
-- 60e. Owner with only an unverified factor (enrolment never finished), aal1 → works.
do $$ begin perform pg_temp.check('60e owner with only unverified factor, aal1 → all owner capabilities', 3, 'aal1', true); end $$;

-- 60f. Customer rights do not depend on MFA (C1 no factor, C2 verified factor; both aal1).
do $$ declare r text; begin
  r := pg_temp.as_user('60000000-0000-0000-0000-0000000000c1', 'aal1', 'v',
         $q$select count(*) from public.bookings where user_id = auth.uid()$q$);
  assert r = '6', 'C1 must see own 6 bookings, got ' || r;
  r := pg_temp.as_user('60000000-0000-0000-0000-0000000000c1', 'aal1', 'v',
         $q$select count(*) from public.payments where user_id = auth.uid()$q$);
  assert r = '3', 'C1 must see own 3 payments, got ' || r;
  r := pg_temp.as_user('60000000-0000-0000-0000-0000000000c2', 'aal1', 'v',
         $q$select count(*) from public.bookings where user_id = auth.uid()$q$);
  assert r = '1', 'C2 (verified factor, aal1) must still see own booking, got ' || r;
  r := pg_temp.as_user('60000000-0000-0000-0000-0000000000c2', 'aal1', 'x',
         $q$select public.cancel_booking('63000000-0000-0000-0000-0000000000c2', 'test')$q$);
  assert r = 'ok 1', 'C2 (verified factor, aal1) must still cancel own booking, got ' || r;
  r := pg_temp.as_user('60000000-0000-0000-0000-0000000000c2', 'aal1', 'x',
         $q$select public.create_booking_hold('62000000-0000-0000-0000-000000000011', pg_temp.slot(3, 18))$q$);
  assert r = 'ok 1', 'C2 (verified factor, aal1) must still create a hold, got ' || r;
  raise notice 'ok 60f customer access unaffected by MFA (with and without factor)';
end $$;

-- 60g. Anon still reads active venues/pitches/hours; owner_mfa_satisfied is not callable by anon.
set role anon;
do $$ begin
  assert (select count(*) from public.venues where id::text like '61000000-0000-0000-0000-0000000000_1') = 3, 'anon sees active venues';
  assert (select count(*) from public.venues where id::text like '61000000-0000-0000-0000-0000000000_2') = 0, 'anon must not see pending';
  assert (select count(*) from public.pitches where id::text like '62000000-0000-0000-0000-0000000000_1') = 3, 'anon sees active pitches';
  assert (select count(*) from public.venue_hours where venue_id::text like '61000000-0000-0000-0000-0000000000_1') = 21, 'anon sees hours';
  begin
    perform public.owner_mfa_satisfied();
    raise exception 'FAIL: anon called owner_mfa_satisfied';
  exception when insufficient_privilege then null;
  end;
  raise notice 'ok 60g public reads unchanged; helper not exposed to anon';
end $$;
reset role;

-- 60h. Helper is security definer with a fixed search_path; clients cannot read auth.mfa_factors.
do $$ begin
  assert (select prosecdef and 'search_path=public' = any (proconfig) from pg_proc
           where oid = 'public.owner_mfa_satisfied()'::regprocedure), 'owner_mfa_satisfied must be security definer + search_path';
  assert not has_table_privilege('authenticated', 'auth.mfa_factors', 'select'), 'authenticated must not read mfa_factors';
  assert not has_table_privilege('anon', 'auth.mfa_factors', 'select'), 'anon must not read mfa_factors';
  raise notice 'ok 60h helper hardening';
end $$;
\o

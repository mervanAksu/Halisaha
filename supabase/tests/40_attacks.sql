\o /dev/null
-- =====================================================================================================
-- 40_attacks.sql — red-team attack suite (security/THREAT_MODEL.md, security/FINDINGS.md).
--
-- Every attack runs as the attacker role (anon / authenticated customer / other owner / service_role)
-- and ASSERTS that it is blocked:
--   ok A<n> <name>            → defended
--   WARNING VULN A<n> <name>  → known open finding (soft assertion, listed in security/FINDINGS.md).
--                               After the fix, flip the call's last argument (p_soft) to false.
--   ERROR FAIL A<n> …         → a hard assertion regressed: the suite (and CI) stops.
--   ERROR TESTBUG A<n> …      → the attack was "blocked" by an unexpected error; fix the test.
--
-- Side effects of successful exploits are rolled back (sub-transaction + sentinel error ZX999), so the
-- attacks are independent. Fixtures use their own ids (4xxxxxxx-…) and do not depend on 10_/20_/30_.
-- =====================================================================================================

-- ---------------------------------------------------------------------------------------------------
-- Harness
-- ---------------------------------------------------------------------------------------------------
create temp table t_atk (id text, name text, blocked boolean, detail text, soft boolean);
grant all on t_atk to public;

-- Switch actor for the rest of the current transaction (DO block). Session user is superuser, so we can
-- always switch back; anything set here is undone when the sub-transaction rolls back.
create function pg_temp.act(p_role text, p_uid uuid default null) returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  perform set_config('role', p_role, true);
end $$;

-- Runs a statement as the current role. 'ok <rows>' or 'ERR <sqlstate> <message>'. Keeps side effects.
create function pg_temp.try(p_sql text) returns text language plpgsql as $$
declare n bigint; st text; msg text;
begin
  execute p_sql;
  get diagnostics n = row_count;
  return 'ok ' || n;
exception when others then
  get stacked diagnostics st = returned_sqlstate, msg = message_text;
  return 'ERR ' || st || ' ' || msg;
end $$;

-- Single value of a query as text, or 'ERR <sqlstate> <message>'.
create function pg_temp.val(p_sql text) returns text language plpgsql as $$
declare v text; st text; msg text;
begin
  execute p_sql into v;
  return coalesce(v, '<null>');
exception when others then
  get stacked diagnostics st = returned_sqlstate, msg = message_text;
  return 'ERR ' || st || ' ' || msg;
end $$;

create function pg_temp.report(p_id text, p_name text, p_blocked boolean, p_detail text, p_soft boolean default false)
returns void language plpgsql as $$
begin
  insert into t_atk values (p_id, p_name, p_blocked, p_detail, p_soft);
  if p_blocked then
    raise notice 'ok % % (%)', p_id, p_name, left(p_detail, 160);
  elsif p_soft then
    raise warning 'VULN % %: %', p_id, p_name, p_detail;
  else
    raise exception 'FAIL % %: exploit succeeded: %', p_id, p_name, p_detail;
  end if;
end $$;

-- Exploit statement must error with an expected code/message (regex on 'sqlstate message') or touch 0 rows.
-- Always rolled back.
create function pg_temp.must_fail(p_id text, p_name text, p_sql text, p_expect text default '42501',
                                  p_soft boolean default false) returns void language plpgsql as $$
declare r text;
begin
  begin
    r := pg_temp.try(p_sql);
    raise exception using errcode = 'ZX999', message = 'rollback';
  exception when sqlstate 'ZX999' then null;
  end;
  if r = 'ok 0' then
    perform pg_temp.report(p_id, p_name, true, '0 rows');
  elsif r like 'ERR %' then
    if substr(r, 5) !~ p_expect then
      raise exception 'TESTBUG % %: unexpected error "%" (expected /%/)', p_id, p_name, r, p_expect;
    end if;
    perform pg_temp.report(p_id, p_name, true, substr(r, 5));
  else
    perform pg_temp.report(p_id, p_name, false, r, p_soft);
  end if;
end $$;

-- Query returning one number must return 0 (nothing leaked) or error with an expected code. Rolled back.
create function pg_temp.must_zero(p_id text, p_name text, p_sql text, p_expect text default '42501',
                                  p_soft boolean default false) returns void language plpgsql as $$
declare r text;
begin
  begin
    r := pg_temp.val(p_sql);
    raise exception using errcode = 'ZX999', message = 'rollback';
  exception when sqlstate 'ZX999' then null;
  end;
  if r = '0' then
    perform pg_temp.report(p_id, p_name, true, '0 rows');
  elsif r like 'ERR %' then
    if substr(r, 5) !~ p_expect then
      raise exception 'TESTBUG % %: unexpected error "%" (expected /%/)', p_id, p_name, r, p_expect;
    end if;
    perform pg_temp.report(p_id, p_name, true, substr(r, 5));
  else
    perform pg_temp.report(p_id, p_name, false, 'leaked: ' || r, p_soft);
  end if;
end $$;

-- Venue-local slot start: today(Istanbul) + d days at hh:mm.
create function pg_temp.slot(d int, h int, m int default 0) returns timestamptz language sql stable as $$
  select (((now() at time zone 'Europe/Istanbul')::date + d) + make_time(h, m, 0)) at time zone 'Europe/Istanbul'
$$;

-- ---------------------------------------------------------------------------------------------------
-- Fixtures (as postgres). OA owns VA (active) + VAP (pending). OB owns VB (active), VBS (suspended),
-- VBP (pending). CX = victim customer with a paid booking at VB. CY = attacker customer.
-- ---------------------------------------------------------------------------------------------------
insert into auth.users (id, phone, email, raw_user_meta_data) values
  ('40000000-0000-0000-0000-0000000000a0', null, 'owner-a@example.com', '{"full_name":"Owner A"}'),
  ('40000000-0000-0000-0000-0000000000b0', null, 'owner-b@example.com', '{"full_name":"Owner B"}'),
  ('40000000-0000-0000-0000-0000000000c0', '905551110000', null, '{"full_name":"Kurban X"}'),
  ('40000000-0000-0000-0000-0000000000c9', '905551110009', null, '{"full_name":"Saldırgan Y"}'),
  ('40000000-0000-0000-0000-0000000000ca', '905551110010', null, '{"full_name":"Müşteri Z"}'),
  ('40000000-0000-0000-0000-0000000000cb', '905551110011', null, '{"full_name":"Müşteri W"}'),
  ('40000000-0000-0000-0000-0000000000cc', '905551110012', null, '{"full_name":"Müşteri V"}'),
  ('40000000-0000-0000-0000-0000000000cd', '905551110013', null, '{"full_name":"Müşteri U"}');
update public.profiles set role = 'owner'
 where id in ('40000000-0000-0000-0000-0000000000a0', '40000000-0000-0000-0000-0000000000b0');

insert into public.venues (id, owner_id, name, district, status, cancellation_window_hours) values
  ('41000000-0000-0000-0000-0000000000a1', '40000000-0000-0000-0000-0000000000a0', 'Atak Arena A',     'Kadıköy', 'active',    24),
  ('41000000-0000-0000-0000-0000000000a2', '40000000-0000-0000-0000-0000000000a0', 'Atak Bekleyen A',  'Kadıköy', 'pending',   24),
  ('41000000-0000-0000-0000-0000000000b1', '40000000-0000-0000-0000-0000000000b0', 'Rakip Arena B',    'Beşiktaş', 'active',   24),
  ('41000000-0000-0000-0000-0000000000b2', '40000000-0000-0000-0000-0000000000b0', 'Askıdaki Saha B',  'Beşiktaş', 'suspended', 24),
  ('41000000-0000-0000-0000-0000000000b3', '40000000-0000-0000-0000-0000000000b0', 'Gizli Bekleyen B', 'Beşiktaş', 'pending',   24);
-- Live fixture venues need a PayTR sub-merchant key (F-03: deposits must go through the marketplace split).
update public.venues set paytr_submerchant_key = 'TEST-SM-' || right(id::text, 4)
 where id in ('41000000-0000-0000-0000-0000000000a1', '41000000-0000-0000-0000-0000000000b1');

insert into public.venue_hours (venue_id, iso_weekday, open_time, close_time)
select v::uuid, d::smallint, '08:00', '00:00'
  from unnest(array['41000000-0000-0000-0000-0000000000a1', '41000000-0000-0000-0000-0000000000a2',
                    '41000000-0000-0000-0000-0000000000b1', '41000000-0000-0000-0000-0000000000b2',
                    '41000000-0000-0000-0000-0000000000b3']) v, generate_series(1, 7) d;

insert into public.pitches (id, venue_id, name, hourly_price_kurus, deposit_kurus, slot_minutes, is_active) values
  ('42000000-0000-0000-0000-0000000000a1', '41000000-0000-0000-0000-0000000000a1', 'A-60',      300000, 50000, 60,  true),
  ('42000000-0000-0000-0000-0000000000a2', '41000000-0000-0000-0000-0000000000a1', 'A-90',      300000, 50000, 90,  true),
  ('42000000-0000-0000-0000-0000000000a4', '41000000-0000-0000-0000-0000000000a1', 'A-pasif',   300000, 50000, 60,  false),
  ('42000000-0000-0000-0000-0000000000a5', '41000000-0000-0000-0000-0000000000a2', 'AP-60',     300000, 50000, 60,  true),
  ('42000000-0000-0000-0000-0000000000b1', '41000000-0000-0000-0000-0000000000b1', 'B-60',      300000, 50000, 60,  true),
  ('42000000-0000-0000-0000-0000000000b2', '41000000-0000-0000-0000-0000000000b2', 'BS-60',     300000, 50000, 60,  true),
  ('42000000-0000-0000-0000-0000000000b3', '41000000-0000-0000-0000-0000000000b3', 'BP-60',     300000, 50000, 60,  true);

insert into public.venue_payout_accounts (venue_id, legal_name, tax_number, iban)
values ('41000000-0000-0000-0000-0000000000b1', 'Rakip Spor Ltd', '1234567890', 'TR000000000000000000000001');

-- Victim's paid booking at VB, 4 days ahead.
insert into public.bookings (id, pitch_id, venue_id, user_id, source, status, starts_at, ends_at,
                             price_kurus, deposit_kurus, commission_kurus)
values ('43000000-0000-0000-0000-0000000000c0', '42000000-0000-0000-0000-0000000000b1', '41000000-0000-0000-0000-0000000000b1',
        '40000000-0000-0000-0000-0000000000c0', 'app', 'confirmed', pg_temp.slot(4, 20), pg_temp.slot(4, 21),
        300000, 50000, 5000);
insert into public.payments (id, booking_id, user_id, merchant_oid, amount_kurus, status, provider_payload)
values ('44000000-0000-0000-0000-0000000000c0', '43000000-0000-0000-0000-0000000000c0', '40000000-0000-0000-0000-0000000000c0',
        'HSatkvictim01', 50000, 'succeeded', '{"total_amount":"50000"}');
insert into public.favorites (user_id, venue_id) values ('40000000-0000-0000-0000-0000000000c0', '41000000-0000-0000-0000-0000000000b1');
insert into public.device_tokens (token, user_id, platform) values ('fcm-victim-cx', '40000000-0000-0000-0000-0000000000c0', 'ios');

-- =====================================================================================================
-- 1. Direct table access as anon
-- =====================================================================================================
do $$ begin
  perform pg_temp.act('anon');
  perform pg_temp.must_zero('A1',  'anon reads profiles',              $q$select count(*) from public.profiles$q$);
  perform pg_temp.must_zero('A2',  'anon reads bookings',              $q$select count(*) from public.bookings$q$);
  perform pg_temp.must_zero('A3',  'anon reads payments',              $q$select count(*) from public.payments$q$);
  perform pg_temp.must_zero('A4',  'anon reads venue_payout_accounts', $q$select count(*) from public.venue_payout_accounts$q$);
  perform pg_temp.must_zero('A5',  'anon reads favorites',             $q$select count(*) from public.favorites$q$);
  perform pg_temp.must_zero('A6',  'anon reads device_tokens',         $q$select count(*) from public.device_tokens$q$);
  perform pg_temp.must_zero('A7',  'anon reads non-active venues',
    $q$select count(*) from public.venues where id in ('41000000-0000-0000-0000-0000000000a2','41000000-0000-0000-0000-0000000000b2','41000000-0000-0000-0000-0000000000b3')$q$);
  perform pg_temp.must_zero('A8',  'anon reads pitches/hours of non-active venues',
    $q$select (select count(*) from public.pitches where venue_id in ('41000000-0000-0000-0000-0000000000a2','41000000-0000-0000-0000-0000000000b2','41000000-0000-0000-0000-0000000000b3'))
           + (select count(*) from public.venue_hours where venue_id in ('41000000-0000-0000-0000-0000000000a2','41000000-0000-0000-0000-0000000000b2','41000000-0000-0000-0000-0000000000b3'))$q$);
  perform pg_temp.must_zero('A9',  'anon reads commission_bps / paytr_submerchant_key',
    $q$select count(commission_bps) + count(paytr_submerchant_key) from public.venues$q$);
  perform pg_temp.must_fail('A9b', 'anon writes venues',
    $q$insert into public.venues (owner_id, name, district) values ('40000000-0000-0000-0000-0000000000a0', 'anon venue', 'Kadıköy')$q$);
end $$;

-- =====================================================================================================
-- 2. Customer Y → data of customer X (IDOR)
-- =====================================================================================================
do $$ begin
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c9');
  perform pg_temp.must_zero('A10', 'customer reads other customer''s booking',
    $q$select count(*) from public.bookings where id = '43000000-0000-0000-0000-0000000000c0' or user_id = '40000000-0000-0000-0000-0000000000c0'$q$);
  perform pg_temp.must_zero('A11', 'customer reads other customer''s payment',
    $q$select count(*) from public.payments where booking_id = '43000000-0000-0000-0000-0000000000c0' or merchant_oid = 'HSatkvictim01'$q$);
  perform pg_temp.must_zero('A12', 'customer reads other customer''s profile (phone)',
    $q$select count(*) from public.profiles where id <> auth.uid()$q$);
  perform pg_temp.must_zero('A13', 'customer reads other customer''s favorites',
    $q$select count(*) from public.favorites where user_id <> auth.uid()$q$);
  perform pg_temp.must_zero('A14', 'customer reads other customer''s device tokens',
    $q$select count(*) from public.device_tokens where user_id <> auth.uid()$q$);
  perform pg_temp.must_zero('A15', 'customer reads payout accounts (IBAN/VKN)',
    $q$select count(*) from public.venue_payout_accounts$q$);
  perform pg_temp.must_zero('A16', 'customer reads owner profile rows',
    $q$select count(*) from public.profiles where role <> 'customer'$q$);
end $$;

-- =====================================================================================================
-- 3. Owner A → data of owner B (cross-tenant IDOR)
-- =====================================================================================================
do $$ begin
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
  perform pg_temp.must_zero('A17', 'owner reads other venue''s bookings',
    $q$select count(*) from public.bookings where venue_id::text like '41000000-0000-0000-0000-0000000000b%' or id = '43000000-0000-0000-0000-0000000000c0'$q$);
  perform pg_temp.must_zero('A18', 'owner reads other venue''s payments',
    $q$select count(*) from public.payments where merchant_oid = 'HSatkvictim01'$q$);
  perform pg_temp.must_zero('A19', 'owner reads other venue''s payout account',
    $q$select count(*) from public.venue_payout_accounts where venue_id = '41000000-0000-0000-0000-0000000000b1'$q$);
  perform pg_temp.must_zero('A20', 'owner reads other venue''s customer profile',
    $q$select count(*) from public.profiles where id = '40000000-0000-0000-0000-0000000000c0'$q$);
  perform pg_temp.must_zero('A21', 'owner reads other owner''s pending/suspended venues',
    $q$select count(*) from public.venues where id in ('41000000-0000-0000-0000-0000000000b2','41000000-0000-0000-0000-0000000000b3')$q$);
  perform pg_temp.must_zero('A22', 'owner_customer_contacts with another venue''s customer id',
    $q$select count(*) from public.owner_customer_contacts(array['40000000-0000-0000-0000-0000000000c0','40000000-0000-0000-0000-0000000000b0','40000000-0000-0000-0000-0000000000a1']::uuid[])$q$);
  perform pg_temp.must_fail('A23', 'get_availability on another owner''s pending venue',
    $q$select * from public.get_availability('42000000-0000-0000-0000-0000000000b3', current_date + 2)$q$, 'pitch_not_found');
end $$;

-- =====================================================================================================
-- 4. Privilege escalation through direct writes
-- =====================================================================================================
do $$ begin
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c9');
  perform pg_temp.must_fail('A24', 'customer sets own role=admin',
    $q$update public.profiles set role = 'admin' where id = auth.uid()$q$);
  perform pg_temp.must_fail('A25', 'customer changes own verified phone/email',
    $q$update public.profiles set phone = '905000000000', email = 'x@evil.test' where id = auth.uid()$q$);
  perform pg_temp.must_fail('A26', 'customer inserts a second profile as owner',
    $q$insert into public.profiles (id, role) values ('40000000-0000-0000-0000-0000000000ff', 'owner')$q$);
  perform pg_temp.must_fail('A27', 'customer creates a venue',
    $q$insert into public.venues (name, district) values ('Sahte Saha', 'Kadıköy')$q$);
  perform pg_temp.must_fail('A27b', 'customer updates other customer''s profile name',
    $q$update public.profiles set full_name = 'hacked' where id = '40000000-0000-0000-0000-0000000000c0'$q$);

  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
  perform pg_temp.must_fail('A28', 'owner inserts venue with owner_id of another owner',
    $q$insert into public.venues (owner_id, name, district) values ('40000000-0000-0000-0000-0000000000b0', 'Spoof', 'Kadıköy')$q$);
  perform pg_temp.must_fail('A29', 'owner inserts venue already status=active',
    $q$insert into public.venues (name, district, status) values ('Kendi Onayım', 'Kadıköy', 'active')$q$);
  perform pg_temp.must_fail('A30', 'owner inserts venue with commission_bps=0',
    $q$insert into public.venues (name, district, commission_bps) values ('Komisyonsuz', 'Kadıköy', 0)$q$);
  perform pg_temp.must_fail('A31', 'owner self-approves pending venue',
    $q$update public.venues set status = 'active' where id = '41000000-0000-0000-0000-0000000000a2'$q$);
  perform pg_temp.must_fail('A32', 'owner lowers own commission / sets PayTR sub-merchant key',
    $q$update public.venues set commission_bps = 0, paytr_submerchant_key = 'attacker' where id = '41000000-0000-0000-0000-0000000000a1'$q$);
  perform pg_temp.must_fail('A33', 'owner reassigns owner_id of own/other venue',
    $q$update public.venues set owner_id = '40000000-0000-0000-0000-0000000000a0' where id = '41000000-0000-0000-0000-0000000000b1'$q$);
  perform pg_temp.must_fail('A34', 'owner edits another owner''s venue',
    $q$update public.venues set name = 'Hacked', phone = '0000' where id = '41000000-0000-0000-0000-0000000000b1'$q$);
  perform pg_temp.must_fail('A35', 'owner inserts pitch into another owner''s venue',
    $q$insert into public.pitches (venue_id, name, hourly_price_kurus, deposit_kurus) values ('41000000-0000-0000-0000-0000000000b1', 'Sızma', 100, 0)$q$);
  perform pg_temp.must_fail('A36', 'owner overwrites another venue''s opening hours (upsert)',
    $q$insert into public.venue_hours (venue_id, iso_weekday, open_time, close_time) values ('41000000-0000-0000-0000-0000000000b1', 1, '03:00', '04:00')
       on conflict (venue_id, iso_weekday) do update set open_time = excluded.open_time, close_time = excluded.close_time$q$);
  perform pg_temp.must_fail('A36b', 'owner deletes another venue''s opening hours',
    $q$delete from public.venue_hours where venue_id = '41000000-0000-0000-0000-0000000000b1'$q$);
  perform pg_temp.must_fail('A37', 'owner deletes another owner''s pitch',
    $q$delete from public.pitches where venue_id = '41000000-0000-0000-0000-0000000000b1'$q$);
  perform pg_temp.must_fail('A38', 'owner moves own pitch into another owner''s venue',
    $q$update public.pitches set venue_id = '41000000-0000-0000-0000-0000000000b1' where id = '42000000-0000-0000-0000-0000000000a1'$q$);
  perform pg_temp.must_fail('A39', 'owner pulls another owner''s pitch into own venue',
    $q$update public.pitches set venue_id = '41000000-0000-0000-0000-0000000000a1' where id = '42000000-0000-0000-0000-0000000000b1'$q$);
  perform pg_temp.must_fail('A40', 'owner upserts payout IBAN for another venue',
    $q$insert into public.venue_payout_accounts (venue_id, legal_name, tax_number, iban) values ('41000000-0000-0000-0000-0000000000b1', 'Attacker', '1111111111', 'TR999999999999999999999999')
       on conflict (venue_id) do update set iban = excluded.iban$q$);
  perform pg_temp.must_fail('A41', 'owner updates another venue''s payout IBAN',
    $q$update public.venue_payout_accounts set iban = 'TR999999999999999999999999' where venue_id = '41000000-0000-0000-0000-0000000000b1'$q$);
  perform pg_temp.must_fail('A41b', 'owner deletes venues (no delete grant)',
    $q$delete from public.venues where id = '41000000-0000-0000-0000-0000000000a2'$q$);

  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c9');
  perform pg_temp.must_fail('A42', 'customer adds favorite on behalf of another user',
    $q$insert into public.favorites (user_id, venue_id) values ('40000000-0000-0000-0000-0000000000c0', '41000000-0000-0000-0000-0000000000a1')$q$);
  perform pg_temp.must_fail('A43', 'customer registers a push token for another user',
    $q$insert into public.device_tokens (token, user_id, platform) values ('fcm-evil', '40000000-0000-0000-0000-0000000000c0', 'ios')$q$);
  perform pg_temp.must_fail('A44', 'customer steals another user''s push token row',
    $q$update public.device_tokens set user_id = auth.uid() where token = 'fcm-victim-cx'$q$);
  perform pg_temp.must_fail('A45', 'customer inserts a confirmed booking directly',
    $q$insert into public.bookings (pitch_id, venue_id, user_id, status, starts_at, ends_at) values ('42000000-0000-0000-0000-0000000000a1', '41000000-0000-0000-0000-0000000000a1', auth.uid(), 'confirmed', now() + interval '3 days', now() + interval '3 days 1 hour')$q$);
  perform pg_temp.must_fail('A47', 'customer inserts a succeeded payment directly',
    $q$insert into public.payments (booking_id, user_id, merchant_oid, amount_kurus, status) values ('43000000-0000-0000-0000-0000000000c0', auth.uid(), 'HSforged', 1, 'succeeded')$q$);
  perform pg_temp.must_fail('A49', 'customer calls admin_update_venue',
    $q$select public.admin_update_venue('41000000-0000-0000-0000-0000000000b3', 'active', 0, 'x')$q$, 'forbidden');

  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c0');
  perform pg_temp.must_fail('A46', 'customer edits own booking (status/deposit/time)',
    $q$update public.bookings set status = 'confirmed', deposit_kurus = 0, starts_at = starts_at + interval '1 hour' where id = '43000000-0000-0000-0000-0000000000c0'$q$);
  perform pg_temp.must_fail('A46b', 'customer edits own payment status',
    $q$update public.payments set status = 'refund_required' where merchant_oid = 'HSatkvictim01'$q$);

  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
  perform pg_temp.must_fail('A48', 'owner edits bookings directly (bypassing RPC rules)',
    $q$update public.bookings set status = 'cancelled' where venue_id = '41000000-0000-0000-0000-0000000000a1'$q$);
  perform pg_temp.must_fail('A50', 'owner calls admin_update_venue on own venue',
    $q$select public.admin_update_venue('41000000-0000-0000-0000-0000000000a2', 'active', 0, 'self')$q$, 'forbidden');
  perform pg_temp.must_fail('A51', 'owner calls admin_list_venues',
    $q$select count(*) from public.admin_list_venues()$q$, 'forbidden');
end $$;

-- =====================================================================================================
-- 5. RPC abuse with crafted arguments
-- =====================================================================================================
do $$ begin
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
  perform pg_temp.must_fail('A53', 'owner_create_manual_booking on another owner''s pitch',
    $q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000b1', pg_temp.slot(5, 10), pg_temp.slot(5, 11), 'block')$q$, 'forbidden');
  perform pg_temp.must_fail('A55', 'owner block longer than 24h',
    $q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(5, 10), pg_temp.slot(6, 10) + interval '1 second', 'block')$q$, 'invalid_range');
  perform pg_temp.must_fail('A56', 'owner booking with end <= start (negative range)',
    $q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(5, 11), pg_temp.slot(5, 10), 'manual', 'x')$q$, 'invalid_range');
  perform pg_temp.must_fail('A57', 'owner booking with NULL start/end',
    $q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000a1', null, null, 'block')$q$, '23502|invalid_range');
  perform pg_temp.must_fail('A58', 'owner forges source=app (skips payment)',
    $q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(5, 10), pg_temp.slot(5, 11), 'app')$q$, 'invalid_source');
  perform pg_temp.must_fail('A58b', 'owner passes NULL source',
    $q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(5, 10), pg_temp.slot(5, 11), null)$q$, '23502|invalid_source');
  perform pg_temp.must_fail('A59', 'owner manual booking on non-existent pitch',
    $q$select public.owner_create_manual_booking(gen_random_uuid(), pg_temp.slot(5, 10), pg_temp.slot(5, 11), 'block')$q$, 'forbidden');
  perform pg_temp.must_fail('A59b', 'owner infinite block (-infinity..infinity)',
    $q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000a1', '-infinity', 'infinity', 'block')$q$, 'invalid_range|infinite|out of range');

  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c9');
  perform pg_temp.must_fail('A54', 'customer calls owner_create_manual_booking',
    $q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(5, 10), pg_temp.slot(5, 11), 'block')$q$, 'forbidden');
  perform pg_temp.must_fail('A60', 'hold on pending (unapproved) venue',
    $q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a5', pg_temp.slot(3, 18))$q$, 'pitch_not_found');
  perform pg_temp.must_fail('A61', 'hold on suspended venue',
    $q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000b2', pg_temp.slot(3, 18))$q$, 'pitch_not_found');
  perform pg_temp.must_fail('A62', 'hold on inactive pitch',
    $q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a4', pg_temp.slot(3, 18))$q$, 'pitch_not_found');
  perform pg_temp.must_fail('A63', 'hold with NULL pitch',
    $q$select public.create_booking_hold(null, pg_temp.slot(3, 18))$q$, 'pitch_not_found');
  perform pg_temp.must_fail('A63b', 'hold with NULL start',
    $q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', null)$q$, 'outside_opening_hours|slot_in_past');
  perform pg_temp.must_fail('A64', 'hold at -infinity',
    $q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', '-infinity')$q$, 'slot_in_past');
  perform pg_temp.must_fail('A64b', 'hold at +infinity',
    $q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', 'infinity')$q$, 'too_far_ahead');
  perform pg_temp.must_fail('A65', 'hold misaligned by 1 second',
    $q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(3, 18) + interval '1 second')$q$, 'outside_opening_hours');
  perform pg_temp.must_fail('A65b', 'hold outside opening hours (03:00)',
    $q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(3, 3))$q$, 'outside_opening_hours');
  perform pg_temp.must_fail('A66', 'hold 31 days ahead',
    $q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(31, 18))$q$, 'too_far_ahead');
  perform pg_temp.must_fail('A67', 'hold starting within 15 minutes',
    $q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', now() + interval '5 minutes')$q$, 'slot_in_past');
  perform pg_temp.must_fail('A69', 'customer cancels another customer''s booking',
    $q$select * from public.cancel_booking('43000000-0000-0000-0000-0000000000c0', 'x')$q$, 'booking_not_found');
  perform pg_temp.must_fail('A70', 'cancel_booking(NULL)',
    $q$select * from public.cancel_booking(null)$q$, 'booking_not_found');
  perform pg_temp.must_fail('A71b', 'customer calls owner_cancel_booking on own paid booking (forced full refund)',
    $q$select public.owner_cancel_booking('43000000-0000-0000-0000-0000000000c0')$q$, 'forbidden');
  perform pg_temp.must_zero('A74', 'customer calls owner_customer_contacts',
    $q$select count(*) from public.owner_customer_contacts(array['40000000-0000-0000-0000-0000000000c0','40000000-0000-0000-0000-0000000000a0']::uuid[])$q$);

  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
  perform pg_temp.must_fail('A71', 'owner cancels another venue''s booking (forced refund)',
    $q$select public.owner_cancel_booking('43000000-0000-0000-0000-0000000000c0')$q$, 'forbidden');
  perform pg_temp.must_fail('A72', 'owner marks another venue''s booking no_show',
    $q$select public.owner_mark_attendance('43000000-0000-0000-0000-0000000000c0', 'no_show')$q$, 'forbidden');

  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000b0');
  perform pg_temp.must_fail('A73', 'owner marks a future paid booking no_show',
    $q$select public.owner_mark_attendance('43000000-0000-0000-0000-0000000000c0', 'no_show')$q$, 'invalid_status');
  perform pg_temp.must_fail('A73b', 'owner cancels via owner_mark_attendance(status=cancelled) to dodge refund',
    $q$select public.owner_mark_attendance('43000000-0000-0000-0000-0000000000c0', 'cancelled')$q$, 'invalid_status');
end $$;

-- A68. Overlap through different slot lengths (60 / 90 / 120) and arbitrary owner ranges. Rolled back.
do $$
declare r1 text; r2 text; r3 text; r4 text; r5 text; st text;
begin
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
    r1 := pg_temp.try($q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(6, 20, 30), pg_temp.slot(6, 22), 'block')$q$);
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000cd');
    r2 := pg_temp.try($q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(6, 21))$q$);
    r3 := pg_temp.try($q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(6, 14))$q$);   -- 14:00-15:00
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
    perform pg_temp.try($q$update public.pitches set slot_minutes = 90 where id = '42000000-0000-0000-0000-0000000000a1'$q$);
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000cc');
    r4 := pg_temp.try($q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(6, 14))$q$);   -- 14:00-15:30 on the new 90-min grid
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
    r5 := pg_temp.try($q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(6, 13), pg_temp.slot(6, 15), 'manual', 'Telefon')$q$); -- 120 min
    st := (select state from public.get_availability('42000000-0000-0000-0000-0000000000a1', ((pg_temp.slot(6, 14)) at time zone 'Europe/Istanbul')::date)
            where starts_at = pg_temp.slot(6, 14));
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  perform pg_temp.report('A68', 'overlap via 60/90/120-minute slots and odd owner ranges',
    r1 = 'ok 1' and r3 = 'ok 1' and r2 like '%slot_taken%' and r4 like '%slot_taken%' and r5 like '%slot_taken%' and st = 'booked',
    format('block=%s hold21=%s hold14=%s hold90=%s manual120=%s state=%s', r1, r2, r3, r4, r5, st));
end $$;

-- =====================================================================================================
-- 6. DoS / resource abuse and injection through text parameters
-- =====================================================================================================
do $$
declare t0 timestamptz; n text; ms numeric;
begin
  perform pg_temp.act('anon');
  t0 := clock_timestamp();
  n := pg_temp.val($q$select count(*) from public.get_availability('42000000-0000-0000-0000-0000000000a1', 'infinity')$q$)
    || '/' || pg_temp.val($q$select count(*) from public.get_availability('42000000-0000-0000-0000-0000000000a1', '200000-01-01')$q$)
    || '/' || pg_temp.val($q$select count(*) from public.get_availability('42000000-0000-0000-0000-0000000000a1', null)$q$);
  ms := extract(epoch from clock_timestamp() - t0) * 1000;
  perform pg_temp.report('A76', 'get_availability on infinite / far-future / NULL dates', ms < 2000 and n !~ 'ERR [^2]',
    format('rows=%s in %s ms', n, round(ms)));

  t0 := clock_timestamp();
  n := pg_temp.val($q$select count(*) from public.list_venues(repeat('%_', 100000))$q$) || '/'
    || pg_temp.val($q$select count(*) from public.list_venues(repeat('a%', 50000) || 'b', repeat('x', 100000), array[repeat('x', 100000)])$q$);
  ms := extract(epoch from clock_timestamp() - t0) * 1000;
  perform pg_temp.report('A79', 'list_venues with 200 KB pathological LIKE pattern', ms < 2000, format('rows=%s in %s ms', n, round(ms)));

  perform pg_temp.must_zero('A78', 'list_venues(''%'') leaks non-active venues',
    $q$select count(*) from public.list_venues('%') where id in ('41000000-0000-0000-0000-0000000000a2','41000000-0000-0000-0000-0000000000b2','41000000-0000-0000-0000-0000000000b3')$q$);
  perform pg_temp.must_zero('A78b', 'list_venues search by exact hidden venue name / LIKE wildcards',
    $q$select (select count(*) from public.list_venues('Gizli%')) + (select count(*) from public.list_venues('_skıdaki'))$q$);
  perform pg_temp.must_zero('A80', 'SQL injection through list_venues p_search / p_city / p_districts',
    $q$select count(*) from public.list_venues($x$'; delete from public.bookings; --$x$, $x$' or 1=1 --$x$, array[$x$' or 1=1 --$x$])$q$);

  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
  t0 := clock_timestamp();
  n := pg_temp.val($q$select count(*) from public.owner_customer_contacts(array(select gen_random_uuid() from generate_series(1, 100000)))$q$);
  ms := extract(epoch from clock_timestamp() - t0) * 1000;
  perform pg_temp.report('A75', 'owner_customer_contacts with 100k random ids', n = '0' and ms < 3000, format('rows=%s in %s ms', n, round(ms)));
end $$;

-- A81/A82. Stored SQL-injection payloads in free-text RPC params are inert and truncated. Rolled back.
do $$
declare b public.bookings; nb_before bigint; nb_after bigint; reason text; r text;
begin
  select count(*) into nb_before from public.bookings;
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
    select * into b from public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(7, 10), pg_temp.slot(7, 11), 'manual',
      $x$Robert'); delete from public.bookings; --$x$ || repeat('A', 10000), $x$0'||(select phone from public.profiles limit 1)||'$x$,
      $x$<script>alert(1)</script>%_\$x$ || repeat('n', 5000));
    perform public.owner_cancel_booking(b.id, $x$x'); update public.payments set status='refund_required'; --$x$ || repeat('r', 100000));
    perform pg_temp.act('postgres');
    select count(*) into nb_after from public.bookings;
    select cancel_reason into reason from public.bookings where id = b.id;
    r := format('name_len=%s phone=%s note_len=%s reason_len=%s', char_length(b.customer_name), b.customer_phone, char_length(b.note), char_length(reason));
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  perform pg_temp.report('A81', 'SQLi/XSS payloads in customer_name/phone/note/reason stored inert + truncated',
    nb_after = nb_before + 1 and r like 'name_len=80 %' and r like '%note_len=500 %' and r like '%reason_len=300'
      and not exists (select 1 from public.payments where merchant_oid = 'HSatkvictim01' and status <> 'succeeded'),
    r);
end $$;

-- A96. Mass holds by one account are capped (2 pending, 6/hour). Rolled back.
do $$
declare res text[] := '{}'; i int; r text;
begin
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000cc');
    for i in 0..2 loop
      res := res || pg_temp.try(format($q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(8, %s))$q$, 9 + i));
    end loop;
    -- hold → cancel loop to keep slots locked without paying
    for i in 0..5 loop
      perform pg_temp.try($q$select public.cancel_booking(id) from public.bookings where user_id = auth.uid() and status = 'pending_payment'$q$);
      res := res || pg_temp.try(format($q$select public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(9, %s))$q$, 9 + i));
    end loop;
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  r := array_to_string(res, ' | ');
  perform pg_temp.report('A96', 'mass holds / hold-cancel-hold loop from one account',
    res[3] like '%too_many_pending_holds%' and r like '%too_many_recent_holds%', r);
end $$;

-- =====================================================================================================
-- 7. Payment forgery
-- =====================================================================================================
do $$
declare f text; bad text := '';
begin
  foreach f in array array[
    $q$select public.confirm_payment('HSatkvictim01', true, 999999, '{}')$q$,
    $q$select public.start_payment('43000000-0000-0000-0000-0000000000c0', '40000000-0000-0000-0000-0000000000c0')$q$,
    $q$select * from public.claim_refunds(100)$q$,
    $q$select public.mark_refunded('44000000-0000-0000-0000-0000000000c0', '{}')$q$,
    $q$select public.release_refund_claim('44000000-0000-0000-0000-0000000000c0', 'x')$q$,
    $q$select public.expire_stale_holds()$q$,
    $q$select public.complete_past_bookings()$q$,
    $q$select public.prepare_account_deletion('40000000-0000-0000-0000-0000000000c0')$q$,
    $q$select public._is_valid_slot('42000000-0000-0000-0000-0000000000a1', now())$q$,
    $q$select public.handle_new_user()$q$,
    $q$select public.touch_updated_at()$q$]
  loop
    perform pg_temp.act('anon');
    if pg_temp.try(f) !~ '^ERR 42501' then bad := bad || ' anon:' || f; end if;
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c0');
    if pg_temp.try(f) !~ '^ERR 42501' then bad := bad || ' customer:' || f; end if;
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000b0');
    if pg_temp.try(f) !~ '^ERR 42501' then bad := bad || ' owner:' || f; end if;
  end loop;
  perform pg_temp.act('postgres');
  perform pg_temp.report('A83', 'anon/customer/owner call service-only payment & internal functions', bad = '',
    coalesce(nullif(bad, ''), 'all 11 functions x 3 roles → 42501'));
end $$;

-- A84. Replay of a success callback after the booking was cancelled + refunded never re-confirms. Service role.
do $$
declare r1 text; r2 text; bst text; pst text;
begin
  begin
    perform pg_temp.act('service_role');
    update public.payments set status = 'refunded' where merchant_oid = 'HSatkvictim01';
    update public.bookings set status = 'cancelled' where id = '43000000-0000-0000-0000-0000000000c0';
    r1 := public.confirm_payment('HSatkvictim01', true, 50000, '{"total_amount":"50000"}');
    r2 := public.confirm_payment('HSatkvictim01', true, 50000, '{"total_amount":"50000"}');
    select status into bst from public.bookings where id = '43000000-0000-0000-0000-0000000000c0';
    select status into pst from public.payments where merchant_oid = 'HSatkvictim01';
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  perform pg_temp.report('A84', 'replayed success callback on refunded payment', r1 = 'refunded' and r2 = 'refunded' and bst = 'cancelled' and pst = 'refunded',
    format('replay1=%s replay2=%s booking=%s payment=%s', r1, r2, bst, pst));
end $$;

-- A85-A88, A90, A91. Payment flows driven through the real RPCs. Each sub-scenario rolled back.
do $$
declare b public.bookings; p public.payments; r text; r2 text; s text; i int; rs text := '';
begin
  -- A85 amount tampering (underpayment) never confirms
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000cb');
    b := public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(10, 18));
    perform pg_temp.act('service_role');
    p := public.start_payment(b.id, b.user_id);
    r := public.confirm_payment(p.merchant_oid, true, p.amount_kurus - 1, '{}');
    select status into s from public.bookings where id = b.id;
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  perform pg_temp.report('A85', 'underpaid callback (amount tampering)', r = 'refund_required' and s = 'pending_payment',
    format('result=%s booking=%s', r, s));

  -- A86 start_payment bound to a different user (mis-bound JWT) is refused
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000cb');
    b := public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(10, 19));
    perform pg_temp.act('service_role');
    r := pg_temp.try(format($q$select public.start_payment(%L, '40000000-0000-0000-0000-0000000000c9')$q$, b.id));
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  perform pg_temp.report('A86', 'start_payment for someone else''s booking', r like '%booking_not_found%', r);

  -- A87 more than 5 payment attempts per booking
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000cb');
    b := public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(10, 20));
    perform pg_temp.act('service_role');
    for i in 1..6 loop rs := rs || ' ' || pg_temp.try(format('select public.start_payment(%L, %L)', b.id, b.user_id)); end loop;
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  perform pg_temp.report('A87', 'unlimited payment attempts (PayTR token farming)', rs like '%too_many_payment_attempts%', rs);

  -- A88 late success after the customer cancelled the hold → refund, booking stays cancelled
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000cb');
    b := public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(10, 21));
    perform pg_temp.act('service_role');
    p := public.start_payment(b.id, b.user_id);
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000cb');
    perform public.cancel_booking(b.id, 'vazgeçtim');
    perform pg_temp.act('service_role');
    r := public.confirm_payment(p.merchant_oid, true, p.amount_kurus, format('{"total_amount":"%s"}', p.amount_kurus)::jsonb);
    select status into s from public.bookings where id = b.id;
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  perform pg_temp.report('A88', 'late success after customer cancelled hold', r = 'refund_required' and s = 'cancelled',
    format('result=%s booking=%s', r, s));

  -- A90 PayTR sends "failed" then "success" for the same merchant_oid (retry inside the same iFrame token,
  --     or out-of-order delivery). Money is captured but the callback is swallowed: no confirm, no refund.
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000cb');
    b := public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(10, 22));
    perform pg_temp.act('service_role');
    p := public.start_payment(b.id, b.user_id);
    r := public.confirm_payment(p.merchant_oid, false, 0, '{"failed_reason_msg":"yetersiz bakiye"}');
    r2 := public.confirm_payment(p.merchant_oid, true, p.amount_kurus, format('{"total_amount":"%s"}', p.amount_kurus)::jsonb);
    select status into s from public.bookings where id = b.id;
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  perform pg_temp.report('A90', 'failed→success callback for same merchant_oid loses captured money',
    r2 in ('succeeded', 'refund_required'),
    format('first=%s second(success)=%s booking=%s → captured deposit neither confirmed nor queued for refund', r, r2, s),
    true);

  -- A91 malicious owner raises cancellation_window_hours after the customer paid → deposit forfeited
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000ca');
    b := public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(3, 18));
    perform pg_temp.act('service_role');
    p := public.start_payment(b.id, b.user_id);
    perform public.confirm_payment(p.merchant_oid, true, p.amount_kurus, '{}');
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
    perform pg_temp.try($q$update public.venues set cancellation_window_hours = 168 where id = '41000000-0000-0000-0000-0000000000a1'$q$);
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000ca');
    select c.refund_eligible::text into r from public.cancel_booking(b.id, 'x') c;
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  perform pg_temp.report('A91', 'owner changes cancellation window after payment (refund rule not snapshotted)', r = 'true',
    format('booking 3 days ahead, window booked under=24h, owner set 168h → refund_eligible=%s', r), false);
end $$;

-- =====================================================================================================
-- 8. Data exposure, KVKK and integrity
-- =====================================================================================================
do $$
declare cols text[];
begin
  select array_agg(a) into cols from pg_proc p, unnest(p.proargnames) a
   where p.oid = 'public.get_availability(uuid, date)'::regprocedure;
  perform pg_temp.report('A92', 'get_availability exposes no booker identity (signature)',
    not cols && array['user_id', 'customer_name', 'customer_phone', 'booking_id', 'note'], array_to_string(cols, ','));
  select array_agg(a) into cols from pg_proc p, unnest(p.proargnames) a
   where p.oid = 'public.list_venues(text, text, text[], double precision, double precision)'::regprocedure;
  perform pg_temp.report('A92b', 'list_venues exposes no owner/commission/PayTR columns (signature)',
    not cols && array['owner_id', 'commission_bps', 'paytr_submerchant_key', 'phone'], array_to_string(cols, ','));
end $$;

do $$ begin
  -- A93 customer reads commission_kurus of own booking → per-venue commission rate derivable
  --     (commission_bps is deliberately hidden by column grants, 20261120090600).
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c0');
  perform pg_temp.must_zero('A93', 'customer derives venue commission from bookings.commission_kurus',
    $q$select sum(commission_kurus) from public.bookings where id = '43000000-0000-0000-0000-0000000000c0'$q$, '42501', false);


  -- A95 push-token flood from one account (no per-user cap)
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c9');
  perform pg_temp.must_fail('A95', 'one account registers 1000 push tokens',
    $q$insert into public.device_tokens (token, platform) select 'flood-' || g, 'android' from generate_series(1, 1000) g$q$,
    '42501|too_many|23514|P0001', false);
end $$;
do $$
declare n int;
begin
  -- A95b same flood through the RPC (the only write path since F-07): at most 5 tokens survive
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c9');
  for i in 1..50 loop perform public.register_device_token('flood-token-' || lpad(i::text, 20, '0'), 'android'); end loop;
  perform set_config('role', 'postgres', true);
  select count(*) into n from public.device_tokens where user_id = '40000000-0000-0000-0000-0000000000c9';
  perform pg_temp.report('A95b', 'RPC token flood capped per user', n <= 5, 'tokens kept: ' || n, false);
end $$;

-- A94 KVKK: consent evidence is client-controlled (backdated aydınlatma acknowledgement). Blocked when the
--     write errors or the server overrides the value with its own clock.
do $$
declare r text; stored timestamptz;
begin
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c0');
    r := pg_temp.try($q$update public.profiles set kvkk_ack_at = '2000-01-01T00:00:00Z' where id = auth.uid()$q$);
    perform pg_temp.act('postgres');
    select kvkk_ack_at into stored from public.profiles where id = '40000000-0000-0000-0000-0000000000c0';
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  perform pg_temp.report('A94', 'customer forges kvkk_ack_at (backdated consent evidence)',
    r like 'ERR %' or stored is null or abs(extract(epoch from stored - now())) < 60,
    format('update=%s stored kvkk_ack_at=%s', r, stored), false);
end $$;

-- A97 push-token squatting: attacker pre-registers the victim's FCM token. Since F-07 the only write path is
--     register_device_token, where the device's real owner re-registering takes the token over.
do $$
declare owner_now uuid;
begin
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c9');
  perform public.register_device_token('fcm-shared-device-token-000000000001', 'ios');
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000c0');
  perform public.register_device_token('fcm-shared-device-token-000000000001', 'ios');
  perform set_config('role', 'postgres', true);
  select user_id into owner_now from public.device_tokens where token = 'fcm-shared-device-token-000000000001';
  perform pg_temp.report('A97', 'push-token squatting blocks victim registration',
    owner_now = '40000000-0000-0000-0000-0000000000c0', 'token owner after victim registers: ' || owner_now, false);
end $$;

-- A98 owner_customer_contacts discloses the phone of a user who only opened a hold and cancelled it
--     (never paid, never played) → KVKK data minimisation.
do $$
declare r text;
begin
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000ca');
    perform public.cancel_booking((public.create_booking_hold('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(12, 12))).id);
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
    r := pg_temp.val($q$select coalesce(string_agg(phone, ','), '0') from public.owner_customer_contacts(array['40000000-0000-0000-0000-0000000000ca']::uuid[])$q$);
    raise exception using errcode = 'ZX999';
  exception when sqlstate 'ZX999' then null;
  end;
  perform pg_temp.report('A98', 'owner gets phone of a customer who only held+cancelled (never paid)', r = '0',
    'leaked phone: ' || r, false);
end $$;

-- A99 owner writes arbitrary photo paths directly via PostgREST (server action check is bypassed):
--     other venue's objects, traversal, unbounded array.
do $$ begin
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
  perform pg_temp.must_fail('A99', 'owner sets cover/photo paths outside own folder (+5000 entries)',
    $q$update public.venues set cover_photo_path = '41000000-0000-0000-0000-0000000000b1/stolen.jpg',
                                photo_paths = array(select '../../../other-bucket/' || g || '.jpg' from generate_series(1, 5000) g)
        where id = '41000000-0000-0000-0000-0000000000a1'$q$, '23514|42501', false);

  -- A100 owner back-dates a manual booking (fabricated history / reports)
  perform pg_temp.must_fail('A100', 'owner creates manual booking in the past',
    $q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000a1', pg_temp.slot(-3, 20), pg_temp.slot(-3, 21), 'manual', 'Hayali Müşteri')$q$,
    'invalid_range|slot_in_past', false);

  -- A101 admin activates a venue that has no PayTR sub-merchant key → deposits land in the platform's own
  --      merchant account (MASTER_PROMPT: platform must not hold customer money).
  perform pg_temp.act('authenticated', '00000000-0000-0000-0000-0000000000a1');
  perform set_config('request.jwt.claims', '{"aal":"aal2"}', true);
  perform pg_temp.must_fail('A101', 'venue activated without PayTR sub-merchant key',
    $q$select public.admin_update_venue('41000000-0000-0000-0000-0000000000a2', 'active')$q$, 'submerchant|payout', false);
end $$;

-- A102 Storage write policy (venue_photos_owner_write, 20261120090100): same predicate evaluated with a
--      local copy of storage.foldername(), since plain Postgres has no storage schema.
create function pg_temp.foldername(name text) returns text[] language sql immutable as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;
create function pg_temp.photo_write_allowed(name text) returns text language plpgsql as $$
begin
  return (public.is_venue_owner(((pg_temp.foldername(name))[1])::uuid))::text;
exception when others then return 'error';  -- policy error = request denied
end $$;
do $$
declare r text;
begin
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
  r := format('own=%s other=%s root=%s junk=%s upper=%s',
    pg_temp.photo_write_allowed('41000000-0000-0000-0000-0000000000a1/a.jpg'),
    pg_temp.photo_write_allowed('41000000-0000-0000-0000-0000000000b1/a.jpg'),
    pg_temp.photo_write_allowed('a.jpg'),
    pg_temp.photo_write_allowed('../41000000-0000-0000-0000-0000000000b1/a.jpg'),
    pg_temp.photo_write_allowed(upper('41000000-0000-0000-0000-0000000000b1') || '/a.jpg'));
  perform pg_temp.report('A102', 'storage path policy: write only under own <venue_id>/',
    r = 'own=true other=false root=false junk=error upper=false', r);
  perform pg_temp.act('anon');
  perform pg_temp.report('A102b', 'storage path policy: anon cannot write',
    pg_temp.photo_write_allowed('41000000-0000-0000-0000-0000000000a1/a.jpg') in ('false', 'error'), 'anon → denied');
end $$;

-- =====================================================================================================
-- Location reference data (ADR-11, 20261122090000): tr_provinces / tr_districts are read-only for clients.
-- =====================================================================================================
do $$
declare t0 timestamptz; ms numeric; n text;
begin
  -- A103 owner rewrites the il/ilçe list (e.g. adds a fake district so a venue can claim it)
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
  perform pg_temp.must_fail('A103', 'owner inserts a fake district into tr_districts',
    $q$insert into public.tr_districts (province, name) values ('İstanbul', 'Hayalköy')$q$);
  perform pg_temp.must_fail('A103b', 'owner renames / deletes districts (cascades into venues)',
    $q$update public.tr_districts set name = 'Hacked' where province = 'İstanbul' and name = 'Beşiktaş'$q$);
  perform pg_temp.must_fail('A103c', 'owner deletes a province',
    $q$delete from public.tr_provinces where plate = 34$q$);
  perform pg_temp.act('anon');
  perform pg_temp.must_fail('A103d', 'anon truncates tr_districts',
    $q$truncate public.tr_districts cascade$q$);

  -- A104 owner moves own venue to a made-up district (would split the filter / hide from the picker)
  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000a0');
  perform pg_temp.must_fail('A104', 'owner sets own venue to a district outside the official list',
    $q$update public.venues set district = 'Kadiköy' where id = '41000000-0000-0000-0000-0000000000a1'$q$, '23503');

  -- A105 huge p_districts array: only the first 50 are considered, the call stays fast
  perform pg_temp.act('anon');
  t0 := clock_timestamp();
  n := pg_temp.val($q$select count(*) from public.list_venues(null, 'İstanbul',
         array(select 'x' || g from generate_series(1, 200000) g) || array['Kadıköy'])$q$);
  ms := extract(epoch from clock_timestamp() - t0) * 1000;
  perform pg_temp.report('A105', 'list_venues with 200 000-element p_districts (cap 50)', n = '0' and ms < 2000,
    format('rows=%s in %s ms (Kadıköy at index 200001 must be ignored)', n, round(ms)));

  -- A106 SQL-ish / wildcard strings in p_city match nothing (no dynamic SQL, equality only)
  perform pg_temp.must_zero('A106', 'SQL-ish and wildcard strings in list_venues p_city',
    $q$select (select count(*) from public.list_venues(null, $x$İstanbul' or '1'='1$x$))
           + (select count(*) from public.list_venues(null, '%'))
           + (select count(*) from public.list_venues(null, $x$İstanbul'; drop table public.venues; --$x$, array['Kadıköy']))$q$);
end $$;

-- =====================================================================================================
-- Owner MFA (S-18, 20261122100000): a stolen password gives an aal1 JWT (mobile e-mail login / direct
-- PostgREST). For an owner with a verified TOTP factor that session must not reach owner capabilities.
-- OM owns VM (active, payout account); CX has a paid booking at VM. Each attack has an aal2 control that
-- must succeed, so "blocked" is proven to come from the MFA check and not from a broken fixture (TESTBUG).
-- =====================================================================================================
insert into auth.users (id, phone, email, raw_user_meta_data) values
  ('40000000-0000-0000-0000-0000000000d0', null, 'owner-mfa@example.com', '{"full_name":"Owner MFA"}');
update public.profiles set role = 'owner' where id = '40000000-0000-0000-0000-0000000000d0';
insert into auth.mfa_factors (user_id, status, factor_type) values ('40000000-0000-0000-0000-0000000000d0', 'verified', 'totp');
insert into public.venues (id, owner_id, name, district, status, cancellation_window_hours, paytr_submerchant_key) values
  ('41000000-0000-0000-0000-0000000000d1', '40000000-0000-0000-0000-0000000000d0', 'MFA Arena', 'Kadıköy', 'active', 24, 'TEST-SM-00d1');
insert into public.venue_hours (venue_id, iso_weekday, open_time, close_time)
select '41000000-0000-0000-0000-0000000000d1', d::smallint, '08:00', '00:00' from generate_series(1, 7) d;
insert into public.pitches (id, venue_id, name, hourly_price_kurus, deposit_kurus, slot_minutes) values
  ('42000000-0000-0000-0000-0000000000d1', '41000000-0000-0000-0000-0000000000d1', 'M-60', 300000, 50000, 60);
insert into public.venue_payout_accounts (venue_id, legal_name, tax_number, iban)
values ('41000000-0000-0000-0000-0000000000d1', 'MFA Spor Ltd', '1234567891', 'TR000000000000000000000002');
insert into public.bookings (id, pitch_id, venue_id, user_id, source, status, starts_at, ends_at,
                             price_kurus, deposit_kurus, commission_kurus, confirmed_at)
values ('43000000-0000-0000-0000-0000000000d1', '42000000-0000-0000-0000-0000000000d1', '41000000-0000-0000-0000-0000000000d1',
        '40000000-0000-0000-0000-0000000000c0', 'app', 'confirmed', pg_temp.slot(5, 20), pg_temp.slot(5, 21),
        300000, 50000, 5000, now() - interval '1 day');

-- Runs p_sql (value or statement) as OM with the given aal, rolled back. Used for the aal2 controls.
create function pg_temp.as_om(p_aal text, p_sql text, p_value boolean) returns text language plpgsql as $$
declare r text;
begin
  begin
    perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000d0');
    perform set_config('request.jwt.claims', json_build_object('aal', p_aal)::text, true);
    r := case when p_value then pg_temp.val(p_sql) else pg_temp.try(p_sql) end;
    raise exception using errcode = 'ZX999', message = 'rollback';
  exception when sqlstate 'ZX999' then null;
  end;
  return r;
end $$;
create function pg_temp.control(p_id text, p_sql text, p_want text, p_value boolean default false) returns void
language plpgsql as $$
declare r text := pg_temp.as_om('aal2', p_sql, p_value);
begin
  if r is distinct from p_want then
    raise exception 'TESTBUG % control (aal2) must succeed: want "%" got "%"', p_id, p_want, r;
  end if;
end $$;

do $$
declare
  q_contacts text := $q$select count(*) from public.owner_customer_contacts(array['40000000-0000-0000-0000-0000000000c0']::uuid[])$q$;
  q_manual   text := $q$select public.owner_create_manual_booking('42000000-0000-0000-0000-0000000000d1', pg_temp.slot(6, 10), pg_temp.slot(6, 11), 'manual', 'Sahte')$q$;
  q_venue    text := $q$update public.venues set name = 'Ele Geçirildi', phone = '905000000000' where id = '41000000-0000-0000-0000-0000000000d1'$q$;
  q_bookings text := $q$select count(*) from public.bookings where venue_id = '41000000-0000-0000-0000-0000000000d1'$q$;
  q_payout_r text := $q$select count(*) from public.venue_payout_accounts where venue_id = '41000000-0000-0000-0000-0000000000d1'$q$;
  q_payout_w text := $q$update public.venue_payout_accounts set iban = 'TR990000000000000000000099' where venue_id = '41000000-0000-0000-0000-0000000000d1'$q$;
  q_cancel   text := $q$select public.owner_cancel_booking('43000000-0000-0000-0000-0000000000d1', 'stolen')$q$;
  q_pitch    text := $q$insert into public.pitches (venue_id, name, hourly_price_kurus, deposit_kurus) values ('41000000-0000-0000-0000-0000000000d1', 'Bedava', 100, 0)$q$;
  q_storage  text := $q$select count(*) filter (where public.is_venue_owner('41000000-0000-0000-0000-0000000000d1')) from (values (1)) v$q$;
begin
  perform pg_temp.control('A107',  q_contacts, '1', true);
  perform pg_temp.control('A107b', q_manual,   'ok 1');
  perform pg_temp.control('A107c', q_venue,    'ok 1');
  perform pg_temp.control('A107d', q_bookings, '1', true);
  perform pg_temp.control('A107e', q_payout_r, '1', true);
  perform pg_temp.control('A107f', q_payout_w, 'ok 1');
  perform pg_temp.control('A107g', q_cancel,   'ok 1');
  perform pg_temp.control('A107h', q_pitch,    'ok 1');
  perform pg_temp.control('A107i', q_storage,  '1', true);

  perform pg_temp.act('authenticated', '40000000-0000-0000-0000-0000000000d0');
  perform set_config('request.jwt.claims', '{"aal":"aal1"}', true);
  perform pg_temp.must_zero('A107',  'stolen password (aal1, owner has TOTP): owner_customer_contacts', q_contacts);
  perform pg_temp.must_fail('A107b', 'stolen password (aal1): owner_create_manual_booking', q_manual, '^P0001 forbidden$');
  perform pg_temp.must_fail('A107c', 'stolen password (aal1): update own venue', q_venue);
  perform pg_temp.must_zero('A107d', 'stolen password (aal1): read bookings of own venue', q_bookings);
  perform pg_temp.must_zero('A107e', 'stolen password (aal1): read payout account (IBAN/VKN)', q_payout_r);
  perform pg_temp.must_fail('A107f', 'stolen password (aal1): redirect payouts (IBAN change)', q_payout_w);
  perform pg_temp.must_fail('A107g', 'stolen password (aal1): owner_cancel_booking of a paid booking', q_cancel, '^P0001 forbidden$');
  perform pg_temp.must_fail('A107h', 'stolen password (aal1): insert pitch', q_pitch, '^42501 new row violates row-level security policy');
  perform pg_temp.must_zero('A107i', 'stolen password (aal1): storage write predicate on venue-photos', q_storage);
  -- No aal claim at all (old / hand-made token) counts as aal1.
  perform set_config('request.jwt.claims', '{}', true);
  perform pg_temp.must_zero('A107j', 'token without aal claim: read bookings of own venue', q_bookings);
end $$;

-- =====================================================================================================
-- Summary
-- =====================================================================================================
\o
do $$
declare n_ok int; n_vuln int; v text;
begin
  select count(*) filter (where blocked), count(*) filter (where not blocked),
         string_agg(id, ' ' order by id) filter (where not blocked)
    into n_ok, n_vuln, v from t_atk;
  raise notice 'attack suite: % blocked, % open VULN (%)', n_ok, n_vuln, coalesce(v, '-');
end $$;
\o /dev/null

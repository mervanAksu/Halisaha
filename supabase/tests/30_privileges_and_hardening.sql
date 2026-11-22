\o /dev/null
-- 30. With Supabase-style default privileges in place (see shim), only the allow-listed functions are callable.
do $$
declare
  r record;
  allowed_anon text[] := array['get_availability','list_venues','list_venue_locations','is_admin','is_venue_owner','venue_is_visible'];
  allowed_auth text[] := allowed_anon || array['create_booking_hold','cancel_booking','my_completed_match_count',
    'owner_create_manual_booking','owner_cancel_booking','owner_mark_attendance','owner_customer_contacts',
    'admin_update_venue','admin_list_venues','register_device_token','admin_verify_payout',
    'owner_mfa_satisfied'];
  bad text := '';
begin
  for r in
    select p.oid, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prokind = 'f'
       and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')  -- skip extension functions
  loop
    if has_function_privilege('anon', r.oid, 'execute') and not r.proname = any(allowed_anon) then
      bad := bad || ' anon:' || r.proname;
    end if;
    if has_function_privilege('authenticated', r.oid, 'execute') and not r.proname = any(allowed_auth) then
      bad := bad || ' authenticated:' || r.proname;
    end if;
  end loop;
  assert bad = '', 'functions exposed beyond allow-list:' || bad;
  raise notice 'ok 30a function privileges locked down';
end $$;

-- 30b. The exploit from the security review: customer self-confirms without paying.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
do $$ begin
  perform public.confirm_payment('HSdoesnotmatter', true, 999999, '{}');
  raise exception 'FAIL: customer could call confirm_payment';
exception when insufficient_privilege then raise notice 'ok 30b confirm_payment not callable by customers';
end $$;
do $$ begin
  perform public.prepare_account_deletion('00000000-0000-0000-0000-0000000000c1');
  raise exception 'FAIL: prepare_account_deletion callable';
exception when insufficient_privilege then raise notice 'ok 30c prepare_account_deletion not callable';
end $$;
reset role;

-- 30d. Availability marks slots within 15 minutes as past (QA-Ö3).
do $$ declare st text; begin
  select state into st from public.get_availability('20000000-0000-0000-0000-000000000003',
      (now() at time zone 'Europe/Istanbul')::date)
   where starts_at > now() and starts_at <= now() + interval '15 minutes' limit 1;
  assert st is null or st = 'past', 'slot inside 15 min must be past, got ' || st;
  raise notice 'ok 30d 15-minute rule consistent';
end $$;

-- 30e. A late payment never confirms a match that already started (QA-K1).
insert into public.bookings (id, pitch_id, venue_id, user_id, source, status, starts_at, ends_at, price_kurus, deposit_kurus, hold_expires_at, created_at)
values ('30000000-0000-0000-0000-0000000000e1', '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-0000000000c1', 'app', 'expired', now() - interval '2 hours', now() - interval '1 hour', 350000, 50000,
        now() - interval '3 hours', now() - interval '3 hours');
insert into public.payments (booking_id, user_id, merchant_oid, amount_kurus)
values ('30000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000c1', 'HSlatepastmatch', 50000);
do $$ begin
  assert public.confirm_payment('HSlatepastmatch', true, 50000, '{"total_amount":"50000"}') = 'refund_required', 'past match must refund';
  assert (select status from public.bookings where id = '30000000-0000-0000-0000-0000000000e1') = 'expired';
  raise notice 'ok 30e late payment on started match → refund';
end $$;

-- 30f. Refund claim is exclusive and amount-capped (SEC-Ö4, SEC-K-6).
update public.payments set provider_payload = '{"total_amount":"100"}' where merchant_oid = 'HSlatepastmatch';
do $$ declare n1 int; n2 int; amt int; begin
  select count(*) into n1 from public.claim_refunds(100);
  select count(*) into n2 from public.claim_refunds(100);
  assert n1 >= 1 and n2 = 0, format('second claim must get nothing (%s, %s)', n1, n2);
  assert (select status from public.payments where merchant_oid = 'HSlatepastmatch') = 'refund_processing';
  perform public.release_refund_claim((select id from public.payments where merchant_oid = 'HSlatepastmatch'), 'test');
  select refund_amount_kurus into amt from public.claim_refunds(100) where merchant_oid = 'HSlatepastmatch';
  assert amt = 100, 'refund must not exceed charged amount, got ' || amt;
  raise notice 'ok 30f refund claims exclusive and capped';
end $$;

-- 30g. Owners see only name + phone of their own customers; no profile row access (SEC-Ö3).
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', false);
do $$ begin
  assert (select count(*) from public.profiles where id = '00000000-0000-0000-0000-0000000000c1') = 0, 'owner must not read profile rows';
  assert (select count(*) from public.owner_customer_contacts(array['00000000-0000-0000-0000-0000000000c1'::uuid])) = 1, 'contact via RPC';
  assert (select count(*) from public.owner_customer_contacts(array['00000000-0000-0000-0000-0000000000a1'::uuid])) = 0, 'no contact for non-customers';
  raise notice 'ok 30g owner customer contacts minimised';
end $$;

-- 30h. Owner cannot cancel (and refund) a match that already started (QA-K-1).
do $$ begin
  perform public.owner_cancel_booking('30000000-0000-0000-0000-0000000000e1');
  raise exception 'FAIL';
exception when others then
  assert sqlerrm in ('slot_started', 'not_cancellable'), 'got ' || sqlerrm;
  raise notice 'ok 30h started match not cancellable by owner';
end $$;

-- 30i. Active booking cap covers zero-deposit confirmed bookings (SEC-Ö2).
reset role;
update public.pitches set deposit_kurus = 0 where id = '20000000-0000-0000-0000-000000000002';
update public.bookings set status = 'cancelled' where user_id = '00000000-0000-0000-0000-0000000000c1' and status = 'pending_payment';
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
do $$ declare d date := (now() at time zone 'Europe/Istanbul')::date + 5; i int; begin
  for i in 0..3 loop
    begin
      perform public.create_booking_hold('20000000-0000-0000-0000-000000000002',
        ((d + time '12:00') at time zone 'Europe/Istanbul') + make_interval(hours => i));
    exception when others then
      assert sqlerrm in ('too_many_active_bookings', 'too_many_recent_holds'), 'unexpected ' || sqlerrm;
      raise notice 'ok 30i free-booking cap enforced after % bookings (%)', i, sqlerrm;
      return;
    end;
  end loop;
  raise exception 'FAIL: unlimited zero-deposit bookings';
end $$;
reset role;

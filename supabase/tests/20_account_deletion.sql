\o /dev/null
-- Customer 2 has a confirmed booking 3 days ahead (outside the 24h window) → cancelled + refund_required; account deletable.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c2', false);
set role authenticated;
create temp table t_del as select * from public.create_booking_hold('20000000-0000-0000-0000-000000000002',
  ((((now() at time zone 'Europe/Istanbul')::date + 3) + time '18:00') at time zone 'Europe/Istanbul'));
reset role;
create temp table t_delp as select * from public.start_payment((select id from t_del), '00000000-0000-0000-0000-0000000000c2');
select public.confirm_payment((select merchant_oid from t_delp), true, (select amount_kurus from t_delp), '{}');
do $$ begin
  assert public.prepare_account_deletion('00000000-0000-0000-0000-0000000000c2') >= 1, 'future bookings cancelled';
  assert (select status from public.bookings where id = (select id from t_del)) = 'cancelled';
  assert (select status from public.payments where id = (select id from t_delp)) = 'refund_required';
  delete from auth.users where id = '00000000-0000-0000-0000-0000000000c2';
  assert (select user_id from public.bookings where id = (select id from t_del)) is null, 'booking anonymised';
  assert not exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-0000000000c2'), 'profile removed';
  raise notice 'ok 20a account deletion cancels, flags refund, anonymises';
end $$;
do $$ begin
  perform public.prepare_account_deletion('00000000-0000-0000-0000-0000000000b1');
  raise exception 'FAIL: owner deleted';
exception when others then
  assert sqlerrm = 'owner_account', 'got ' || sqlerrm;
  raise notice 'ok 20b owner accounts protected';
end $$;
do $$ begin
  perform public.mark_refunded((select id from t_delp), '{"status":"success"}');
  assert (select status from public.payments where id = (select id from t_delp)) = 'refunded';
  raise notice 'ok 20c mark_refunded';
end $$;

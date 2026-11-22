\o /dev/null
-- 50. İl → ilçe konum filtresi (ADR-11, migration 20261122090000).
-- Fixtures use Ankara / İzmir so the seed (İstanbul) and 40_attacks fixtures do not affect the counts.
--   51…01 Ankara/Çankaya   active, active pitch
--   51…02 Ankara/Çankaya   active, active pitch
--   51…03 Ankara/Elmadağ   active, active pitch
--   51…04 Ankara/Mamak     active, active pitch
--   51…05 Ankara/Keçiören  suspended, active pitch        → never listed
--   51…06 Ankara/Etimesgut active, only an inactive pitch → never listed
--   51…07 Ankara/Sincan    pending, active pitch          → never listed
--   51…08 İzmir/Karşıyaka  active, active pitch
insert into public.venues (id, owner_id, name, city, district, status, paytr_submerchant_key) values
  ('51000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1', 'Konum Çankaya Bir', 'Ankara', 'Çankaya',   'active',    'TEST-SM-5101'),
  ('51000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000b1', 'Konum Çankaya İki', 'Ankara', 'Çankaya',   'active',    'TEST-SM-5102'),
  ('51000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000b1', 'Konum Elmadağ',     'Ankara', 'Elmadağ',   'active',    'TEST-SM-5103'),
  ('51000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000b1', 'Konum Mamak',       'Ankara', 'Mamak',     'active',    'TEST-SM-5104'),
  ('51000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000b1', 'Konum Askıda',      'Ankara', 'Keçiören',  'suspended', 'TEST-SM-5105'),
  ('51000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000b1', 'Konum Pasif Saha',  'Ankara', 'Etimesgut', 'active',    'TEST-SM-5106'),
  ('51000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-0000000000b1', 'Konum Bekleyen',    'Ankara', 'Sincan',    'pending',   null),
  ('51000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-0000000000b1', 'Konum Karşıyaka',   'İzmir',  'Karşıyaka', 'active',    'TEST-SM-5108');
insert into public.pitches (id, venue_id, name, format, is_indoor, hourly_price_kurus, deposit_kurus, is_active)
select ('52000000-0000-0000-0000-00000000000' || g)::uuid, ('51000000-0000-0000-0000-00000000000' || g)::uuid,
       'Saha', '7v7', true, 300000, 50000, g <> 6
  from generate_series(1, 8) g;

-- 50a. Reference data is complete.
do $$ begin
  assert (select count(*) from public.tr_provinces) = 81, 'expected 81 provinces';
  assert (select count(*) from public.tr_districts) = 973, 'expected 973 districts';
  assert (select count(*) from public.tr_provinces p
           where not exists (select 1 from public.tr_districts d where d.province = p.name)) = 0, 'province without districts';
  assert exists (select 1 from public.tr_districts where province = 'Ankara' and name = 'Mamak'), 'Mamak missing';
  assert not exists (select 1 from public.tr_districts where name = 'Amak'), 'typo Amak must be fixed';
  assert (select count(*) from public.tr_districts where province = 'İstanbul') = 39, 'İstanbul has 39 districts';
  assert (select name from public.tr_provinces where plate = 34) = 'İstanbul';
  raise notice 'ok 50a tr_provinces 81 / tr_districts 973';
end $$;

-- 50b. Everyone reads the lists; nobody writes them (42501 = insufficient_privilege).
set role anon;
do $$ begin
  assert (select count(*) from public.tr_districts) = 973, 'anon must read all districts';
  assert (select count(*) from public.tr_provinces) = 81, 'anon must read all provinces';
  raise notice 'ok 50b anon reads tr_provinces / tr_districts';
end $$;
do $$ begin
  insert into public.tr_districts (province, name) values ('İstanbul', 'Hayalköy');
  raise exception 'FAIL: anon inserted into tr_districts';
exception when insufficient_privilege then raise notice 'ok 50c anon insert tr_districts → 42501';
end $$;
do $$ begin
  update public.tr_districts set name = 'X' where province = 'Ankara' and name = 'Mamak';
  raise exception 'FAIL: anon updated tr_districts';
exception when insufficient_privilege then raise notice 'ok 50d anon update tr_districts → 42501';
end $$;
do $$ begin
  delete from public.tr_provinces where plate = 6;
  raise exception 'FAIL: anon deleted from tr_provinces';
exception when insufficient_privilege then raise notice 'ok 50e anon delete tr_provinces → 42501';
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000b1', false);
do $$ begin
  insert into public.tr_provinces (plate, name) values (82, 'Hayalil');
  raise exception 'FAIL: owner inserted into tr_provinces';
exception when insufficient_privilege then raise notice 'ok 50f owner insert tr_provinces → 42501';
end $$;
do $$ begin
  delete from public.tr_districts where province = 'Ankara';
  raise exception 'FAIL: owner deleted from tr_districts';
exception when insufficient_privilege then raise notice 'ok 50g owner delete tr_districts → 42501';
end $$;
reset role;

-- 50h. venues (city, district) must be a real pair (23503 = foreign_key_violation).
do $$ begin
  insert into public.venues (owner_id, name, city, district) values ('00000000-0000-0000-0000-0000000000b1', 'Hayal Saha', 'Ankara', 'Hayalköy');
  raise exception 'FAIL: venue with unknown district accepted';
exception when foreign_key_violation then raise notice 'ok 50h unknown district → 23503';
end $$;
do $$ begin
  insert into public.venues (owner_id, name, city, district) values ('00000000-0000-0000-0000-0000000000b1', 'Yanlış İl', 'Ankara', 'Kadıköy');
  raise exception 'FAIL: district of another province accepted';
exception when foreign_key_violation then raise notice 'ok 50i district/province mismatch → 23503';
end $$;
do $$ begin
  insert into public.venues (owner_id, name, district) values ('00000000-0000-0000-0000-0000000000b1', 'Yazım Hatası', 'Kadiköy');
  raise exception 'FAIL: misspelled district accepted';
exception when foreign_key_violation then raise notice 'ok 50j misspelled district (Kadiköy) → 23503';
end $$;

-- 50k–50p. list_venues filters (as anon, like the app before sign-in).
set role anon;
do $$
declare junk text[] := array(select 'yok' || g from generate_series(1, 50) g);
begin
  assert (select count(*) from public.list_venues(p_city => 'Ankara')) = 4, 'Ankara: 4 listable venues';
  assert (select bool_and(city = 'Ankara') from public.list_venues(p_city => 'Ankara')), 'city column returned';
  assert (select count(*) from public.list_venues(p_city => 'İzmir')) = 1, 'İzmir: 1 venue';
  assert (select count(*) from public.list_venues(p_city => 'Ankara', p_districts => array['Keçiören', 'Etimesgut', 'Sincan'])) = 0,
         'suspended / no active pitch / pending venues never listed';
  raise notice 'ok 50k list_venues filters by city';

  assert (select count(*) from public.list_venues(p_city => 'Ankara', p_districts => array['Çankaya'])) = 2;
  assert (select count(*) from public.list_venues(p_city => 'Ankara', p_districts => array['Çankaya', 'Mamak'])) = 3;
  assert (select count(*) from public.list_venues(p_city => 'Ankara', p_districts => array['Karşıyaka'])) = 0,
         'district of another city must not match';
  assert (select count(*) from public.list_venues(p_city => 'Ankara', p_districts => '{}'::text[])) = 4, 'empty array = whole city';
  raise notice 'ok 50l list_venues filters by multiple districts';

  assert (select count(*) from public.list_venues(p_districts => array['Mamak']))
       = (select count(*) from public.list_venues()), 'districts ignored when city is null';
  assert (select count(*) from public.list_venues(p_districts => array['Mamak'])) > 1;
  raise notice 'ok 50m p_districts ignored without p_city';

  assert (select count(*) from public.list_venues(p_city => 'Ankara', p_districts => junk[1:49] || array['Mamak'])) = 1,
         'district at index 50 is used';
  assert (select count(*) from public.list_venues(p_city => 'Ankara', p_districts => junk || array['Mamak'])) = 0,
         'district at index 51 is ignored';
  raise notice 'ok 50n p_districts capped at 50';

  assert (select count(*) from public.list_venues('ankar')) = 4, 'search matches city';
  assert (select count(*) from public.list_venues('Elmadağ', 'Ankara')) = 1, 'search + city';
  raise notice 'ok 50o search matches city';

  assert (select array_agg(name order by name) from public.list_venues(p_city => 'Ankara', p_lat => 39.92, p_lng => 32.85))
         is not null, 'location ordering works with new signature';
  assert (select count(*) from public.list_venues(p_city => 'Ankara', p_lat => 'NaN', p_lng => 32.85) where distance_km is not null) = 0,
         'S-17 coordinate guard kept';
  raise notice 'ok 50p coordinate guard kept';
end $$;

-- 50q. list_venue_locations: only cities/districts with listable venues, correct counts, Turkish order.
do $$
declare got text;
begin
  select string_agg(district || ':' || venue_count, ',' order by ord) into got
    from (select *, row_number() over () as ord from public.list_venue_locations()) l
   where city = 'Ankara';
  assert got = 'Çankaya:2,Elmadağ:1,Mamak:1', 'Ankara locations (Turkish order, no suspended/pending/no-pitch): ' || coalesce(got, '<null>');
  assert (select venue_count from public.list_venue_locations() where city = 'İzmir' and district = 'Karşıyaka') = 1;
  assert not exists (select 1 from public.list_venue_locations() where district in ('Keçiören', 'Etimesgut', 'Sincan')),
         'suspended / pending / pitchless venues excluded';
  assert not exists (select 1 from public.list_venue_locations() l
                      where not exists (select 1 from public.list_venues(p_city => l.city, p_districts => array[l.district]))),
         'every location yields a non-empty list';
  select string_agg(city, ',' order by ord) into got
    from (select city, min(ord) ord from (select *, row_number() over () as ord from public.list_venue_locations()) x group by city) c;
  assert got = 'Ankara,İstanbul,İzmir', 'city order: ' || coalesce(got, '<null>');
  raise notice 'ok 50q list_venue_locations';
end $$;
reset role;

-- 50r. Suspending a venue removes its district from the picker.
update public.venues set status = 'suspended' where id = '51000000-0000-0000-0000-000000000004';
set role anon;
do $$ begin
  assert not exists (select 1 from public.list_venue_locations() where city = 'Ankara' and district = 'Mamak'), 'suspended Mamak still listed';
  assert (select count(*) from public.list_venues(p_city => 'Ankara')) = 3;
  raise notice 'ok 50r suspended venue leaves the picker';
end $$;
reset role;
update public.venues set status = 'active' where id = '51000000-0000-0000-0000-000000000004';

-- 50s. Both functions are callable by anon and authenticated, nothing else changed.
do $$ begin
  assert has_function_privilege('anon', 'public.list_venue_locations()', 'execute');
  assert has_function_privilege('authenticated', 'public.list_venue_locations()', 'execute');
  assert has_function_privilege('anon', 'public.list_venues(text, text, text[], double precision, double precision)', 'execute');
  assert to_regprocedure('public.list_venues(text, text, double precision, double precision)') is null, 'old list_venues dropped';
  assert to_regclass('public.venues_status_district_idx') is null and to_regclass('public.venues_status_city_district_idx') is not null;
  assert not has_table_privilege('anon', 'public.tr_districts', 'insert')
     and not has_table_privilege('authenticated', 'public.tr_districts', 'update')
     and not has_table_privilege('authenticated', 'public.tr_provinces', 'truncate');
  raise notice 'ok 50s privileges / index / old signature';
end $$;

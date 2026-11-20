-- Local development seed (fictional data). Never run against production.
insert into auth.users (id, phone, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', null,          'admin@example.com', '{"full_name":"Admin"}'),
  ('00000000-0000-0000-0000-0000000000b1', null,          'owner@example.com', '{"full_name":"Saha Sahibi"}'),
  ('00000000-0000-0000-0000-0000000000c1', '905550000001', null,               '{"full_name":"Oyuncu Bir"}'),
  ('00000000-0000-0000-0000-0000000000c2', '905550000002', null,               '{"full_name":"Oyuncu İki"}')
on conflict (id) do nothing;

update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-0000000000a1';
update public.profiles set role = 'owner' where id = '00000000-0000-0000-0000-0000000000b1';

insert into public.venues (id, owner_id, name, district, address, lat, lng, phone, status, amenities, description) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1', 'Yeşilvadi Spor Tesisi',
   'Büyükçekmece', 'Örnek Mah. Deneme Cad. No:1', 41.0205, 28.5850, '02120000000', 'active',
   '{otopark,dus,kafeterya}', 'Kapalı ve açık sahalar, gece geç saate kadar açık.'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000b1', 'Gece Yarısı Arena',
   'Esenyurt', 'Örnek Mah. Test Sok. No:5', 41.0340, 28.6770, '02120000001', 'active',
   '{otopark,dus}', 'Öğleden sabaha kadar açık.')
on conflict (id) do nothing;

-- Venue 1: 11:00–24:00 every day. Venue 2: 12:00–06:00 (closes after midnight).
insert into public.venue_hours (venue_id, iso_weekday, open_time, close_time)
select '10000000-0000-0000-0000-000000000001'::uuid, d::smallint, '11:00'::time, '00:00'::time from generate_series(1, 7) d
union all
select '10000000-0000-0000-0000-000000000002'::uuid, d::smallint, '12:00'::time, '06:00'::time from generate_series(1, 7) d
on conflict do nothing;

insert into public.pitches (id, venue_id, name, format, is_indoor, hourly_price_kurus, deposit_kurus) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Saha 1', '7v7', true,  350000, 50000),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Saha 2', '6v6', false, 300000, 50000),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'Ana Saha', '7v7', true, 420000, 60000)
on conflict (id) do nothing;

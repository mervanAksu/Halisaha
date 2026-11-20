-- Security fix (found by flutter-engineer review): table-wide SELECT on venues exposed commission_bps and
-- paytr_submerchant_key to anon users. Replace it with column-level grants; admins read them via RPC.
revoke select on public.venues from anon, authenticated;
grant select (id, owner_id, name, description, city, district, address, lat, lng, phone, cover_photo_path,
              photo_paths, amenities, status, cancellation_window_hours, created_at, updated_at)
  on public.venues to anon, authenticated;

create or replace function public.admin_list_venues()
returns setof public.venues
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query select * from public.venues order by created_at desc;
end $$;
revoke all on function public.admin_list_venues() from public;
grant execute on function public.admin_list_venues() to authenticated;

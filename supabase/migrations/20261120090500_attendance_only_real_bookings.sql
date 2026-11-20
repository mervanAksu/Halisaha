-- owner_mark_attendance: blocks (closed slots) have no attendee; only app/manual bookings can be marked.
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
  if v_booking.source = 'block'
     or v_booking.status not in ('confirmed', 'completed', 'no_show')
     or v_booking.starts_at > now() then
    raise exception 'invalid_status';
  end if;
  update public.bookings set status = p_status where id = v_booking.id returning * into v_booking;
  return v_booking;
end $$;

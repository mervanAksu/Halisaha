-- Account deletion support (Apple 5.1.1(v), KVKK). Called by the delete-account Edge Function (service role)
-- right before auth.admin.deleteUser(). Future bookings are cancelled with the normal refund rule;
-- financial rows stay but lose the user link (on delete set null).
create or replace function public.prepare_account_deletion(p_user_id uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_count integer := 0;
  r record;
begin
  if exists (select 1 from public.venues where owner_id = p_user_id) then
    raise exception 'owner_account';  -- venue owners are offboarded by the platform team
  end if;

  for r in
    select b.id, b.status, b.starts_at, v.cancellation_window_hours
      from public.bookings b join public.venues v on v.id = b.venue_id
     where b.user_id = p_user_id and b.status in ('pending_payment', 'confirmed') and b.starts_at > now()
     for update of b
  loop
    update public.bookings
       set status = 'cancelled', cancelled_at = now(), cancelled_by = p_user_id,
           cancel_reason = 'account_deleted', hold_expires_at = null
     where id = r.id;
    if r.status = 'confirmed' and r.starts_at - now() >= make_interval(hours => r.cancellation_window_hours) then
      update public.payments set status = 'refund_required' where booking_id = r.id and status = 'succeeded';
    end if;
    v_count := v_count + 1;
  end loop;

  -- Remove personal free-text kept on bookings the user created.
  update public.bookings set note = null where user_id = p_user_id;
  return v_count;
end $$;

revoke all on function public.prepare_account_deletion(uuid) from public;
grant execute on function public.prepare_account_deletion(uuid) to service_role;

-- Refund job helper: mark a refund as done (service role only).
create or replace function public.mark_refunded(p_payment_id uuid, p_payload jsonb)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.payments
     set status = 'refunded',
         provider_payload = coalesce(provider_payload, '{}'::jsonb) || jsonb_build_object('refund', p_payload)
   where id = p_payment_id and status = 'refund_required';
end $$;
revoke all on function public.mark_refunded(uuid, jsonb) from public;
grant execute on function public.mark_refunded(uuid, jsonb) to service_role;

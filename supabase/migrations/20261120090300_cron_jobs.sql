-- Scheduled jobs (pg_cron is available on Supabase; skipped silently elsewhere, e.g. plain-Postgres tests).
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('expire-stale-holds',    '* * * * *',  'select public.expire_stale_holds()');
    perform cron.schedule('complete-past-bookings', '5 * * * *', 'select public.complete_past_bookings()');
  else
    raise notice 'pg_cron not available; scheduled jobs not created';
  end if;
end $$;

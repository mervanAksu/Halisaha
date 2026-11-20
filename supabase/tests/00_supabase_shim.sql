-- Minimal stand-in for Supabase's auth schema and roles so migrations can be tested on plain Postgres.
-- NOT a migration. Used only by tests/run_local.sh.
create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key, phone text, email text, raw_user_meta_data jsonb default '{}'::jsonb
);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;
grant usage on schema public, auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- Mirror Supabase's default privileges: on a real project, every new table/function/sequence in `public`
-- is granted to anon/authenticated/service_role automatically. Migrations must revoke explicitly.
-- (Without this line the local suite missed a critical privilege bug — see CHANGELOG "Security".)
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;

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

-- auth.jwt(): claims of the current request (Supabase). Tests set request.jwt.claims, e.g. '{"aal":"aal2"}'.
create or replace function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;
grant execute on function auth.jwt() to anon, authenticated, service_role;

-- auth.mfa_factors: subset of Supabase's table used by public.owner_mfa_satisfied() (S-18).
-- On Supabase, status is enum auth.factor_status ('unverified','verified'); factor_type is auth.factor_type.
do $$ begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                  where n.nspname = 'auth' and t.typname = 'factor_status') then
    create type auth.factor_status as enum ('unverified', 'verified');
  end if;
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                  where n.nspname = 'auth' and t.typname = 'factor_type') then
    create type auth.factor_type as enum ('totp', 'webauthn', 'phone');
  end if;
end $$;
create table if not exists auth.mfa_factors (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  status      auth.factor_status not null,
  factor_type auth.factor_type not null default 'totp',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
-- Clients have no access to auth.mfa_factors (Supabase does not expose it through PostgREST).
revoke all on auth.mfa_factors from anon, authenticated;

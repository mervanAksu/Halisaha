-- Core schema: profiles, venues, pitches, opening hours, bookings, payments, favorites, device tokens.
-- Invariants (see docs/MASTER_PROMPT.md):
--   * money is integer kuruş
--   * time is timestamptz (UTC); venue-local time is Europe/Istanbul
--   * double booking is impossible at DB level (exclusion constraint on bookings)

create extension if not exists btree_gist;
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.app_role as enum ('customer', 'owner', 'admin');
create type public.venue_status as enum ('pending', 'active', 'suspended');
create type public.booking_source as enum ('app', 'manual', 'block');
create type public.booking_status as enum (
  'pending_payment',  -- slot held for a short time while the customer pays
  'confirmed',        -- deposit paid (app) or entered by owner (manual/block)
  'cancelled',
  'expired',          -- hold timed out without a successful payment
  'completed',
  'no_show'
);
create type public.payment_status as enum (
  'initiated', 'succeeded', 'failed', 'refund_required', 'refunded'
);

-- ---------------------------------------------------------------------------
-- Profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  full_name          text not null default '' check (char_length(full_name) <= 80),
  phone              text,
  email              text,
  role               public.app_role not null default 'customer',
  marketing_consent  boolean not null default false,  -- İYS/KVKK: separate explicit consent
  kvkk_ack_at        timestamptz,                     -- when the aydınlatma metni was shown/acknowledged
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Venues (a halısaha business; one owner can have many)
-- ---------------------------------------------------------------------------
create table public.venues (
  id                         uuid primary key default gen_random_uuid(),
  owner_id                   uuid not null references public.profiles (id) on delete restrict,
  name                       text not null check (char_length(name) between 2 and 80),
  description                text not null default '' check (char_length(description) <= 2000),
  city                       text not null default 'İstanbul',
  district                   text not null,
  address                    text not null default '',
  lat                        double precision check (lat between -90 and 90),
  lng                        double precision check (lng between -180 and 180),
  phone                      text,
  cover_photo_path           text,                       -- Supabase Storage path in bucket 'venue-photos'
  photo_paths                text[] not null default '{}',
  amenities                  text[] not null default '{}', -- e.g. {'otopark','dus','kafeterya'}
  status                     public.venue_status not null default 'pending',
  commission_bps             integer not null default 1000 check (commission_bps between 0 and 5000), -- 1000 = %10 of deposit
  cancellation_window_hours  integer not null default 24 check (cancellation_window_hours between 0 and 168),
  paytr_submerchant_key      text,                       -- VERIFY(paytr): sub-merchant identifier from PayTR marketplace
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now()
);
create index venues_owner_idx on public.venues (owner_id);
create index venues_status_district_idx on public.venues (status, district);

-- Payout details are kept apart from venues so they are never exposed by public venue reads.
create table public.venue_payout_accounts (
  venue_id      uuid primary key references public.venues (id) on delete cascade,
  legal_name    text not null,
  tax_number    text not null,          -- VKN or TCKN (sole proprietor)
  iban          text not null check (iban ~ '^TR[0-9]{24}$'),
  updated_at    timestamptz not null default now()
);

-- Opening hours per ISO weekday (1 = Monday … 7 = Sunday), venue-local time.
-- close_time <= open_time means the venue closes after midnight (e.g. 12:00 → 06:00).
create table public.venue_hours (
  venue_id    uuid not null references public.venues (id) on delete cascade,
  iso_weekday smallint not null check (iso_weekday between 1 and 7),
  open_time   time not null,
  close_time  time not null,
  primary key (venue_id, iso_weekday)
);

-- ---------------------------------------------------------------------------
-- Pitches (a field inside a venue)
-- ---------------------------------------------------------------------------
create table public.pitches (
  id                   uuid primary key default gen_random_uuid(),
  venue_id             uuid not null references public.venues (id) on delete cascade,
  name                 text not null check (char_length(name) between 1 and 40),
  format               text not null default '7v7',     -- '5v5', '6v6', '7v7', '8v8' …
  is_indoor            boolean not null default true,
  hourly_price_kurus   integer not null check (hourly_price_kurus > 0),
  deposit_kurus        integer not null check (deposit_kurus >= 0),
  slot_minutes         integer not null default 60 check (slot_minutes in (60, 90, 120)),
  is_active            boolean not null default true,
  sort_order           integer not null default 0,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint deposit_not_above_price check (deposit_kurus <= hourly_price_kurus * slot_minutes / 60)
);
create index pitches_venue_idx on public.pitches (venue_id);

-- ---------------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------------
create table public.bookings (
  id                uuid primary key default gen_random_uuid(),
  pitch_id          uuid not null references public.pitches (id) on delete restrict,
  venue_id          uuid not null references public.venues (id) on delete restrict, -- denormalised for RLS/queries
  user_id           uuid references public.profiles (id) on delete set null,       -- null for manual/block or deleted accounts
  source            public.booking_source not null default 'app',
  status            public.booking_status not null,
  starts_at         timestamptz not null,
  ends_at           timestamptz not null,
  price_kurus       integer not null default 0 check (price_kurus >= 0),
  deposit_kurus     integer not null default 0 check (deposit_kurus >= 0),
  commission_kurus  integer not null default 0 check (commission_kurus >= 0),
  hold_expires_at   timestamptz,
  customer_name     text check (char_length(customer_name) <= 80),  -- manual bookings only
  customer_phone    text check (char_length(customer_phone) <= 20),
  note              text check (char_length(note) <= 500),
  cancelled_at      timestamptz,
  cancelled_by      uuid,
  cancel_reason     text check (char_length(cancel_reason) <= 300),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint ends_after_starts check (ends_at > starts_at),
  constraint pending_has_hold check (status <> 'pending_payment' or hold_expires_at is not null),
  -- THE invariant: two live bookings on the same pitch can never overlap.
  constraint no_overlapping_bookings exclude using gist (
    pitch_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status in ('pending_payment', 'confirmed'))
);
create index bookings_user_idx on public.bookings (user_id, starts_at desc);
create index bookings_venue_time_idx on public.bookings (venue_id, starts_at);
create index bookings_pending_idx on public.bookings (hold_expires_at) where status = 'pending_payment';

-- ---------------------------------------------------------------------------
-- Payments (one booking may have several attempts; at most one succeeds)
-- ---------------------------------------------------------------------------
create table public.payments (
  id                uuid primary key default gen_random_uuid(),
  booking_id        uuid not null references public.bookings (id) on delete restrict,
  user_id           uuid references public.profiles (id) on delete set null,
  provider          text not null default 'paytr',
  merchant_oid      text not null unique check (merchant_oid ~ '^[A-Za-z0-9]{1,64}$'),
  amount_kurus      integer not null check (amount_kurus > 0),
  status            public.payment_status not null default 'initiated',
  provider_payload  jsonb,           -- raw callback (no card data is ever received)
  failed_reason     text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index payments_booking_idx on public.payments (booking_id);
create unique index payments_one_success_per_booking on public.payments (booking_id) where status = 'succeeded';

-- ---------------------------------------------------------------------------
-- Favorites, push tokens
-- ---------------------------------------------------------------------------
create table public.favorites (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  venue_id    uuid not null references public.venues (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, venue_id)
);

create table public.device_tokens (
  token       text primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  platform    text not null check (platform in ('ios', 'android')),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger venues_touch   before update on public.venues   for each row execute function public.touch_updated_at();
create trigger pitches_touch  before update on public.pitches  for each row execute function public.touch_updated_at();
create trigger bookings_touch before update on public.bookings for each row execute function public.touch_updated_at();
create trigger payments_touch before update on public.payments for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Create a profile row for every new auth user (phone OTP or email sign-up).
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, phone, email, full_name)
  values (
    new.id,
    new.phone,
    new.email,
    coalesce(left(new.raw_user_meta_data ->> 'full_name', 80), '')
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

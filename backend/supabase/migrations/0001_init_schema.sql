-- ============================================================
-- Secret Places — core schema
-- Sensitive paid-place fields live on the base `places` table which is NOT
-- client-selectable; the public teaser is exposed via `places_public` and full
-- data only via the entitlement-checking RPC get_place_details().
-- ============================================================
create extension if not exists pgcrypto;
create extension if not exists postgis with schema extensions;

-- ---------------- Reference / geo hierarchy ----------------
create table public.countries (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null, name text not null, emoji_flag text, cover_url text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.regions (
  id uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.countries(id) on delete cascade,
  slug text not null, name text not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (country_id, slug)
);
create table public.cities (
  id uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.countries(id) on delete cascade,
  region_id uuid references public.regions(id) on delete set null,
  slug text not null, title text not null, description text,
  lat double precision, lng double precision, cover_url text,
  is_outside_city boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (country_id, slug)
);
create table public.neighborhoods (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities(id) on delete cascade,
  slug text not null, title text not null, description text,
  lat double precision, lng double precision, cover_url text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (city_id, slug)
);
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null, title text not null, icon text,
  sort int not null default 0, is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------------- Places ----------------
create table public.places (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null, internal_name text,
  -- teaser (public)
  teaser_title text not null, teaser_description text not null, hero_image_url text,
  -- SENSITIVE (only via get_place_details when unlocked)
  full_title text, full_description text,
  exact_lat double precision, exact_lng double precision, exact_address text, business_name text,
  walking_instructions text, parking_info text, insider_tips text, photo_spot text,
  website text, booking_url text, apple_maps_url text, google_maps_url text, opening_hours jsonb,
  -- public approximate location (fuzzed)
  approx_lat double precision, approx_lng double precision,
  geog extensions.geography(Point,4326),
  -- geo fks
  country_id uuid references public.countries(id) on delete set null,
  region_id uuid references public.regions(id) on delete set null,
  city_id uuid references public.cities(id) on delete set null,
  neighborhood_id uuid references public.neighborhoods(id) on delete set null,
  primary_category_id uuid references public.categories(id) on delete set null,
  -- commerce
  access_type text not null default 'paid' check (access_type in ('free','paid','includedInCollection','promotionalFree')),
  price_cents int not null default 99, currency text not null default 'USD', product_id text,
  promotion_start_at timestamptz, promotion_end_at timestamptz,
  -- non-identifying guide info (teaser-safe)
  travel_time_min int, recommended_transport text, best_time text, best_season text,
  expected_duration_min int,
  crowd_level text check (crowd_level in ('low','medium','high') or crowd_level is null),
  price_level int check (price_level between 1 and 4 or price_level is null),
  accessibility_info text, safety_info text, mobile_signal text, what_to_bring text,
  rating numeric(3,2) not null default 0, ratings_count int not null default 0,
  status text not null default 'draft' check (status in ('draft','published','disabled')),
  featured boolean not null default false, editors_choice boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.place_categories (
  place_id uuid not null references public.places(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  primary key (place_id, category_id)
);
create table public.place_tags (
  place_id uuid not null references public.places(id) on delete cascade,
  tag text not null, primary key (place_id, tag)
);
create table public.place_images (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places(id) on delete cascade,
  url text not null, sort int not null default 0, is_hero boolean not null default false,
  preview_allowed boolean not null default true, created_at timestamptz not null default now()
);

-- ---------------- Collections ----------------
create table public.collections (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null, title text not null, description text, cover_url text,
  country_id uuid references public.countries(id) on delete set null,
  city_id uuid references public.cities(id) on delete set null,
  neighborhood_id uuid references public.neighborhoods(id) on delete set null,
  is_free boolean not null default true, price_cents int not null default 0,
  currency text not null default 'USD', product_id text, featured boolean not null default false,
  status text not null default 'draft' check (status in ('draft','published','disabled')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.collection_places (
  collection_id uuid not null references public.collections(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  sort int not null default 0, primary key (collection_id, place_id)
);

-- ---------------- User-owned ----------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text, interests text[] not null default '{}',
  home_city_id uuid references public.cities(id) on delete set null,
  onboarded boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.user_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  place_id uuid references public.places(id) on delete cascade,
  collection_id uuid references public.collections(id) on delete cascade,
  product_id text not null, transaction_id text, original_transaction_id text,
  source text not null default 'app_store' check (source in ('app_store','promo','grant','collection')),
  purchased_at timestamptz not null default now(), revoked_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, place_id, original_transaction_id)
);
create table public.user_saved_places (
  user_id uuid not null references auth.users(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  created_at timestamptz not null default now(), primary key (user_id, place_id)
);
create table public.user_place_status (
  user_id uuid not null references auth.users(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  status text not null check (status in ('want_to_visit','visited')),
  updated_at timestamptz not null default now(), primary key (user_id, place_id)
);
create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  score int not null check (score between 1 and 5), feedback text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (user_id, place_id)
);
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  place_id uuid not null references public.places(id) on delete cascade,
  reason text not null check (reason in ('closed','inaccessible','wrong_coordinates','unsafe','price_changed','duplicate','not_worth','other')),
  details text, status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now()
);
create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  title text not null, description text, category_slug text,
  lat double precision, lng double precision, why_special text, tips text,
  photo_urls text[] not null default '{}',
  state text not null default 'submitted' check (state in ('draft','submitted','underReview','approved','rejected')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nearby_new boolean not null default true, saved_city_new boolean not null default true,
  free_today boolean not null default true, neighborhood_collections boolean not null default false,
  trip_recommendations boolean not null default false, updated_at timestamptz not null default now()
);

-- ---------------- Indexes ----------------
create index idx_places_status on public.places(status);
create index idx_places_city on public.places(city_id);
create index idx_places_neighborhood on public.places(neighborhood_id);
create index idx_places_country on public.places(country_id);
create index idx_places_category on public.places(primary_category_id);
create index idx_places_access on public.places(access_type);
create index idx_places_featured on public.places(featured) where featured;
create index idx_places_geog on public.places using gist (geog);
create index idx_place_images_place on public.place_images(place_id);
create index idx_place_tags_tag on public.place_tags(tag);
create index idx_neighborhoods_city on public.neighborhoods(city_id);
create index idx_cities_country on public.cities(country_id);
create index idx_entitlements_user on public.user_entitlements(user_id);
create index idx_saved_user on public.user_saved_places(user_id);
create index idx_status_user on public.user_place_status(user_id);

-- keep geog in sync with exact coords
create or replace function public.places_sync_geog() returns trigger
language plpgsql as $$
begin
  if new.exact_lat is not null and new.exact_lng is not null then
    new.geog := extensions.ST_SetSRID(extensions.ST_MakePoint(new.exact_lng, new.exact_lat), 4326)::extensions.geography;
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger trg_places_sync_geog before insert or update on public.places
  for each row execute function public.places_sync_geog();

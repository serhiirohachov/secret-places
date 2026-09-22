-- Events / city listings (posters). An event may be tied to a venue (place).
-- Public listing shows event details + the venue TEASER; the exact venue door
-- stays gated behind the place unlock.
create table public.events (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  description text,
  kind text not null default 'party' check (kind in ('rave','concert','gig','party','exhibition','film','market','talk','other')),
  place_id uuid references public.places(id) on delete set null,
  city_id uuid references public.cities(id) on delete set null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  poster_url text,
  ticket_url text,
  price_from_cents int,
  currency text not null default 'UAH',
  is_free boolean not null default false,
  lineup text[] not null default '{}',
  featured boolean not null default false,
  status text not null default 'draft' check (status in ('draft','published','cancelled')),
  source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_events_starts on public.events(starts_at);
create index idx_events_city on public.events(city_id);
create index idx_events_place on public.events(place_id);

alter table public.events enable row level security;
create policy events_read on public.events for select using (status = 'published');
grant select on public.events to anon, authenticated;

create view public.events_public with (security_invoker = true) as
select e.id, e.slug, e.title, e.description, e.kind, e.starts_at, e.ends_at,
  e.poster_url, e.ticket_url, e.price_from_cents, e.currency, e.is_free, e.lineup,
  e.featured, e.city_id, e.place_id,
  p.teaser_title as venue_teaser, p.approx_lat as venue_approx_lat, p.approx_lng as venue_approx_lng,
  p.primary_category_id as venue_category, p.access_type as venue_access
from public.events e
left join public.places p on p.id = e.place_id and p.status = 'published'
where e.status = 'published' and coalesce(e.ends_at, e.starts_at) >= now() - interval '6 hours';
grant select on public.events_public to anon, authenticated;

-- Real event feeds announce a public venue name (and often only an approximate
-- location). Events are public listings, so the venue name is shown directly.
-- A linked curated place (place_id) still adds the teaser + approx map + gating.
alter table public.events add column if not exists venue_name text;
alter table public.events add column if not exists venue_lat double precision;
alter table public.events add column if not exists venue_lng double precision;

create or replace view public.events_public with (security_invoker = true) as
select e.id, e.slug, e.title, e.description, e.kind, e.starts_at, e.ends_at,
  e.poster_url, e.ticket_url, e.price_from_cents, e.currency, e.is_free, e.lineup,
  e.featured, e.city_id, e.place_id,
  coalesce(e.venue_name, p.teaser_title) as venue_teaser,
  coalesce(e.venue_lat, p.approx_lat) as venue_approx_lat,
  coalesce(e.venue_lng, p.approx_lng) as venue_approx_lng,
  p.primary_category_id as venue_category, p.access_type as venue_access,
  e.venue_name
from public.events e
left join public.places p on p.id = e.place_id and p.status = 'published'
where e.status = 'published' and coalesce(e.ends_at, e.starts_at) >= now() - interval '6 hours';
grant select on public.events_public to anon, authenticated;

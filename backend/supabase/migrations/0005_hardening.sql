-- ============================================================
-- Secret Places — security hardening
-- Column-level privileges on `places`: the teaser is directly readable but
-- selecting any sensitive column raises "permission denied", enforced by
-- Postgres itself; places_public becomes a plain security_invoker view.
-- ============================================================
alter table public.place_categories enable row level security;
create policy read_place_categories on public.place_categories for select using (
  exists (select 1 from public.places p where p.id = place_id and p.status = 'published'));
grant select on public.place_categories to anon, authenticated;

create policy places_read_published on public.places for select using (status = 'published');

grant select (
  id, slug, teaser_title, teaser_description, hero_image_url,
  approx_lat, approx_lng, country_id, region_id, city_id, neighborhood_id, primary_category_id,
  access_type, price_cents, currency, product_id, promotion_start_at, promotion_end_at,
  travel_time_min, recommended_transport, best_time, best_season, expected_duration_min,
  crowd_level, price_level, accessibility_info, safety_info, mobile_signal, what_to_bring,
  rating, ratings_count, status, featured, editors_choice, created_at, updated_at
) on public.places to anon, authenticated;
-- exact_lat/exact_lng/exact_address/business_name/full_title/full_description/walking_instructions/
-- parking_info/insider_tips/photo_spot/website/booking_url/apple_maps_url/google_maps_url/opening_hours/
-- geog/internal_name are NEVER granted.

drop view if exists public.places_public;
create view public.places_public with (security_invoker = true) as
select p.id, p.slug, p.teaser_title, p.teaser_description, p.hero_image_url, p.approx_lat, p.approx_lng,
  p.country_id, p.region_id, p.city_id, p.neighborhood_id, p.primary_category_id,
  p.access_type, p.price_cents, p.currency, p.product_id, p.promotion_start_at, p.promotion_end_at,
  (p.access_type in ('free','promotionalFree')
    or (p.promotion_start_at is not null and p.promotion_end_at is not null
        and now() between p.promotion_start_at and p.promotion_end_at)) as is_free_now,
  p.travel_time_min, p.recommended_transport, p.best_time, p.best_season, p.expected_duration_min,
  p.crowd_level, p.price_level, p.accessibility_info, p.safety_info, p.mobile_signal, p.what_to_bring,
  p.rating, p.ratings_count, p.featured, p.editors_choice, p.created_at, p.updated_at
from public.places p where p.status = 'published';
grant select on public.places_public to anon, authenticated;

create or replace function public.places_sync_geog() returns trigger
language plpgsql set search_path = public, extensions as $$
begin
  if new.exact_lat is not null and new.exact_lng is not null then
    new.geog := extensions.ST_SetSRID(extensions.ST_MakePoint(new.exact_lng, new.exact_lat), 4326)::extensions.geography;
  end if;
  new.updated_at := now();
  return new;
end $$;

revoke execute on function public.is_place_unlocked(uuid, uuid) from anon, authenticated;
revoke execute on function public.recompute_place_rating(uuid) from anon, authenticated;
revoke execute on function public.ratings_after_change() from anon, authenticated;
revoke execute on function public.handle_new_user() from anon, authenticated;
revoke execute on function public.places_sync_geog() from anon, authenticated;
revoke execute on function public.can_rate_place(uuid) from anon;

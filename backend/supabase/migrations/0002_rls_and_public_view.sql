-- ============================================================
-- Secret Places — RLS + public teaser view. Apply AFTER 0003.
-- (0005 later replaces the definer view with a column-privilege model.)
-- ============================================================
revoke all on public.places from anon, authenticated;
alter table public.places enable row level security;

create or replace view public.places_public with (security_invoker = false) as
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

alter table public.countries enable row level security;
alter table public.regions enable row level security;
alter table public.cities enable row level security;
alter table public.neighborhoods enable row level security;
alter table public.categories enable row level security;
alter table public.collections enable row level security;
alter table public.collection_places enable row level security;
alter table public.place_images enable row level security;
alter table public.place_tags enable row level security;

create policy read_countries on public.countries for select using (true);
create policy read_regions on public.regions for select using (true);
create policy read_cities on public.cities for select using (true);
create policy read_neighborhoods on public.neighborhoods for select using (true);
create policy read_categories on public.categories for select using (is_active);
create policy read_collections on public.collections for select using (status = 'published');
create policy read_collection_places on public.collection_places for select using (
  exists (select 1 from public.collections c where c.id = collection_id and c.status = 'published'));
create policy read_place_images on public.place_images for select using (
  preview_allowed and exists (select 1 from public.places p where p.id = place_id and p.status = 'published'));
create policy read_place_tags on public.place_tags for select using (
  exists (select 1 from public.places p where p.id = place_id and p.status = 'published'));
grant select on public.countries, public.regions, public.cities, public.neighborhoods,
  public.categories, public.collections, public.collection_places, public.place_images, public.place_tags
  to anon, authenticated;

alter table public.profiles enable row level security;
alter table public.user_entitlements enable row level security;
alter table public.user_saved_places enable row level security;
alter table public.user_place_status enable row level security;
alter table public.ratings enable row level security;
alter table public.reports enable row level security;
alter table public.submissions enable row level security;
alter table public.notification_preferences enable row level security;

grant select, insert, update, delete on
  public.profiles, public.user_saved_places, public.user_place_status,
  public.ratings, public.reports, public.submissions, public.notification_preferences to authenticated;
grant select on public.user_entitlements to authenticated;   -- read-only; writes via edge fn (service role)

create policy profiles_select on public.profiles for select using (auth.uid() = id);
create policy profiles_upsert on public.profiles for insert with check (auth.uid() = id);
create policy profiles_update on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy entitlements_select on public.user_entitlements for select using (auth.uid() = user_id);
create policy saved_all on public.user_saved_places for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy status_all on public.user_place_status for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy ratings_read on public.ratings for select using (true);
create policy ratings_insert on public.ratings for insert with check (auth.uid() = user_id and public.can_rate_place(place_id));
create policy ratings_update on public.ratings for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
grant select on public.ratings to anon;
create policy reports_insert on public.reports for insert with check (auth.uid() = user_id or user_id is null);
create policy reports_select on public.reports for select using (auth.uid() = user_id);
create policy submissions_insert on public.submissions for insert with check (auth.uid() = user_id);
create policy submissions_select on public.submissions for select using (auth.uid() = user_id);
create policy submissions_update on public.submissions for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy notif_all on public.notification_preferences for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

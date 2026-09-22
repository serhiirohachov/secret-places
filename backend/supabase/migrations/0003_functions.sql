-- ============================================================
-- Secret Places — server-side business logic (the entitlement gate)
-- Apply BEFORE 0002 (RLS policy on ratings calls can_rate_place).
-- ============================================================

create or replace function public.is_place_unlocked(p_place_id uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select
    coalesce((
      select (pl.access_type in ('free','promotionalFree'))
        or (pl.promotion_start_at is not null and pl.promotion_end_at is not null
            and now() between pl.promotion_start_at and pl.promotion_end_at)
      from public.places pl where pl.id = p_place_id and pl.status = 'published'
    ), false)
    or (p_user is not null and exists (
      select 1 from public.user_entitlements e
      where e.user_id = p_user and e.place_id = p_place_id and e.revoked_at is null));
$$;

create or replace function public.can_rate_place(p_place_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_place_unlocked(p_place_id, auth.uid())
    or exists (select 1 from public.user_place_status s
               where s.user_id = auth.uid() and s.place_id = p_place_id and s.status = 'visited');
$$;

-- THE ENTITLEMENT GATE: full data only when unlocked, else teaser + locked:true.
create or replace function public.get_place_details(p_place_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public, extensions as $$
declare
  p public.places%rowtype; v_uid uuid := auth.uid(); v_unlocked boolean;
  v_teaser jsonb; v_images jsonb; v_tags jsonb;
begin
  select * into p from public.places where id = p_place_id and status = 'published';
  if not found then return jsonb_build_object('error','not_found'); end if;
  v_unlocked := public.is_place_unlocked(p_place_id, v_uid);
  select coalesce(jsonb_agg(jsonb_build_object('url', pi.url, 'sort', pi.sort, 'is_hero', pi.is_hero) order by pi.sort), '[]'::jsonb)
    into v_images from public.place_images pi
    where pi.place_id = p_place_id and (v_unlocked or pi.preview_allowed);
  select coalesce(jsonb_agg(t.tag), '[]'::jsonb) into v_tags from public.place_tags t where t.place_id = p_place_id;
  v_teaser := jsonb_build_object(
    'id', p.id, 'slug', p.slug, 'locked', not v_unlocked,
    'teaser_title', p.teaser_title, 'teaser_description', p.teaser_description, 'hero_image_url', p.hero_image_url,
    'approx_lat', p.approx_lat, 'approx_lng', p.approx_lng,
    'country_id', p.country_id, 'region_id', p.region_id, 'city_id', p.city_id,
    'neighborhood_id', p.neighborhood_id, 'primary_category_id', p.primary_category_id,
    'access_type', p.access_type, 'price_cents', p.price_cents, 'currency', p.currency, 'product_id', p.product_id,
    'travel_time_min', p.travel_time_min, 'recommended_transport', p.recommended_transport,
    'best_time', p.best_time, 'best_season', p.best_season, 'expected_duration_min', p.expected_duration_min,
    'crowd_level', p.crowd_level, 'price_level', p.price_level,
    'accessibility_info', p.accessibility_info, 'safety_info', p.safety_info,
    'mobile_signal', p.mobile_signal, 'what_to_bring', p.what_to_bring,
    'rating', p.rating, 'ratings_count', p.ratings_count,
    'featured', p.featured, 'editors_choice', p.editors_choice, 'images', v_images, 'tags', v_tags,
    'is_free_now', (p.access_type in ('free','promotionalFree')
      or (p.promotion_start_at is not null and p.promotion_end_at is not null
          and now() between p.promotion_start_at and p.promotion_end_at)));
  if not v_unlocked then return v_teaser; end if;   -- SENSITIVE FIELDS NEVER INCLUDED
  return v_teaser || jsonb_build_object(
    'full_title', p.full_title, 'full_description', p.full_description,
    'exact_lat', p.exact_lat, 'exact_lng', p.exact_lng, 'exact_address', p.exact_address, 'business_name', p.business_name,
    'walking_instructions', p.walking_instructions, 'parking_info', p.parking_info,
    'insider_tips', p.insider_tips, 'photo_spot', p.photo_spot, 'website', p.website, 'booking_url', p.booking_url,
    'apple_maps_url', p.apple_maps_url, 'google_maps_url', p.google_maps_url, 'opening_hours', p.opening_hours);
end $$;
grant execute on function public.get_place_details(uuid) to anon, authenticated;
grant execute on function public.is_place_unlocked(uuid, uuid) to authenticated;
grant execute on function public.can_rate_place(uuid) to authenticated;

-- Nearby: teaser rows + rounded distance. Never exact coords for locked places.
create or replace function public.nearby_places(p_lat double precision, p_lng double precision, p_radius_m double precision, p_limit int default 50)
returns table (id uuid, slug text, teaser_title text, teaser_description text, hero_image_url text,
  approx_lat double precision, approx_lng double precision, primary_category_id uuid,
  access_type text, price_cents int, currency text, is_free_now boolean,
  rating numeric, ratings_count int, distance_m double precision, unlocked boolean)
language sql stable security definer set search_path = public, extensions as $$
  select p.id, p.slug, p.teaser_title, p.teaser_description, p.hero_image_url,
    p.approx_lat, p.approx_lng, p.primary_category_id, p.access_type, p.price_cents, p.currency,
    (p.access_type in ('free','promotionalFree')
      or (p.promotion_start_at is not null and p.promotion_end_at is not null
          and now() between p.promotion_start_at and p.promotion_end_at)) as is_free_now,
    p.rating, p.ratings_count,
    round(extensions.ST_Distance(p.geog, extensions.ST_SetSRID(extensions.ST_MakePoint(p_lng, p_lat),4326)::extensions.geography) / 100.0) * 100 as distance_m,
    public.is_place_unlocked(p.id, auth.uid()) as unlocked
  from public.places p
  where p.status = 'published' and p.geog is not null
    and extensions.ST_DWithin(p.geog, extensions.ST_SetSRID(extensions.ST_MakePoint(p_lng, p_lat),4326)::extensions.geography, p_radius_m)
  order by p.geog operator(extensions.<->) extensions.ST_SetSRID(extensions.ST_MakePoint(p_lng, p_lat),4326)::extensions.geography
  limit p_limit;
$$;
grant execute on function public.nearby_places(double precision, double precision, double precision, int) to anon, authenticated;

-- Rating aggregate maintenance.
create or replace function public.recompute_place_rating(p_place_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.places p set
    rating = coalesce((select round(avg(score)::numeric, 2) from public.ratings r where r.place_id = p_place_id), 0),
    ratings_count = (select count(*) from public.ratings r where r.place_id = p_place_id)
  where p.id = p_place_id;
$$;
create or replace function public.ratings_after_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin perform public.recompute_place_rating(coalesce(new.place_id, old.place_id)); return null; end $$;
create trigger trg_ratings_aggregate after insert or update or delete on public.ratings
  for each row execute function public.ratings_after_change();

-- New auth user → profile + notification defaults.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name) values (new.id, coalesce(new.raw_user_meta_data->>'full_name', null))
    on conflict (id) do nothing;
  insert into public.notification_preferences (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end $$;
create trigger trg_handle_new_user after insert on auth.users
  for each row execute function public.handle_new_user();

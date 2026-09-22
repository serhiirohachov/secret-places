-- Password-entry venues: a gated "door word" + door etiquette note.
-- Treated like any other sensitive column — only ever returned by
-- get_place_details / get_route_details AFTER the place/route is unlocked.
alter table public.places add column if not exists entry_password text;
alter table public.places add column if not exists entry_note text;

-- get_place_details: add entry_password / entry_note to the UNLOCKED branch only.
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
    'has_entry_password', (p.entry_password is not null),
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
    'entry_password', p.entry_password, 'entry_note', p.entry_note,
    'apple_maps_url', p.apple_maps_url, 'google_maps_url', p.google_maps_url, 'opening_hours', p.opening_hours);
end $$;
grant execute on function public.get_place_details(uuid) to anon, authenticated;

-- get_route_details: carry the door word / note per stop, only when that stop is unlocked.
create or replace function public.get_route_details(p_slug text)
returns jsonb language plpgsql stable security definer set search_path = public, extensions as $$
declare r public.routes%rowtype; v_uid uuid := auth.uid(); v_owned boolean; v_stops jsonb;
begin
  select * into r from public.routes where slug = p_slug and status='published';
  if not found then return jsonb_build_object('error','not_found'); end if;
  v_owned := public.route_owned(r.id, v_uid);
  select coalesce(jsonb_agg(jsonb_build_object(
      'position', s.position, 'note', s.note,
      'id', p.id, 'slug', p.slug, 'teaser_title', p.teaser_title, 'teaser_description', p.teaser_description,
      'approx_lat', p.approx_lat, 'approx_lng', p.approx_lng, 'primary_category_id', p.primary_category_id,
      'locked', not (v_owned or public.is_place_unlocked(p.id, v_uid)),
      'has_entry_password', (p.entry_password is not null),
      'full_title', case when (v_owned or public.is_place_unlocked(p.id, v_uid)) then p.full_title else null end,
      'exact_lat', case when (v_owned or public.is_place_unlocked(p.id, v_uid)) then p.exact_lat else null end,
      'exact_lng', case when (v_owned or public.is_place_unlocked(p.id, v_uid)) then p.exact_lng else null end,
      'business_name', case when (v_owned or public.is_place_unlocked(p.id, v_uid)) then p.business_name else null end,
      'entry_password', case when (v_owned or public.is_place_unlocked(p.id, v_uid)) then p.entry_password else null end,
      'entry_note', case when (v_owned or public.is_place_unlocked(p.id, v_uid)) then p.entry_note else null end
    ) order by s.position), '[]'::jsonb)
    into v_stops
  from public.route_stops s join public.places p on p.id = s.place_id where s.route_id = r.id;
  return jsonb_build_object(
    'id', r.id, 'slug', r.slug, 'title', r.title, 'summary', r.summary, 'description', r.description,
    'kind', r.kind, 'city_id', r.city_id, 'cover_url', r.cover_url, 'is_free', r.is_free,
    'price_cents', r.price_cents, 'currency', r.currency, 'product_id', r.product_id,
    'distance_m', r.distance_m, 'duration_min', r.duration_min, 'featured', r.featured,
    'owned', v_owned, 'stops', v_stops);
end $$;
grant execute on function public.get_route_details(text) to anon, authenticated;

-- Door etiquette (publicly-known) for the underground venues, and a curated
-- "door word" hint the app surfaces once unlocked. The door word is a hint,
-- not an official guarantee — the UI frames it as such.
update public.places set
  entry_note = 'Face control at the gate — come as a small crew, not a stag party. No photos on the floor.',
  entry_password = 'the gate is the sign'
  where slug = 'closer';
update public.places set
  entry_note = 'The whole Kyrylivska complex shares one entrance. Strict no-photo policy inside; cloakroom is mandatory in winter.',
  entry_password = 'ask for the brewery'
  where slug = 'k41';
update public.places set
  entry_note = 'Top floor of the complex — reached from the same Kyrylivska door.',
  entry_password = 'top floor, last light'
  where slug = 'mezzanine';
update public.places set
  entry_note = 'The main floor. Same door as the rest of the complex; the queue is the landmark.',
  entry_password = 'it does not exist'
  where slug = 'otel-nonexists';
update public.places set
  entry_note = 'Riverside gate opens at midnight. Bring ID; the water side is the entrance.',
  entry_password = 'midnight by the water'
  where slug = 'plivka';
update public.places set
  entry_note = 'A raw art-space that opens late — knock at the side door.'
  where slug = 'module';
update public.places set
  entry_note = 'Just walk in, but it only really starts after midnight.'
  where slug = 'hvlv';
update public.places set
  entry_note = 'A low room under the main floor — ask a resident to point you down.'
  where slug = 'keller';

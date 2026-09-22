-- Underground category + curated Kyiv underground venues (public, well-known).
-- Closer, K41 (∄), Mezzanine, Keller, Module, ХВЛВ, Plivka. Identity hidden until unlock.
insert into public.categories (slug, title, icon, sort) values ('underground','Underground','waveform',135)
  on conflict (slug) do nothing;

with ids as (
  select 'd3786fb9-57fb-4518-a5f9-a6ed01bfbcde'::uuid country,
         '29cc9f04-d832-49e1-b534-d784da628569'::uuid city,
         (select id from public.categories where slug='underground') cat
)
insert into public.places (
  slug, teaser_title, teaser_description, full_title, full_description,
  exact_lat, exact_lng, approx_lat, approx_lng, exact_address, business_name, walking_instructions,
  apple_maps_url, google_maps_url, country_id, city_id, primary_category_id,
  access_type, price_cents, product_id, status, featured, editors_choice,
  travel_time_min, recommended_transport, best_time, best_season, expected_duration_min,
  crowd_level, price_level, mobile_signal, source, source_ref)
select v.slug, v.tt, v.td, v.ft, v.fd, v.lat, v.lng, round(v.lat::numeric,2), round(v.lng::numeric,2),
  v.addr, v.ft, 'From Podil, walk toward the industrial riverside — look for the gate and the queue, not a sign.',
  'https://maps.apple.com/?ll='||v.lat||','||v.lng, 'https://www.google.com/maps/search/?api=1&query='||v.lat||','||v.lng,
  ids.country, ids.city, ids.cat, v.access, v.price, v.product, 'published', v.featured, v.editors,
  18, 'taxi', 'night', 'all year', 240, 'high', 3, 'patchy', 'curated', v.slug
from ids, (values
  ('closer','A warehouse party behind an unmarked gate','Industrial, loud, and open till the sun — if you know the door.','Closer','Closer — Nyzhnoiurkivska St, Kyiv. A legendary underground club, garden and art space in a former factory.',50.4757,30.4897,'Nyzhnoiurkivska St 31, Kyiv','free',0,null,true,true),
  ('k41','A techno cathedral you find by asking','Concrete, sound, and hours that stretch far past dawn.','K41 (∄)','K41 / ∄ — Kyrylivska St 41, Kyiv. Kyiv''s best-known techno venue, a multi-floor club in an old brewery.',50.4788,30.4872,'Kyrylivska St 41, Kyiv','paid',99,'com.secretplaces.place.k41',true,false),
  ('otel-nonexists','The after-hours room the city hides','No frontage, no list online — just a crowd who already know.','∄ (Otel'')','∄ (Otel'') — Kyrylivska St 41, Kyiv. The main floor of the K41 complex.',50.4788,30.4872,'Kyrylivska St 41, Kyiv','paid',99,'com.secretplaces.place.otel-nonexists',false,false),
  ('mezzanine','An underground floor with no sign','Down a stairwell, into the bass — and out at sunrise.','Mezzanine','Mezzanine — Kyrylivska St 41, Kyiv. A room within the K41 complex.',50.4788,30.4872,'Kyrylivska St 41, Kyiv','paid',99,'com.secretplaces.place.mezzanine',false,false),
  ('keller','A small low room under the main floor','Tight, dark, and loud — the good kind of uncomfortable.','Keller','Keller — Kyrylivska St 41, Kyiv. The basement room of the K41 complex.',50.4788,30.4872,'Kyrylivska St 41, Kyiv','free',0,null,false,false),
  ('module','A raw art-space that turns into a rave','Half gallery, half dancefloor — depends what night you catch it.','Module (Модуль)','Module — Nyzhnoiurkivska area, Kyiv. A raw art and rave space near the riverfront.',50.4762,30.4905,'Nyzhnoiurkivska St, Kyiv','free',0,null,false,true),
  ('hvlv','A cultural dive that goes late','Cheap drinks, good people, and no closing time worth mentioning.','ХВЛВ (HVLV)','HVLV — Verkhnii Val, Podil, Kyiv. A beloved cultural bar that runs late.',50.4659,30.5127,'Verkhnii Val, Kyiv','free',0,null,false,true),
  ('plivka','A riverside floor that opens at midnight','Water on one side, sound on the other — a summer secret.','Plivka','Plivka — Naberezhno-Rybalska, Kyiv. A riverside open-air club that comes alive after midnight.',50.4772,30.5215,'Naberezhno-Rybalska Rd, Kyiv','paid',99,'com.secretplaces.place.plivka',true,false)
) as v(slug,tt,td,ft,fd,lat,lng,addr,access,price,product,featured,editors)
on conflict (slug) do nothing;

insert into public.place_categories(place_id, category_id)
  select id, primary_category_id from public.places where source='curated' on conflict do nothing;

insert into public.place_tags(place_id, tag)
  select id, t from public.places p cross join (values ('techno'),('rave'),('club'),('underground')) x(t)
  where p.source='curated' on conflict do nothing;

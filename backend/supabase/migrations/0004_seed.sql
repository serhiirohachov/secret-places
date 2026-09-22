-- ============================================================
-- Secret Places — development seed
-- Public, non-sensitive demo coordinates for well-known areas.
-- ============================================================
insert into public.categories (slug, title, icon, sort) values
  ('food_drink','Food & Drink','fork.knife',10),('bars','Bars','wineglass',20),
  ('coffee','Coffee','cup.and.saucer',30),('nature','Nature','leaf',40),
  ('rooftops','Rooftops','building.2',50),('viewpoints','Viewpoints','binoculars',60),
  ('beaches','Beaches','beach.umbrella',70),('architecture','Architecture','building.columns',80),
  ('date_spots','Date Spots','heart',90),('walks','Walks','figure.walk',100),
  ('road_trips','Road Trips','car',110),('culture','Culture','theatermasks',120),
  ('night','Night','moon.stars',130),('weekend_escape','Weekend Escape','suitcase',140);

insert into public.countries (slug, name, emoji_flag) values ('ukraine','Ukraine','🇺🇦');

insert into public.cities (country_id, slug, title, description, lat, lng, is_outside_city)
select id, 'kyiv', 'Kyiv', 'Ukraine''s capital — layered history, riverside hills, hidden courtyards and a restless creative scene.', 50.4501, 30.5234, false
from public.countries where slug='ukraine';
insert into public.cities (country_id, slug, title, description, lat, lng, is_outside_city)
select id, 'carpathians', 'Carpathians', 'Mountain ridges, polonynas and waterfalls beyond the cities of western Ukraine.', 48.16, 24.50, true
from public.countries where slug='ukraine';

insert into public.neighborhoods (city_id, slug, title, description, lat, lng)
select c.id, n.slug, n.title, n.descr, n.lat, n.lng
from public.cities c
join (values
  ('golden-gate','Golden Gate','Medieval gate, leafy streets, coffee courtyards and quiet bars.',50.4485,30.5137),
  ('podil','Podil','The old riverside district — cobblestones, galleries, nightlife.',50.4650,30.5190),
  ('pechersk','Pechersk','Green hills above the Dnipro with monasteries and viewpoints.',50.4270,30.5580),
  ('lypky','Lypky','Elegant streets, embassies, hidden mansions and rooftop views.',50.4440,30.5350)
) as n(slug,title,descr,lat,lng) on true
where c.slug='kyiv';

create or replace function pg_temp.seed_place(
  p_slug text, p_city text, p_nb text, p_cat text, p_access text,
  p_teaser_title text, p_teaser_desc text, p_full_title text, p_full_desc text,
  p_exact_lat double precision, p_exact_lng double precision,
  p_business text, p_walk text, p_tips text, p_featured boolean, p_editors boolean,
  p_promo_start timestamptz, p_promo_end timestamptz
) returns void language plpgsql as $$
declare v_city uuid; v_country uuid; v_nb uuid; v_cat uuid;
begin
  select id, country_id into v_city, v_country from public.cities where slug=p_city;
  select id into v_nb from public.neighborhoods where slug=p_nb and city_id=v_city;
  select id into v_cat from public.categories where slug=p_cat;
  insert into public.places (
    slug, teaser_title, teaser_description, full_title, full_description,
    exact_lat, exact_lng, approx_lat, approx_lng, exact_address, business_name, walking_instructions, insider_tips,
    apple_maps_url, google_maps_url, country_id, city_id, neighborhood_id, primary_category_id,
    access_type, price_cents, product_id, status, featured, editors_choice,
    travel_time_min, recommended_transport, best_time, best_season, expected_duration_min,
    crowd_level, price_level, accessibility_info, safety_info, mobile_signal, what_to_bring,
    hero_image_url, promotion_start_at, promotion_end_at
  ) values (
    p_slug, p_teaser_title, p_teaser_desc, p_full_title, p_full_desc,
    p_exact_lat, p_exact_lng, round(p_exact_lat::numeric,2), round(p_exact_lng::numeric,2),
    'Kyiv, Ukraine', p_business, p_walk, p_tips,
    'https://maps.apple.com/?ll='||p_exact_lat||','||p_exact_lng,
    'https://www.google.com/maps/search/?api=1&query='||p_exact_lat||','||p_exact_lng,
    v_country, v_city, v_nb, v_cat,
    p_access, case when p_access='free' then 0 else 99 end,
    'com.secretplaces.place.'||p_slug, 'published', p_featured, p_editors,
    12, 'walk', 'evening', 'all year', 60, 'medium', 2,
    'Street level, some cobblestones', 'Well-lit central area', 'good', 'Comfortable shoes',
    'https://images.secretplaces.app/'||p_slug||'.jpg', p_promo_start, p_promo_end);
  insert into public.place_categories(place_id, category_id) select id, v_cat from public.places where slug=p_slug;
end $$;

select pg_temp.seed_place('gg-hidden-coffee-courtyard','kyiv','golden-gate','coffee','free',
  'A coffee courtyard hidden behind a gate','Pass through an unmarked arch into a green courtyard where a tiny roaster pulls some of the best espresso in the district.',
  'Courtyard Roasters — Yaroslaviv Val','Push the wooden gate at the address, cross the courtyard to the far-left corner.',
  50.4487,30.5142,'Courtyard Roasters','Enter the arch, keep left past the bikes.','Order the honey-process filter; benches warm up by 10am.',true,false,null,null);
select pg_temp.seed_place('gg-quiet-breakfast','kyiv','golden-gate','food_drink','free',
  'A quiet breakfast spot locals keep to themselves','No sign, six tables, syrniki that sell out by noon.',
  'Ranok Kitchen','Ground floor, blue door on the side street.',50.4479,30.5129,'Ranok Kitchen','Side street entrance, blue door.','Go before 10:30 for syrniki.',false,false,null,null);
select pg_temp.seed_place('gg-unmarked-cocktail-bar','kyiv','golden-gate','bars','paid',
  'A cocktail bar behind an unmarked entrance','Knock-to-enter speakeasy with a seasonal menu and no street presence — you have to know.',
  'The Val Speakeasy','Unmarked steel door beside the flower kiosk; ring once.',50.4490,30.5150,'The Val','Steel door by the flower kiosk. Ring the buzzer once.','Ask the bartender for the off-menu horobyna sour.',true,true,null,null);
select pg_temp.seed_place('gg-rooftop-date-view','kyiv','golden-gate','rooftops','paid',
  'A rooftop with the best sunset over old Kyiv','A residential rooftop that opens to guests at golden hour — domes, rooftops and the gate below.',
  'Val Rooftop','Enter courtyard, take the left stairwell to the top, code on the last door.',50.4483,30.5133,'Val Rooftop','Left stairwell, 7 floors, code 1147# on the roof door.','Bring a layer — it gets windy after sunset.',true,false,null,null);
select pg_temp.seed_place('gg-hidden-courtyard-mosaic','kyiv','golden-gate','architecture','free',
  'A hidden courtyard covered in Soviet-era mosaics','A working courtyard where an entire wall is a forgotten mosaic mural.',
  'Mosaic Courtyard','Through the passage, second courtyard on the right.',50.4492,30.5121,'Mosaic Courtyard','Passage, second courtyard on the right.','Best light is late morning.',false,true,null,null);
select pg_temp.seed_place('gg-architecture-walk','kyiv','golden-gate','walks','paid',
  'A 45-minute architecture walk through secret passages','A curated loop connecting five inner courtyards most tourists never find.',
  'Golden Gate Passages Walk','Start at the gate, follow the mapped passages.',50.4486,30.5140,'Golden Gate Passages','Start under the gate arch, head north.','Do it on a weekday morning to have the courtyards to yourself.',false,false,null,null);
select pg_temp.seed_place('gg-secret-wine-cellar','kyiv','golden-gate','bars','promotionalFree',
  'A wine cellar under a bookshop — free this week','Descend past the poetry shelves into a candlelit cellar pouring natural wines by the glass.',
  'Pidval Wine — under Knyharnya','Back of the bookshop, stairs down behind the poetry shelf.',50.4481,30.5147,'Pidval Wine','Back of the bookshop, down the stairs behind poetry.','Tuesday flights are the move.',true,false, now() - interval '1 day', now() + interval '6 days');

select pg_temp.seed_place('podil-river-sauna','kyiv','podil','nature','paid',
  'A riverside sauna with a cold Dnipro plunge','A wooden banya on the water where locals steam and plunge straight into the river.',
  'Dnipro Banya','Walk the embankment north, wooden jetty past the yacht club.',50.4712,30.5205,'Dnipro Banya','Embankment north, wooden jetty past the yacht club.','Sunday mornings are quietest.',false,false,null,null);
select pg_temp.seed_place('podil-vinyl-basement','kyiv','podil','culture','free',
  'A vinyl basement that turns into a tiny club','Record shop by day, 40-person dancefloor after midnight on weekends.',
  'Basement Records','Courtyard, unmarked metal door, downstairs.',50.4661,30.5178,'Basement Records','Courtyard, unmarked metal door, downstairs.','Fridays after midnight.',false,true,null,null);
select pg_temp.seed_place('podil-hidden-gallery','kyiv','podil','culture','paid',
  'A hidden gallery inside a former factory','A raw industrial space showing Ukrainian contemporary art, open by appointment.',
  'Zavod Gallery','Factory gate, building C, third floor.',50.4689,30.5152,'Zavod Gallery','Factory gate, building C, third floor.','Openings on the first Thursday.',false,false,null,null);

select pg_temp.seed_place('pechersk-monastery-viewpoint','kyiv','pechersk','viewpoints','free',
  'A viewpoint over the golden domes and the river','A quiet ledge away from the crowds with the classic Lavra-and-Dnipro panorama.',
  'Pechersk Ledge','Path behind the bell tower, follow the ridge south.',50.4342,30.5577,'Pechersk Ledge','Path behind the bell tower, follow the ridge south.','Sunrise is unreal here.',true,false,null,null);
select pg_temp.seed_place('pechersk-secret-garden-cafe','kyiv','pechersk','coffee','paid',
  'A secret garden café behind an embassy wall','A hidden terrace café tucked behind ivy walls with slow mornings and good pastries.',
  'Sad Café','Green gate on the quiet lane, ring for the terrace.',50.4288,30.5541,'Sad Café','Green gate on the quiet lane, ring for the terrace.','Cardamom bun + filter.',false,true,null,null);

select pg_temp.seed_place('lypky-rooftop-bar','kyiv','lypky','rooftops','paid',
  'A rooftop bar hidden above a mansion','Members mostly know it — a small rooftop with cocktails over the chestnut canopy.',
  'Lypky Rooftop','Mansion entrance, elevator to 6, then the staff stairs.',50.4451,30.5362,'Lypky Rooftop','Mansion entrance, elevator to 6, then staff stairs.','Golden hour, order the chestnut old fashioned.',true,true,null,null);
select pg_temp.seed_place('lypky-quiet-park-bench','kyiv','lypky','walks','free',
  'The quietest bench in central Kyiv','A forgotten pocket park where nobody goes — pure calm five minutes from the noise.',
  'Lypky Pocket Park','Through the arch between the two yellow buildings.',50.4432,30.5338,'Lypky Pocket Park','Through the arch between the two yellow buildings.','Bring a book.',false,false,null,null);

select pg_temp.seed_place('carp-hidden-waterfall','kyiv','golden-gate','nature','paid',
  'A hidden Carpathian waterfall off the marked trail','A cold, clear cascade most hikers walk right past — a short scramble off the main route.',
  'Prykarpattia Falls','From the trailhead, take the unmarked left fork after the wooden bridge.',48.1602,24.5010,'Prykarpattia Falls','From the trailhead, left fork after the wooden bridge, 15 min.','Go after rain; bring grippy shoes.',true,false,null,null);
update public.places set city_id = (select id from public.cities where slug='carpathians'), neighborhood_id = null
  where slug='carp-hidden-waterfall';

insert into public.collections (slug, title, description, is_free, featured, status, city_id)
select 'secret-golden-gate','Secret Golden Gate','The full hidden loop of Kyiv''s Golden Gate — courtyards, bars, rooftops and walks.', true, true, 'published', id
from public.cities where slug='kyiv';
insert into public.collection_places (collection_id, place_id, sort)
select (select id from public.collections where slug='secret-golden-gate'), p.id, row_number() over (order by p.slug)
from public.places p join public.neighborhoods n on n.id = p.neighborhood_id and n.slug='golden-gate';

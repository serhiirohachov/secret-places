-- Kyiv underground bar crawls across the curated venues from 0013.
-- Buying a route unlocks every place it contains; locked stops stay
-- teaser-only until owned (exact door revealed via get_route_details).

-- 1) Kyrylivska Night Shift — the industrial techno cluster.
insert into public.routes (slug, title, summary, description, city_id, kind, is_free, price_cents, currency, product_id, distance_m, duration_min, featured, status)
select 'kyrylivska-night-shift','Kyrylivska Night Shift',
  'Five rooms, one industrial night — from an unmarked gate to a techno cathedral.',
  'A self-guided crawl through Kyiv''s underground core off Nyzhnoiurkivska and Kyrylivska: a warehouse garden, a raw art-rave space, and the floors of the old-brewery complex that runs far past dawn. Unlock to reveal each exact door, in order, and the walking route between them.',
  (select id from public.cities where slug='kyiv'),'bar_crawl', false, 399, 'USD', 'com.secretplaces.route.kyrylivska-night-shift', 1200, 300, true, 'published'
on conflict (slug) do nothing;

with r as (select id from public.routes where slug='kyrylivska-night-shift'),
     s(pos, place_slug, note) as (values
       (1,'closer','Start at the warehouse — garden, sound, the whole factory.'),
       (2,'module','Cross to the raw art-rave space next door.'),
       (3,'keller','Down into the small basement room under the main floor.'),
       (4,'k41','Up into the techno cathedral itself.'),
       (5,'mezzanine','Finish on the top floor as the sun comes up.'))
insert into public.route_stops (route_id, position, place_id, note)
select r.id, s.pos, p.id, s.note
from r, s join public.places p on p.slug = s.place_slug
on conflict do nothing;

-- 2) Podil to the River — a Podil dive, the warehouse, then the riverside.
insert into public.routes (slug, title, summary, description, city_id, kind, is_free, price_cents, currency, product_id, distance_m, duration_min, featured, status)
select 'podil-to-the-river','Podil to the River',
  'A late Podil dive, a warehouse party, and a floor that opens at midnight by the water.',
  'A self-guided arc from a beloved Podil cultural bar, out to the unmarked warehouse gate, and down to the riverside club that comes alive after midnight. Unlock to reveal each exact door, in order, and the walking route between them.',
  (select id from public.cities where slug='kyiv'),'bar_crawl', false, 299, 'USD', 'com.secretplaces.route.podil-to-the-river', 4000, 300, false, 'published'
on conflict (slug) do nothing;

with r as (select id from public.routes where slug='podil-to-the-river'),
     s(pos, place_slug, note) as (values
       (1,'hvlv','Warm up at the Podil dive that never really closes.'),
       (2,'closer','Walk up to the warehouse behind the unmarked gate.'),
       (3,'plivka','End at the riverside floor that opens at midnight.'))
insert into public.route_stops (route_id, position, place_id, note)
select r.id, s.pos, p.id, s.note
from r, s join public.places p on p.slug = s.place_slug
on conflict do nothing;

-- Bar crawl across real Golden Gate bars.
insert into public.routes (slug, title, summary, description, city_id, kind, is_free, price_cents, currency, product_id, distance_m, duration_min, featured, status)
select 'gg-after-dark','Golden Gate After Dark',
  'Five unmarked bars, one night — a self-guided crawl through the doors only locals knock on.',
  'A curated bar crawl through the Golden Gate district: knock-to-enter speakeasies, low-lit rooms and a nightcap spot that is not on the map. Unlock to reveal each exact door, in order, and the walking route between them.',
  (select id from public.cities where slug='kyiv'),'bar_crawl', false, 299, 'USD', 'com.secretplaces.route.gg-after-dark', 1800, 180, true, 'published'
on conflict (slug) do nothing;

insert into public.route_stops (route_id, position, place_id, note)
select (select id from public.routes where slug='gg-after-dark'),
       row_number() over (order by p.editors_choice desc, p.rating desc, p.slug),
       p.id, 'Stop ' || row_number() over (order by p.editors_choice desc, p.rating desc, p.slug)
from public.places p
where p.source='openstreetmap' and p.primary_category_id='07912007-6a3f-4034-b067-e3438649de72'
  and p.neighborhood_id='910a1927-5edc-466b-9a51-b42d674abc31'
order by p.editors_choice desc, p.rating desc, p.slug
limit 5
on conflict do nothing;

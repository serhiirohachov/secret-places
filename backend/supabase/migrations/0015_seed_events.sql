-- Sample events at real venues (dates are relative to load time; lineups are
-- generic placeholders, not fabricated real acts). Replace via a real feed/CMS.
insert into public.events (slug, title, description, kind, place_id, city_id, starts_at, ends_at, ticket_url, price_from_cents, currency, is_free, lineup, featured, status, source)
select v.slug, v.title, v.descr, v.kind,
  (select id from public.places where slug = v.place_slug),
  (select id from public.cities where slug='kyiv'),
  v.starts, v.ends, null, v.price, 'UAH', v.free, v.lineup, v.featured, 'published', 'sample'
from (values
  ('ev-open-air-allnighter','Open-air all-nighter','Doors at 23:00, music till the garden fills with morning light.','rave','closer',((current_date + 3) + time '23:00')::timestamptz, ((current_date + 4) + time '08:00')::timestamptz, 40000, false, array['Resident DJs','Special guest TBA'], true),
  ('ev-techno-night','Techno night','Multi-floor, all night — bring water and stamina.','rave','k41',((current_date + 5) + time '23:00')::timestamptz, ((current_date + 6) + time '10:00')::timestamptz, 50000, false, array['Line-up announced closer to the date'], true),
  ('ev-art-rave-night','Art & rave night','A show that turns into a dancefloor after dark.','party','module',((current_date + 2) + time '22:00')::timestamptz, ((current_date + 3) + time '05:00')::timestamptz, 30000, false, array['Local collective'], false),
  ('ev-riverside-session','Riverside sunset session','Open-air by the water — starts at golden hour.','party','plivka',((current_date + 6) + time '18:00')::timestamptz, ((current_date + 7) + time '02:00')::timestamptz, null, true, array['Resident selectors'], true),
  ('ev-live-and-djs','Live set + DJs','A small live gig, then records till late.','gig','hvlv',((current_date + 1) + time '21:00')::timestamptz, ((current_date + 2) + time '02:00')::timestamptz, null, true, array['Local band','DJ set'], false),
  ('ev-group-show-opening','Group show — opening night','New work from local artists; drinks and a walkthrough.','exhibition','kit-panteleimon-8076b7',((current_date + 4) + time '18:00')::timestamptz, ((current_date + 4) + time '22:00')::timestamptz, null, true, array['Several artists'], false),
  ('ev-coffee-cupping','Coffee cupping & tasting','Taste this season''s roasts, guided by the team.','talk','peaberry-b881a4',((current_date + 2) + time '11:00')::timestamptz, ((current_date + 2) + time '13:00')::timestamptz, null, true, array['Head roaster'], false),
  ('ev-rooftop-sunset','Rooftop sunset','A short evening set as the city lights come on.','party','krysha-933879',((current_date + 7) + time '19:00')::timestamptz, ((current_date + 7) + time '23:30')::timestamptz, 25000, false, array['Resident DJ'], true)
) as v(slug,title,descr,kind,place_slug,starts,ends,price,free,lineup,featured)
on conflict (slug) do nothing;

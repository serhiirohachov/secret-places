-- Vary teaser copy per place (identity still hidden). Deterministic by slug hash.
-- idx picks 1..6 stably: 1 + ((hashtext(slug) % 6) + 6) % 6

-- Viewpoints
with t as (select
  array['A view over the city most people miss','A rooftop-height panorama without the crowd','The overlook locals save for golden hour','A quiet ledge with a very loud view','A skyline moment hiding in plain sight','Where the city lays itself out below'] as titles,
  array['Climb a little and the whole district unfolds — if you know where to stand.','No queue, no ticket booth — just the skyline and whoever already knows.','Come at dusk and watch the domes and rooftops catch the last light.','Tucked off the main path, it opens onto more of the city than you''d expect.','Everyone walks past the turn — take it, and look up.','A short climb, a wide horizon, and almost nobody else.'] as descs)
update public.places p set
  teaser_title = t.titles[1 + ((hashtext(p.slug) % 6) + 6) % 6],
  teaser_description = t.descs[1 + ((hashtext(p.slug) % 6) + 6) % 6]
from t where p.source='openstreetmap' and p.primary_category_id='53563598-2466-4347-981e-004b31a9efba';

-- Bars
with t as (select
  array['A bar the regulars keep quiet about','A drink behind an unmarked door','A low-lit room that doesn''t advertise','A hidden pour worth the detour','The nightcap spot that isn''t on the map','A bar that trusts you to find it'] as titles,
  array['No queue, no sign shouting for attention — just a door, and people who already know.','You have to know it''s there — then it''s the easiest place in the city to stay too long.','Small, unhurried, and better the later it gets.','Off the main strip, with a short menu and a long memory.','Ask the right people and they''ll send you here — now you don''t have to ask.','No frontage, no fuss — just good drinks and people in on the secret.'] as descs)
update public.places p set
  teaser_title = t.titles[1 + ((hashtext(p.slug) % 6) + 6) % 6],
  teaser_description = t.descs[1 + ((hashtext(p.slug) % 6) + 6) % 6]
from t where p.source='openstreetmap' and p.primary_category_id='07912007-6a3f-4034-b067-e3438649de72';

-- Coffee
with t as (select
  array['A specialty coffee spot down a side street','The quiet cup locals don''t post about','A hidden roastery-café worth the walk','A slow-morning coffee corner','The pour-over place friends whisper about','A tiny café that takes coffee seriously'] as titles,
  array['Small, unhurried, and serious about the pour — the kind of place you keep to yourself.','A few seats, a good roast, and mornings that stretch.','Tucked away, but the espresso is the reason people keep coming back.','No rush, no crowd — just a proper flat white and a window seat.','Off the tourist track, and all the better for it.','Blink and you''d miss the door — don''t.'] as descs)
update public.places p set
  teaser_title = t.titles[1 + ((hashtext(p.slug) % 6) + 6) % 6],
  teaser_description = t.descs[1 + ((hashtext(p.slug) % 6) + 6) % 6]
from t where p.source='openstreetmap' and p.primary_category_id='b4933bc8-24fa-49f3-9ca1-00214956e248';

-- Walks / parks
with t as (select
  array['A green pocket to slow down in','A patch of calm most people rush past','The park bench locals keep for themselves','A quiet loop away from the crowds','A slow walk the guidebooks skip','A hidden bit of green worth finding'] as titles,
  array['A quiet corner of the city to walk off a morning — away from the main flow.','Trees, a path, and room to breathe five minutes from the noise.','Come with a coffee and stay longer than you planned.','Enough green to forget you''re in the middle of the city.','Nothing to tick off — just somewhere good to wander.','Off the main avenue, and calmer for it.'] as descs)
update public.places p set
  teaser_title = t.titles[1 + ((hashtext(p.slug) % 6) + 6) % 6],
  teaser_description = t.descs[1 + ((hashtext(p.slug) % 6) + 6) % 6]
from t where p.source='openstreetmap' and p.primary_category_id='14632edb-43ee-4bf8-95bd-afe4598c49b4';

-- Culture / street art
with t as (select
  array['A piece of the city worth finding','Street art you''ll only spot if you look up','A small monument with a big story','A detail of the city hiding in plain sight','The mural locals point friends to','A quiet landmark the tours miss'] as titles,
  array['A small landmark most guides skip — go look before everyone else does.','A wall most people walk straight past — turn the corner and there it is.','Off the main square, but it stops you when you find it.','No plaque, no crowd — just something worth the short detour.','Tucked into a courtyard, and better in person.','Find it yourself and it feels like yours.'] as descs)
update public.places p set
  teaser_title = t.titles[1 + ((hashtext(p.slug) % 6) + 6) % 6],
  teaser_description = t.descs[1 + ((hashtext(p.slug) % 6) + 6) % 6]
from t where p.source='openstreetmap' and p.primary_category_id='545c90c8-75ac-4b25-8115-ef6e6d6fc947';

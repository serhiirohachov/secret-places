-- Nightlife beyond Kyiv: switch the Resident Advisor source from Kyiv (area
-- 517) to all-Ukraine (area 165 = /guide/ua/all). The sync-events RA provider
-- now assigns each event's city from its RA venue area (Kyiv / Lviv / Odesa /
-- Kharkiv / Dnipro / …), so any Ukrainian RA event lands in the right city.
-- (RA's Ukrainian scene is currently Kyiv-heavy; Lviv/Odesa flow in as they
-- get listed.)
update public.event_sources
set config = '{"area":165}'::jsonb,
    label = 'Resident Advisor — Ukraine',
    city_slug = 'kyiv'
where provider = 'resident_advisor';

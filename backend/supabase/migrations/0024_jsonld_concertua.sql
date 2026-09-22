-- Generic schema.org JSON-LD provider + connect Concert.ua (Kyiv).
-- Concert.ua renders ~90 schema.org Event objects per city page (name,
-- startDate, location, offers/price, image, ticket url) — real multi-category
-- coverage (concerts, stand-up, theatre, shows). No Cloudflare, no bot-evasion.
-- Karabas is behind a Cloudflare challenge; kontramarka/internet-bilet render
-- client-side without JSON-LD, so they need per-site API work (not added).
alter table public.event_sources drop constraint if exists event_sources_provider_check;
alter table public.event_sources add constraint event_sources_provider_check
  check (provider in ('resident_advisor','ics','molodyy','jsonld'));

insert into public.event_sources (provider, label, kind, city_slug, config)
select 'jsonld','Concert.ua — Kyiv','concert','kyiv','{"url":"https://concert.ua/uk/city/kyiv"}'::jsonb
where not exists (select 1 from public.event_sources where provider='jsonld' and config->>'url'='https://concert.ua/uk/city/kyiv');

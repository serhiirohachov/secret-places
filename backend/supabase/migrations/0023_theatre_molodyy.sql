-- Add a theatre provider: Molodyy Theatre (Молодий театр, Kyiv). Its /afisha
-- is server-rendered HTML (no Cloudflare), so sync-events can parse it with a
-- plain fetch — no headless browser. Each theatre needs its own parser, so the
-- provider is named per-theatre.
alter table public.event_sources drop constraint if exists event_sources_provider_check;
alter table public.event_sources add constraint event_sources_provider_check
  check (provider in ('resident_advisor','ics','molodyy'));

insert into public.event_sources (provider, label, kind, city_slug, venue_name, config)
select 'molodyy','Молодий театр — афіша','theatre','kyiv','Молодий театр','{"base":"https://molodyytheatre.com"}'::jsonb
where not exists (select 1 from public.event_sources where provider='molodyy');

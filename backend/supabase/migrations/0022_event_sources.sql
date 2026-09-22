-- Broaden the event taxonomy and add a source registry so the Афіша can
-- cover anything — theatre, gastro nights, flea markets, festivals, stand-up,
-- exhibitions, film, sport, kids, tours, workshops — by adding a ROW, not code.

-- 1) Widen the kind check to the full taxonomy.
alter table public.events drop constraint if exists events_kind_check;
alter table public.events add constraint events_kind_check check (kind in (
  'rave','club','concert','gig','music','party',
  'theatre','standup','film','exhibition','art',
  'food','market','festival','fair',
  'sport','kids','tour','workshop','talk','other'
));

-- 2) Source registry. Each row is one feed the sync job ingests.
--    provider = how to fetch; config = provider-specific params; kind = default
--    category for its events; venue_name = default venue when the feed omits one.
create table if not exists public.event_sources (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('resident_advisor','ics')),
  label text,
  kind text not null default 'other',
  city_slug text not null default 'kyiv',
  venue_name text,
  config jsonb not null default '{}'::jsonb,
  enabled boolean not null default true,
  last_run_at timestamptz,
  last_result jsonb,
  created_at timestamptz not null default now()
);
alter table public.event_sources enable row level security;
-- No anon/auth grants — only the service role (edge function) reads/writes this.

-- 3) Seed the existing real source: Resident Advisor, Kyiv (electronic).
insert into public.event_sources (provider, label, kind, city_slug, config)
select 'resident_advisor','Resident Advisor — Kyiv','rave','kyiv','{"area":517}'::jsonb
where not exists (select 1 from public.event_sources where provider='resident_advisor' and config->>'area'='517');

-- Examples to light up other categories later (add a real public ICS URL):
--   insert into public.event_sources (provider,label,kind,venue_name,config) values
--     ('ics','Some Theatre — season','theatre','Theatre name','{"url":"https://.../calendar.ics"}'),
--     ('ics','Flea market calendar','market',null,'{"url":"https://.../market.ics"}');

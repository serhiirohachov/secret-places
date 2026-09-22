-- Provenance for imported places (not exposed publicly).
alter table public.places add column if not exists source text;
alter table public.places add column if not exists source_ref text;
comment on column public.places.source is 'Data provenance, e.g. openstreetmap';
comment on column public.places.source_ref is 'Source id, e.g. OSM node id';

# Data tools

## world_import.py — add any city in the world

Turns a list of `(country, city, center lat/lng)` into curated Secret Places
SQL from OpenStreetMap (viewpoints, bars, coffee, parks, street art), with the
same teaser/privacy model and varied teaser copy. The platform's country →
city → neighborhood hierarchy and PostGIS proximity are already global; this
just supplies data.

```bash
python3 backend/tools/world_import.py     # writes world_seed.sql
psql "$DATABASE_URL" -f world_seed.sql    # or apply via the Supabase API
```

Edit the `CITIES` list to add destinations. Data © OpenStreetMap contributors (ODbL).
Overpass mirrors are rate-limited/occasionally down; the fetch retries across
mirrors. Re-run when a mirror is available.

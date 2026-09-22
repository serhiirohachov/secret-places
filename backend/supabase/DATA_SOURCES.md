# Data sources & attribution

The seeded place data in `0008_real_places_osm.sql` is derived from
**OpenStreetMap** and is © **OpenStreetMap contributors**, available under the
**Open Database License (ODbL)** — https://www.openstreetmap.org/copyright.

- Fetched via the Overpass API (Kyiv area): named `tourism=viewpoint` and
  `amenity=bar` nodes, transformed into teaser/full place records.
- Names, coordinates, addresses, opening hours and websites originate from OSM.
- The app displays "Place data © OpenStreetMap contributors" in Profile → Privacy.

To refresh or extend the dataset, re-run the Overpass fetch + transform and
regenerate `0008_real_places_osm.sql`.

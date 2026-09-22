-- Decorative, non-identifying cover imagery (grayscale to match the dark
-- editorial theme). Free-to-use Lorem Picsum, seeded per-slug so each row is
-- stable. NOTE: intentionally NOT applied to paid/hidden place teasers — their
-- neutral placeholder preserves the "secret" and avoids implying a real photo
-- of a specific door. Only routes, events, cities and free places get covers.
update public.routes
  set cover_url = 'https://picsum.photos/seed/spr-' || slug || '/1000/600?grayscale'
  where cover_url is null;

update public.events
  set poster_url = 'https://picsum.photos/seed/spe-' || slug || '/900/1100?grayscale'
  where poster_url is null;

update public.cities
  set cover_url = 'https://picsum.photos/seed/spc-' || slug || '/800/500?grayscale'
  where cover_url is null;

-- Free places only (never paid/hidden ones).
update public.places
  set hero_image_url = 'https://picsum.photos/seed/spp-' || slug || '/900/600?grayscale'
  where hero_image_url is null and access_type in ('free','promotionalFree');

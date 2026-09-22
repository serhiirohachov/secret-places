-- The bar crawl stops are real Kyiv bars, but the seed copy carried a
-- "Golden Gate" (San Francisco) label. Retitle it to its actual city.
-- Slug and product_id are kept (they are baked into the StoreKit product id).
update public.routes
set title = 'Podil After Dark',
    summary = 'Five unmarked bars, one night — a self-guided crawl through the doors only locals knock on.',
    description = 'A curated bar crawl through Podil and the riverside: knock-to-enter rooms, low-lit bars and a nightcap spot that is not on the map. Unlock to reveal each exact door, in order, and the walking route between them.'
where slug = 'gg-after-dark';

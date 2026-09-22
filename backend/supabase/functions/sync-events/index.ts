// ============================================================
// Secret Places — sync-events Edge Function
// Pulls a REAL events feed for Kyiv and upserts it into public.events
// (service role). Current provider: Resident Advisor public GraphQL
// (area 517 = Kyiv, Ukraine) — real electronic-music listings at the
// same venues the app curates. Events are public announcements, so the
// venue NAME is stored and shown; when the venue matches a curated place
// we also link place_id (adds the teaser + approx map + place gating).
//
// Trigger: POST with header  x-sync-secret: <SYNC_SECRET>  (set as a
// function secret). Optional body: { pages?: number, dropSample?: boolean }.
// Schedule via pg_cron + pg_net, or invoke manually.
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SYNC_SECRET = Deno.env.get("SYNC_SECRET") ?? "";

const RA_ENDPOINT = "https://ra.co/graphql";
const RA_AREA_KYIV = 517;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-sync-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

// Map a Resident Advisor venue name to one of our curated place slugs.
function placeSlugForVenue(name: string): string | null {
  const n = name.toLowerCase();
  if (n.includes("closer")) return "closer";
  if (n.includes("k41") || n.includes("∄") || n.includes("otel")) return "k41";
  if (n.includes("plivka") || n.includes("плівка")) return "plivka";
  if (n.includes("hvlv") || n.includes("хвлв")) return "hvlv";
  if (n.includes("module") || n.includes("модуль")) return "module";
  if (n.includes("keller")) return "keller";
  if (n.includes("mezzanine")) return "mezzanine";
  return null;
}

const RA_QUERY = `query GET_EVENT_LISTINGS($filters: FilterInputDtoInput, $pageSize: Int, $page: Int) {
  eventListings(filters: $filters, pageSize: $pageSize, page: $page) {
    data { event {
      id title startTime endTime isTicketed
      images { filename }
      venue { name }
      artists { name }
    } }
    totalResults
  }
}`;

async function fetchRaPage(page: number, sinceISO: string) {
  const body = {
    operationName: "GET_EVENT_LISTINGS",
    variables: { filters: { areas: { eq: RA_AREA_KYIV }, listingDate: { gte: sinceISO } }, pageSize: 20, page },
    query: RA_QUERY,
  };
  const res = await fetch(RA_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "User-Agent": "Mozilla/5.0 (SecretPlaces event sync)",
      "Referer": "https://ra.co/events/ua/kyiv",
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`RA http ${res.status}`);
  const j = await res.json();
  if (j.errors) throw new Error(`RA gql: ${JSON.stringify(j.errors).slice(0, 200)}`);
  return j.data?.eventListings?.data ?? [];
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // Shared-secret gate — never expose the writer to anonymous callers.
  // Accept a dedicated SYNC_SECRET, or the service-role key (used by cron).
  const provided = req.headers.get("x-sync-secret") ?? "";
  const authed = (SYNC_SECRET && provided === SYNC_SECRET) || (provided && provided === SERVICE_ROLE);
  if (!authed) return json({ error: "unauthorized" }, 401);

  const opts = await req.json().catch(() => ({}));
  const pages = Math.min(Math.max(Number(opts.pages ?? 3), 1), 8);

  const db = createClient(SUPABASE_URL, SERVICE_ROLE);

  // City + curated place coordinates for venue linking.
  const { data: city } = await db.from("cities").select("id").eq("slug", "kyiv").maybeSingle();
  const cityId = city?.id ?? null;
  const { data: places } = await db.from("places").select("id, slug, approx_lat, approx_lng");
  const placeBySlug = new Map((places ?? []).map((p: any) => [p.slug, p]));

  // Pull RA pages, dedupe by event id.
  const since = new Date().toISOString().slice(0, 10);
  const seen = new Set<string>();
  const rows: any[] = [];
  let fetched = 0;
  for (let page = 1; page <= pages; page++) {
    let listings: any[] = [];
    try { listings = await fetchRaPage(page, since); }
    catch (e) { return json({ error: "provider_failed", detail: String(e), upserted: 0 }, 502); }
    if (listings.length === 0) break;
    for (const l of listings) {
      const e = l.event;
      if (!e?.id || seen.has(e.id)) continue;
      seen.add(e.id);
      fetched++;
      const venueName: string | null = e.venue?.name ?? null;
      const slug = venueName ? placeSlugForVenue(venueName) : null;
      const place = slug ? placeBySlug.get(slug) : null;
      const lineup = (e.artists ?? []).map((a: any) => a.name).filter(Boolean);
      rows.push({
        slug: `ra-${e.id}`,
        title: e.title,
        kind: "rave",
        city_id: cityId,
        place_id: place?.id ?? null,
        starts_at: e.startTime,
        ends_at: e.endTime ?? null,
        poster_url: e.images?.[0]?.filename ?? null,
        ticket_url: `https://ra.co/events/${e.id}`,
        price_from_cents: null,
        currency: "UAH",
        is_free: false,
        lineup,
        venue_name: venueName,
        venue_lat: place?.approx_lat ?? null,
        venue_lng: place?.approx_lng ?? null,
        featured: false,
        status: "published",
        source: "resident_advisor",
        updated_at: new Date().toISOString(),
      });
    }
  }

  if (rows.length === 0) return json({ ok: true, fetched, upserted: 0, note: "no events returned" });

  const { error: upErr } = await db.from("events").upsert(rows, { onConflict: "slug" });
  if (upErr) return json({ error: "upsert_failed", detail: upErr.message }, 500);

  // Retire RA events that dropped out of the feed or are already over.
  const keep = rows.map((r) => r.slug);
  const { count: retired } = await db
    .from("events")
    .delete({ count: "exact" })
    .eq("source", "resident_advisor")
    .not("slug", "in", `(${keep.join(",")})`);

  // Optionally drop the old demo seed once the real feed is in place.
  let droppedSample = 0;
  if (opts.dropSample) {
    const { count } = await db.from("events").delete({ count: "exact" }).eq("source", "sample");
    droppedSample = count ?? 0;
  }

  return json({ ok: true, provider: "resident_advisor", area: RA_AREA_KYIV, fetched, upserted: rows.length, retired: retired ?? 0, droppedSample });
});

// ============================================================
// Secret Places — sync-events Edge Function (multi-provider)
// Reads public.event_sources (a registry of feeds) and upserts every
// enabled source into public.events with the service role. Adding a new
// category — theatre, gastro, flea market, festival, anything — is a ROW
// in event_sources, not a code change.
//
// Providers:
//   resident_advisor : RA public GraphQL, by area (config.area). Real
//                      electronic-music listings; links a curated place
//                      when the RA venue name matches one.
//   ics              : any public iCalendar (.ics) feed (config.url). The
//                      open standard many theatres / markets / venues publish.
//
// Events are public announcements, so the venue NAME is stored and shown.
// Trigger: POST with x-sync-secret (SYNC_SECRET env, service-role key, or the
// Vault secret sync_events_secret used by pg_cron). Body: { pages?, dropSample? }.
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SYNC_SECRET = Deno.env.get("SYNC_SECRET") ?? "";

const RA_ENDPOINT = "https://ra.co/graphql";
const SYNCED_SOURCES = ["resident_advisor", "ics", "molodyy", "jsonld"]; // events we own & may retire

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-sync-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

type EventRow = Record<string, unknown>;

// ---- Venue → curated place mapping (adds teaser + approx map + gating) ----
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

// ---- Resident Advisor provider ----
const RA_QUERY = `query GET_EVENT_LISTINGS($filters: FilterInputDtoInput, $pageSize: Int, $page: Int) {
  eventListings(filters: $filters, pageSize: $pageSize, page: $page) {
    data { event { id title startTime endTime images { filename } venue { name area { name } } artists { name } } }
  }
}`;

async function raPage(area: number, page: number, sinceISO: string) {
  const res = await fetch(RA_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "User-Agent": "Mozilla/5.0 (SecretPlaces event sync)",
      "Referer": "https://ra.co/events/ua/kyiv",
    },
    body: JSON.stringify({
      operationName: "GET_EVENT_LISTINGS",
      variables: { filters: { areas: { eq: area }, listingDate: { gte: sinceISO } }, pageSize: 20, page },
      query: RA_QUERY,
    }),
  });
  if (!res.ok) throw new Error(`RA http ${res.status}`);
  const j = await res.json();
  if (j.errors) throw new Error(`RA gql: ${JSON.stringify(j.errors).slice(0, 160)}`);
  return j.data?.eventListings?.data ?? [];
}

async function fromResidentAdvisor(src: any, ctx: Ctx): Promise<EventRow[]> {
  const area = Number(src.config?.area);
  if (!area) throw new Error("resident_advisor source missing config.area");
  const since = new Date().toISOString().slice(0, 10);
  const seen = new Set<string>();
  const rows: EventRow[] = [];
  for (let page = 1; page <= ctx.pages; page++) {
    const listings = await raPage(area, page, since);
    if (listings.length === 0) break;
    for (const l of listings) {
      const e = l.event;
      if (!e?.id || seen.has(e.id)) continue;
      seen.add(e.id);
      const venueName: string | null = e.venue?.name ?? null;
      const place = venueName ? ctx.placeBySlug.get(placeSlugForVenue(venueName) ?? "") : null;
      // Assign the city from the RA venue area (Kyiv / Lviv / Odesa / …).
      const areaName: string = (e.venue?.area?.name ?? "").toLowerCase();
      const cityId = ctx.cityByKey.get(areaName) ?? ctx.cityId ?? null;
      rows.push(mkEvent({
        slug: `ra-${e.id}`,
        title: e.title,
        kind: src.kind ?? "rave",
        starts_at: e.startTime,
        ends_at: e.endTime ?? null,
        poster_url: e.images?.[0]?.filename ?? null,
        ticket_url: `https://ra.co/events/${e.id}`,
        lineup: (e.artists ?? []).map((a: any) => a.name).filter(Boolean),
        venue_name: venueName ?? src.venue_name ?? null,
        place, cityId, source: "resident_advisor",
      }));
    }
  }
  return rows;
}

// ---- ICS (iCalendar) provider ----
function unfoldICS(text: string): string[] {
  // RFC5545 line unfolding: a leading space/tab continues the previous line.
  const out: string[] = [];
  for (const raw of text.split(/\r?\n/)) {
    if ((raw.startsWith(" ") || raw.startsWith("\t")) && out.length) out[out.length - 1] += raw.slice(1);
    else out.push(raw);
  }
  return out;
}
function icsUnescape(v: string): string {
  return v.replace(/\\n/gi, "\n").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");
}
function parseIcsDate(val: string, params: string): string | null {
  // Forms: 20260305T190000Z | 20260305T190000 | 20260305 (all-day)
  const m = val.match(/(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?(Z)?/);
  if (!m) return null;
  const [_, y, mo, d, hh = "00", mi = "00", ss = "00", z] = m;
  if (z || !val.includes("T")) return `${y}-${mo}-${d}T${hh}:${mi}:${ss}Z`;
  // TZID or floating: approximate Kyiv local as +03:00 (announcements, not billing).
  return `${y}-${mo}-${d}T${hh}:${mi}:${ss}+03:00`;
}
async function fromICS(src: any, ctx: Ctx): Promise<EventRow[]> {
  const url = String(src.config?.url ?? "");
  if (!url) throw new Error("ics source missing config.url");
  const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 (SecretPlaces event sync)" } });
  if (!res.ok) throw new Error(`ICS http ${res.status}`);
  const lines = unfoldICS(await res.text());
  const rows: EventRow[] = [];
  let cur: Record<string, string> | null = null;
  const nowMs = Date.now();
  for (const line of lines) {
    if (line === "BEGIN:VEVENT") { cur = {}; continue; }
    if (line === "END:VEVENT") {
      if (cur) {
        const uid = cur["UID"] || `${cur["SUMMARY"]}-${cur["DTSTART"]}`;
        const start = cur["DTSTART"] ? parseIcsDate(cur["DTSTART_VAL"] ?? cur["DTSTART"], cur["DTSTART_PARAMS"] ?? "") : null;
        if (start && cur["SUMMARY"] && new Date(start).getTime() >= nowMs - 6 * 3600e3) {
          const end = cur["DTEND"] ? parseIcsDate(cur["DTEND_VAL"] ?? cur["DTEND"], cur["DTEND_PARAMS"] ?? "") : null;
          const venue = cur["LOCATION"] ? icsUnescape(cur["LOCATION"]) : (src.venue_name ?? null);
          const place = venue ? ctx.placeBySlug.get(placeSlugForVenue(venue) ?? "") : null;
          rows.push(mkEvent({
            slug: `ics-${slugifyId(uid)}`,
            title: icsUnescape(cur["SUMMARY"]),
            description: cur["DESCRIPTION"] ? icsUnescape(cur["DESCRIPTION"]).slice(0, 600) : null,
            kind: src.kind ?? "other",
            starts_at: start,
            ends_at: end,
            poster_url: null,
            ticket_url: cur["URL"] || null,
            lineup: [],
            venue_name: venue,
            place, cityId: ctx.cityId, source: "ics",
          }));
        }
      }
      cur = null; continue;
    }
    if (!cur) continue;
    const idx = line.indexOf(":");
    if (idx < 0) return [];
    const left = line.slice(0, idx);
    const value = line.slice(idx + 1);
    const [key, ...params] = left.split(";");
    cur[key] = value;
    cur[`${key}_VAL`] = value;
    cur[`${key}_PARAMS`] = params.join(";");
  }
  return rows;
}

// ---- Molodyy Theatre provider (server-rendered HTML, per-theatre parser) ----
function decodeEntities(s: string): string {
  return s
    .replace(/&#0?39;|&apos;/g, "'").replace(/&quot;/g, '"').replace(/&amp;/g, "&")
    .replace(/&laquo;/g, "«").replace(/&raquo;/g, "»").replace(/&mdash;/g, "—").replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(+n));
}
async function getText(url: string): Promise<string> {
  const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 (SecretPlaces event sync)", "Accept-Language": "uk" } });
  if (!res.ok) throw new Error(`http ${res.status}`);
  return await res.text();
}
async function fromMolodyy(src: any, ctx: Ctx): Promise<EventRow[]> {
  const base = String(src.config?.base ?? "https://molodyytheatre.com");
  const today = new Date().toISOString().slice(0, 10);
  const main = await getText(`${base}/afisha`);
  const days = [...new Set([...main.matchAll(/\/afisha\/(\d{4}-\d{2}-\d{2})/g)].map((m) => m[1]))]
    .filter((d) => d >= today).sort().slice(0, 40);
  const rows: EventRow[] = [];
  const seen = new Set<string>();
  for (const d of days) {
    let html = "";
    try { html = await getText(`${base}/afisha/${d}`); } catch { continue; }
    for (const b of html.split('class="views-row').slice(1)) {
      const blk = b.slice(0, 4000);
      const mt = blk.match(/\/tickets\/(\d+)\/(\d{4}-\d{2}-\d{2})(?:%20|\s)(\d{2})(?:%3A|:)(\d{2})/);
      if (!mt) continue;
      const [, pid, date, hh, mm] = mt;
      const mtl = blk.match(/views-field-field-event-title[\s\S]*?<div class="field-content">([\s\S]*?)<\/div>/);
      const title = mtl ? decodeEntities(mtl[1].replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()) : "";
      if (!title) continue;
      const slug = `molodyy-${pid}-${date}`;
      if (seen.has(slug)) continue;
      seen.add(slug);
      rows.push(mkEvent({
        slug, title, kind: src.kind ?? "theatre",
        starts_at: `${date}T${hh}:${mm}:00+03:00`, ends_at: null, poster_url: null,
        ticket_url: `${base}/tickets/${pid}/${date} ${hh}:${mm}:00`,
        lineup: [], venue_name: src.venue_name ?? "Молодий театр",
        place: null, venueLat: 50.45, venueLng: 30.52, cityId: ctx.cityId, source: "molodyy",
      }));
    }
  }
  return rows;
}

function slugifyId(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 60) || crypto.randomUUID();
}

// ---- Generic schema.org JSON-LD provider (any server-rendered listing) ----
function stripImageSuffix(u: string): string {
  return u.replace(/\.(jpe?g|png|webp|gif)(:[^/?#]*)?/i, ".$1");
}
function inferKind(name: string, atType: string, fallback: string): string {
  const n = name.toLowerCase();
  if (atType.includes("Theater") || /вистав|театр|п['’]єс/.test(n)) return "theatre";
  if (/stand ?up|стенд.?ап/.test(n)) return "standup";
  if (/дитяч|для дітей|kids/.test(n)) return "kids";
  if (/фестивал/.test(n)) return "festival";
  if (/виставк|exhibition/.test(n)) return "exhibition";
  if (/кіно|показ фільму|\bfilm\b/.test(n)) return "film";
  // Only strong, unambiguous nightlife signals (avoid mislabeling plays/
  // concerts). concert.ua is mostly concerts/theatre; RA is the real
  // nightlife source and is already tagged 'rave' by its own provider.
  if (/\btechno\b|техно[- ]?(?:сет|вечір|rave|party)|\brave\b|рейв|afterparty|\bdj[- ]?set\b|діджей[- ]?сет|drum ?[&n] ?bass/.test(n)) return "club";
  if (atType.includes("Music") || /концерт|\blive\b|гурт|tribute/.test(n)) return "concert";
  return fallback;
}
async function fromJsonLd(src: any, ctx: Ctx): Promise<EventRow[]> {
  const url = String(src.config?.url ?? "");
  if (!url) throw new Error("jsonld source missing config.url");
  const html = await getText(url);
  const blocks = [...html.matchAll(/<script[^>]*type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/gi)].map((m) => m[1]);
  const evs: any[] = [];
  const walk = (o: any) => {
    if (Array.isArray(o)) o.forEach(walk);
    else if (o && typeof o === "object") {
      const t = o["@type"]; const ts = Array.isArray(t) ? t.join(",") : String(t ?? "");
      if (ts.includes("Event")) evs.push(o);
      for (const v of Object.values(o)) walk(v);
    }
  };
  for (const b of blocks) { try { walk(JSON.parse(b)); } catch { /* skip malformed block */ } }
  const nowMs = Date.now();
  const seen = new Set<string>();
  const rows: EventRow[] = [];
  for (const e of evs) {
    const start = e.startDate ?? null;
    if (!start || new Date(start).getTime() < nowMs - 6 * 3600e3) continue;
    const evUrl = String(e.url ?? "");
    const seg = evUrl.replace(/[#?].*$/, "").replace(/\/+$/, "").split("/").pop() || String(e.name ?? "");
    const slug = `jsonld-${slugifyId(seg)}`;
    if (seen.has(slug)) continue; seen.add(slug);
    const loc = e.location;
    const venue = loc && typeof loc === "object" ? (loc.name ?? null) : (typeof loc === "string" ? loc : null);
    let img = Array.isArray(e.image) ? e.image[0] : e.image;
    img = typeof img === "string" ? stripImageSuffix(img) : null;
    const offers = Array.isArray(e.offers) ? e.offers[0] : e.offers;
    const priceNum = offers && offers.price != null ? Number(offers.price) : null;
    const atType = Array.isArray(e["@type"]) ? e["@type"].join(",") : String(e["@type"] ?? "");
    const place = venue ? ctx.placeBySlug.get(placeSlugForVenue(String(venue)) ?? "") : null;
    rows.push(mkEvent({
      slug,
      title: String(e.name ?? "").trim(),
      description: e.description ? String(e.description).replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim().slice(0, 600) : null,
      kind: inferKind(String(e.name ?? ""), atType, src.kind ?? "concert"),
      starts_at: start, ends_at: e.endDate ?? null,
      poster_url: img,
      ticket_url: evUrl || null,
      priceFromCents: priceNum != null && !isNaN(priceNum) && priceNum > 0 ? Math.round(priceNum * 100) : null,
      isFree: priceNum === 0,
      currency: offers?.priceCurrency ?? "UAH",
      lineup: [],
      venue_name: venue ? String(venue).trim() : (src.venue_name ?? null),
      place, cityId: ctx.cityId, source: "jsonld",
    }));
  }
  return rows;
}

// ---- shared row builder ----
// Known Kyiv nightclubs / party venues — events here are nightlife even when a
// ticketing feed tags them "concert". Underground venues + the venues that
// actually appear in the RA / Concert.ua Kyiv feeds.
const CLUB_VENUES = /closer|k41|∄|\botel|mezzanine|keller|\bmodule\b|модуль|plivka|плівка|hvlv|хвлв|\batlas\b|атлас|caribbean|кариб|confidance|конфіданс|some people|rhythm|брукст|brukxt|sentrum|сентрум|bel ?etage|indigo|індіго|skvot|сквот|closer|\bnag\b|нічний клуб|night ?club/i;
function clubify(kind: string, venue: string | null): string {
  if (!venue) return kind;
  if (["concert", "music", "party", "other"].includes(kind) && CLUB_VENUES.test(venue)) return "club";
  return kind;
}

type Ctx = { cityId: string | null; placeBySlug: Map<string, any>; cityByKey: Map<string, string>; pages: number };
function mkEvent(o: any): EventRow {
  const place = o.place ?? null;
  return {
    slug: o.slug,
    title: o.title,
    description: o.description ?? null,
    kind: clubify(o.kind, o.venue_name ?? null),
    city_id: o.cityId,
    place_id: place?.id ?? null,
    starts_at: o.starts_at,
    ends_at: o.ends_at ?? null,
    poster_url: o.poster_url ?? null,
    ticket_url: o.ticket_url ?? null,
    price_from_cents: o.priceFromCents ?? null,
    currency: o.currency ?? "UAH",
    is_free: o.isFree ?? false,
    lineup: o.lineup ?? [],
    venue_name: o.venue_name ?? null,
    venue_lat: place?.approx_lat ?? o.venueLat ?? null,
    venue_lng: place?.approx_lng ?? o.venueLng ?? null,
    featured: false,
    status: "published",
    source: o.source,
    updated_at: new Date().toISOString(),
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const db = createClient(SUPABASE_URL, SERVICE_ROLE);

  const provided = req.headers.get("x-sync-secret") ?? "";
  let authed = (SYNC_SECRET && provided === SYNC_SECRET) || (provided !== "" && provided === SERVICE_ROLE);
  if (!authed && provided !== "") {
    const { data: ok } = await db.rpc("check_sync_secret", { p: provided });
    authed = ok === true;
  }
  if (!authed) return json({ error: "unauthorized" }, 401);

  const opts = await req.json().catch(() => ({}));
  const pages = Math.min(Math.max(Number(opts.pages ?? 3), 1), 8);

  const { data: cities } = await db.from("cities").select("id, slug, title");
  const cityIdBySlug = new Map((cities ?? []).map((c: any) => [c.slug, c.id]));
  // Resolve a city by its slug OR its English title (e.g. RA's venue area "Lviv").
  const cityByKey = new Map<string, string>();
  for (const c of cities ?? []) {
    cityByKey.set(String(c.slug).toLowerCase(), c.id);
    if (c.title) cityByKey.set(String(c.title).toLowerCase(), c.id);
  }
  const odesaId = cityByKey.get("odesa");
  if (odesaId) cityByKey.set("odessa", odesaId);   // RA sometimes spells it Odessa
  const { data: places } = await db.from("places").select("id, slug, approx_lat, approx_lng");
  const placeBySlug = new Map((places ?? []).map((p: any) => [p.slug, p]));

  const { data: sources } = await db.from("event_sources").select("*").eq("enabled", true);
  if (!sources || sources.length === 0) return json({ ok: true, sources: 0, upserted: 0, note: "no enabled sources" });

  const all: EventRow[] = [];
  const perSource: any[] = [];
  for (const src of sources) {
    const ctx: Ctx = { cityId: cityIdBySlug.get(src.city_slug) ?? null, placeBySlug, cityByKey, pages };
    let rows: EventRow[] = [];
    let err: string | null = null;
    try {
      if (src.provider === "resident_advisor") rows = await fromResidentAdvisor(src, ctx);
      else if (src.provider === "ics") rows = await fromICS(src, ctx);
      else if (src.provider === "molodyy") rows = await fromMolodyy(src, ctx);
      else if (src.provider === "jsonld") rows = await fromJsonLd(src, ctx);
      else err = `unknown provider ${src.provider}`;
    } catch (e) { err = String(e); }
    // De-dupe within a source by slug.
    const bySlug = new Map(rows.map((r) => [r.slug as string, r]));
    const deduped = [...bySlug.values()];
    all.push(...deduped);
    const result = { count: deduped.length, error: err };
    perSource.push({ label: src.label ?? src.provider, ...result });
    await db.from("event_sources").update({ last_run_at: new Date().toISOString(), last_result: result }).eq("id", src.id);
  }

  // Global de-dupe across sources (slug wins first-seen).
  const bySlug = new Map(all.map((r) => [r.slug as string, r]));
  const rows = [...bySlug.values()];

  let upserted = 0, retired = 0;
  if (rows.length > 0) {
    const { error: upErr } = await db.from("events").upsert(rows, { onConflict: "slug" });
    if (upErr) return json({ error: "upsert_failed", detail: upErr.message, perSource }, 500);
    upserted = rows.length;
    const keep = rows.map((r) => r.slug as string);
    const { count } = await db.from("events").delete({ count: "exact" })
      .in("source", SYNCED_SOURCES)
      .not("slug", "in", `(${keep.join(",")})`);
    retired = count ?? 0;
  }

  let droppedSample = 0;
  if (opts.dropSample) {
    const { count } = await db.from("events").delete({ count: "exact" }).eq("source", "sample");
    droppedSample = count ?? 0;
  }

  return json({ ok: true, sources: sources.length, upserted, retired, droppedSample, perSource });
});

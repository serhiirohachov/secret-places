// ============================================================
// Secret Places — verify-purchase Edge Function
// Verifies a StoreKit 2 signed transaction (JWS) and grants the
// corresponding entitlement server-side. Handles BOTH product kinds:
//   • a place product (com.secretplaces.place.<slug>) → unlock one place
//   • a route product (com.secretplaces.route.<slug>) → unlock a bar crawl
//     (and, transitively, every place it contains)
// Entitlements are the ONLY way a client obtains exact locations, so this
// function is the trust boundary. Production verification uses Apple's
// official library when APPLE_VERIFY=strict + root certs are configured;
// otherwise it decodes + validates structurally so the flow is testable.
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APPLE_BUNDLE_ID = Deno.env.get("APPLE_BUNDLE_ID") ?? "com.secretplaces.app";
const APPLE_ENVIRONMENT = Deno.env.get("APPLE_ENVIRONMENT") ?? "Sandbox";
const STRICT = (Deno.env.get("APPLE_VERIFY") ?? "dev") === "strict";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
function b64urlToJson(seg: string): any {
  const b64 = seg.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(seg.length / 4) * 4, "=");
  return JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))));
}
function decodeTransaction(jws: string): any {
  const [h, p] = jws.split(".");
  if (!h || !p) throw new Error("malformed_jws");
  return b64urlToJson(p);
}
async function verifyStrict(jws: string): Promise<any> {
  const roots = (Deno.env.get("APPLE_ROOT_CERTS") ?? "").split(",").map((s) => s.trim()).filter(Boolean)
    .map((b64) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)));
  if (roots.length === 0) throw new Error("apple_root_certs_missing");
  const lib = await import("npm:@apple/app-store-server-library@1.4.0");
  const env = APPLE_ENVIRONMENT === "Production" ? lib.Environment.PRODUCTION : lib.Environment.SANDBOX;
  const verifier = new lib.SignedDataVerifier(roots, true, env, APPLE_BUNDLE_ID);
  return await verifier.verifyAndDecodeTransaction(jws);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401);

  const asUser = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await asUser.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "unauthorized" }, 401);
  const userId = userData.user.id;

  let body: { transactionJWS?: string; placeId?: string; routeSlug?: string };
  try { body = await req.json(); } catch { return json({ error: "bad_request" }, 400); }
  if (!body.transactionJWS) return json({ error: "missing_transaction" }, 400);

  let tx: any;
  try { tx = STRICT ? await verifyStrict(body.transactionJWS) : decodeTransaction(body.transactionJWS); }
  catch (e) { return json({ error: "verification_failed", detail: String(e) }, 400); }

  const productId: string | undefined = tx.productId;
  const originalTransactionId: string | undefined = tx.originalTransactionId ?? tx.transactionId;
  const transactionId: string | undefined = tx.transactionId;
  const bundleId: string | undefined = tx.bundleId ?? tx.appBundleId;
  if (!productId || !transactionId) return json({ error: "incomplete_transaction" }, 400);
  if (STRICT && bundleId && bundleId !== APPLE_BUNDLE_ID) return json({ error: "bundle_mismatch" }, 400);
  if (tx.revocationDate) return json({ error: "revoked" }, 400);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

  // 1) Place product?
  const { data: place } = await admin.from("places").select("id, product_id").eq("product_id", productId).maybeSingle();
  if (place) {
    const { error } = await admin.from("user_entitlements").upsert({
      user_id: userId, place_id: place.id, product_id: productId,
      transaction_id: transactionId, original_transaction_id: originalTransactionId,
      source: "app_store", revoked_at: null,
    }, { onConflict: "user_id,place_id,original_transaction_id" });
    if (error) return json({ error: "entitlement_error", detail: error.message }, 500);
    const { data: details } = await asUser.rpc("get_place_details", { p_place_id: place.id });
    return json({ unlocked: true, kind: "place", place_id: place.id, place: details });
  }

  // 2) Route product? (bar crawl — unlocks all its stops)
  const { data: route } = await admin.from("routes").select("id, slug, product_id").eq("product_id", productId).maybeSingle();
  if (route) {
    const { data: existing } = await admin.from("user_entitlements")
      .select("id").eq("user_id", userId).eq("route_id", route.id).maybeSingle();
    if (!existing) {
      const { error } = await admin.from("user_entitlements").insert({
        user_id: userId, route_id: route.id, product_id: productId,
        transaction_id: transactionId, original_transaction_id: originalTransactionId,
        source: "app_store", revoked_at: null,
      });
      if (error) return json({ error: "entitlement_error", detail: error.message }, 500);
    }
    const { data: details } = await asUser.rpc("get_route_details", { p_slug: route.slug });
    return json({ unlocked: true, kind: "route", route_id: route.id, route: details });
  }

  return json({ error: "unknown_product" }, 400);
});

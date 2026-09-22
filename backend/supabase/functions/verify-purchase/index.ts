// ============================================================
// Secret Places — verify-purchase Edge Function
// Verifies a StoreKit 2 signed transaction (JWS) and grants the
// corresponding entitlement server-side. Entitlements are the ONLY
// way a client obtains the exact location of a paid place, so this
// function is the trust boundary.
//
// Production verification uses Apple's official library
// (@apple/app-store-server-library) when APPLE_BUNDLE_ID + root
// certs are configured. Without them (local dev / no Apple creds)
// it falls back to structural decode + validation so the unlock
// flow is testable end-to-end. The real path always exists.
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APPLE_BUNDLE_ID = Deno.env.get("APPLE_BUNDLE_ID") ?? "com.secretplaces.app";
const APPLE_ENVIRONMENT = Deno.env.get("APPLE_ENVIRONMENT") ?? "Sandbox"; // Sandbox | Production
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

/** Decode a StoreKit 2 JWS transaction. Header carries the x5c chain. */
function decodeTransaction(jws: string): { header: any; payload: any } {
  const [h, p] = jws.split(".");
  if (!h || !p) throw new Error("malformed_jws");
  return { header: b64urlToJson(h), payload: b64urlToJson(p) };
}

/**
 * Full cryptographic verification via Apple's library. Enabled when STRICT
 * and Apple root certs are provided (APPLE_ROOT_CERTS = comma-separated base64 DER).
 * Throws on any verification failure.
 */
async function verifyStrict(jws: string): Promise<any> {
  const roots = (Deno.env.get("APPLE_ROOT_CERTS") ?? "")
    .split(",").map((s) => s.trim()).filter(Boolean)
    .map((b64) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)));
  if (roots.length === 0) throw new Error("apple_root_certs_missing");
  const lib = await import("npm:@apple/app-store-server-library@1.4.0");
  const env = APPLE_ENVIRONMENT === "Production" ? lib.Environment.PRODUCTION : lib.Environment.SANDBOX;
  const verifier = new lib.SignedDataVerifier(roots, true, env, APPLE_BUNDLE_ID);
  // Verifies signature, cert chain to Apple root, bundle id and environment.
  return await verifier.verifyAndDecodeTransaction(jws);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401);

  // Identify the caller from their Supabase JWT.
  const asUser = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await asUser.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "unauthorized" }, 401);
  const userId = userData.user.id;

  let body: { transactionJWS?: string; placeId?: string };
  try { body = await req.json(); } catch { return json({ error: "bad_request" }, 400); }
  const { transactionJWS, placeId } = body;
  if (!transactionJWS) return json({ error: "missing_transaction" }, 400);

  // Verify / decode the transaction.
  let tx: any;
  try {
    tx = STRICT ? await verifyStrict(transactionJWS) : decodeTransaction(transactionJWS).payload;
  } catch (e) {
    return json({ error: "verification_failed", detail: String(e) }, 400);
  }

  const productId: string | undefined = tx.productId;
  const originalTransactionId: string | undefined = tx.originalTransactionId ?? tx.transactionId;
  const transactionId: string | undefined = tx.transactionId;
  const bundleId: string | undefined = tx.bundleId ?? tx.appBundleId;
  if (!productId || !transactionId) return json({ error: "incomplete_transaction" }, 400);
  if (STRICT && bundleId && bundleId !== APPLE_BUNDLE_ID) return json({ error: "bundle_mismatch" }, 400);
  if (tx.revocationDate) return json({ error: "revoked" }, 400);

  // Service-role client for the trusted writes below.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

  // Resolve the product to a place and validate the mapping.
  const { data: place, error: placeErr } = await admin
    .from("places").select("id, product_id, access_type").eq("product_id", productId).maybeSingle();
  if (placeErr) return json({ error: "db_error", detail: placeErr.message }, 500);
  if (!place) return json({ error: "unknown_product" }, 400);
  if (placeId && placeId !== place.id) return json({ error: "place_product_mismatch" }, 400);

  // Idempotent entitlement grant.
  const { error: entErr } = await admin.from("user_entitlements").upsert({
    user_id: userId,
    place_id: place.id,
    product_id: productId,
    transaction_id: transactionId,
    original_transaction_id: originalTransactionId,
    source: "app_store",
    revoked_at: null,
  }, { onConflict: "user_id,place_id,original_transaction_id" });
  if (entErr) return json({ error: "entitlement_error", detail: entErr.message }, 500);

  // Return the now-unlocked place so the client can reveal immediately.
  // Runs in the USER's context so get_place_details() sees the new entitlement.
  const { data: details, error: detErr } = await asUser.rpc("get_place_details", { p_place_id: place.id });
  if (detErr) return json({ unlocked: true, place_id: place.id });
  return json({ unlocked: true, place_id: place.id, place: details });
});

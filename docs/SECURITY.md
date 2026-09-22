# Secret Places — security model

## Threat: a non-entitled user obtaining a paid place's exact location

The critical acceptance criterion: a non-entitled user must not retrieve the exact
latitude/longitude or identifying data of a paid place via API request, direct Supabase query,
inspecting normal responses, switching place IDs, or manipulating client state.

## Controls

1. **Base `places` table — column-level privileges + RLS.**
   `anon`/`authenticated` are granted `SELECT` on teaser columns only. Sensitive columns
   (`exact_lat`, `exact_lng`, `exact_address`, `business_name`, `full_title`, `full_description`,
   `walking_instructions`, `parking_info`, `insider_tips`, `photo_spot`, `website`, `booking_url`,
   `apple_maps_url`, `google_maps_url`, `opening_hours`, `geog`, `internal_name`) are **never
   granted**. RLS restricts rows to `status = 'published'`. Any query selecting a sensitive
   column — including `select=*` — fails with `permission denied`.

2. **`places_public` view** (security_invoker) exposes teaser columns only, with `approx_lat/lng`
   (rounded to ~1 km). Used by all lists, search, map and detail teasers.

3. **`get_place_details(uuid)`** (SECURITY DEFINER) is the sole path to full data. It computes
   `is_place_unlocked(place, auth.uid())` = free/promo-active **or** a non-revoked entitlement,
   and returns sensitive fields **only** when unlocked; otherwise the teaser with `locked: true`.

4. **Entitlements are server-written only.** `user_entitlements` has an RLS `SELECT`-own policy
   and **no client insert/update grant**. Rows are written exclusively by the `verify-purchase`
   Edge Function (service role) after verifying the StoreKit 2 JWS.

## Verified on the live backend (anon key)

| Probe | Result |
|-------|--------|
| `GET /rest/v1/places?select=exact_lat,exact_lng,business_name` | `permission denied` |
| `GET /rest/v1/places?id=eq.<paid>&select=*` (switching IDs) | `permission denied` |
| `GET /rest/v1/places_public?select=exact_lat` | `column ... does not exist` |
| `GET /rest/v1/places_public?id=eq.<paid>&select=approx_lat,approx_lng` | approx only (50.45, 30.52) |
| `POST /rpc/get_place_details` (paid, not entitled) | `locked: true`, **no** exact/sensitive keys |
| `POST /rpc/get_place_details` (free) | full data incl. `exact_lat`, `business_name` |
| after inserting an entitlement → `is_place_unlocked(paid, user)` | `true` (reveals full data) |
| set place to `hidden` | disappears from `places_public` and lists |

The Supabase security advisor reports **no ERROR-level** findings (definer-view and
missing-RLS issues resolved). The two remaining WARN entries are the intentionally-public
`get_place_details` and `nearby_places` RPCs, which are safe by design.

## Client-side

The iOS app fetches teasers from `places_public` and full data only from `get_place_details`.
The `DiskCache` persists only **unlocked/free** place details for offline use — never locked
sensitive data. Unit tests (`PrivacyAndEntitlementTests`, `DecodingTests`) assert that a locked
`PlaceDetails` carries no `exactLat`/`businessName`/`fullDescription`, mirroring the server.

## Other privacy

- User-owned tables (`profiles`, `user_saved_places`, `user_place_status`, `ratings`, `reports`,
  `submissions`, `notification_preferences`, `user_entitlements`) are RLS-scoped to `auth.uid()`.
- `ratings` insert requires `can_rate_place` (unlocked or visited).
- Account deletion (`delete-account` Edge Function) removes the auth user; all user rows cascade.
- Analytics carries no precise GPS; location permission is optional and the app works without it.

-- ============================================================
-- Secret Places — remove implicit PUBLIC execute from internal/trigger helpers.
-- get_place_details + nearby_places remain intentionally public (safe by design).
-- ============================================================
revoke execute on function public.is_place_unlocked(uuid, uuid) from public;
revoke execute on function public.recompute_place_rating(uuid) from public;
revoke execute on function public.ratings_after_change() from public;
revoke execute on function public.handle_new_user() from public;
revoke execute on function public.places_sync_geog() from public;
revoke execute on function public.can_rate_place(uuid) from public, anon;
grant execute on function public.can_rate_place(uuid) to authenticated;  -- needed by RLS on ratings

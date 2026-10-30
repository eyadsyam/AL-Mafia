-- The owner-notice trigger functions are security definer: never part of the
-- client surface (server_surface_test). Triggers still call them.
revoke all on function public.push_owner_on_order() from public, anon, authenticated;
revoke all on function public.push_owner_on_play() from public, anon, authenticated;
revoke all on function public.push_owner_on_report() from public, anon, authenticated;
revoke all on function public.push_owner_on_tester() from public, anon, authenticated;

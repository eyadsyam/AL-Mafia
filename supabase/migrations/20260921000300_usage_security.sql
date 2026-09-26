-- Trigger functions execute through their triggers; clients never call them.
revoke all on function public.capture_room_usage() from public,anon,authenticated;
revoke all on function public.capture_room_usage_after() from public,anon,authenticated;


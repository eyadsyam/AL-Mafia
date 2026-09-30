-- The minimum-build row is public config: two integers and nothing else.
--
-- The update gate reads it on every launch, before (and whether or not) the
-- player has any session. Asking it with a signed-in client meant creating an
-- anonymous user on every fresh install and every web visit just to read a
-- number, which burns the per-IP anonymous sign-in limit on shared mobile NAT
-- and lets bots fill auth.users. The bare publishable key (role `anon`) may now
-- read this one table, select only; nothing else about `anon` changes, and the
-- economy's private configuration stays closed.

grant select on public.app_config to anon;
drop policy if exists app_config_public_read on public.app_config;
create policy app_config_public_read on public.app_config
  for select to anon using (true);

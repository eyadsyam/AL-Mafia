-- Four Dossiers: a remote kill switch for the entirely local, flavour-only
-- character bond ledger. No bond data is sent to or stored by the server.

alter table public.economy_config
  add column if not exists character_bonds_enabled boolean not null default false;

alter function public.economy_capabilities(uuid)
  rename to economy_capabilities_pre_character_bonds;

create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer
set search_path=public,pg_temp as $$
declare cfg public.economy_config; base jsonb;
begin
  select * into cfg from public.economy_config limit 1;
  base := public.economy_capabilities_pre_character_bonds(p_user);
  return base || jsonb_build_object(
    'fun', coalesce(base->'fun', '{}'::jsonb) || jsonb_build_object(
      'characterBonds', coalesce(cfg.character_bonds_enabled, false)));
end $$;

revoke all on function public.economy_capabilities_pre_character_bonds(uuid)
  from public, anon, authenticated;
grant execute on function public.economy_capabilities_pre_character_bonds(uuid)
  to service_role;
revoke all on function public.economy_capabilities(uuid)
  from public, anon, authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;

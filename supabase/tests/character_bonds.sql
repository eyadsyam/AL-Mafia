-- Four Dossiers capability contract. Rolled back by the SQL harness.
begin;
do $$
declare u uuid:=gen_random_uuid(); caps jsonb;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u,null,null,true);

  caps := public.economy_capabilities(u);
  assert caps ? 'fun' and caps->'fun' ? 'characterBonds', caps::text;
  assert not (caps->'fun'->>'characterBonds')::boolean,
    'character bonds must deploy off';

  update public.economy_config set character_bonds_enabled=true;
  caps := public.economy_capabilities(u);
  assert (caps->'fun'->>'characterBonds')::boolean, caps::text;
  assert caps->'fun' ? 'awards' and caps->'fun' ? 'reactions'
    and caps->'fun' ? 'founder', 'earlier fun flags lost: '||caps::text;

  assert not has_function_privilege(
    'authenticated',
    'public.economy_capabilities_pre_character_bonds(uuid)',
    'execute');
end $$;
rollback;

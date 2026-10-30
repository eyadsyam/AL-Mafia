-- Contract for 20261030000100_owner_review. Rolled back.
begin;

-- The harness's auth.users is minimal; the hosted one has this column.
alter table auth.users add column if not exists last_sign_in_at timestamptz;

do $$
declare admin uuid := gen_random_uuid(); stranger uuid := gen_random_uuid(); r jsonb;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(admin,'owner@example.com',now(),false),(stranger,null,null,true);
  insert into public.commerce_admins(user_id,note) values(admin,'owner');

  -- Nobody else reads it.
  begin
    perform public.owner_review(stranger,'overview','');
    raise exception 'stranger read the review';
  exception when others then
    assert sqlerrm='NOT_ADMIN', sqlerrm;
  end;

  r := public.owner_review(admin,'overview','');
  assert (r->>'accountsTotal')::int >= 2, r::text;
  assert r ? 'pendingItems', r::text;

  for r in select public.owner_review(admin,a,'') from unnest(array['players','rooms','store','push','testers']) a loop
    assert jsonb_typeof(r->'items')='array', r::text;
  end loop;
  r := public.owner_review(admin,'config','');
  assert r ? 'app' and r ? 'economy', r::text;

  begin
    perform public.owner_review(admin,'everything','');
    raise exception 'unknown action answered';
  exception when others then
    assert sqlerrm='BAD_REQUEST', sqlerrm;
  end;

  assert not has_function_privilege('authenticated','public.owner_review(uuid,text,text)','execute');
end $$;

rollback;

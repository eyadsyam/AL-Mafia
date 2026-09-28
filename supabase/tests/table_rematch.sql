-- Contract for 20260928000200_table_rematch. Rolled back.
begin;
do $$
declare host uuid := gen_random_uuid(); guest uuid := gen_random_uuid();
  old jsonb; r uuid; first jsonb; second jsonb; carried jsonb;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(host,null,null,true),(guest,null,null,true);
  old := public.create_room_atomic('RMTCH2',host,'Host','male',42,
    jsonb_build_object('settings',jsonb_build_object('playerCount',6),
      'visibility','public','title','Friday'));
  r := (old->>'roomId')::uuid;
  select x.settings into carried from public.rooms x where x.id=r;

  -- A live room cannot be rematched.
  begin
    perform public.rematch_room_atomic(r,host,'Host','male','RMTCH3',7);
    assert false, 'rematched a live room';
  exception when others then assert sqlerrm='PHASE_CLOSED', 'live: '||sqlerrm; end;

  update public.rooms set status='finished', ended_at=now() where id=r;
  update public.room_state set phase='result',
    public_data=jsonb_build_object('outcome','town') where room_id=r;

  -- Only the host opens the next table.
  begin
    perform public.rematch_room_atomic(r,guest,'Guest','female','RMTCH4',7);
    assert false, 'a guest rematched';
  exception when others then assert sqlerrm='NOT_HOST', 'guest: '||sqlerrm; end;

  first := public.rematch_room_atomic(r,host,'Host','male','RMTCH5',7);
  assert first->>'code'='RMTCH5', first::text;
  assert (select settings from public.rooms where id=(first->>'roomId')::uuid)=carried,
    'settings not carried over';
  assert (select visibility from public.rooms where id=(first->>'roomId')::uuid)='public';
  assert (select public_data->'rematch'->>'code' from public.room_state where room_id=r)='RMTCH5',
    'old room does not announce the rematch';
  assert (select public_data->>'outcome' from public.room_state where room_id=r)='town',
    'the finished result was changed';

  -- A second tap returns the same table instead of opening another.
  second := public.rematch_room_atomic(r,host,'Host','male','RMTCH6',8);
  assert second->>'roomId'=first->>'roomId', second::text;
  assert not exists(select 1 from public.rooms where code='RMTCH6'), 'a second room was opened';

  assert not has_function_privilege('authenticated',
    'public.rematch_room_atomic(uuid,uuid,text,text,text,bigint)','execute');
end $$;
rollback;

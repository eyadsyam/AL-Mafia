begin;
do $$
declare r uuid:=gen_random_uuid(); a uuid:=gen_random_uuid();
  b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); d uuid:=gen_random_uuid();
  out jsonb;
begin
  insert into public.rooms(id,code,host_id,match_seed,status)
    values(r,'RDYVTE',a,3,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive) values
    (r,a,'A',0,'mafia',true),(r,b,'B',1,'doctor',true),
    (r,c,'C',2,'citizen',true),(r,d,'D',3,'citizen',false);
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(r,'discuss',2,'{"readyToVote":{"number":1,"seats":[0,1,2]}}');

  -- A set from an earlier day is not carried into this one.
  out := public.mark_ready_to_vote(r,a,true);
  if out->'seats' <> '[0]'::jsonb then raise exception 'stale set carried: %', out; end if;
  if (out->>'everyone')::boolean then raise exception 'one of three is not everyone'; end if;
  if (out->>'living')::int <> 3 then raise exception 'dead seat counted as living'; end if;

  -- Idempotent, and a change of mind is honoured.
  out := public.mark_ready_to_vote(r,a,true);
  if out->'seats' <> '[0]'::jsonb then raise exception 'double ready duplicated: %', out; end if;
  out := public.mark_ready_to_vote(r,b,true);
  out := public.mark_ready_to_vote(r,a,false);
  if out->'seats' <> '[1]'::jsonb then raise exception 'un-ready ignored: %', out; end if;

  -- The dead do not get a say.
  begin
    perform public.mark_ready_to_vote(r,d,true);
    raise exception 'dead player accepted';
  exception when others then
    if sqlerrm<>'NOT_ALIVE' then raise; end if;
  end;

  -- Everyone living → everyone.
  out := public.mark_ready_to_vote(r,a,true);
  out := public.mark_ready_to_vote(r,c,true);
  if not (out->>'everyone')::boolean then raise exception 'all three ready not everyone: %', out; end if;
  if (select public_data #> '{readyToVote,seats}' from public.room_state where room_id=r)
      <> '[0,1,2]'::jsonb then
    raise exception 'public record wrong';
  end if;

  -- A seat that dies after saying ready stops counting.
  update public.room_players set alive=false where room_id=r and user_id=c;
  out := public.mark_ready_to_vote(r,a,true);
  if out->'seats' <> '[0,1]'::jsonb or (out->>'living')::int <> 2 then
    raise exception 'dead ready seat still counted: %', out;
  end if;

  -- Only during the discussion.
  update public.room_state set phase='vote' where room_id=r;
  begin
    perform public.mark_ready_to_vote(r,a,true);
    raise exception 'ready accepted outside the discussion';
  exception when others then
    if sqlerrm<>'PHASE_CLOSED' then raise; end if;
  end;

  -- Not callable by clients.
  if has_function_privilege('authenticated', 'public.mark_ready_to_vote(uuid,uuid,boolean)', 'execute') then
    raise exception 'clients may call mark_ready_to_vote';
  end if;
end $$;
rollback;

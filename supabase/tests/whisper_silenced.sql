begin;
do $$
declare r uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'WHSNCE',a,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role) values
    (r,a,'A',0,'citizen'),(r,b,'B',1,'citizen');
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(r,'discuss',2,'{"morning":{"silencedSeat":0}}'::jsonb);
  begin
    perform public.commit_whisper(r,a,1,2,'it was him');
    raise exception 'a silenced player whispered';
  exception when raise_exception then if sqlerrm<>'SILENCED' then raise; end if; end;
  assert not exists(select 1 from public.whisper_meta where room_id=r),
    'a refused whisper left an edge';
  -- The other player is not silenced and may whisper, even to the silenced.
  assert public.commit_whisper(r,b,0,2,'are you ok') is not null,
    'an unsilenced whisper was refused';
  -- Tomorrow's morning names nobody: the silence is over.
  update public.room_state set phase_number=3, public_data='{"morning":{}}'::jsonb where room_id=r;
  assert public.commit_whisper(r,a,1,3,'now I can') is not null,
    'yesterday''s silence still held';
end $$;
rollback;
select 'PASS whisper silenced: refused for the day only' as result;

-- Contract for 20260930000600_founder_window. Rolled back by the harness.
begin;
do $$
declare u uuid:=gen_random_uuid(); rid uuid:=gen_random_uuid(); first timestamptz;
begin
  insert into auth.users(id,email) values(u,u::text||'@founder.test');
  -- Off: nothing opens.
  update public.economy_config set founder_enabled=false,founder_window_start=null;
  assert public.founder_window_open() is null,'flag off opens nothing';
  assert (select founder_window_start from public.economy_config) is null;

  -- On with no window: the badge was unreachable before the window opens.
  update public.economy_config set founder_enabled=true;
  assert not public.fun_on('founder'),'no window, no founder';
  first:=public.founder_window_open();
  assert first is not null,'window opened';
  assert public.fun_on('founder'),'founder live once the window is open';
  -- Idempotent: a second run leaves the window where it was.
  assert public.founder_window_open() is null,'second run opens nothing';
  assert (select founder_window_start from public.economy_config)=first,'window unchanged';

  -- A match finished inside the window grants the badge, once.
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(rid,'FNDR22',u,'finished',1,first,first+interval '20 minutes');
  insert into public.room_players(room_id,user_id,seat,name,role)
    values(rid,u,0,'A','citizen');
  insert into public.room_state(room_id,phase,public_data)
    values(rid,'result','{"outcome":"town"}');
  assert public.fun_grant_founder(u),'badge granted';
  assert (select count(*) from public.player_badges where user_id=u and badge='founder')=1;

  -- A window that was set long ago (over) is never reopened.
  update public.economy_config set founder_window_start=now()-interval '400 days';
  assert public.founder_window_open() is null,'an old window is kept';
end $$;
rollback;

-- Contract for 20260930000100_invites_push. Rolled back.
begin;

create function pg_temp.ip_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(u,null,null,true);
  return u;
end $$;

-- A finished room where every listed user held a role.
create function pg_temp.ip_table(p_users uuid[], p_code text) returns uuid language plpgsql as $$
declare r uuid; i int;
begin
  r := (public.create_room_atomic(p_code,p_users[1],'U1','male',1,'{}'::jsonb)->>'roomId')::uuid;
  for i in 2..array_length(p_users,1) loop
    insert into public.room_players(room_id,user_id,name,gender,seat)
      values(r,p_users[i],'U'||i,'female',i-1);
  end loop;
  update public.room_players set role='citizen' where room_id=r;
  update public.rooms set status='finished', ended_at=now() where id=r;
  return r;
end $$;

create function pg_temp.ip_handles(p jsonb) returns text[] language sql as $$
  select coalesce(array_agg(r->>'handle' order by n),'{}') from jsonb_array_elements(p->'rows')
    with ordinality as t(r,n)
$$;

-- ── Handles: normalisation and uniqueness ───────────────────────────────────
do $$
declare a uuid := pg_temp.ip_user(); b uuid := pg_temp.ip_user(); c uuid := pg_temp.ip_user();
  me jsonb;
begin
  -- Off: nothing answers.
  begin perform public.directory_hello(a,'إياد','male','EG','ar'); assert false, 'hello while off';
  exception when others then assert sqlerrm='FEATURE_OFF', sqlerrm; end;
  assert (public.economy_capabilities(a)->'social'->>'directory')::boolean = false;
  assert (public.economy_capabilities(a)->'social'->>'pushInvites')::boolean = false;
  update public.economy_config set friends_enabled=true;
  assert (public.economy_capabilities(a)->'social'->>'directory')::boolean;
  assert (public.economy_capabilities(a)->'social'->>'pushInvites')::boolean = false, 'push is off by default';

  -- Arabic variants, taa marbuta, tatweel, diacritics, case.
  assert public.directory_norm('أحمـــد') = 'احمد';
  assert public.directory_norm('إيـاد') = public.directory_norm('ايّاد');
  assert public.directory_norm('آمنة') = 'امنه';
  assert public.directory_norm('مصطفى') = 'مصطفي';
  assert public.directory_norm('Eyad_X') = 'eyad_x';
  assert public.directory_name_norm('  Salma   Ali ') = 'salma ali';

  me := public.directory_hello(a,'إياد','male','EG','ar');
  assert me->>'handle' = 'إياد', me::text;
  -- Same name, normalised the same: the second gets a suffix.
  me := public.directory_hello(b,'اياد','male','EG','ar');
  assert me->>'handle' = 'اياد_2', me::text;
  -- A refused name cannot register; a name too short for a handle gets «player».
  begin perform public.directory_hello(c,'Mafia Master','female','sa','EN'); assert false, 'refused name';
  exception when others then assert sqlerrm='NAME_NOT_ALLOWED', sqlerrm; end;
  me := public.directory_hello(c,'Al','female','sa','EN');
  assert me->>'handle' = 'player', me::text;
  assert (select country from public.player_directory where user_id=c) = 'SA';
  assert (select lang from public.player_directory where user_id=c) = 'en';
  -- A later hello refreshes the name, not the handle.
  perform public.directory_hello(c,'Salma Ali','female',null,null);
  assert public.directory_me(c)->>'handle' = 'player';
  assert (select display_name from public.player_directory where user_id=c) = 'Salma Ali';
  assert (select country from public.player_directory where user_id=c) = 'SA', 'no tz keeps the country';

  -- Changing a handle: shape, name rules, taken (normalised), rate limit.
  begin perform public.directory_set_handle(c,'a b'); assert false, 'space accepted';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  begin perform public.directory_set_handle(c,'admin'); assert false, 'refused name accepted';
  exception when others then assert sqlerrm='NAME_NOT_ALLOWED', sqlerrm; end;
  begin perform public.directory_set_handle(c,'أياد'); assert false, 'taken (normalised) accepted';
  exception when others then assert sqlerrm='HANDLE_TAKEN', sqlerrm; end;
  me := public.directory_set_handle(c,'salma_ali');
  assert me->>'handle' = 'salma_ali' and me->>'handleChangeAt' is not null, me::text;
  begin perform public.directory_set_handle(c,'salma2'); assert false, 'changed twice in a week';
  exception when others then assert sqlerrm='RATE_LIMITED', sqlerrm; end;
  -- Unchanged is not a change.
  perform public.directory_set_handle(c,'salma_ali');
  update public.player_directory set handle_changed_at=now()-interval '8 days' where user_id=c;
  assert public.directory_set_handle(c,'salma2')->>'handle' = 'salma2';

  assert not has_function_privilege('authenticated','public.directory_search(uuid,text,int)','execute');
  assert not has_function_privilege('anon','public.directory_hello(uuid,text,text,text,text)','execute');
  assert not has_table_privilege('authenticated','public.push_tokens','select');
  assert not has_table_privilege('authenticated','public.player_directory','select');
end $$;

-- ── Search excludes blocked, hidden and restricted; rows are public only ────
do $$
declare me uuid := pg_temp.ip_user(); x uuid := pg_temp.ip_user(); y uuid := pg_temp.ip_user();
  z uuid := pg_temp.ip_user(); w uuid := pg_temp.ip_user(); s jsonb; i int;
begin
  update public.economy_config set friends_enabled=true;
  perform public.directory_hello(me,'Karim','male','EG','ar');
  perform public.directory_hello(x,'Nour Hassan','female','EG','ar');
  perform public.directory_hello(y,'نورة','female','EG','ar');
  perform public.directory_hello(z,'Noura','female','EG','ar');
  perform public.directory_hello(w,'Nour_w','female','EG','ar');
  insert into public.player_inventory(user_id,item_code) values(x,'frame_gilded');
  insert into public.player_equipment(user_id,slot,item_code) values(x,'frame','frame_gilded');

  s := public.directory_search(me,'nour',0);
  assert pg_temp.ip_handles(s) @> array['Nour_Hassan','Noura','Nour_w'], s::text;
  -- Row shape: public identity only.
  assert (select every(r ?& array['handle','name','gender','level','state','frame','plate','friend']
      and not r ? 'id' and not r ? 'userId' and not r ? 'code')
    from jsonb_array_elements(s->'rows') r), s::text;
  assert (select r->>'frame' from jsonb_array_elements(s->'rows') r where r->>'handle'='Nour_Hassan')
    = 'frame_gilded', s::text;
  -- Arabic normalised match, second word of a name, underscore is literal.
  assert pg_temp.ip_handles(public.directory_search(me,'نوره',0)) = array['نورة'];
  assert pg_temp.ip_handles(public.directory_search(me,'hass',0)) = array['Nour_Hassan'];
  assert pg_temp.ip_handles(public.directory_search(me,'nour_',0)) @> array['Nour_w'];
  assert not pg_temp.ip_handles(public.directory_search(me,'nour_',0)) @> array['Noura'];
  -- Too short: nothing.
  assert jsonb_array_length(public.directory_search(me,'n',0)->'rows') = 0;

  -- Hidden, blocked either way, restricted: gone.
  perform public.directory_prefs(z,false,null);
  insert into public.player_blocks(blocker_id,blocked_id) values(w,me);
  insert into public.safety_restrictions(user_id,kind) values(x,'online');
  s := public.directory_search(me,'nour',0);
  assert pg_temp.ip_handles(s) = '{}', s::text;
  assert pg_temp.ip_handles(public.directory_search(me,'نور',0)) = array['نورة'];
  -- The blocked side cannot see the blocker either.
  assert not pg_temp.ip_handles(public.directory_search(w,'kar',0)) @> array['Karim'];
  -- Never yourself.
  assert pg_temp.ip_handles(public.directory_search(me,'karim',0)) = '{}';

  -- Paging: 20 per page, `more`.
  for i in 1..23 loop
    perform public.directory_hello(pg_temp.ip_user(),'Page'||i,'male','EG','ar');
  end loop;
  update public.economy_config set directory_queries_per_minute=100;
  s := public.directory_search(me,'page',0);
  assert jsonb_array_length(s->'rows')=20 and (s->>'more')::boolean, s::text;
  s := public.directory_search(me,'page',1);
  assert jsonb_array_length(s->'rows')=3 and not (s->>'more')::boolean, s::text;

  -- Per-user rate limit.
  update public.economy_config set directory_queries_per_minute=1;
  delete from public.directory_queries where user_id=me;
  perform public.directory_search(me,'page',0);
  begin perform public.directory_search(me,'page',0); assert false, 'not rate limited';
  exception when others then assert sqlerrm='RATE_LIMITED', sqlerrm; end;
  update public.economy_config set directory_queries_per_minute=20;
end $$;

-- ── Discover: country, social, online, level — in that order ────────────────
do $$
declare me uuid := pg_temp.ip_user(); mate uuid := pg_temp.ip_user(); shella uuid := pg_temp.ip_user();
  far uuid := pg_temp.ip_user(); onl uuid := pg_temp.ip_user(); lvl uuid := pg_temp.ip_user();
  plain uuid := pg_temp.ip_user(); gone uuid := pg_temp.ip_user(); s jsonb; h text[];
begin
  update public.economy_config set friends_enabled=true, directory_queries_per_minute=100;
  delete from public.player_directory;  -- only this block's players
  perform public.directory_hello(me,'Me','male','EG','ar');
  perform public.directory_hello(mate,'Mate','male','EG','ar');
  perform public.directory_hello(shella,'Shella','male','EG','ar');
  perform public.directory_hello(far,'Far','male','SA','ar');
  perform public.directory_hello(onl,'Onl','male','EG','ar');
  perform public.directory_hello(lvl,'Lvl','male','EG','ar');
  perform public.directory_hello(plain,'Plain','male','EG','ar');
  perform public.directory_hello(gone,'Gone','male','EG','ar');
  -- Played once with mate; twice with shella (a «شلة»); far played too, but
  -- is in another country.
  perform pg_temp.ip_table(array[me,mate,far], 'DSCA22');
  perform pg_temp.ip_table(array[me,shella], 'DSCB22');
  perform pg_temp.ip_table(array[me,shella], 'DSCC22');
  -- Seen now: onl. Everyone else was last seen an hour ago.
  update public.player_directory set last_seen_at=now()-interval '1 hour'
   where user_id in (me,mate,shella,far,lvl,plain);
  update public.player_directory set last_seen_at=now()-interval '61 days' where user_id=gone;
  -- Levels: me and lvl high, plain at 1.
  insert into public.council_xp_events(user_id,source_key,xp,week) values
    (me,'t:me',50000,'2026-W39'), (lvl,'t:lvl',50000,'2026-W39');

  s := public.directory_discover(me,null,0);
  h := pg_temp.ip_handles(s);
  assert h = array['Shella','Mate','Onl','Lvl','Plain','Far'], h::text;
  assert (s->'rows'->2->>'state') = 'online', s::text;
  assert not h @> array['Gone'], 'not seen for 60 days';
  assert not (s::text ~ '[0-9a-f]{8}-[0-9a-f]{4}-'), 'a user id left the server';

  assert pg_temp.ip_handles(public.directory_discover(me,'near',0)) = array['Shella','Mate','Onl','Lvl','Plain'];
  assert pg_temp.ip_handles(public.directory_discover(me,'online',0)) = array['Onl'];
  assert pg_temp.ip_handles(public.directory_discover(me,'played',0)) = array['Shella','Mate','Far'];
  assert pg_temp.ip_handles(public.directory_discover(me,'level',0)) = array['Lvl'];
  begin perform public.directory_discover(me,'coords',0); assert false, 'unknown filter';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;

  -- Blocked and restricted players never appear.
  insert into public.player_blocks(blocker_id,blocked_id) values(me,shella);
  insert into public.safety_restrictions(user_id,kind) values(mate,'online');
  h := pg_temp.ip_handles(public.directory_discover(me,null,0));
  assert not h && array['Shella','Mate'], h::text;
  -- A restricted caller cannot look at all.
  insert into public.safety_restrictions(user_id,kind) values(me,'online');
  begin perform public.directory_discover(me,null,0); assert false, 'restricted caller';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
end $$;

-- ── Invites to strangers: caps, mute, block, expiry, push targets ───────────
do $$
declare host uuid := pg_temp.ip_user(); t uuid := pg_temp.ip_user(); hid uuid := pg_temp.ip_user();
  s2 uuid := pg_temp.ip_user(); lobby uuid; lobby2 uuid; r jsonb; inv uuid; box jsonb; i int;
  someone uuid;
begin
  update public.economy_config set friends_enabled=true;
  perform public.directory_hello(host,'Eyad','male','EG','ar');
  perform public.directory_hello(t,'Target','female','EG','ar');
  perform public.directory_hello(hid,'Hidden','female','EG','ar');
  perform public.directory_hello(s2,'Other','male','EG','ar');
  lobby := (public.create_room_atomic('NVTA22',host,'إياد','male',3,'{}'::jsonb)->>'roomId')::uuid;

  -- Not in the room: refused.
  begin perform public.room_invite_send(s2,'Target',null,lobby); assert false, 'outsider invited';
  exception when others then assert sqlerrm='NOT_A_MEMBER', sqlerrm; end;
  -- Unknown handle: the generic refusal.
  begin perform public.room_invite_send(host,'nobody_here',null,lobby); assert false, 'unknown handle';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;

  r := public.room_invite_send(host,'target',null,lobby);
  assert (r->>'fresh')::boolean, r::text;
  inv := (r->>'inviteId')::uuid;
  -- The same pending invite is not sent (or pushed) twice.
  r := public.room_invite_send(host,'Target',null,lobby);
  assert not (r->>'fresh')::boolean and (r->>'inviteId')::uuid = inv, r::text;
  assert (select count(*) from public.invite_events where from_user=host) = 1;

  -- The recipient's inbox: face, handle, code; no sender id for a stranger.
  box := public.invites_inbox(t);
  assert jsonb_array_length(box)=1, box::text;
  assert box->0->>'code'='NVTA22' and box->0->>'name'='إياد' and box->0->>'handle'='Eyad', box::text;
  assert (box->0->>'stranger')::boolean and box->0->'from' = 'null'::jsonb, box::text;
  assert public.friends_status(t)->'invites'->0->>'id' = inv::text;
  assert public.friends_status(t)->'me'->>'handle' = 'Target';

  -- Push targets: nothing while push is off; tokens once on.
  assert public.invite_push_targets(inv)->>'enabled' = 'false';
  perform public.push_token_register(t,repeat('t',40),'android');
  perform public.push_token_register(t,repeat('w',40),'web');
  begin perform public.push_token_register(t,'short','android'); assert false, 'short token';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  begin perform public.push_token_register(t,repeat('i',40),'ios'); assert false, 'unknown platform';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  update public.economy_config set push_invites_enabled=true;
  r := public.invite_push_targets(inv);
  assert (r->>'enabled')::boolean and r->>'code'='NVTA22' and jsonb_array_length(r->'tokens')=2, r::text;
  -- The payload names nothing beyond code, sender name/handle and the id.
  assert (select array_agg(k order by k) from jsonb_object_keys(r) k)
    = array['code','enabled','fromHandle','fromName','inviteId','kind','tokens'], r::text;
  -- A token moves with its device to another account; dead tokens can be dropped.
  perform public.push_token_register(s2,repeat('w',40),'web');
  assert jsonb_array_length(public.invite_push_targets(inv)->'tokens')=1;
  perform public.push_token_drop(repeat('t',40));
  assert jsonb_array_length(public.invite_push_targets(inv)->'tokens')=0;
  -- At most ten devices per player.
  for i in 1..12 loop perform public.push_token_register(t,repeat('d',30)||i,'android'); end loop;
  assert (select count(*) from public.push_tokens where user_id=t) = 10;

  -- Declining clears it from the inbox.
  r := public.invite_respond(t,inv,false);
  assert jsonb_array_length(r->'invites')=0 and not (r->>'open')::boolean, r::text;

  -- Hidden players and players who muted strangers cannot be invited by strangers.
  perform public.directory_prefs(hid,false,null);
  begin perform public.room_invite_send(host,'Hidden',null,lobby); assert false, 'hidden invited';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;
  perform public.directory_prefs(hid,true,false);
  begin perform public.room_invite_send(host,'Hidden',null,lobby); assert false, 'muted invited';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;

  -- A block stops everything, and removes what was pending.
  r := public.room_invite_send(host,'Other',null,lobby);
  insert into public.player_blocks(blocker_id,blocked_id) values(s2,host);
  assert jsonb_array_length(public.invites_inbox(s2))=0;
  begin perform public.room_invite_send(host,'Other',null,lobby); assert false, 'invited through a block';
  exception when others then assert sqlerrm='NOT_ALLOWED', sqlerrm; end;

  -- Per-recipient cap from strangers (10/day) …
  update public.economy_config set stranger_invites_received_per_day=2, stranger_invites_per_day=20;
  delete from public.invite_events;
  for i in 1..2 loop
    someone := pg_temp.ip_user();
    perform public.directory_hello(someone,'Sender'||i,'male','EG','ar');
    lobby2 := (public.create_room_atomic('NVCZ'||(array['AA','BB'])[i],someone,'S','male',4,'{}'::jsonb)->>'roomId')::uuid;
    perform public.room_invite_send(someone,'Target',null,lobby2);
  end loop;
  begin perform public.room_invite_send(host,'Target',null,lobby); assert false, 'recipient cap';
  exception when others then assert sqlerrm='RATE_LIMITED', sqlerrm; end;
  -- … and per-sender cap to strangers (20/day).
  update public.economy_config set stranger_invites_received_per_day=10, stranger_invites_per_day=1;
  delete from public.invite_events;
  perform public.room_invite_send(host,'Target',null,lobby);
  someone := pg_temp.ip_user();
  perform public.directory_hello(someone,'Fresh','male','EG','ar');
  begin perform public.room_invite_send(host,'Fresh',null,lobby); assert false, 'sender cap';
  exception when others then assert sqlerrm='RATE_LIMITED', sqlerrm; end;
  update public.economy_config set stranger_invites_per_day=20;

  -- The lobby starting expires its invites (and their push).
  inv := (select id from public.room_invites where room_id=lobby and to_user=t);
  assert public.invites_inbox(t) @> jsonb_build_array(jsonb_build_object('id',inv));
  update public.rooms set status='playing' where id=lobby;
  assert (select status from public.room_invites where id=inv) = 'expired';
  assert not public.invites_inbox(t) @> jsonb_build_array(jsonb_build_object('id',inv));
  assert public.invite_push_targets(inv)->>'enabled' = 'false';
  -- Invites past their time are gone too.
  lobby2 := (public.create_room_atomic('NVTB22',host,'إياد','male',5,'{}'::jsonb)->>'roomId')::uuid;
  inv := (public.room_invite_send(host,'Target',null,lobby2)->>'inviteId')::uuid;
  update public.room_invites set expires_at=now()-interval '1 minute' where id=inv;
  assert not public.invites_inbox(t) @> jsonb_build_array(jsonb_build_object('id',inv));
  r := public.invite_respond(t,inv,true);
  assert not (r->>'open')::boolean, r::text;
end $$;

-- ── Friends keep working through the same door ──────────────────────────────
do $$
declare a uuid := pg_temp.ip_user(); b uuid := pg_temp.ip_user(); lobby uuid; r jsonb;
begin
  update public.economy_config set friends_enabled=true;
  perform pg_temp.ip_table(array[a,b], 'FRPA22');
  perform public.friend_request(a,b);
  perform public.friend_request(b,a);
  -- b never opened the directory, muted nothing: a friend invite still lands.
  lobby := (public.create_room_atomic('FRPB22',a,'U1','male',6,'{}'::jsonb)->>'roomId')::uuid;
  r := public.friend_invite(a,b,lobby);
  assert (r->>'invited')::boolean, r::text;
  r := public.friends_status(b)->'invites'->0;
  assert r->>'code'='FRPB22' and not (r->>'stranger')::boolean and r->>'from'=a::text, r::text;
  r := public.invite_respond(b,(r->>'id')::uuid,true);
  assert (r->>'open')::boolean and r->>'code'='FRPB22', r::text;
end $$;
rollback;

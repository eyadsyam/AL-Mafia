-- Contract for 20260928001100_safety_v11 (F11). Rolled back by the SQL harness.
begin;
do $$
declare
  a uuid := '00000000-0000-4000-8000-00000000a011';   -- blocker
  b uuid := '00000000-0000-4000-8000-00000000b011';   -- blocked
  c uuid := '00000000-0000-4000-8000-00000000c011';   -- neutral
  d uuid := '00000000-0000-4000-8000-00000000d011';
  e uuid := '00000000-0000-4000-8000-00000000e011';
  f uuid := '00000000-0000-4000-8000-00000000f011';
  g uuid := '00000000-0000-4000-8000-00000000a911';
  admin uuid := '00000000-0000-4000-8000-00000000ad11';
  lobby uuid; pub uuid; played uuid; res jsonb; rep uuid; rep2 uuid; t text; i integer;
  expect_fail text;
begin
  -- ── The predicate ──
  insert into public.player_blocks(blocker_id,blocked_id) values(a,b);
  assert not public.safety_users_compatible(a,b) and not public.safety_users_compatible(b,a);
  assert public.safety_users_compatible(a,c) and public.safety_users_compatible(a,a);
  assert public.friends_blocked(b,a), 'friends did not adopt the rule';

  -- ── Joining: the blocked side is refused, generically; others are not ──
  lobby := (public.create_room_atomic('SAFEAA',a,'Host A','male',1,'{}'::jsonb)->>'roomId')::uuid;
  begin
    perform public.join_room_atomic('SAFEAA',b,'Bee','male');
    raise exception 'a blocked player joined';
  exception when raise_exception then
    assert sqlerrm='ROOM_UNAVAILABLE', sqlerrm;
  end;
  perform public.join_room_atomic('SAFEAA',c,'Cee','male');
  -- The other direction: the blocker cannot sit down with the one they blocked.
  perform public.create_room_atomic('SAFEBB',b,'Bee','male',2,'{}'::jsonb);
  begin
    perform public.join_room_atomic('SAFEBB',a,'Host A','male');
    raise exception 'a blocker joined the blocked';
  exception when raise_exception then
    assert sqlerrm='ROOM_UNAVAILABLE', sqlerrm;
  end;

  -- ── The public list and quick match never offer that table ──
  -- Fixture seats are inserted directly, so nobody is moved out of SAFEAA.
  pub := (public.create_room_atomic('PUBLCC',e,'Eee','male',3,
    '{"visibility":"public","settings":{"scenarioCode":"classic"}}'::jsonb)->>'roomId')::uuid;
  insert into public.room_players(room_id,user_id,name,seat) values(pub,a,'Host A',1);
  assert exists(select 1 from public.public_room_listing_v2(d) where code='PUBLCC');
  assert not exists(select 1 from public.public_room_listing_v2(b) where code='PUBLCC'), 'listed to the blocked';
  res := public.quick_match_atomic(b,'Bee','male');
  assert (res->>'created')::boolean and res->>'code'<>'PUBLCC', 'quick match seated the blocked: '||res::text;

  -- ── Mid-match: the seat stays; rejoin is not refused ──
  played := gen_random_uuid();
  insert into public.rooms(id,code,host_id,match_seed,status) values(played,'PLAYDD',f,4,'playing');
  insert into public.room_players(room_id,user_id,name,seat) values(played,f,'Eff',0),(played,g,'Gee',1);
  insert into public.player_blocks(blocker_id,blocked_id) values(f,g);
  res := public.join_room_atomic('PLAYDD',g,'Gee','male');
  assert (res->>'rejoined')::boolean, 'a seated player lost the seat to a block';
  delete from public.player_blocks where blocker_id=f;

  -- ── A block ends friendship, requests and invitations ──
  insert into public.friend_links(user_lo,user_hi,requested_by,accepted_at)
    values(least(f,g),greatest(f,g),f,now());
  insert into public.room_invites(room_id,to_user,from_user) values(pub,g,f);
  insert into public.player_blocks(blocker_id,blocked_id) values(g,f);
  assert not exists(select 1 from public.friend_links where user_lo=least(f,g) and user_hi=greatest(f,g));
  assert not exists(select 1 from public.room_invites where to_user=g and from_user=f);
  delete from public.player_blocks where blocker_id=g;
  assert not exists(select 1 from public.friend_links where user_lo=least(f,g) and user_hi=greatest(f,g)),
    'an unblock restored a friendship';

  -- ── Reactions: the blocker does not receive the blocked's ──
  insert into public.room_players(room_id,user_id,name,seat) values(pub,b,'Bee',5);
  insert into public.room_reactions(room_id,user_id,seat,kind) values(pub,b,5,'laugh'),(pub,e,0,'rose');
  perform set_config('request.jwt.claim.sub', a::text, true);
  set local role authenticated;
  assert (select count(*) from public.room_reactions where room_id=pub)=1, 'blocked reaction delivered';
  reset role;
  perform set_config('request.jwt.claim.sub', e::text, true);
  set local role authenticated;
  assert (select count(*) from public.room_reactions where room_id=pub)=2, 'reactions lost for others';
  reset role;
  delete from public.room_players where room_id=pub and user_id=b;

  -- ── Names ──
  assert public.safety_normalize_name('  أحـــمد   إبراهيم ')='احمد ابراهيم';
  assert public.safety_normalize_name('مُصْطَفَى')='مصطفي';
  assert public.safety_normalize_name('ADMIN')='admin';
  assert not public.safety_name_allowed('شَرْمُوط','name'), 'diacritics slipped through';
  assert not public.safety_name_allowed('شر موط','name'), 'spaced letters slipped through';
  assert not public.safety_name_allowed('Admin','name');
  assert not public.safety_name_allowed('مافيا ماستر','name');
  assert public.safety_name_allowed('دخول','name'), 'a short word matched inside an ordinary word';
  assert public.safety_name_allowed('زبون','name');
  assert public.safety_name_allowed('Admin','title'), 'a name-only term applied to a title';
  begin
    perform public.join_room_atomic('SAFEAA',d,'FUCK u','male');
    raise exception 'a refused name was seated';
  exception when raise_exception then
    assert sqlerrm='NAME_NOT_ALLOWED', sqlerrm;
  end;
  begin
    update public.rooms set title='قعدة الشراميط ياشرموطة' where id=lobby;
    raise exception 'a refused title was written';
  exception when raise_exception then
    assert sqlerrm='NAME_NOT_ALLOWED', sqlerrm;
  end;
  update public.rooms set title='قعدة الخميس' where id=lobby;
  -- A row written before a term existed is not re-checked by unrelated writes.
  alter table public.room_players disable trigger room_players_name_allowed;
  update public.room_players set name='شرموط' where room_id=lobby and user_id=c;
  alter table public.room_players enable trigger room_players_name_allowed;
  update public.room_players set status='away' where room_id=lobby and user_id=c;
  update public.room_players set name='Cee', status='connected' where room_id=lobby and user_id=c;

  -- ── Restrictions ──
  insert into public.safety_restrictions(user_id,kind,ends_at) values(d,'public_rooms',now()+interval '1 day');
  assert not exists(select 1 from public.public_room_listing_v2(d)), 'restricted player sees the list';
  begin
    perform public.quick_match_atomic(d,'Dee','male');
    raise exception 'restricted player quick-matched';
  exception when raise_exception then assert sqlerrm='ACCOUNT_RESTRICTED', sqlerrm; end;
  begin
    perform public.create_room_atomic('PUBXEE',d,'Dee','male',5,'{"visibility":"public"}'::jsonb);
    raise exception 'restricted player opened a public room';
  exception when raise_exception then assert sqlerrm='ACCOUNT_RESTRICTED', sqlerrm; end;
  perform public.create_room_atomic('PRVTFF',d,'Dee','male',6,'{}'::jsonb);
  update public.safety_restrictions set kind='online' where user_id=d;
  begin
    perform public.join_room_atomic('SAFEAA',d,'Dee','male');
    raise exception 'suspended player joined';
  exception when raise_exception then assert sqlerrm='ACCOUNT_RESTRICTED', sqlerrm; end;
  update public.safety_restrictions set ends_at=now()-interval '1 second' where user_id=d;
  assert not public.safety_restricted(d,'online'), 'an expired restriction still applies';
  delete from public.safety_restrictions where user_id=d;

  -- ── Reports ──
  rep := (public.safety_report(c,'lobby',lobby,0,null,'harassment','shouted',
    '10000000-0000-4000-8000-000000000001')->>'receipt')::uuid;
  assert (public.safety_report(c,'lobby',lobby,0,null,'harassment','again',
    '10000000-0000-4000-8000-000000000001')->>'replayed')::boolean, 'request id did not replay';
  assert (public.safety_report(c,'lobby',lobby,0,null,'harassment','dup',
    '10000000-0000-4000-8000-000000000002')->>'receipt')::uuid=rep, 'same target+category not deduplicated';
  perform public.safety_report(c,'lobby',lobby,0,null,'spam','',
    '10000000-0000-4000-8000-000000000003');
  begin
    perform public.safety_report(c,'lobby',lobby,0,null,'threat','',
      '10000000-0000-4000-8000-000000000004');
    raise exception 'third report on one target in a day';
  exception when raise_exception then assert sqlerrm='RATE_LIMITED', sqlerrm; end;
  begin
    perform public.safety_report(c,'lobby',lobby,0,null,'abuse','',
      '10000000-0000-4000-8000-000000000005');
    raise exception 'an old reason was accepted as a v11 category';
  exception when raise_exception then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  begin
    perform public.safety_report(b,'friends',null,null,c,'other','',
      '10000000-0000-4000-8000-000000000006');
    raise exception 'a stranger was reported from the friends list';
  exception when raise_exception then assert sqlerrm='NOT_A_MEMBER', sqlerrm; end;
  -- Evidence is the whitelist, and nothing private.
  select evidence::text into t from public.safety_reports where id=rep;
  assert (select array_agg(k order by k) from jsonb_object_keys((select evidence from public.safety_reports where id=rep)) k)
    = array['context','roomCode','roomStatus','roomTitle','targetName','targetSeat'], t;
  assert t !~* '(role|mafia|doctor|detective|citizen|whisper|voice|night)', 'private data in evidence: '||t;

  -- Blocks: 30 new a day.
  for i in 1..30 loop
    perform public.safety_block(admin, gen_random_uuid());
  end loop;
  begin
    perform public.safety_block(admin, gen_random_uuid());
    raise exception 'a 31st block in a day';
  exception when raise_exception then assert sqlerrm='RATE_LIMITED', sqlerrm; end;
  delete from public.player_blocks where blocker_id=admin;

  -- ── The owner's queue ──
  begin
    perform public.admin_safety_list(c,'open',null,null);
    raise exception 'a player read the queue';
  exception when raise_exception then assert sqlerrm='NOT_ADMIN', sqlerrm; end;
  insert into public.commerce_admins(user_id) values(admin);
  res := public.admin_safety_list(admin,'open',null,null,1);
  assert jsonb_array_length(res->'items')=1 and res->>'next' is not null, res::text;
  res := public.admin_safety_list(admin,'open',null,res->>'next',1);
  assert jsonb_array_length(res->'items')=1, res::text;
  rep2 := (res->'items'->0->>'id')::uuid;
  if rep2=rep then rep2 := (select id from public.safety_reports where reporter_id=c and reason='spam'); end if;

  res := public.admin_safety_resolve(admin,rep,'suspend',7,'repeated harassment',
    '20000000-0000-4000-8000-000000000001');
  assert res->>'status'='actioned' and res->>'endsAt' is not null, res::text;
  assert (public.admin_safety_resolve(admin,rep,'suspend',7,'x',
    '20000000-0000-4000-8000-000000000001')->>'replayed')::boolean, 'resolve did not replay';
  begin
    perform public.admin_safety_resolve(admin,rep,'warn',null,'',
      '20000000-0000-4000-8000-000000000002');
    raise exception 'a closed report was resolved twice';
  exception when raise_exception then assert sqlerrm='REPORT_CLOSED', sqlerrm; end;
  assert public.safety_restricted(a,'online'), 'suspension not applied';
  res := public.safety_my_status(a);
  assert res->'restrictions'->0->>'kind'='online' and res->'notices'->0->>'kind'='suspend', res::text;
  assert public.safety_ack_notice(a,(res->'notices'->0->>'id')::uuid);
  assert jsonb_array_length(public.safety_my_status(a)->'notices')=0;
  assert exists(select 1 from public.safety_audit where report_id=rep and action='suspend');

  -- ── Retention ──
  update public.safety_reports set status='dismissed', resolved_at=now()-interval '91 days' where id=rep2;
  insert into public.safety_reports(reporter_id,room_id,target_id,reason,status,resolved_at,created_at)
    values(d,lobby,a,'other','dismissed',now()-interval '60 days',now()-interval '60 days');
  insert into public.safety_audit(admin_id,action,created_at) values(admin,'warn',now()-interval '400 days');
  res := public.purge_safety_evidence(admin,'30000000-0000-4000-8000-000000000001');
  assert not exists(select 1 from public.safety_reports where id=rep2), 'dismissed report kept past 90 days';
  assert exists(select 1 from public.safety_reports where reporter_id=d and reason='other'), 'recent dismissal purged';
  assert exists(select 1 from public.safety_reports where id=rep), 'actioned report purged early';
  assert not exists(select 1 from public.safety_audit where created_at<now()-interval '365 days');
  assert exists(select 1 from public.safety_audit_monthly where action='warn');

  -- ── None of it is a client surface ──
  assert not has_table_privilege('authenticated','public.safety_restrictions','select');
  assert not has_table_privilege('authenticated','public.safety_notices','select');
  assert not has_table_privilege('authenticated','public.safety_name_terms','select');
  assert not has_table_privilege('authenticated','public.safety_audit','select');
  assert not has_function_privilege('authenticated','public.safety_report(uuid,text,uuid,integer,uuid,text,text,uuid)','execute');
  assert not has_function_privilege('authenticated','public.admin_safety_resolve(uuid,uuid,text,integer,text,uuid)','execute');
  assert not has_function_privilege('authenticated','public.safety_users_compatible(uuid,uuid)','execute');
  assert (public.economy_capabilities(c)->'safety'->>'v11')='false', 'v11 on by default';
  assert public.economy_capabilities(c) ? 'caseOfDay', 'earlier capabilities lost';
end $$;
rollback;

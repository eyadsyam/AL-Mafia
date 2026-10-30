begin;
do $$
declare r uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
        w uuid:=gen_random_uuid(); n integer;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'WREADP',a,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role) values
    (r,a,'A',0,'citizen'),(r,b,'B',1,'citizen');
  insert into public.room_state(room_id,phase,phase_number) values(r,'discuss',1);
  insert into public.whisper_meta(id,room_id,day,from_id,to_id) values(w,r,1,a,b);
  insert into public.whisper_content(whisper_id,body) values(w,'secret');
  set local role authenticated;
  perform set_config('request.jwt.claim.sub',b::text,true);
  select count(*) into n from public.whisper_content where whisper_id=w;
  assert n=1, 'recipient cannot read ordinary body';
  reset role;
  insert into public.whisper_blocks(room_id,blocker_id,blocked_id) values(r,b,a);
  set local role authenticated;
  select count(*) into n from public.whisper_content where whisper_id=w;
  assert n=0, 'blocked sender body visible to recipient';
  reset role;
  delete from public.whisper_blocks where room_id=r;
  update public.whisper_meta set voided=true where id=w;
  set local role authenticated;
  select count(*) into n from public.whisper_content where whisper_id=w;
  assert n=0, 'voided body visible to recipient';
  perform set_config('request.jwt.claim.sub',a::text,true);
  select count(*) into n from public.whisper_content where whisper_id=w;
  assert n=1, 'sender cannot read own body';
  reset role;
end $$;
rollback;
select 'PASS whisper read: normal recipient, blocked/voided hidden, sender retains access' as result;

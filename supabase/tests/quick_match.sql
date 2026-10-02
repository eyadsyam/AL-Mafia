begin;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); first jsonb; second jsonb; third jsonb;
begin
  insert into auth.users(id) values(a),(b),(c);
  first:=public.quick_match_atomic(a,'A','male');
  assert (first->>'created')::boolean;
  second:=public.quick_match_atomic(b,'B','female');
  assert not (second->>'created')::boolean;
  assert second->>'roomId'=first->>'roomId';
  third:=public.quick_match_atomic(c,'C','unspecified');
  assert third->>'roomId'=first->>'roomId';
  assert (select count(*) from room_players where room_id=(first->>'roomId')::uuid and not kicked)=3;
end $$;
rollback;

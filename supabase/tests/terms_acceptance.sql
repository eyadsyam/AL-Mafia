-- Contract for 20260924000100_terms_acceptance. Rolled back.
begin;
do $$
declare p uuid:=gen_random_uuid();
begin
  insert into auth.users(id) values(p);
  assert public.record_terms_acceptance(p,'2026-09-23',true,now()-interval '1 day');
  -- Idempotent: a retried sync neither fails nor duplicates.
  assert public.record_terms_acceptance(p,'2026-09-23',true,now());
  assert (select count(*) from public.terms_acceptances where user_id=p)=1;
  -- The device clock cannot claim the future.
  assert public.record_terms_acceptance(p,'2027-01-01',true,now()+interval '10 days');
  assert (select accepted_at from public.terms_acceptances where user_id=p and terms_version='2027-01-01')<=now();
  begin perform public.record_terms_acceptance(p,'2026-09-23',false,now()); assert false;
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  begin perform public.record_terms_acceptance(p,'latest',true,now()); assert false;
  exception when check_violation then null; end;
  assert not has_function_privilege('authenticated','public.record_terms_acceptance(uuid,text,boolean,timestamptz)','execute');
  assert not has_table_privilege('authenticated','public.terms_acceptances','select');
end $$;
rollback;

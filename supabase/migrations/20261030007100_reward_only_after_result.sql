-- Resolution stores a winner before the public result phase. A receipt must
-- wait until that phase actually opens, or a host departure in the gap can
-- leave a closed room with a reward already issued.
create or replace function public.guard_match_receipt_result() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare room_status text; room_phase text;
begin
  select status into room_status from public.rooms
    where id=new.room_id for share;
  -- A receipt for a room long since purged is not this guard's question.
  if not found then return new; end if;
  if room_status is distinct from 'finished' then return null; end if;
  select phase into room_phase from public.room_state
    where room_id=new.room_id for share;
  if room_phase is distinct from 'result' then return null; end if;
  return new;
end;
$$;
revoke all on function public.guard_match_receipt_result() from public,anon,authenticated;
drop trigger if exists match_receipt_result_guard on public.match_receipts;
create trigger match_receipt_result_guard before insert on public.match_receipts
  for each row execute function public.guard_match_receipt_result();

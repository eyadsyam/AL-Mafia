-- A round-one revote that did not affect the ballot returns its spent charge.
-- Removing the use also frees the match and phase limits. The public toolLog
-- remains in room_state as the table's record of what was announced.
create function public.refund_unused_table_tool(
  p_room uuid, p_tool text, p_phase_number int
) returns int language plpgsql security definer
set search_path=public,pg_temp as $$
declare
  buyer record;
  refunded int := 0;
begin
  if p_tool is distinct from 'revote' then
    raise exception 'unsupported refundable tool';
  end if;

  for buyer in
    delete from public.room_tool_uses
      where room_id=p_room and tool_code=p_tool and phase_number=p_phase_number
      returning user_id
  loop
    if not public.has_all_access(buyer.user_id) then
      insert into public.player_tool_charges(user_id,tool_code,charges)
        values(buyer.user_id,p_tool,1)
      on conflict (user_id,tool_code) do update
        set charges=public.player_tool_charges.charges+1, updated_at=now();
      refunded := refunded + 1;
    end if;
  end loop;
  return refunded;
end $$;
revoke all on function public.refund_unused_table_tool(uuid,text,int) from public,anon,authenticated;
grant execute on function public.refund_unused_table_tool(uuid,text,int) to service_role;

-- «صوت من القبر» (grave_vote) is retired (owner, 2026-10-22).
--
-- A dead player sees every role (witness view), so a ballot cast after death
-- carries that knowledge back to the living table: in an open ballot, or when
-- the dead seat's role was shown, the living read the Mafia off it (Doc 05).
--
-- table_tools_snapshot, buy_table_tool and use_table_tool read only active
-- tools, so this one row takes it off the store and out of every match for
-- every client, old builds included. Every unused charge is paid back at the
-- single-charge price, the most any charge cost.

update public.table_tools set active=false where code='grave_vote';

do $$
declare r record; amount bigint;
begin
  for r in
    select c.user_id, c.charges, t.coin_price
      from public.player_tool_charges c
      join public.table_tools t on t.code=c.tool_code
     where c.tool_code='grave_vote' and c.charges>0
       for update of c
  loop
    amount := r.charges::bigint * r.coin_price;
    update public.wallet_accounts set balance=balance+amount, updated_at=now()
     where user_id=r.user_id;
    if found then
      insert into public.wallet_ledger(user_id,kind,amount,item_code)
        values(r.user_id,'operator_adjustment',amount,'grave_vote');
      update public.player_tool_charges set charges=0, updated_at=now()
       where user_id=r.user_id and tool_code='grave_vote';
    end if;
  end loop;
end $$;

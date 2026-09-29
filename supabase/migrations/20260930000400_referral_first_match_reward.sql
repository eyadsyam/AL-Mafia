-- The room invite promises +100/+50 when the invited player finishes their
-- first online match. Economy v3 had split the inviter's 100 into 25 now and
-- 75 after a later retention settlement, so the visible promise was false.
-- New referrals receive the full amount at the first eligible receipt. Rows
-- that already received 25 before this migration still receive their missing
-- 75 at settlement; new rows are not paid again.
insert into public.reward_catalog(
    code,coin_price,sort_order,kind,slot,contents,active,released)
  values('frame_invite',1,145,'frame','frame','{}',false,true)
on conflict(code) do update set kind=excluded.kind,slot=excluded.slot,
  contents=excluded.contents,active=false,released=true;

-- Older rows recorded the milestone but could not put its frame in inventory.
insert into public.player_inventory(user_id,item_code)
select user_id,'frame_invite' from public.invite_unlocks where code='frame_invite'
on conflict do nothing;

create or replace function public.invite_v3_settle(p_user uuid,p_locked uuid[])
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.council_invite_redemptions; n int; days int; apart int; mates int;
  season bigint:=public.invite_v3_season(); settled_season_n int; settled_life int;
  who text; created timestamptz; under_caps boolean; p int; legacy_stage boolean;
begin
  if not public.economy_v3_on() or not public.council_on('invites') then return; end if;
  for r in select * from public.council_invite_redemptions
      where not detached and inviter is not null and settled_at is null
        and (invitee=p_user or inviter=p_user)
        and (rewarded_at is null or stage1_at is not null)
      order by redeemed_at limit 50 for update loop
    continue when not (r.invitee=any(p_locked) and r.inviter=any(p_locked));
    select count(*)::int,count(distinct day)::int,
        count(*) filter (where not (r.inviter=any(co_players)))::int
      into n,days,apart from public.match_receipts where user_id=r.invitee;
    continue when n=0;
    select count(distinct mate)::int into mates
      from public.match_receipts x, unnest(x.co_players) mate
     where x.user_id=r.invitee and mate<>r.inviter;
    select count(*) filter (where settled_season is not distinct from season)::int,count(*)::int
      into settled_season_n,settled_life
      from public.council_invite_redemptions where inviter=r.inviter and settled_at is not null;
    under_caps:=settled_season_n<10 and settled_life<40;
    select left(btrim(name),40) into who from public.council_identity where user_id=r.invitee;
    who:=coalesce(who,'');

    if r.stage1_at is null then
      perform public.credit_earned(r.invitee,'council_invite_invitee',50,null,'invitee');
      if under_caps and public.credit_earned(r.inviter,'invite_inviter_stage',100,null,r.invitee::text) then
        insert into public.invite_notices(user_id,invitee,kind,name,progress,coins)
          values(r.inviter,r.invitee,'first_match',who,0,100) on conflict do nothing;
      end if;
      update public.council_invite_redemptions
         set stage1_at=now(),rewarded_at=coalesce(rewarded_at,now())
       where invitee=r.invitee;
    end if;
    for p in 1..least(n,3) loop
      insert into public.invite_notices(user_id,invitee,kind,name,progress)
        values(r.inviter,r.invitee,'progress',who,p) on conflict do nothing;
    end loop;

    created:=public.council_account_created(r.invitee);
    if n>=3 and days>=2 and apart>=1 and mates>=5 and under_caps
       and created is not null and created<=now()-interval '48 hours' then
      select exists(select 1 from public.wallet_ledger
        where user_id=r.inviter and kind='invite_inviter_stage'
          and source_key=r.invitee::text and amount=25) into legacy_stage;
      if legacy_stage and public.credit_earned(
          r.inviter,'invite_inviter_settlement',75,null,r.invitee::text) then
        insert into public.invite_notices(user_id,invitee,kind,name,progress,coins)
          values(r.inviter,r.invitee,'settled',who,3,75) on conflict do nothing;
      else
        insert into public.invite_notices(user_id,invitee,kind,name,progress,coins)
          values(r.inviter,r.invitee,'settled',who,3,0) on conflict do nothing;
      end if;
      update public.council_invite_redemptions set settled_at=now(),settled_season=season
       where invitee=r.invitee;
      settled_life:=settled_life+1;
      if settled_life>=3 then
        insert into public.invite_unlocks(user_id,code) values(r.inviter,'title_kabir_elshella')
          on conflict do nothing;
      end if;
      if settled_life>=10 then
        insert into public.invite_unlocks(user_id,code) values(r.inviter,'frame_invite')
          on conflict do nothing;
        insert into public.player_inventory(user_id,item_code) values(r.inviter,'frame_invite')
          on conflict do nothing;
      end if;
    end if;
  end loop;
end $$;

revoke all on function public.invite_v3_settle(uuid,uuid[]) from public,anon,authenticated;
grant execute on function public.invite_v3_settle(uuid,uuid[]) to service_role;

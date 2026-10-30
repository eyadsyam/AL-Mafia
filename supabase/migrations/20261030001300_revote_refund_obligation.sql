-- Resolution and its refund obligation commit together. Payment may retry.
create table public.revote_refund_obligations (
  room_id uuid not null references public.rooms(id) on delete cascade,
  day integer not null,
  refunded_at timestamptz,
  refunded_count integer,
  created_at timestamptz not null default now(),
  primary key(room_id,day)
);
alter table public.revote_refund_obligations enable row level security;
revoke all on public.revote_refund_obligations from public,anon,authenticated;
grant all on public.revote_refund_obligations to service_role;

create function public.commit_vote_resolution(
  p_room uuid, p_phase text, p_number integer, p_round integer,
  p_victim uuid, p_saved_seat integer, p_archive jsonb,
  p_patch jsonb, p_next text, p_deadline timestamptz, p_fingerprint text,
  p_refund_revote boolean
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_phase <> 'vote' then raise exception 'vote only'; end if;
  if not public.commit_resolution(p_room,p_phase,p_number,p_round,p_victim,
      p_saved_seat,p_archive,p_patch,p_next,p_deadline,p_fingerprint) then return false; end if;
  if p_refund_revote then
    insert into public.revote_refund_obligations(room_id,day) values(p_room,p_number)
      on conflict do nothing;
  end if;
  return true;
end $$;
revoke all on function public.commit_vote_resolution(uuid,text,integer,integer,uuid,integer,jsonb,jsonb,text,timestamptz,text,boolean) from public,anon,authenticated;
grant execute on function public.commit_vote_resolution(uuid,text,integer,integer,uuid,integer,jsonb,jsonb,text,timestamptz,text,boolean) to service_role;

create function public.retry_revote_refunds(p_room uuid default null)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare pending record; paid integer:=0; this_refund integer;
begin
  for pending in select room_id,day from public.revote_refund_obligations
    where refunded_at is null and (p_room is null or room_id=p_room)
    order by created_at for update skip locked
  loop
    this_refund:=public.refund_unused_table_tool(pending.room_id,'revote',pending.day);
    paid:=paid+this_refund;
    update public.revote_refund_obligations set refunded_at=now(),
      refunded_count=this_refund where room_id=pending.room_id and day=pending.day;
  end loop;
  return paid;
end $$;
revoke all on function public.retry_revote_refunds(uuid) from public,anon,authenticated;
grant execute on function public.retry_revote_refunds(uuid) to service_role;

do $$ begin
  if exists(select 1 from pg_namespace where nspname='cron') then
    perform cron.schedule('retry-revote-refunds','30 seconds',
      'select public.retry_revote_refunds();');
  end if;
end $$;

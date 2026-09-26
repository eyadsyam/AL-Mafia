alter table public.safety_reports
  add column if not exists status text not null default 'pending',
  add column if not exists priority smallint not null default 1,
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by text,
  add column if not exists resolution_note text not null default '';

alter table public.safety_reports drop constraint if exists safety_reports_status_valid;
alter table public.safety_reports add constraint safety_reports_status_valid
  check(status in ('pending','reviewing','actioned','dismissed'));
alter table public.safety_reports drop constraint if exists safety_reports_priority_valid;
alter table public.safety_reports add constraint safety_reports_priority_valid check(priority between 1 and 3);
alter table public.safety_reports drop constraint if exists safety_reports_resolution_note_length;
alter table public.safety_reports add constraint safety_reports_resolution_note_length
  check(char_length(resolution_note)<=1000);
create index if not exists safety_reports_queue on public.safety_reports(status,priority desc,created_at);

create table if not exists public.moderation_notifications (
  id bigint generated always as identity primary key,
  kind text not null check(kind in ('report','deletion')),
  reference_id uuid not null,
  recipient text not null,
  status text not null default 'pending' check(status in ('pending','sent','failed')),
  attempts smallint not null default 0 check(attempts>=0),
  next_attempt_at timestamptz not null default now(),
  last_error text not null default '' check(char_length(last_error)<=300),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  unique(kind,reference_id)
);
alter table public.moderation_notifications enable row level security;
revoke all on table public.moderation_notifications from public,anon,authenticated;
grant select,insert,update,delete on table public.moderation_notifications to service_role;

create or replace function public.queue_moderation_notification()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  insert into public.moderation_notifications(kind,reference_id,recipient)
  values(case when tg_table_name='safety_reports' then 'report' else 'deletion' end,
    new.id,'eyadsyam124@gmail.com') on conflict do nothing;
  return new;
end $$;
revoke all on function public.queue_moderation_notification() from public,anon,authenticated;

drop trigger if exists safety_report_notification on public.safety_reports;
create trigger safety_report_notification after insert on public.safety_reports
for each row execute function public.queue_moderation_notification();
drop trigger if exists deletion_request_notification on public.data_deletion_requests;
create trigger deletion_request_notification after insert on public.data_deletion_requests
for each row execute function public.queue_moderation_notification();

create or replace function public.claim_safety_report(p_report uuid,p_reviewer text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if length(btrim(coalesce(p_reviewer,''))) not between 1 and 100 then raise exception 'BAD_REQUEST'; end if;
  update public.safety_reports set status='reviewing',reviewed_at=now(),reviewed_by=btrim(p_reviewer)
    where id=p_report and status='pending';
  return found;
end $$;
revoke all on function public.claim_safety_report(uuid,text) from public,anon,authenticated;
grant execute on function public.claim_safety_report(uuid,text) to service_role;

create or replace function public.resolve_safety_report(p_report uuid,p_status text,p_note text,p_reviewer text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_status not in ('actioned','dismissed') or char_length(coalesce(p_note,''))>1000 or
    length(btrim(coalesce(p_reviewer,''))) not between 1 and 100 then raise exception 'BAD_REQUEST'; end if;
  update public.safety_reports set status=p_status,resolution_note=coalesce(p_note,''),
    reviewed_at=now(),reviewed_by=btrim(p_reviewer),resolved_at=now()
    where id=p_report and status in ('pending','reviewing');
  return found;
end $$;
revoke all on function public.resolve_safety_report(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.resolve_safety_report(uuid,text,text,text) to service_role;

create or replace function public.moderation_summary()
returns table(pending_reports bigint,reviewing_reports bigint,pending_deletions bigint,pending_notifications bigint)
language sql security definer set search_path=public,pg_temp as $$
  select
    (select count(*) from public.safety_reports where status='pending'),
    (select count(*) from public.safety_reports where status='reviewing'),
    (select count(*) from public.data_deletion_requests where completed_at is null),
    (select count(*) from public.moderation_notifications where status in ('pending','failed'))
$$;
revoke all on function public.moderation_summary() from public,anon,authenticated;
grant execute on function public.moderation_summary() to service_role;


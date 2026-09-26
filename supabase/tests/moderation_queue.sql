begin;
do $$ declare u uuid:=gen_random_uuid(); r uuid:=gen_random_uuid(); report uuid; n public.moderation_notifications;
begin
  insert into public.safety_reports(id,reporter_id,room_id,reason,details)
    values(gen_random_uuid(),u,r,'other','untrusted report text') returning id into report;
  select * into n from public.moderation_notifications where kind='report' and reference_id=report;
  if n.id is null or n.recipient<>'eyadsyam124@gmail.com' or n.status<>'pending' then raise exception 'notification missing'; end if;
  if row_to_json(n)::text like '%untrusted report text%' then raise exception 'sensitive details copied'; end if;
  if not public.claim_safety_report(report,'Eyad Syam') then raise exception 'claim failed'; end if;
  if public.claim_safety_report(report,'Eyad Syam') then raise exception 'double claim'; end if;
  if not public.resolve_safety_report(report,'dismissed','reviewed','Eyad Syam') then raise exception 'resolve failed'; end if;
  if (select status<>'dismissed' or resolved_at is null from public.safety_reports where id=report) then raise exception 'resolution missing'; end if;
end $$;
rollback;


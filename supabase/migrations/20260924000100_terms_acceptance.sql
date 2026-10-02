-- Terms acceptance recorded per anonymous/linked user and terms version.
-- Evidence of agreement, not an access gate: an old client that never sends
-- it keeps working, and a failed sync never makes the client ask again.
create table public.terms_acceptances (
  user_id uuid not null,
  terms_version text not null check (terms_version ~ '^\d{4}-\d{2}-\d{2}$'),
  adult_confirmed boolean not null,
  accepted_at timestamptz not null,
  recorded_at timestamptz not null default now(),
  primary key (user_id, terms_version)
);
alter table public.terms_acceptances enable row level security;
revoke all on public.terms_acceptances from anon, authenticated;
grant all on public.terms_acceptances to service_role;

create function public.record_terms_acceptance(p_user uuid, p_version text,
  p_adult boolean, p_accepted_at timestamptz)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_user is null or p_version is null or p_adult is not true then
    raise exception 'BAD_REQUEST';
  end if;
  -- The device clock is the player's; it may not claim the future.
  insert into public.terms_acceptances(user_id, terms_version, adult_confirmed, accepted_at)
  values (p_user, p_version, true, least(coalesce(p_accepted_at, now()), now()))
  on conflict (user_id, terms_version) do nothing;
  return true;
end $$;
revoke all on function public.record_terms_acceptance(uuid,text,boolean,timestamptz) from public, anon, authenticated;
grant execute on function public.record_terms_acceptance(uuid,text,boolean,timestamptz) to service_role;

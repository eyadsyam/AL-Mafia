-- Whispers, in two tables (doc 09 §5, doc 10 §4).
--
-- The split is the feature. `whisper_meta` is the graph — who wrote to whom,
-- on which day — and the whole room may read it, because a visible alliance
-- map that everybody can argue about is the point of the layer. `whisper_content`
-- is the body, and only the two parties may read it.
--
-- Two tables rather than one table with a filtered column, for the same reason
-- the offline side uses two collections: a policy that has to null out a column
-- is a policy somebody can get wrong, and a table nobody but the parties can
-- select from is a boundary rather than a redaction.

create table if not exists public.whisper_meta (
  id       uuid primary key default gen_random_uuid(),
  room_id  uuid not null references public.rooms (id) on delete cascade,
  day      int  not null,
  from_id  uuid not null,
  to_id    uuid not null,

  -- The recipient died before reading (doc 09 §3.4). The sender is told
  -- «الهمسة ماوصلتش»; the body is never delivered.
  voided   boolean not null default false,

  created_at timestamptz not null default now(),

  constraint whisper_meta_no_self check (from_id <> to_id)
);

-- H-E1, enforced **server-side** as doc 09 §3.5 requires: "1/day, enforced
-- server-side in online mode — never trust the client". A unique index is the
-- only version of this rule that a race cannot get past.
create unique index if not exists whisper_meta_one_per_day
  on public.whisper_meta (room_id, day, from_id);

create index if not exists whisper_meta_recipient
  on public.whisper_meta (room_id, to_id, day);

create table if not exists public.whisper_content (
  whisper_id uuid primary key
               references public.whisper_meta (id) on delete cascade,

  -- H-E6/H-E10 — never truncated silently, and never empty.
  body       text not null
               check (char_length(body) between 1 and 120),

  read       boolean not null default false
);

alter table public.whisper_meta enable row level security;
alter table public.whisper_content enable row level security;

-- Blocks are per account and per room. H-E9: a blocked sender's whisper is
-- **silently** dropped for the recipient and the sender is never told — do not
-- build a harassment feedback loop.
create table if not exists public.whisper_blocks (
  room_id    uuid not null references public.rooms (id) on delete cascade,
  blocker_id uuid not null,
  blocked_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (room_id, blocker_id, blocked_id),
  constraint whisper_blocks_no_self check (blocker_id <> blocked_id)
);

alter table public.whisper_blocks enable row level security;

-- A report flags the row for review. Deliberately separate from a block: one
-- is "I do not want to see this person", the other is "somebody should look at
-- this", and conflating them makes both worse.
create table if not exists public.whisper_reports (
  whisper_id  uuid not null references public.whisper_meta (id) on delete cascade,
  reporter_id uuid not null,
  created_at  timestamptz not null default now(),
  primary key (whisper_id, reporter_id)
);

alter table public.whisper_reports enable row level security;

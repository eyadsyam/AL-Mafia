-- «الطلقة الواحدة», online (doc 13 §2, as doc 14 §4 left it).
--
-- ## What was missing, and how it showed
--
-- Two roles hold one irreversible move for the whole match: the Mafia's
-- «الليلة الهادية» — decline the kill, and let the morning be ambiguous — and
-- the Doctor's self-protection. Offline the engine spends them and remembers.
-- Online there was nowhere to remember, so `OnlineTransport.supportsBullets`
-- returned false and the last tile on the night grid was an ordinary skip.
--
-- For the Mafia that was nearly harmless: a skip already produces a quiet
-- night, so only the *once per match* part was missing. For the Doctor it was
-- not harmless at all. `submit_night_action` refuses a self-target outright —
-- `"not yourself"` — so an online Doctor could not protect themselves even
-- once, and the tile bearing their own name was a tile the server rejected.
--
-- ## Why the flag lives on the action and not on the player
--
-- The obvious column is `room_players.bullet_spent`. It is the wrong place,
-- and for a doc 05 reason rather than a normalisation one.
--
-- The roster is the one table every member of the room reads — it is how the
-- table is drawn. Only two of the four roles hold a bullet, so a public
-- `bullet_spent = true` on seat 3 would say *seat 3 is the Mafia or the
-- Doctor*, which is most of the game. It would have had to be kept off
-- `room_players_public`, which means a private per-caller route, which means a
-- new Edge Function to answer one boolean.
--
-- `night_actions` already is that route. Its read policy is
-- `actor_id = auth.uid()` — a player reads their own rows and nobody else's,
-- which is precisely the audience for this fact — and the client already loads
-- those rows on every resync to work out whether it still owes a move tonight.
-- So the flag rides along on a query that was already being made, refreshes
-- itself on reconnect, and needs no new grant and no new function.
--
-- ## Once per match, enforced by the database
--
-- The Edge Function checks before it writes, which is where the refusal gets a
-- reason the screen can render. The index below is what makes the rule true
-- rather than merely checked: two racing requests can both pass a `select` and
-- only one can win a unique index.

alter table public.night_actions
  add column if not exists used_bullet boolean not null default false;

comment on column public.night_actions.used_bullet is
  'Whether this action spent the actor''s once-per-match ability (doc 13 §2). '
  'Readable by the actor alone, through night_actions_own_read — the fact that '
  'somebody holds a bullet at all is a fact about their role.';

-- At most one spent bullet per player per room, whatever the night.
create unique index if not exists night_actions_one_bullet_per_player
  on public.night_actions (room_id, actor_id)
  where used_bullet;

-- ── the self-protect exception, in the constraint that forbade it ────────
--
-- Nothing here forbade a self-target; `submit_night_action` did, in code, and
-- for every other action it is still right to. This migration does not relax
-- anything in the schema — the exception is narrow (doctor, protect, with the
-- bullet) and belongs where the role is known, which is the function. Noted
-- here so the next reader looking for "where is self-protect allowed" does not
-- go looking for a constraint that was never there.

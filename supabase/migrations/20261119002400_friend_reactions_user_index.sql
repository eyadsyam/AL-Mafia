-- Performance advisor 2026-11-19: friend_activity_reactions.user_id references
-- auth.users without a covering index, so deleting an account scans the table.
-- Idempotent.
create index if not exists friend_activity_reactions_user
  on public.friend_activity_reactions(user_id);

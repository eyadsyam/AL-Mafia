-- Match awards were never computed on the hosted project (0 rows in
-- match_awards_computed, found by a real app match on 2026-11-10): the
-- scratch tables were emptied with a bare `delete from fun_players;`, which
-- the hosted database refuses ("DELETE requires a WHERE clause"), so the
-- whole call failed and the economy endpoint answered 500. `truncate` empties
-- the same session-local tables and is not refused. The body is otherwise the
-- one in force, patched in place so no other change rides along.
do $$
declare
  body text := pg_get_functiondef('public.compute_match_awards(uuid)'::regprocedure);
  fixed text;
begin
  fixed := replace(body,
    'delete from fun_players; delete from fun_ballots; delete from fun_day_out;',
    'truncate fun_players, fun_ballots, fun_day_out;');
  if fixed = body then
    raise exception 'compute_match_awards: scratch delete not found';
  end if;
  execute fixed;
end $$;

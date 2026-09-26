-- Council Vault (store v2): the three cosmetic categories that had fewer than
-- three items get their third. Additive only: nothing existing is repriced,
-- renamed or regranted, and a re-run leaves an owner-edited row alone.
--
-- Presentation only, like 20260924000300: a room scene, two text narration
-- styles (no recorded voice) and a collection of existing items. None of it
-- changes a vote, a role, information or timing, and the engine never reads it.
--
-- Clients built after 1.1.3 draw these codes; 1.1.3 and older filter them out of
-- the catalog (unknown codes are never offered). Prices are proposals for the
-- owner (packs 600–1200, bundles below the sum of their contents).
insert into public.reward_catalog(code,coin_price,sort_order,kind,slot,contents) values
  ('pack_moonlit_archive',750,330,'presentation_pack','room_pack','{}'),
  ('narrator_keeper',1000,420,'narrator_pack','narrator','{}'),
  ('narrator_noir',1000,430,'narrator_pack','narrator','{}'),
  -- 750 + 300 + 150 + 1000 = 2200 bought one by one.
  ('bundle_nocturne',1800,530,'bundle',null,
    '{pack_moonlit_archive,frame_moonlit,plate_noir,narrator_keeper}')
on conflict(code) do nothing;

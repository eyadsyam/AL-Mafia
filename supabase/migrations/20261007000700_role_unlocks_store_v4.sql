-- Store v4 (plan v3): the three new roles are bought once and unlock in the
-- buyer's rooms; the cosmetics nobody wanted leave the shop (owned copies keep
-- working). Frames and narrator packs stay.
alter table public.reward_catalog drop constraint if exists reward_catalog_kind_known;
alter table public.reward_catalog add constraint reward_catalog_kind_known check (kind = any (array[
  'guide','frame','nameplate','presentation_pack','narrator_pack','bundle','role']));
alter table public.reward_catalog drop constraint if exists reward_catalog_slot_known;
alter table public.reward_catalog add constraint reward_catalog_slot_known check (
  (kind = any (array['guide','bundle','role']) and slot is null)
  or (kind='frame' and slot='frame') or (kind='nameplate' and slot='nameplate')
  or (kind='presentation_pack' and slot='room_pack') or (kind='narrator_pack' and slot='narrator'));
insert into public.reward_catalog(code,coin_price,active,released,kind,slot,sort_order)
values ('role_elder',5000,true,true,'role',null,900),
       ('role_sniper',6000,true,true,'role',null,910),
       ('role_silencer',7000,true,true,'role',null,920)
on conflict (code) do update set coin_price=excluded.coin_price, active=true, released=true;

update public.reward_catalog set active=false
 where kind in ('nameplate','presentation_pack','bundle');

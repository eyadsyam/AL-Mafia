drop policy if exists whisper_content_parties on public.whisper_content;
create policy whisper_content_parties on public.whisper_content
  for select to authenticated using (
    exists (
      select 1 from public.whisper_meta m
      where m.id=whisper_content.whisper_id
        and ((select auth.uid())=m.from_id or
          ((select auth.uid())=m.to_id and not m.voided and not exists (
            select 1 from public.whisper_blocks b
            where b.room_id=m.room_id and b.blocker_id=m.to_id and b.blocked_id=m.from_id
          )))
    )
  );

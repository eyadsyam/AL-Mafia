/**
 * M6 — a committed whisper whose response was lost comes back as a retry and
 * hits the one-per-day unique index (23505). The retry is the same whisper
 * only when today's whisper from this sender went to the same seat's player
 * and holds exactly the same stored body; anything else keeps the refusal.
 * No schema change: this reads the rows the first send already wrote.
 */
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

/** The id of today's whisper from this sender, if it is exactly this one. */
export async function sameWhisper(
  db: SupabaseClient,
  roomId: string,
  senderId: string,
  day: number,
  toSeat: number,
  text: string,
): Promise<string | null> {
  const { data: meta, error: metaError } = await db
    .from("whisper_meta")
    .select("id, to_id")
    .eq("room_id", roomId)
    .eq("day", day)
    .eq("from_id", senderId)
    .maybeSingle();
  if (metaError || !meta) return null;
  const { data: target, error: targetError } = await db
    .from("room_players")
    .select("user_id")
    .eq("room_id", roomId)
    .eq("seat", toSeat)
    .maybeSingle();
  if (targetError || !target || target.user_id !== meta.to_id) return null;
  const { data: content, error: contentError } = await db
    .from("whisper_content")
    .select("body")
    .eq("whisper_id", meta.id)
    .maybeSingle();
  if (contentError || !content || content.body !== text) return null;
  return meta.id as string;
}

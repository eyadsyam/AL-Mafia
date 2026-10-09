/** A missing silence target is not seat zero. Never coerce null into a seat. */
export function silencedSeatOf(publicData: Record<string, unknown> | null | undefined): number | null {
  const morning = publicData?.morning as Record<string, unknown> | null | undefined;
  const seat = morning?.silencedSeat;
  return typeof seat === "number" && Number.isInteger(seat) && seat >= 0 ? seat : null;
}

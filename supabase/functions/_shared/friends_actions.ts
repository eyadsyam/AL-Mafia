/**
 * `friends` routing, kept pure so Node can test it (no Deno, no network).
 * The caller always comes from the session, never from the body; every field
 * is validated here and again in SQL (20260930000100_invites_push.sql).
 */

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const handle = /^[A-Za-z0-9_ء-ي٠-٩]{1,20}$/;

export type FriendsCall = { fn: string; args: Record<string, unknown> };

/** Actions that seat nobody but still need the caller in the room. */
export const needsMembership = new Set(["invite"]);

function page(value: unknown): number | null {
  if (value == null) return 0;
  return Number.isInteger(value) && (value as number) >= 0 && (value as number) <= 50
    ? value as number
    : null;
}

/** The RPC for one request body, or null when the body is not acceptable. */
export function friendsCall(body: Record<string, unknown>, userId: string): FriendsCall | null {
  const action = String(body.action ?? "status");
  const target = body.userId == null ? null : String(body.userId);
  if (target != null && !uuid.test(target)) return null;
  switch (action) {
    case "status":
      return { fn: "friends_status", args: { p_user: userId } };
    case "request":
      return target ? { fn: "friend_request", args: { p_user: userId, p_target: target } } : null;
    case "respond":
      if (!target || typeof body.accept !== "boolean") return null;
      return { fn: "friend_respond", args: { p_user: userId, p_target: target, p_accept: body.accept } };
    case "remove":
      return target ? { fn: "friend_remove", args: { p_user: userId, p_target: target } } : null;
    case "invite": {
      // A friend by id (as before) or anyone found by search, by handle.
      const roomId = String(body.roomId ?? "");
      const h = body.handle == null ? null : String(body.handle);
      if (!uuid.test(roomId)) return null;
      if ((target == null) === (h == null)) return null;
      if (h != null && !handle.test(h)) return null;
      return {
        fn: "room_invite_send",
        args: { p_user: userId, p_handle: h, p_target: target, p_room: roomId.toLowerCase() },
      };
    }
    case "inbox":
      return { fn: "invites_inbox", args: { p_user: userId } };
    case "respondInvite": {
      const id = String(body.inviteId ?? "");
      if (!uuid.test(id) || typeof body.accept !== "boolean") return null;
      return { fn: "invite_respond", args: { p_user: userId, p_invite: id.toLowerCase(), p_accept: body.accept } };
    }
    case "hello": {
      const name = typeof body.name === "string" ? body.name : "";
      if (name.trim().length < 1 || name.length > 40) return null;
      const gender = ["male", "female"].includes(String(body.gender)) ? String(body.gender) : "unspecified";
      const tz = typeof body.tz === "string" ? body.tz : "";
      const locale = typeof body.locale === "string" ? body.locale : "";
      return {
        fn: "directory_hello",
        args: {
          p_user: userId, p_name: name, p_gender: gender,
          p_country: countryFrom(tz, locale), p_lang: languageFrom(locale),
        },
      };
    }
    case "me":
      return { fn: "directory_me", args: { p_user: userId } };
    case "setHandle": {
      const h = typeof body.handle === "string" ? body.handle.trim() : "";
      return /^[A-Za-z0-9_ء-ي٠-٩]{3,20}$/.test(h)
        ? { fn: "directory_set_handle", args: { p_user: userId, p_handle: h } }
        : null;
    }
    case "prefs": {
      const s = body.searchable, m = body.strangerInvites;
      if (s != null && typeof s !== "boolean") return null;
      if (m != null && typeof m !== "boolean") return null;
      if (s == null && m == null) return null;
      return {
        fn: "directory_prefs",
        args: { p_user: userId, p_searchable: s ?? null, p_stranger_invites: m ?? null },
      };
    }
    case "search": {
      const q = typeof body.query === "string" ? body.query : "";
      const p = page(body.page);
      if (q.length > 40 || p == null) return null;
      return { fn: "directory_search", args: { p_user: userId, p_query: q, p_page: p } };
    }
    case "discover": {
      const filter = body.filter == null ? null : String(body.filter);
      const p = page(body.page);
      if (p == null || (filter != null && !["near", "online", "played", "level"].includes(filter))) return null;
      return { fn: "directory_discover", args: { p_user: userId, p_filter: filter, p_page: p } };
    }
    case "registerPush": {
      const token = typeof body.token === "string" ? body.token : "";
      const platform = String(body.platform ?? "");
      if (token.length < 20 || token.length > 4096 || !["android", "web"].includes(platform)) return null;
      return { fn: "push_token_register", args: { p_user: userId, p_token: token, p_platform: platform } };
    }
    default:
      return null;
  }
}

/**
 * A coarse country (ISO 3166 alpha-2) from the device time-zone name, else
 * the region of the device locale. Never coordinates, never the IP.
 */
export function countryFrom(tz: string, locale: string): string | null {
  const fromTz = TZ_COUNTRY[tz.trim()];
  if (fromTz) return fromTz;
  const region = /^[a-z]{2,3}[-_]([A-Za-z]{2})\b/i.exec(locale.trim())?.[1];
  return region ? region.toUpperCase() : null;
}

export function languageFrom(locale: string): string | null {
  const lang = /^([a-z]{2})\b/i.exec(locale.trim())?.[1];
  return lang ? lang.toLowerCase() : null;
}

// The zones our players live in: the Arab world first, then where its
// diaspora plays most. An unknown zone falls back to the locale's region.
const TZ_COUNTRY: Record<string, string> = {
  "Africa/Cairo": "EG", "Egypt": "EG",
  "Asia/Riyadh": "SA", "Asia/Dubai": "AE", "Asia/Kuwait": "KW", "Asia/Qatar": "QA",
  "Asia/Bahrain": "BH", "Asia/Muscat": "OM", "Asia/Amman": "JO", "Asia/Beirut": "LB",
  "Asia/Damascus": "SY", "Asia/Baghdad": "IQ", "Asia/Gaza": "PS", "Asia/Hebron": "PS",
  "Asia/Aden": "YE", "Africa/Tripoli": "LY", "Libya": "LY", "Africa/Tunis": "TN",
  "Africa/Algiers": "DZ", "Africa/Casablanca": "MA", "Africa/El_Aaiun": "MA",
  "Africa/Khartoum": "SD", "Africa/Nouakchott": "MR", "Africa/Mogadishu": "SO",
  "Africa/Djibouti": "DJ", "Indian/Comoro": "KM", "Asia/Jerusalem": "IL",
  "Europe/Istanbul": "TR", "Asia/Istanbul": "TR", "Asia/Tehran": "IR",
  "Europe/London": "GB", "Europe/Dublin": "IE", "Europe/Paris": "FR", "Europe/Berlin": "DE",
  "Europe/Amsterdam": "NL", "Europe/Brussels": "BE", "Europe/Rome": "IT", "Europe/Madrid": "ES",
  "Europe/Stockholm": "SE", "Europe/Oslo": "NO", "Europe/Copenhagen": "DK", "Europe/Vienna": "AT",
  "Europe/Zurich": "CH", "Europe/Athens": "GR",
  "America/New_York": "US", "America/Chicago": "US", "America/Denver": "US",
  "America/Los_Angeles": "US", "America/Phoenix": "US", "America/Detroit": "US",
  "America/Toronto": "CA", "America/Vancouver": "CA", "America/Montreal": "CA",
  "Australia/Sydney": "AU", "Australia/Melbourne": "AU", "Asia/Kolkata": "IN",
  "Asia/Karachi": "PK", "Asia/Kuala_Lumpur": "MY", "Asia/Jakarta": "ID",
};

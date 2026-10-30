/**
 * Invite push over FCM HTTP v1 (Android and web).
 *
 * The payload is the whole of what a notification may carry (Doc 05): the
 * room code, the sender's display name and handle, and the invite id. Never a
 * role, a seat, a phase or anything about a match in progress.
 *
 * No secret, no push: when `FCM_SERVICE_ACCOUNT_B64` is missing or unusable
 * the invite still lands in the app and this step is skipped (one log line,
 * nothing to the client). A token FCM calls UNREGISTERED is deleted.
 */

export interface PushTarget {
  enabled: boolean;
  kind?: "invite" | "friend_request" | "friend_accepted" | "order_paid" | "order_rejected" | EventKind | OwnerKind;
  /** Stable number that picks one of an event's wordings (the outbox row id). */
  variant?: number;
  inviteId?: string;
  code?: string;
  fromName?: string;
  fromHandle?: string;
  tokens?: { token: string; platform: "android" | "web" }[];
}

/** Kinds written by the push outbox (20261002000100_push_outbox.sql). */
export type EventKind = "room_start" | "night" | "daily" | "thursday" | "comeback";

export interface PushDeps {
  /** The secret's value, or undefined when it is not set. */
  secret: string | undefined;
  /** OAuth token from the service account (serviceAccountToken). */
  accessToken: (raw: string) => Promise<string>;
  fetch: typeof fetch;
  /** Deletes a dead token. */
  dropToken: (token: string) => Promise<void>;
  log: (line: string) => void;
}

export type PushOutcome =
  | { result: "skipped"; reason: "off" | "no_tokens" | "no_secret" | "bad_secret" }
  | { result: "sent"; sent: number; dead: number; failed: number };

/** The web link the notification opens (the existing deep-link route). */
export const WEB_ORIGIN = (
  (typeof Deno === "undefined" ? undefined : Deno.env.get("PUBLIC_WEB_ORIGIN")) ||
  "https://saidalmafia.com"
).replace(/\/$/, "");

/** Long knock pattern (ms): wait, buzz, pause, buzz … about two seconds. */
export const INVITE_VIBRATION_MS = [0, 400, 180, 400, 180, 700];

/** Our gold (design token `ShareCardTokens.gold`), for the Android accent. */
export const INVITE_ACCENT = "#C2AF81";

/** Friend requests: one short buzz (`InviteTokens.shortVibration`). */
export const SOCIAL_VIBRATION_MS = [0, 180];

const CODE = /^[A-Z0-9]{6}$/;

/** One FCM v1 message for one device. */
export function inviteMessage(t: PushTarget, token: string, platform: "android" | "web") {
  const code = String(t.code ?? "");
  if (!CODE.test(code)) throw new Error("BAD_CODE");
  const name = String(t.fromName ?? "").slice(0, 40);
  const title = "دعوة للعب";
  const body = `${name} بيدعوك تلعبوا مع بعض — أوضة ${code}`;
  const link = `${WEB_ORIGIN}/join/${code}`;
  const data = {
    kind: "invite",
    inviteId: String(t.inviteId ?? ""),
    code,
    fromName: name,
    fromHandle: String(t.fromHandle ?? "").slice(0, 20),
  };
  if (platform === "android") {
    return {
      message: {
        token,
        data,
        notification: { title, body },
        android: {
          priority: "HIGH",
          ttl: "1800s",
          collapse_key: `invite_${code}`,
          notification: {
            channel_id: "mafia_invites",
            sound: "invite_knock",
            icon: "ic_stat_mafia",
            color: INVITE_ACCENT,
            tag: `invite_${code}`,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            default_vibrate_timings: false,
            vibrate_timings: INVITE_VIBRATION_MS.slice(1).map((ms) => `${ms / 1000}s`),
            notification_priority: "PRIORITY_MAX",
            visibility: "PUBLIC",
          },
        },
      },
    };
  }
  return {
    message: {
      token,
      data,
      webpush: {
        headers: { Urgency: "high", TTL: "1800" },
        notification: {
          title, body,
          icon: "/icons/Icon-192.png",
          badge: "/icons/badge-72.png",
          tag: `invite_${code}`,
          requireInteraction: true,
          renotify: true,
          vibrate: INVITE_VIBRATION_MS.slice(1),
          dir: "rtl", lang: "ar",
          data: { link },
        },
        fcm_options: { link },
      },
    },
  };
}

/**
 * D: a friend request or an accepted request, on the quieter `mafia_social`
 * channel (default sound, short vibration). Only the kind and the sender's
 * display name travel.
 */
export function socialMessage(t: PushTarget, token: string, platform: "android" | "web") {
  const name = String(t.fromName ?? "").slice(0, 40);
  const accepted = t.kind === "friend_accepted";
  const title = accepted ? "بقيتوا أصحاب" : "طلب صداقة";
  const body = accepted ? `${name} قبل طلب الصداقة` : `${name} عايز يبقى صاحبك`;
  const data = { kind: accepted ? "friend_accepted" : "friend_request", fromName: name };
  const link = `${WEB_ORIGIN}/online`;
  if (platform === "android") {
    return {
      message: {
        token, data,
        notification: { title, body },
        android: {
          priority: "NORMAL",
          notification: {
            channel_id: "mafia_social",
            icon: "ic_stat_mafia",
            color: INVITE_ACCENT,
            default_sound: true,
            default_vibrate_timings: false,
            vibrate_timings: SOCIAL_VIBRATION_MS.slice(1).map((ms) => `${ms / 1000}s`),
          },
        },
      },
    };
  }
  return {
    message: {
      token, data,
      webpush: {
        notification: {
          title, body, icon: "/icons/Icon-192.png", badge: "/icons/badge-72.png",
          vibrate: SOCIAL_VIBRATION_MS.slice(1), dir: "rtl", lang: "ar", data: { link },
        },
        fcm_options: { link },
      },
    },
  };
}

/** Payment notices carry no balance, item, or transaction details. */
export function paymentMessage(t: PushTarget, token: string, platform: "android" | "web") {
  const paid = t.kind === "order_paid";
  const title = paid ? "طلبك اتوافق عليه 🎉" : "تحديث طلب التحويل";
  const body = paid ? "افتح الخزنة وشوف العملات أو الحاجة اللي اشتريتها." : "طلب التحويل اترفض. افتح الخزنة وشوف السبب.";
  const link = `${WEB_ORIGIN}/`;
  const data = { kind: t.kind ?? "order_rejected" };
  if (platform === "android") return { message: {
    token, data, notification: { title, body },
    android: { priority: "HIGH", notification: {
      channel_id: "mafia_social", icon: "ic_stat_mafia", color: INVITE_ACCENT,
      default_sound: true,
    } },
  } };
  return { message: { token, data, webpush: {
    notification: { title, body, icon: "/icons/Icon-192.png", badge: "/icons/badge-72.png", dir: "rtl", lang: "ar", data: { link } },
    fcm_options: { link },
  } } };
}

/** Short buzz for turn-like notices, a gentler one for reminders. */
export const GAME_VIBRATION_MS = [0, 250, 120, 250];

/**
 * The wording of every outbox kind. Each says only a fact about the room's
 * phase that every seat sees at once, or a reminder with no match content:
 * never a role, a seat, a name or a night result (Doc 05). Gentle reminders
 * vary by row id; room events use one identical line for every seat.
 */
export const EVENT_TEXT: Record<EventKind, {
  channel: "mafia_game" | "mafia_daily";
  image: boolean;
  lines: { title: string; body: string }[];
}> = {
  room_start: {
    channel: "mafia_game",
    image: false,
    lines: [
      { title: "الأوضة بدأت", body: "اللعب ابتدا. ارجع دلوقتي قبل ما تفوتك الجولة." },
      { title: "يلا، اللعبة ابتدت", body: "صحابك كلهم جوه. ادخل." },
    ],
  },
  night: {
    channel: "mafia_game",
    image: false,
    lines: [
      { title: "الليل نزل", body: "الليل بدأ في أوضتك. ارجع للعبة." },
      { title: "المدينة نامت", body: "الليل بدأ عند الكل. افتح الأوضة." },
    ],
  },
  daily: {
    channel: "mafia_daily",
    image: false,
    lines: [
      { title: "العجلة مستنياك", body: "لفّتك النهارده لسه ما اتاخدتش. خد مكافأتك." },
      { title: "مكافأة النهارده جاهزة", body: "افتح اللعبة وخد عملاتك قبل ما اليوم يخلص." },
      { title: "لفّة مجانية", body: "العجلة بتلف النهارده بلاش. جرّب حظك." },
    ],
  },
  thursday: {
    channel: "mafia_daily",
    image: true,
    lines: [
      { title: "ليلة الخميس النهاردة", body: "الغرف المميزة مفتوحة الليلة. اجمع صحابك والعبوا." },
      { title: "الخميس يعني مافيا", body: "ليلة الخميس بدأت. ادعي صحابك لأوضة." },
    ],
  },
  comeback: {
    channel: "mafia_daily",
    image: false,
    lines: [
      { title: "وحشتنا الأوضة", body: "بقالك كام يوم بعيد. صحابك لسه بيلعبوا." },
      { title: "المدينة مستنياك", body: "رجّع الشلة وابدأ جولة جديدة." },
      { title: "جولة سريعة؟", body: "خمس دقايق مافيا تنسيك اليوم. تعالى." },
    ],
  },
};

/** One FCM v1 message for an outbox kind. */
export function eventMessage(t: PushTarget, token: string, platform: "android" | "web") {
  const kind = t.kind as EventKind;
  const spec = EVENT_TEXT[kind];
  const game = spec.channel === "mafia_game";
  // Outbox row ids differ per recipient. They may vary gentle reminders, but
  // a room event must have identical wording for every seat (Doc 05).
  const line = game
    ? spec.lines[0]
    : spec.lines[Math.abs(t.variant ?? 0) % spec.lines.length];
  const link = `${WEB_ORIGIN}/`;
  const image = `${WEB_ORIGIN}/og-image.jpg`;
  const data = { kind };
  if (platform === "android") {
    return {
      message: {
        token,
        data,
        notification: { title: line.title, body: line.body, ...(spec.image ? { image } : {}) },
        android: {
          priority: game ? "HIGH" : "NORMAL",
          ttl: game ? "600s" : "21600s",
          collapse_key: kind,
          notification: {
            channel_id: spec.channel,
            icon: "ic_stat_mafia",
            color: INVITE_ACCENT,
            tag: kind,
            default_sound: true,
            default_vibrate_timings: false,
            vibrate_timings: (game ? GAME_VIBRATION_MS : SOCIAL_VIBRATION_MS)
              .slice(1).map((ms) => `${ms / 1000}s`),
            ...(spec.image ? { image } : {}),
          },
        },
      },
    };
  }
  return {
    message: {
      token,
      data,
      webpush: {
        headers: { Urgency: game ? "high" : "normal", TTL: game ? "600" : "21600" },
        notification: {
          title: line.title,
          body: line.body,
          icon: "/icons/Icon-192.png",
          badge: "/icons/badge-72.png",
          tag: kind,
          renotify: true,
          vibrate: (game ? GAME_VIBRATION_MS : SOCIAL_VIBRATION_MS).slice(1),
          dir: "rtl",
          lang: "ar",
          ...(spec.image ? { image } : {}),
          actions: [{ action: "open", title: "افتح اللعبة" }],
          data: { link },
        },
        fcm_options: { link },
      },
    },
  };
}

/** Notices for the owner's account only (20261030000200_owner_push.sql). */
export type OwnerKind = "owner_order" | "owner_claimed" | "owner_play" | "owner_report" | "owner_tester" | "owner_feedback";

/**
 * What each owner notice says and the admin page it opens on the website.
 * No amounts, names, references or methods travel: the page shows those to
 * the signed-in admin.
 */
export const OWNER_TEXT: Record<OwnerKind, { title: string; body: string; path: string }> = {
  owner_feedback: { title: "اقتراح جديد", body: "فيه لاعب بعت اقتراح. افتح لوحة المراجعة.", path: "/admin/review" },
  owner_order: { title: "طلب دفع جديد", body: "فيه حد طلب يشتري كوينز. افتح لوحة الإدارة.", path: "/admin" },
  owner_claimed: { title: "حد بيقول إنه حوّل", body: "فيه طلب مستني مراجعتك. افتح لوحة الإدارة.", path: "/admin" },
  owner_play: { title: "شراء جديد من جوجل بلاي", body: "فيه حد اشترى من المتجر. افتح لوحة الإدارة.", path: "/admin" },
  owner_report: { title: "بلاغ جديد", body: "فيه بلاغ مستني مراجعتك.", path: "/admin/safety" },
  owner_tester: { title: "طلب اختبار جديد", body: "فيه حد عايز يجرّب التطبيق قبل الناس.", path: "/admin/testers/" },
};

export function isOwnerKind(kind: unknown): kind is OwnerKind {
  return typeof kind === "string" && kind in OWNER_TEXT;
}

/** One owner notice for one device: opens the admin page, never the game. */
export function ownerMessage(t: PushTarget, token: string, platform: "android" | "web") {
  const kind = t.kind as OwnerKind;
  const spec = OWNER_TEXT[kind];
  const link = `${WEB_ORIGIN}${spec.path}`;
  const data = { kind, link };
  if (platform === "android") {
    return { message: {
      token, data, notification: { title: spec.title, body: spec.body },
      android: { priority: "HIGH", notification: {
        channel_id: "mafia_social", icon: "ic_stat_mafia", color: INVITE_ACCENT,
        tag: kind, default_sound: true,
      } },
    } };
  }
  return { message: { token, data, webpush: {
    headers: { Urgency: "high" },
    notification: {
      title: spec.title, body: spec.body, icon: "/icons/Icon-192.png", badge: "/icons/badge-72.png",
      tag: kind, renotify: true, dir: "rtl", lang: "ar", data: { link },
    },
    fcm_options: { link },
  } } };
}

/** The message for one device, by kind. */
export function messageFor(t: PushTarget, token: string, platform: "android" | "web") {
  if (t.kind === "order_paid" || t.kind === "order_rejected") return paymentMessage(t, token, platform);
  if (isOwnerKind(t.kind)) return ownerMessage(t, token, platform);
  if (t.kind && t.kind in EVENT_TEXT) return eventMessage(t, token, platform);
  return t.kind === "friend_request" || t.kind === "friend_accepted"
    ? socialMessage(t, token, platform)
    : inviteMessage(t, token, platform);
}

function projectOf(raw: string): string | null {
  try {
    const account = JSON.parse(raw.trim().startsWith("{") ? raw : atob(raw.trim()));
    return typeof account.project_id === "string" ? account.project_id : null;
  } catch {
    return null;
  }
}

/** Sends one push (an invite or a friend event) to every device of its recipient. Never throws. */
export async function sendPush(t: PushTarget, deps: PushDeps): Promise<PushOutcome> {
  if (!t.enabled) return { result: "skipped", reason: "off" };
  const tokens = t.tokens ?? [];
  if (tokens.length === 0) return { result: "skipped", reason: "no_tokens" };
  if (!deps.secret) {
    deps.log("push skipped: FCM_SERVICE_ACCOUNT_B64 not set");
    return { result: "skipped", reason: "no_secret" };
  }
  const project = projectOf(deps.secret);
  let access: string;
  try {
    if (!project) throw new Error("KEY_INVALID");
    access = await deps.accessToken(deps.secret);
  } catch (error) {
    deps.log(`push skipped: ${String((error as Error)?.message ?? "error").slice(0, 20)}`);
    return { result: "skipped", reason: "bad_secret" };
  }
  let sent = 0, dead = 0, failed = 0;
  for (const { token, platform } of tokens) {
    try {
      const response = await deps.fetch(
        `https://fcm.googleapis.com/v1/projects/${project}/messages:send`,
        {
          method: "POST",
          headers: { authorization: `Bearer ${access}`, "content-type": "application/json" },
          body: JSON.stringify(messageFor(t, token, platform)),
        },
      );
      if (response.ok) { sent++; continue; }
      const text = await response.text().catch(() => "");
      if (response.status === 404 || text.includes("UNREGISTERED")) {
        dead++;
        await deps.dropToken(token).catch(() => {});
      } else {
        failed++;
      }
    } catch {
      failed++;
    }
  }
  deps.log(`push ${t.kind ?? "invite"}: sent=${sent} dead=${dead} failed=${failed}`);
  return { result: "sent", sent, dead, failed };
}

/** The invite step, by its old name. */
export const sendInvitePush = sendPush;

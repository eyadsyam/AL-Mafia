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
  kind?: "invite" | "friend_request" | "friend_accepted";
  inviteId?: string;
  code?: string;
  fromName?: string;
  fromHandle?: string;
  tokens?: { token: string; platform: "android" | "web" }[];
}

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
export const WEB_ORIGIN = "https://almafia.vercel.app";

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

/** The message for one device, by kind. */
export function messageFor(t: PushTarget, token: string, platform: "android" | "web") {
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
  deps.log(`push ${t.kind === "invite" || t.kind == null ? "invite" : "social"}: sent=${sent} dead=${dead} failed=${failed}`);
  return { result: "sent", sent, dead, failed };
}

/** The invite step, by its old name. */
export const sendInvitePush = sendPush;

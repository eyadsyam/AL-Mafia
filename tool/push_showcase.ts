/**
 * Sends one real notification of every kind to the devices in a tokens file,
 * through the same message builders the server uses (_shared/push.ts).
 * For the owner to see them on a phone. Prints counts only, never a token.
 *
 *   npx -y deno run --allow-all tool/push_showcase.ts <tokens.json> <firebase-admin-key.json>
 *
 * tokens.json: [{ "token": "...", "platform": "android" | "web" }, ...]
 */
import { type PushTarget, sendPush } from "../supabase/functions/_shared/push.ts";
import { serviceAccountToken } from "../supabase/functions/_shared/play_auth.ts";

const [tokensPath, keyPath] = Deno.args;
const tokens = JSON.parse(await Deno.readTextFile(tokensPath));
const secret = btoa(await Deno.readTextFile(keyPath));
const deps = {
  secret,
  accessToken: (raw: string) =>
    serviceAccountToken(raw, "https://www.googleapis.com/auth/firebase.messaging"),
  fetch,
  dropToken: async () => {},
  log: (line: string) => console.log(line),
};

const shows: PushTarget[] = [
  { enabled: true, kind: "invite", code: "K7M4QX", fromName: "سيد المافيا", fromHandle: "test", inviteId: "" },
  { enabled: true, kind: "room_start" },
  { enabled: true, kind: "night" },
  { enabled: true, kind: "friend_request", fromName: "سيد المافيا" },
  { enabled: true, kind: "friend_accepted", fromName: "سيد المافيا" },
  { enabled: true, kind: "daily", variant: 0 },
  { enabled: true, kind: "thursday", variant: 0 },
  { enabled: true, kind: "comeback", variant: 0 },
  { enabled: true, kind: "order_paid" },
];
for (const show of shows) {
  await sendPush({ ...show, tokens }, deps);
  await new Promise((done) => setTimeout(done, 2500));
}

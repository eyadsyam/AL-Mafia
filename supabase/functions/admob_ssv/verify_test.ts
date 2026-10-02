// deno test -A supabase/functions/admob_ssv/verify_test.ts
import { assertEquals } from "jsr:@std/assert";
import { generateKeyPairSync, sign } from "node:crypto";
import { verifySsv } from "./verify.ts";

const KEY_ID = 3335741209;
const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
const keys = new Map([[KEY_ID, publicKey.export({ type: "spki", format: "der" }).toString("base64")]]);
const content = "ad_network=5450213213286189855&ad_unit=9448608978" +
  "&custom_data=x1%3Afc8e1922-3e3c-4be1-b632-5d21e924ab73&reward_amount=1" +
  "&reward_item=reward_step&timestamp=1790909000000&transaction_id=abc" +
  "&user_id=fc8e1922-3e3c-4be1-b632-5d21e924ab73";
const b64url = (b: Uint8Array) =>
  btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const urlFor = (signedText: string, query = content) =>
  new URL(`http://x/admob_ssv?${query}&signature=${b64url(sign("sha256", new TextEncoder().encode(signedText), privateKey))}&key_id=${KEY_ID}`);

Deno.test("Google signs the decoded query: a ':' in custom data arrives as %3A", async () => {
  assertEquals(await verifySsv(urlFor(decodeURIComponent(content)), async () => keys), "valid");
});
Deno.test("a callback with nothing to decode still verifies", async () => {
  assertEquals(await verifySsv(urlFor(content), async () => keys), "valid");
});
Deno.test("a tampered amount is refused", async () => {
  const url = urlFor(decodeURIComponent(content));
  const bad = new URL(url.href.replace("reward_amount=1", "reward_amount=9"));
  assertEquals(await verifySsv(bad, async () => keys), "invalid");
});

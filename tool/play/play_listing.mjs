// Store listing images through the Android Publisher API.
//   node play_listing.mjs <service-account.json> --probe
//   node play_listing.mjs <service-account.json> <upload-dir> <lang,lang,...>
// --probe opens an edit, prints each listing language and its image counts,
// and deletes the edit (nothing changes). Upload mode replaces phoneScreenshots
// and featureGraphic for each language with the files in <upload-dir>
// (mm14_screen_*.png in name order, mm14_feature_graphic.png) and commits.
// Prints no key material.
import { readFileSync, readdirSync } from "node:fs";
import { createSign } from "node:crypto";
import { join } from "node:path";

const [keyPath, dirOrProbe, langsArg] = process.argv.slice(2);
const PKG = "com.mafiamaster.mafia_master";
const key = JSON.parse(readFileSync(keyPath, "utf8"));
const API = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PKG}`;
const UP = `https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${PKG}`;

async function token() {
  const now = Math.floor(Date.now() / 1000);
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const head = b64({ alg: "RS256", typ: "JWT" });
  const body = b64({
    iss: key.client_email, scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  });
  const sign = createSign("RSA-SHA256");
  sign.update(`${head}.${body}`);
  const jwt = `${head}.${body}.${sign.sign(key.private_key, "base64url")}`;
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  if (!r.ok) throw new Error(`token ${r.status}`);
  return (await r.json()).access_token;
}

async function call(t, method, url, body, type = "application/json") {
  const r = await fetch(url, {
    method, headers: { authorization: `Bearer ${t}`, ...(body ? { "content-type": type } : {}) },
    body: body ?? undefined,
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`${method} ${url.replace(API, "").replace(UP, "")} -> ${r.status} ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : {};
}

const t = await token();
const edit = await call(t, "POST", `${API}/edits`, "{}");
const listings = (await call(t, "GET", `${API}/edits/${edit.id}/listings`)).listings ?? [];
if (dirOrProbe === "--probe") {
  for (const l of listings) {
    const shots = await call(t, "GET", `${API}/edits/${edit.id}/listings/${l.language}/phoneScreenshots`);
    const feat = await call(t, "GET", `${API}/edits/${edit.id}/listings/${l.language}/featureGraphic`);
    console.log(`listing ${l.language}: ${(shots.images ?? []).length} phone screenshots, ${(feat.images ?? []).length} feature graphic, video ${l.video ? "set" : "none"}`);
  }
  await call(t, "DELETE", `${API}/edits/${edit.id}`);
  console.log("PROBE OK (edit deleted, nothing changed)");
  process.exit(0);
}

const langs = langsArg ? langsArg.split(",") : listings.map((l) => l.language);
const shots = readdirSync(dirOrProbe).filter((f) => /^mm14_screen_\d+\.png$/.test(f)).sort();
const feature = join(dirOrProbe, "mm14_feature_graphic.png");
// A dropped link mid-language redoes that language from its delete, so a
// screenshot that landed before the drop is never uploaded twice.
const pause = (ms) => new Promise((r) => setTimeout(r, ms));
for (const lang of langs) {
  const base = `edits/${edit.id}/listings/${lang}`;
  for (let attempt = 1; ; attempt++) {
    try {
      await call(t, "DELETE", `${API}/${base}/phoneScreenshots`);
      for (const f of shots) {
        await call(t, "POST", `${UP}/${base}/phoneScreenshots?uploadType=media`, readFileSync(join(dirOrProbe, f)), "image/png");
      }
      await call(t, "DELETE", `${API}/${base}/featureGraphic`);
      await call(t, "POST", `${UP}/${base}/featureGraphic?uploadType=media`, readFileSync(feature), "image/png");
      break;
    } catch (e) {
      if (!/fetch failed|-> 5\d\d/.test(String(e.message)) || attempt >= 5) throw e;
      console.log(`listing ${lang}: link dropped (${attempt}), redoing this language`);
      await pause(5000);
    }
  }
  console.log(`listing ${lang}: ${shots.length} screenshots and the feature graphic set`);
}
// 403 until the owner grants store presence: retry once a minute on the same
// edit for COMMIT_WAIT_MINUTES (default 60); a dropped link or 5xx also passes.
const waitMinutes = Number(process.env.COMMIT_WAIT_MINUTES ?? 60);
for (let attempt = 1; ; attempt++) {
  try { await call(await token(), "POST", `${API}/edits/${edit.id}:commit`); break; }
  catch (e) {
    if (!/fetch failed|-> (403|5\d\d)/.test(String(e.message)) || attempt >= waitMinutes) throw e;
    if (attempt === 1 || attempt % 15 === 0) console.log(`commit refused (${String(e.message).match(/-> (\d+)/)?.[1] ?? "link"}), waiting for the store permission (${attempt})`);
    await pause(60000);
  }
}
console.log("COMMITTED listing images");

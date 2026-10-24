// Uploads an AAB to a Play track through the Android Publisher API.
//   node play_upload.mjs <service-account.json> <app.aab|--probe> <track> [notes-ar.txt] [notes-en.txt]
// --probe opens an edit, lists the tracks and commits it empty: it proves the
// account may release without uploading anything. Prints no key material.
import { readFileSync, statSync, openSync, readSync, closeSync } from "node:fs";
import { createSign } from "node:crypto";
import { request } from "node:https";

const [keyPath, aab, track = "alpha", notesAr, notesEn] = process.argv.slice(2);
const PKG = "com.mafiamaster.mafia_master";
const key = JSON.parse(readFileSync(keyPath, "utf8"));
const API = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PKG}`;

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
  if (!r.ok) throw new Error(`${method} ${url.replace(API, "")} -> ${r.status} ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : {};
}

let t = await token();
const edit = await call(t, "POST", `${API}/edits`, "{}");
console.log("edit opened");
if (aab === "--probe") {
  const tracks = await call(t, "GET", `${API}/edits/${edit.id}/tracks`);
  for (const tr of tracks.tracks ?? []) {
    const rel = (tr.releases ?? []).map((x) => `${x.name ?? "?"}:${x.status}:${(x.versionCodes ?? []).join("/")}`);
    console.log(`track ${tr.track}: ${rel.join(", ") || "-"}`);
  }
  await call(t, "POST", `${API}/edits/${edit.id}:commit`);
  console.log("PROBE OK: this account may commit releases");
  process.exit(0);
}
// Resumable upload in 8 MiB pieces: a dropped link resumes from the byte
// Google confirms, and node:https has no 5-minute wait for the last reply.
function put(url, headers, body) {
  return new Promise((resolve, reject) => {
    const req = request(url, { method: "PUT", headers }, (res) => {
      const parts = [];
      res.on("data", (c) => parts.push(c));
      res.on("end", () => resolve({ status: res.statusCode, headers: res.headers,
        text: Buffer.concat(parts).toString() }));
    });
    req.setTimeout(30 * 60 * 1000, () => req.destroy(new Error("piece timeout")));
    req.on("error", reject);
    req.end(body);
  });
}
const pause = (ms) => new Promise((r) => setTimeout(r, ms));
async function uploadBundle(path) {
  const size = statSync(path).size;
  const init = await fetch(
    `https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${PKG}/edits/${edit.id}/bundles?uploadType=resumable`,
    { method: "POST", body: "{}", headers: { authorization: `Bearer ${t}`,
      "content-type": "application/json; charset=UTF-8",
      "x-upload-content-type": "application/octet-stream",
      "x-upload-content-length": String(size) } });
  if (!init.ok) throw new Error(`upload start ${init.status} ${(await init.text()).slice(0, 300)}`);
  const session = init.headers.get("location");
  const PIECE = 8 * 1024 * 1024;
  const fd = openSync(path, "r");
  let offset = 0, failures = 0;
  try {
    for (;;) {
      const end = Math.min(offset + PIECE, size);
      const buf = Buffer.alloc(end - offset);
      readSync(fd, buf, 0, buf.length, offset);
      let r = await put(session, { "content-length": String(buf.length),
        "content-range": `bytes ${offset}-${end - 1}/${size}` }, buf).catch((e) => e);
      if (r instanceof Error || r.status >= 500) {
        if (++failures > 30) throw r instanceof Error ? r : new Error(`upload ${r.status}`);
        console.log(`piece at ${offset} failed (${r instanceof Error ? r.message : r.status}); asking where to resume`);
        await pause(5000);
        r = await put(session, { "content-length": "0", "content-range": `bytes */${size}` },
          Buffer.alloc(0)).catch(() => null);
        if (!r || r.status >= 500) continue;
      }
      if (r.status === 200 || r.status === 201) return JSON.parse(r.text);
      if (r.status !== 308) throw new Error(`upload ${r.status} ${r.text.slice(0, 300)}`);
      offset = r.headers.range ? Number(String(r.headers.range).split("-")[1]) + 1 : 0;
      console.log(`sent ${(offset / 1e6).toFixed(0)} / ${(size / 1e6).toFixed(0)} MB`);
    }
  } finally { closeSync(fd); }
}
console.log(`uploading ${(statSync(aab).size / 1e6).toFixed(1)} MB`);
const up = await uploadBundle(aab);
console.log(`bundle versionCode ${up.versionCode}`);
t = await token(); // a slow upload can outlive the first hour-long token
const notes = [];
if (notesAr) notes.push({ language: "ar", text: readFileSync(notesAr, "utf8").trim() });
if (notesEn) notes.push({ language: "en-US", text: readFileSync(notesEn, "utf8").trim() });
await call(t, "PUT", `${API}/edits/${edit.id}/tracks/${track}`, JSON.stringify({
  track, releases: [{ versionCodes: [String(up.versionCode)], status: "completed", releaseNotes: notes }],
}));
console.log(`track ${track} set`);
// The release permission may be granted while this waits: retry a refused
// commit once a minute on the same edit (an hour, or COMMIT_WAIT_MINUTES), so nothing re-uploads.
const waitMinutes = Number(process.env.COMMIT_WAIT_MINUTES ?? 60);
for (let tries = 1; ; tries++) {
  try { await call(await token(), "POST", `${API}/edits/${edit.id}:commit`); break; }
  catch (e) {
    // 403 until the permission is granted; a 5xx is Google's own and passes.
    if (!/-> (403|5\d\d)/.test(String(e.message)) || tries >= waitMinutes) throw e;
    console.log(`commit refused (403), waiting for the release permission (${tries})`);
    await pause(60000);
  }
}
console.log(`COMMITTED versionCode ${up.versionCode} to ${track}`);

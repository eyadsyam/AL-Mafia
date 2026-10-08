#!/usr/bin/env node
// Listens back to installed voice lines: ElevenLabs speech-to-text on every
// clip, compared with the words it was meant to say. Prints one line per
// clip with a 0-100 match and the duration, and flags anything under 80.
//
//   node tool/voice/verify.mjs haytham
//   node tool/voice/verify.mjs narrator_noir stories

import { readFileSync, existsSync, readdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..", "..");
const arb = JSON.parse(readFileSync(join(root, "lib", "app", "l10n", "app_ar.arb"), "utf8"));
const bank = JSON.parse(readFileSync(join(here, "kratos_lines.json"), "utf8"));
const file = join(homedir(), ".mafia-master", "elevenlabs.key");
const key = process.env.ELEVENLABS_API_KEY || (existsSync(file) ? (readFileSync(file, "utf8").match(/sk_[A-Za-z0-9]+/) ?? [""])[0] : "");
if (!key) process.exit(2);

const PACK_KEYS = {
  narrator_storyteller: { night: "narratorNight", morning: "narratorMorning", discussion: "narratorDiscussion", voting: "narratorVoting", win: "narratorResult" },
  narrator_keeper: { night: "narratorKeeperNight", morning: "narratorKeeperMorning", discussion: "narratorKeeperDiscussion", voting: "narratorKeeperVoting", win: "narratorKeeperResult" },
  narrator_noir: { night: "narratorNoirNight", morning: "narratorNoirMorning", discussion: "narratorNoirDiscussion", voting: "narratorNoirVoting", win: "narratorNoirResult" },
};

// Letters only, with the spellings speech-to-text merges folded together.
const norm = (s) =>
  s.replace(/[ً-ْـ]/g, "")
    .replace(/[أإآ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه")
    .replace(/[^ء-ي0-9]/g, "");

function similarity(a, b) {
  a = norm(a); b = norm(b);
  if (!a.length && !b.length) return 100;
  const d = Array.from({ length: a.length + 1 }, (_, i) => [i]);
  for (let j = 1; j <= b.length; j++) d[0][j] = j;
  for (let i = 1; i <= a.length; i++)
    for (let j = 1; j <= b.length; j++)
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
  return Math.round(100 * (1 - d[a.length][b.length] / Math.max(a.length, b.length)));
}

function duration(path) {
  const out = execFileSync("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]).toString();
  return Number(out).toFixed(1);
}

async function transcribe(path) {
  const form = new FormData();
  form.append("model_id", "scribe_v1");
  form.append("language_code", "ara");
  form.append("file", new Blob([readFileSync(path)]), "clip.ogg");
  const r = await fetch("https://api.elevenlabs.io/v1/speech-to-text", { method: "POST", headers: { "xi-api-key": key }, body: form });
  if (!r.ok) throw new Error(`stt HTTP ${r.status}`);
  return (await r.json()).text ?? "";
}

let flagged = 0;
for (const pack of process.argv.slice(2)) {
  const items = [];
  if (pack === "haytham") {
    for (const l of bank.lines) items.push([join(root, "assets/voice/haytham", `${l.id}.ogg`), l.text]);
  } else if (pack === "stories") {
    for (const f of readdirSync(join(root, "assets/stories")).filter((f) => f.endsWith(".json"))) {
      const s = JSON.parse(readFileSync(join(root, "assets/stories", f), "utf8"));
      items.push([join(root, "assets/voice/stories", `${s.id}.ogg`), `${s.title}. ${s.synopsis}`]);
    }
  } else {
    for (const [beat, k] of Object.entries(PACK_KEYS[pack])) items.push([join(root, "assets/voice", pack, `${beat}.ogg`), arb[k]]);
  }
  for (const [path, text] of items) {
    if (!existsSync(path)) { console.log(`MISSING ${path}`); flagged++; continue; }
    const heard = await transcribe(path);
    const score = similarity(text, heard);
    if (score < 80) flagged++;
    console.log(`${score < 80 ? "CHECK" : "ok   "} ${score}% ${duration(path)}s ${pack}/${path.split(/[\\/]/).pop()}${score < 80 ? `  heard: ${heard}` : ""}`);
  }
}
console.log(`flagged: ${flagged}`);

#!/usr/bin/env node
// Renders every narrator line, store pack and story opening from
// tool/voice/script_v2.json (Cairene text the owner reviews first) and
// installs them for the app:
//
//   assets/voice/narrator/<id>.ogg + manifest.json   the match narrator
//   assets/voice/<pack>/<id>.ogg + manifest.json      the three store packs
//   assets/voice/stories/<story id>.ogg               each case's opening,
//                                                     and `narrationAudio` in
//                                                     assets/stories/<id>.json
//
//   node tool/voice/render_v2.mjs                       every line
//   node tool/voice/render_v2.mjs --only main --ids night_01
//
// The script is spelled the ordinary way (ق stays ق) and every line gains a
// "strong Egyptian accent" tag: the owner's ear picked that over hamza
// spelling and IPA, because eleven_v4 then says the word the Cairo way.
// The key is read like the other voice tools and is never printed.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { homedir, tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..", "..");
const script = JSON.parse(readFileSync(join(here, "script_v2.json"), "utf8"));

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : fallback;
};
const only = new Set(opt("only", "main,narrator_storyteller,narrator_keeper,narrator_noir,stories").split(","));
const ids = opt("ids", null) ? new Set(opt("ids").split(",")) : null;
const model = opt("model", "eleven_v4");

const file = join(homedir(), ".mafia-master", "elevenlabs.key");
const key = process.env.ELEVENLABS_API_KEY || (existsSync(file) ? (readFileSync(file, "utf8").match(/sk_[A-Za-z0-9]+/) ?? [""])[0] : "");
if (!key) {
  console.error("No ElevenLabs key.");
  process.exit(2);
}
const api = "https://api.elevenlabs.io/v1";
const headers = { "xi-api-key": key, "content-type": "application/json" };

const HEAVY = "asetrate=44100*0.95,aresample=44100,bass=g=4:f=110,acompressor=threshold=0.125:ratio=3:attack=5:release=90,aecho=0.8:0.35:60:0.1";
const FILTER = "adelay=120|120,silenceremove=start_periods=1:start_threshold=-60dB:start_silence=0.25,areverse,silenceremove=start_periods=1:start_threshold=-55dB:start_silence=0.3,areverse,loudnorm=I=-16:TP=-1.5:LRA=7";
const ACCENT = "strong Egyptian accent";

function prepare(text) {
  // The leading direction gains the accent; later ones stay as written.
  const out = text.replace(/^\[([^\]]*)\]/, (m, d) => `[${ACCENT}, ${d}]`);
  return out.startsWith("[") ? out : `[${ACCENT}] ${out}`;
}

async function ensureVoices() {
  const mine = await (await fetch(`${api}/voices`, { headers })).json();
  const have = new Set((mine.voices ?? []).map((v) => v.voice_id));
  for (const v of Object.values(script.voices)) {
    if (have.has(v.id)) continue;
    const term = v.name.split(" ")[0].toLowerCase();
    const found = await (await fetch(`${api}/shared-voices?page_size=50&search=${term}`, { headers })).json();
    const s = (found.voices ?? []).find((x) => x.voice_id === v.id);
    if (!s) throw new Error(`voice ${v.name} not in the library`);
    const r = await fetch(`${api}/voices/add/${s.public_owner_id}/${v.id}`, { method: "POST", headers, body: JSON.stringify({ new_name: s.name }) });
    if (!r.ok) throw new Error(`add ${v.name}: HTTP ${r.status}`);
    have.add(v.id);
  }
}

// Safari plays no ogg: the web build loads this twin instead.
const mp3Twin = (ogg) =>
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", ogg, "-c:a", "libmp3lame", "-b:a", "96k", ogg.replace(/\.ogg$/, ".mp3")]);

let chars = 0;
async function render(voice, text, ogg) {
  const spoken = prepare(text);
  const r = await fetch(`${api}/text-to-speech/${voice.id}?output_format=mp3_44100_128`, {
    method: "POST",
    headers: { ...headers, accept: "audio/mpeg" },
    body: JSON.stringify({ text: spoken, model_id: model, voice_settings: { stability: 0.5, similarity_boost: 0.85 } }),
  });
  if (r.status === 402) {
    console.error("ElevenLabs: this account needs a paid plan for library voices.");
    process.exit(3);
  }
  if (!r.ok) throw new Error(`HTTP ${r.status}: ${(await r.text()).slice(0, 200)}`);
  const mp3 = join(tmpdir(), `v2_${Date.now()}.mp3`);
  writeFileSync(mp3, Buffer.from(await r.arrayBuffer()));
  const af = voice.heavy ? `${HEAVY},${FILTER}` : FILTER;
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", mp3, "-af", af, "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", ogg]);
  mp3Twin(ogg);
  chars += spoken.length;
}

await ensureVoices();

const groups = [["main", "narrator", script.main], ...Object.entries(script.packs).map(([k, v]) => [k, k, v])];
for (const [code, dir, lines] of groups) {
  if (!only.has(code)) continue;
  const voice = script.voices[code];
  const out = join(root, "assets", "voice", dir);
  mkdirSync(out, { recursive: true });
  const clips = [];
  // A store voice speaks every moment the main narrator does: each main
  // moment the pack has no line of its own for is read in the pack's voice.
  const own = new Set(lines.map((l) => `${l.beat}|${l.when}`));
  const full = code === "main" ? [] : script.main.filter((l) => !own.has(`${l.beat}|${l.when}`)).map((l) => ({ ...l, id: `full_${l.id}` }));
  for (const l of [...lines, ...full]) {
    const ogg = join(out, `${l.id}.ogg`);
    if (!ids || ids.has(l.id)) {
      await render(voice, l.text, ogg);
      console.log(`${dir}/${l.id}.ogg`);
    } else if (existsSync(ogg)) {
      mp3Twin(ogg);
    }
    clips.push({ id: code === "main" ? l.id : `${code}_${l.id}`, beat: l.beat, when: l.when, family: true, file: `voice/${dir}/${l.id}.ogg` });
  }
  writeFileSync(join(out, "manifest.json"), JSON.stringify({ voice: dir, voiceId: voice.id, model, clips }, null, 2) + "\n");
}

if (only.has("stories")) {
  const voice = script.voices.stories;
  const out = join(root, "assets", "voice", "stories");
  mkdirSync(out, { recursive: true });
  for (const [id, text] of Object.entries(script.stories)) {
    if (ids && !ids.has(id)) continue;
    await render(voice, text, join(out, `${id}.ogg`));
    const path = join(root, "assets", "stories", `${id}.json`);
    const raw = readFileSync(path, "utf8");
    const story = JSON.parse(raw);
    story.narrationAudio = `assets/voice/stories/${id}.ogg`;
    const nl = raw.includes("\r\n") ? "\r\n" : "\n";
    writeFileSync(path, (JSON.stringify(story, null, 2) + "\n").replace(/\n/g, nl));
    console.log(`stories/${id}.ogg`);
  }
}
console.log(`characters sent: ${chars}`);

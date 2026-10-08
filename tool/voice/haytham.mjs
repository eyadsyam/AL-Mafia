#!/usr/bin/env node
// Egyptian narrator voices from the ElevenLabs voice library (owner,
// 2026-10-08): «Haytham» is the game's narrator, three more Egyptian voices
// speak the store packs, and the stories mode reads each case's opening.
//
// Library voices render through the API on a paid plan only (a free account
// answers 402 «paid_plan_required»), and a paid plan is also what grants
// commercial use of the audio. `--check` renders one short line and says
// which of the two it is, spending a few characters.
//
//   node tool/voice/haytham.mjs --check
//   node tool/voice/haytham.mjs                 every pack and every story
//   node tool/voice/haytham.mjs --only main,stories
//
// Writes mono Ogg Vorbis (trimmed, -16 LUFS) into assets/voice/<pack>/ with a
// manifest the app's NarratorBank reads, and `narrationAudio` into each
// assets/stories/<id>.json. The key is read like generate_kratos.mjs reads it
// and is never printed.

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { homedir, tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..", "..");
const arb = JSON.parse(readFileSync(join(root, "lib", "app", "l10n", "app_ar.arb"), "utf8"));
const bank = JSON.parse(readFileSync(join(here, "kratos_lines.json"), "utf8"));

// Library voices (public owner, voice id). Added to the account on first use.
const VOICES = {
  haytham: "wxweiHvoC2r2jFM7mS8b", // Haytham - Dramatic and Narrative
  haythamWarm: "UR972wNGq3zluze0LoIp", // Haytham - Dramatic, Warm and Friendly
  haythamBright: "IES4nrmZdUBHByLBde0P", // Haytham - Energetic, Warm and Cheerful
  fatima: "I3u6waC588j43py1kDN2", // Fatima - Expressive Egyptian
  mamdoh: "68MRVrnQAt8vLbu0FCzw", // Mamdoh - Deep Egyptian Arabic Male
};

const PACKS = {
  // The narrator every match speaks with: the 35 lines of kratos_lines.json.
  main: {
    dir: "haytham",
    voice: VOICES.haytham,
    settings: { stability: 0.45, similarity_boost: 0.85, style: 0.4, use_speaker_boost: true },
    effect: "aecho=0.8:0.4:40:0.12",
  },
  narrator_storyteller: {
    voice: VOICES.haythamWarm,
    settings: { stability: 0.35, similarity_boost: 0.85, style: 0.6, use_speaker_boost: true },
    effect: "atempo=0.95,bass=g=2:f=180,aecho=0.8:0.5:45:0.16",
    keys: { night: "narratorNight", morning: "narratorMorning", discussion: "narratorDiscussion", voting: "narratorVoting", win: "narratorResult" },
  },
  narrator_keeper: {
    voice: VOICES.fatima,
    settings: { stability: 0.7, similarity_boost: 0.9, style: 0.15, use_speaker_boost: true },
    effect: "atempo=0.97,aecho=0.8:0.75:110|230:0.3|0.16",
    keys: { night: "narratorKeeperNight", morning: "narratorKeeperMorning", discussion: "narratorKeeperDiscussion", voting: "narratorKeeperVoting", win: "narratorKeeperResult" },
  },
  narrator_noir: {
    voice: VOICES.mamdoh,
    settings: { stability: 0.55, similarity_boost: 0.85, style: 0.45, use_speaker_boost: true },
    effect: "highpass=f=180,lowpass=f=3800,acompressor=threshold=0.1:ratio=4",
    keys: { night: "narratorNoirNight", morning: "narratorNoirMorning", discussion: "narratorNoirDiscussion", voting: "narratorNoirVoting", win: "narratorNoirResult" },
  },
};

// The stories' two readers: dramatic Haytham for the hard cases, the
// brighter Haytham for the rest.
const STORY_VOICE = (difficulty) => (difficulty >= 4 ? VOICES.haytham : VOICES.haythamBright);
const STORY_SETTINGS = { stability: 0.45, similarity_boost: 0.85, style: 0.45, use_speaker_boost: true };

const args = process.argv.slice(2);
const check = args.includes("--check");
const i = args.indexOf("--only");
const only = i >= 0 ? args[i + 1].split(",") : [...Object.keys(PACKS), "stories"];
// --ids night_01,voting_03 re-renders just those lines of the main pack (or
// those story ids), keeping every other file and the manifest as they are.
const j = args.indexOf("--ids");
const ids = j >= 0 ? new Set(args[j + 1].split(",")) : null;

function keyFromFile() {
  const file = join(homedir(), ".mafia-master", "elevenlabs.key");
  if (!existsSync(file)) return "";
  const m = readFileSync(file, "utf8").match(/sk_[A-Za-z0-9]+/);
  return m ? m[0] : "";
}
const key = process.env.ELEVENLABS_API_KEY || keyFromFile();
if (!key) {
  console.error("No ElevenLabs key.");
  process.exit(2);
}
const api = "https://api.elevenlabs.io/v1";
const headers = { "xi-api-key": key, "content-type": "application/json" };

const FILTER = [
  "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05",
  "areverse",
  "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08",
  "areverse",
  "loudnorm=I=-16:TP=-1.5:LRA=7",
].join(",");

async function ensureVoices() {
  const mine = await (await fetch(`${api}/voices`, { headers })).json();
  const have = new Set((mine.voices ?? []).map((v) => v.voice_id));
  for (const id of new Set(Object.values(VOICES))) {
    if (have.has(id)) continue;
    const term = id === VOICES.fatima ? "fatima" : id === VOICES.mamdoh ? "mamdoh" : "haytham";
    const found = await (await fetch(`${api}/shared-voices?page_size=30&search=${term}`, { headers })).json();
    const v = (found.voices ?? []).find((x) => x.voice_id === id);
    if (!v) throw new Error(`voice ${id} not in the library`);
    const r = await fetch(`${api}/voices/add/${v.public_owner_id}/${id}`, {
      method: "POST",
      headers,
      body: JSON.stringify({ new_name: v.name }),
    });
    if (!r.ok) throw new Error(`add ${v.name}: HTTP ${r.status}`);
    console.log(`added ${v.name}`);
  }
}

async function speak(voice, text, settings) {
  const r = await fetch(`${api}/text-to-speech/${voice}?output_format=mp3_44100_128`, {
    method: "POST",
    headers: { ...headers, accept: "audio/mpeg" },
    body: JSON.stringify({ text, model_id: "eleven_multilingual_v2", voice_settings: settings }),
  });
  if (r.status === 402) {
    console.error("ElevenLabs: this account needs a paid plan to use library voices through the API.");
    process.exit(3);
  }
  if (!r.ok) throw new Error(`HTTP ${r.status}: ${(await r.text()).slice(0, 200)}`);
  return Buffer.from(await r.arrayBuffer());
}

function install(mp3Bytes, effect, ogg) {
  const mp3 = join(tmpdir(), `voice_${Date.now()}.mp3`);
  writeFileSync(mp3, mp3Bytes);
  const af = effect ? `${effect},${FILTER}` : FILTER;
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", mp3, "-af", af, "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", ogg]);
}

if (check) {
  await ensureVoices();
  await speak(VOICES.haytham, "الليل نزل.", PACKS.main.settings);
  console.log("ok: library voices render on this account.");
  process.exit(0);
}

await ensureVoices();

for (const code of only) {
  if (code === "stories") continue;
  const pack = PACKS[code];
  if (!pack) throw new Error(`unknown pack ${code}`);
  const dir = pack.dir ?? code;
  const out = join(root, "assets", "voice", dir);
  mkdirSync(out, { recursive: true });
  const clips = [];
  const lines = pack.keys
    ? Object.entries(pack.keys).map(([beat, k]) => ({ id: `${code}_${beat}`, beat, when: "always", family: true, text: arb[k], file: `${beat}.ogg` }))
    : bank.lines.map((l) => ({ ...l, file: `${l.id}.ogg` }));
  for (const line of lines) {
    if (ids && !ids.has(line.id)) {
      clips.push({ id: line.id, beat: line.beat, when: line.when, family: line.family, file: `voice/${dir}/${line.file}` });
      continue;
    }
    install(await speak(pack.voice, line.text, pack.settings), pack.effect, join(out, line.file));
    clips.push({ id: line.id, beat: line.beat, when: line.when, family: line.family, file: `voice/${dir}/${line.file}` });
    console.log(`${dir}/${line.file}`);
  }
  writeFileSync(join(out, "manifest.json"), JSON.stringify({ voice: dir, voiceId: pack.voice, clips }, null, 2) + "\n");
}

if (only.includes("stories")) {
  const out = join(root, "assets", "voice", "stories");
  mkdirSync(out, { recursive: true });
  for (const f of readdirSync(join(root, "assets", "stories")).filter((f) => f.endsWith(".json"))) {
    const path = join(root, "assets", "stories", f);
    const raw = readFileSync(path, "utf8");
    const story = JSON.parse(raw);
    if (ids && !ids.has(story.id)) continue;
    const text = `${story.title}. ${story.synopsis}`;
    const ogg = join(out, `${story.id}.ogg`);
    install(await speak(STORY_VOICE(story.difficulty), text, STORY_SETTINGS), "", ogg);
    story.narrationAudio = `assets/voice/stories/${story.id}.ogg`;
    const nl = raw.includes("\r\n") ? "\r\n" : "\n";
    writeFileSync(path, (JSON.stringify(story, null, 2) + "\n").replace(/\n/g, nl));
    console.log(`stories/${story.id}.ogg`);
  }
}
console.log("done. Add assets/voice/haytham/ and assets/voice/stories/ to pubspec.yaml if missing.");

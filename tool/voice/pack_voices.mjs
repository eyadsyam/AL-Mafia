#!/usr/bin/env node
// Gives each store narrator pack its own spoken voice.
//
// For every pack in PACKS: renders the pack's five caption lines (the same
// words the pack shows on screen) with the Kratos narrator voice, each pack in
// its own delivery (voice settings) and its own room (an ffmpeg treatment),
// and installs them as assets/voice/<code>/<beat>.ogg plus a manifest the
// app's NarratorBank reads. (Library and designed voices need a paid plan
// through the API; Kratos is the voice this account can render.)
//
// The key is read exactly as generate_kratos.mjs reads it (ELEVENLABS_API_KEY
// or ~/.mafia-master/elevenlabs.key) and is never printed.
//
//   node tool/voice/pack_voices.mjs            render and install every pack
//   node tool/voice/pack_voices.mjs --only narrator_noir

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { homedir, tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..", "..");
const arb = JSON.parse(readFileSync(join(root, "lib", "app", "l10n", "app_ar.arb"), "utf8"));
const kratos = JSON.parse(readFileSync(join(here, "kratos_lines.json"), "utf8")).voice_id;

// The pack's caption keys per app beat. `win` is the match's end, where the
// pack's closing line belongs; the day's vote result keeps its written line.
const PACKS = {
  narrator_storyteller: {
    name: "Mafia Storyteller",
    description:
      "An old Egyptian storyteller (hakawati) in his sixties, warm, deep and slightly husky voice, speaking Egyptian Arabic slowly and theatrically, like telling a tale in a Cairo coffee house at night. Intimate, captivating, a little mischievous.",
    settings: { stability: 0.3, similarity_boost: 0.85, style: 0.65, use_speaker_boost: true },
    // Slower, warmer, a small coffee-house room.
    effect: "atempo=0.93,bass=g=3:f=180,aecho=0.8:0.5:45:0.18",
    keys: { night: "narratorNight", morning: "narratorMorning", discussion: "narratorDiscussion", voting: "narratorVoting", win: "narratorResult" },
  },
  narrator_keeper: {
    name: "Mafia Keeper",
    description:
      "A composed middle-aged Egyptian woman, the keeper of an old archive of secrets. Low, calm, velvety voice, speaking Egyptian Arabic softly and deliberately, almost a whisper, grave and mysterious.",
    settings: { stability: 0.75, similarity_boost: 0.9, style: 0.1, use_speaker_boost: true },
    // Grave and even, in a stone archive hall.
    effect: "atempo=0.97,aecho=0.8:0.75:110|230:0.32|0.18",
    keys: { night: "narratorKeeperNight", morning: "narratorKeeperMorning", discussion: "narratorKeeperDiscussion", voting: "narratorKeeperVoting", win: "narratorKeeperResult" },
  },
  narrator_noir: {
    name: "Mafia Noir",
    description:
      "A hard-boiled Egyptian detective narrator in his forties, gravelly low voice, tired and cynical, short clipped sentences in Egyptian Arabic, like a film noir voice-over on a rainy Cairo night.",
    settings: { stability: 0.55, similarity_boost: 0.85, style: 0.45, use_speaker_boost: true },
    // A lower pitch through an old radio: film-noir voice-over.
    effect: "asetrate=44100*0.9,aresample=44100,atempo=1.08,highpass=f=220,lowpass=f=3600,acompressor=threshold=0.1:ratio=4",
    keys: { night: "narratorNoirNight", morning: "narratorNoirMorning", discussion: "narratorNoirDiscussion", voting: "narratorNoirVoting", win: "narratorNoirResult" },
  },
};

const args = process.argv.slice(2);
const i = args.indexOf("--only");
const only = i >= 0 ? args[i + 1].split(",") : Object.keys(PACKS);

function keyFromFile() {
  const file = join(homedir(), ".mafia-master", "elevenlabs.key");
  if (!existsSync(file)) return "";
  const line = readFileSync(file, "utf8").split(/\r?\n/).map((l) => l.trim()).find((l) => l && !l.startsWith("#"));
  return line && !line.includes(" ") ? line : "";
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

for (const code of only) {
  const pack = PACKS[code];
  if (!pack) throw new Error(`unknown pack ${code}`);
  const out = join(root, "assets", "voice", code);
  mkdirSync(out, { recursive: true });
  const clips = [];
  for (const [beat, arbKey] of Object.entries(pack.keys)) {
    const text = arb[arbKey];
    const r = await fetch(`${api}/text-to-speech/${kratos}?output_format=mp3_44100_128`, {
      method: "POST",
      headers: { ...headers, accept: "audio/mpeg" },
      body: JSON.stringify({
        text,
        model_id: "eleven_multilingual_v2",
        voice_settings: pack.settings,
      }),
    });
    if (!r.ok) throw new Error(`${code}/${beat}: HTTP ${r.status}`);
    const mp3 = join(tmpdir(), `${code}_${beat}.mp3`);
    writeFileSync(mp3, Buffer.from(await r.arrayBuffer()));
    const ogg = join(out, `${beat}.ogg`);
    execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", mp3, "-af", `${pack.effect},${FILTER}`, "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", ogg]);
    clips.push({ id: `${code}_${beat}`, beat, when: "always", family: true, file: `voice/${code}/${beat}.ogg` });
    console.log(`${code}/${beat}`);
  }
  writeFileSync(join(out, "manifest.json"), JSON.stringify({ voice: code, clips }, null, 2) + "\n");
}

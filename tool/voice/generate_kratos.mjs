#!/usr/bin/env node
// Renders the F16 narrator line bank with the owner's ElevenLabs voice.
//
// The API key is read only from ELEVENLABS_API_KEY and is never printed,
// logged or written anywhere. Nothing ships from this script: it writes
// candidate audio plus a provenance record for the F16 listener gate.
//
//   node tool/voice/generate_kratos.mjs --probe            voice name + category only
//   node tool/voice/generate_kratos.mjs --dry-run          list what would render
//   node tool/voice/generate_kratos.mjs --only night_01,morning_none_01
//   node tool/voice/generate_kratos.mjs --model eleven_v3 --out build/voice_trial
//
// Default output: build/voice/kratos/<id>.mp3 (not an app asset until the
// gate passes and the owner approves tone and pronunciation).

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const bank = JSON.parse(readFileSync(join(here, "kratos_lines.json"), "utf8"));

const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const option = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const model = option("model", "eleven_multilingual_v2");
const outDir = resolve(option("out", join(here, "..", "..", "build", "voice", "kratos")));
const only = option("only", "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);
const settings = {
  stability: Number(option("stability", "0.45")),
  similarity_boost: Number(option("similarity", "0.85")),
  style: Number(option("style", "0.35")),
  use_speaker_boost: true,
};

const lines = bank.lines.filter((l) => only.length === 0 || only.includes(l.id));
const missing = only.filter((id) => !bank.lines.some((l) => l.id === id));
if (missing.length) {
  console.error(`Unknown line ids: ${missing.join(", ")}`);
  process.exit(2);
}

if (flag("dry-run")) {
  for (const l of lines) console.log(`${l.id}\t${l.beat}\t${l.when}\t${l.text}`);
  console.log(`${lines.length} lines, ${lines.reduce((n, l) => n + l.text.length, 0)} characters, model ${model}`);
  process.exit(0);
}

const key = process.env.ELEVENLABS_API_KEY;
if (!key) {
  console.error("ELEVENLABS_API_KEY is not set in this environment.");
  process.exit(2);
}

const api = "https://api.elevenlabs.io/v1";

if (flag("probe")) {
  const r = await fetch(`${api}/voices/${bank.voice_id}`, { headers: { "xi-api-key": key } });
  if (!r.ok) {
    console.error(`Probe failed: HTTP ${r.status}`);
    process.exit(1);
  }
  const v = await r.json();
  // Name and category only: "generated" means Voice Design, "cloned" means a recording.
  console.log(JSON.stringify({ name: v.name, category: v.category, labels: v.labels ?? {} }, null, 2));
  process.exit(0);
}

mkdirSync(outDir, { recursive: true });
const manifestPath = join(outDir, "PROVENANCE.json");
const manifest = existsSync(manifestPath)
  ? JSON.parse(readFileSync(manifestPath, "utf8"))
  : {
      pack: bank.pack,
      voice_id: bank.voice_id,
      commercial_use_authorization: "PENDING — recorded by the owner before any line ships",
      voice_origin: "PENDING — designed or cloned (run --probe)",
      renders: [],
    };

for (const l of lines) {
  const url = `${api}/text-to-speech/${bank.voice_id}?output_format=mp3_44100_128`;
  const r = await fetch(url, {
    method: "POST",
    headers: { "xi-api-key": key, "content-type": "application/json", accept: "audio/mpeg" },
    body: JSON.stringify({ text: l.text, model_id: model, voice_settings: settings }),
  });
  if (!r.ok) {
    console.error(`${l.id}: HTTP ${r.status}`);
    process.exitCode = 1;
    continue;
  }
  const audio = Buffer.from(await r.arrayBuffer());
  writeFileSync(join(outDir, `${l.id}.mp3`), audio);
  manifest.renders.push({
    id: l.id,
    text_sha256: createHash("sha256").update(l.text).digest("hex"),
    model,
    settings,
    rendered_at: new Date().toISOString(),
    bytes: audio.length,
  });
  console.log(`${l.id}\t${audio.length} bytes`);
}

writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
console.log(`Wrote ${lines.length} renders to ${outDir}`);

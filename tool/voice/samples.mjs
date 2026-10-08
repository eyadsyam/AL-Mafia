#!/usr/bin/env node
// One sample line per narrator persona, rendered at the moment it plays in
// the game, for the owner to judge before a whole pack is spent on.
//
//   node tool/voice/samples.mjs        → build/voice_samples/*.mp3 + lines.json
//
// The words are written the way a Cairene says them out loud, in everyday
// Egyptian Arabic: no Fusha, no diacritics except where a word would be read
// wrong, «…» where the voice should hold, and no ق-words a voice might read
// in Fusha. The key is read like the other voice tools and is never printed.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { homedir, tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const out = join(root, "build", "voice_samples");
mkdirSync(out, { recursive: true });

const file = join(homedir(), ".mafia-master", "elevenlabs.key");
const key = process.env.ELEVENLABS_API_KEY || (existsSync(file) ? (readFileSync(file, "utf8").match(/sk_[A-Za-z0-9]+/) ?? [""])[0] : "");
if (!key) process.exit(2);
const api = "https://api.elevenlabs.io/v1";
const headers = { "xi-api-key": key, "content-type": "application/json" };

// Slow, low and close: the voice that makes the table uneasy.
const HEAVY = "asetrate=44100*0.95,aresample=44100,atempo=1.0,bass=g=4:f=110,acompressor=threshold=0.125:ratio=3:attack=5:release=90,aecho=0.8:0.35:60:0.1";
const FILTER = "adelay=120|120,silenceremove=start_periods=1:start_threshold=-60dB:start_silence=0.25,areverse,silenceremove=start_periods=1:start_threshold=-55dB:start_silence=0.3,areverse,loudnorm=I=-16:TP=-1.5:LRA=7";
const slow = { stability: 0.55, similarity_boost: 0.85, style: 0.4, use_speaker_boost: true, speed: 0.88 };

// eleven_v3 reads the bracketed directions as delivery, not as words.
// No diacritics (they pull the voices toward Fusha); spelling follows how a
// Cairene says the word: ق is written as a hamza where Cairo drops it
// (أهوة, يئول, أبل, آعد).
const SAMPLES = [
  {
    file: "01_narrator_adam",
    who: "الراوي الأساسي — Adam (Deep, Rich)",
    when: "أول ما الليل يبدأ",
    feel: "بطيء وواطي، فيه تهديد، كأنه بيحذّر الترابيزة",
    voice: "OFHP1Qg30FPoNfkUFFlA",
    heavy: true,
    text: "[slowly, low and menacing] الليل دخل… [pause] غمضوا عنيكو. [low, threatening] ومن الليلة دي… خلي بالك من اللي جنبك.",
  },
  {
    file: "02_noir_mamdoh",
    who: "النوار (من المتجر) — Mamdoh",
    when: "الصبح، لما حد يكون مات بالليل",
    feel: "تعبان وبارد، زي محقق شاف كتير، وفي الآخر بيوطّي صوته",
    voice: "68MRVrnQAt8vLbu0FCzw",
    heavy: true,
    text: "[tired, cold] صحينا على خبر وحش… [pause] واحد مننا مش هيصحى تاني. [low, menacing] واللي عملها… لسه آعد معانا على نفس الترابيزة.",
  },
  {
    file: "03_storyteller_haytham",
    who: "الحكواتي (من المتجر) — Haytham",
    when: "أول النقاش",
    feel: "دافي وفيه شقاوة، بيشجّعهم يتكلموا وبعدين يلمّح إنه شايفهم",
    voice: "UR972wNGq3zluze0LoIp",
    heavy: false,
    text: "[warm, playful] يلا بينا يا جماعة… كل واحد يئول اللي في دماغه. [teasing, lower] بس خلي بالك… الكدب هنا بيبان من أول كلمة.",
  },
  {
    file: "04_keeper_fatima",
    who: "الحارسة (من المتجر) — Fatima",
    when: "قبل التصويت",
    feel: "هادية وجادة، بتتكلم براحة كأنها بتحمّلهم مسؤولية",
    voice: "I3u6waC588j43py1kDN2",
    heavy: false,
    text: "[calm, serious] خلاص… الكلام خلص. [softly] كل واحد يختار… وفكر كويس أبل ما تشاور، [grave] عشان صوتك ممكن يطلع واحد بريء.",
  },
  {
    file: "05_story_haytham",
    who: "قارئ القصص — Haytham (Dramatic)",
    when: "أول ما تفتح قصة «قهوة المعلم»",
    feel: "حكّاء، فيه تشويق، وبيشكّك في آخر الجملة",
    voice: "wxweiHvoC2r2jFM7mS8b",
    heavy: false,
    text: "[storytelling, intrigued] أهوة المعلم. [pause] المعلم صابر مات على كرسيه، وسط دوشة الدومنة. [suspicious] الشاي كان سليم… بس حجر الشيشة وصله متجهز، أبل ما الفحم يولع.",
  },
  {
    file: "06_keeper_sawsan",
    who: "الحارسة (من المتجر) — Sawsan",
    when: "قبل التصويت",
    feel: "ست كبيرة هادية وجادة، بتحمّلهم مسؤولية صوتهم",
    voice: "mS4cERRqrNy5Kmlx8Udf",
    heavy: false,
    text: "[calm, serious] خلاص… الكلام خلص. [softly] كل واحد يختار دلوقتي… بس فكّر كويس أبل ما تشاور، [grave] عشان صوتك ده ممكن يطلّع واحد بريء.",
  },
  {
    file: "07_keeper_heba",
    who: "الحارسة (من المتجر) — Heba",
    when: "قبل التصويت",
    feel: "هادية وجادة",
    voice: "JHdGl5PsEzushIzzVSd1",
    heavy: false,
    text: "[calm, serious] خلاص… الكلام خلص. [softly] كل واحد يختار دلوقتي… بس فكّر كويس أبل ما تشاور، [grave] عشان صوتك ده ممكن يطلّع واحد بريء.",
  },
  {
    file: "08_story_haytham",
    who: "قارئ القصص — Haytham (Dramatic)",
    when: "أول ما تفتح قصة «قهوة المعلم»",
    feel: "بيحكي كأنه قاعد معاك على القهوة، وبيشكّك في الآخر",
    voice: "wxweiHvoC2r2jFM7mS8b",
    heavy: false,
    text: "[conversational, intrigued] أهوة المعلم. [pause] المعلم صابر مات وهو آعد على كرسيه، والأهوة كلها بتلعب دومنة. [suspicious] الشاي ماكانش فيه حاجة… بس حجر الشيشة؟ ده كان متظبطله من أبل ما الفحم يولّع.",
  },
  {
    file: "09_story_haytham",
    who: "قارئ القصص — Haytham (Dramatic)",
    when: "أول ما تفتح قصة «قهوة المعلم»",
    feel: "بيحكي حكاية حصلت، بهدوء، وفي الآخر بيشكّك",
    voice: "wxweiHvoC2r2jFM7mS8b",
    heavy: false,
    text: "[conversational, low] المعلم صابر اتأتل… [pause] وهو آعد على كرسيه في الأهوة، والناس حواليه بيلعبوا ومحدش واخد باله. [suspicious] الشاي كان سليم… بس الشيشة؟ حد ظبّطهاله من أبل ما يولّعها.",
  },
];

const mine = await (await fetch(`${api}/voices`, { headers })).json();
const have = new Set((mine.voices ?? []).map((v) => v.voice_id));
const terms = { OFHP1Qg30FPoNfkUFFlA: "adam", "9SPZl4Mlgwj7QT4gVprb": "adam" };
for (const id of new Set(SAMPLES.map((s) => s.voice))) {
  if (have.has(id)) continue;
  const found = await (await fetch(`${api}/shared-voices?page_size=50&search=${terms[id] ?? "egyptian"}`, { headers })).json();
  const v = (found.voices ?? []).find((x) => x.voice_id === id);
  if (!v) throw new Error(`voice ${id} not found`);
  const r = await fetch(`${api}/voices/add/${v.public_owner_id}/${id}`, { method: "POST", headers, body: JSON.stringify({ new_name: v.name }) });
  if (!r.ok) throw new Error(`add ${v.name}: HTTP ${r.status}`);
}

const onlyArg = process.argv.indexOf("--only");
const pick = onlyArg >= 0 ? new Set(process.argv[onlyArg + 1].split(",")) : null;
let chars = 0;
for (const s of SAMPLES) {
  if (pick && !pick.has(s.file)) continue;
  const r = await fetch(`${api}/text-to-speech/${s.voice}?output_format=mp3_44100_128`, {
    method: "POST",
    headers: { ...headers, accept: "audio/mpeg" },
    body: JSON.stringify({ text: s.text, model_id: "eleven_v3", voice_settings: { stability: 0.5, similarity_boost: 0.85, use_speaker_boost: true } }),
  });
  if (!r.ok) throw new Error(`${s.file}: HTTP ${r.status} ${(await r.text()).slice(0, 160)}`);
  const raw = join(tmpdir(), `${s.file}.mp3`);
  writeFileSync(raw, Buffer.from(await r.arrayBuffer()));
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", raw, "-af", s.heavy ? `${HEAVY},${FILTER}` : FILTER, "-ac", "1", "-b:a", "160k", join(out, `${s.file}.mp3`)]);
  chars += s.text.length;
  writeFileSync(join(out, `${s.file}.raw.mp3`), readFileSync(raw));
  console.log(s.file);
}
writeFileSync(join(out, "lines.json"), JSON.stringify(SAMPLES, null, 1));
console.log(`characters: ${chars}`);

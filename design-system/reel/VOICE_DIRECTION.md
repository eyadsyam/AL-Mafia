# Voice, delivery, and timing contract

## Casting

Verified via ElevenLabs MCP voice catalogue on 2026-10-10:

| Priority | Voice | ID | Why |
|---|---|---|---|
| 1 | Haytham - Conversation | `IES4nrmZdUBHByLBde0P` | Egyptian, warm, energetic conversational voice; first audition |
| 2 | Adam - Deep, Rich and Expressive | `OFHP1Qg30FPoNfkUFFlA` | Egyptian Arabic; alternative if Haytham lacks weight |

These are candidates, not a claim of having heard or approved a take. Re-query the catalogue at production time, match exact ID/name, and use returned IDs. Do not accidentally select the American premade Adam.

## Performance brief (human direction, NOT literal spoken prompt)

راجل مصري بيكلّم واحد صاحبه، صوته واضح وفيه ثقة وهدوء. بياخد اللعبة بجد بس مستمتع بأنه عارف السر. بداية مباشرة، حروف مفهومة، جمل قصيرة. عند «المافيا بتشكركم» تعليق ناشف بابتسامة في الصوت، من غير ضحك. عند التحقيق فضول وتركيز، والنهاية تحدّي خفيف بين صحاب. لا همس رعب، لا صريخ إعلان، لا فصحى، ولا تغليظ مصطنع للصوت.

The seated skull is confident, not a horror trailer monster. Preserve the voice's natural register. Pitch shifting is not a character design method.

## Tools and model (schema inspected during preparation)

- Use ElevenLabs MCP, discovered by tool name/capability; do not assume a prefix will stay stable.
- `creative_generate_speech`: `model_id=eleven_v3`, `voice_id` from catalogue, `prompt` read from `SCRIPT.eleven-v3.txt`.
- v3 chosen because this script needs restrained inline delivery changes. `creative_get_model_guide(eleven_v3)` was read; free-form bracket delivery tags are supported. Tags apply until changed.
- **The prompt is spoken text.** Do not paste this brief, timestamps, scene numbers or camera directions into it.
- Current inspected v3 TTS schema exposes language_code and a deprecated voice_id alias; no stability/similarity/speed fields were exposed. Do not invent numeric controls in tool arguments. Read current schema in the production turn before using model_parameters.
- For multilingual_v2 fallback, use `SCRIPT.ar.txt` WITHOUT bracket tags; otherwise it may speak the tags. Test before adopting a fallback.
- If several generations feed a later node, create a shared flow first and reuse its returned flow_id. Save each returned node/session ID in `STATE.json` immediately.
- An estimate-only call is not audio. A submitted generation is not a completed generation. Poll status with returned IDs; do not duplicate a running request by calling generation again.
- Follow the current tool contract for variation count. The inspected tool defaults to four; this package does not invent a user-specified count. Report actual spend/estimate if available; do not claim an unmeasured cost.

## Audition before full voice

Use `VOICE_AUDITION.eleven-v3.txt` first with Haytham. It samples authority, the dry joke, and the question ending. Select the best available variation yourself if it meets all checks. Only try Adam if Haytham's delivery is unsuitable; comparing more takes is not a goal by itself.

Score each heard take (0–2 per item): Egyptian delivery; word clarity; conversational feel; controlled joke; stable loudness/identity. Require >=8/10, and no wrong words. Record what was heard, not only a transcript score. If the environment cannot play/listen, mark audition as not audibly verified; don't claim confidence from waveform/ASR alone.

Then generate the full text in one coherent take. Avoid nineteen isolated TTS calls: they drift in tone and pacing. Maintain the exact script words. If a repair is necessary, replace an entire phrase at a natural pause, not a consonant, and check the join audibly.

## Phrase-by-phrase performance

`timeline.plan.json` contains every phrase, target frame range, delivery and pause guidance.

- **إنت المافيا**: direct eye-contact delivery, stress on «إنت» then «المافيا». First audible consonant within 0–150 ms of film start.
- **وهما لسه مايعرفوش**: slight confidential drop in energy, keep articulation audible; no whisper tag.
- **هتعرف…؟**: genuine challenge, questioning ending, not a shouting hook.
- **أونلاين**: clear emphasis and enough duration to understand it once. Must be spoken by 10 s; the badge is visible from frame 0.
- **بالليل… الدكتور… المحقق**: explanatory, brisk but intelligible; do not race the role names.
- **الصبح بقى**: small reset/breath, then rising curiosity through the two questions.
- **طلّعتوا بريء؟**: pause around 150–250 ms before **المافيا بتشكركم**. Dry approval, no laugh, no evil growl.
- **كفاية تخبّي**: conversational pivot. **تعالى اكشف مين عملها** invites participation.
- **قهوة المعلم**: Egyptian place name; verify «قهوة» is not pronounced as an unrelated English word. Do not over-diacritize all text; fix only actual mispronunciations.
- **تحرّكاتك محدودة**: meaningful warning about a game resource, not mock urgency.
- **مين عملها؟ ليه؟ وإزاي؟**: three distinct questions with small spaces, each gets its own visual landing.
- **هتتلقط من أول جولة؟**: playful challenge at the same natural pitch as the beginning. No final deep announcer flourish.

## Duration / alignment

Target narration ends around 56–57 s; final image holds 2 s. The 59 s film is 1770 frames. One frame is 33.333… ms; there is no useful femtosecond precision here.

1. Preserve raw provider output with checksum; never overwrite it.
2. Make a working 48 kHz audio copy using a real decoder/resampler; don't relabel an MP3 as WAV.
3. Check leading/trailing silence, clipping, phrase boundaries and exact words.
4. Align spoken phrases/words and save true start/end seconds with confidence/review flags. Quantize VISUAL cue timing by `round(seconds * 30)`, not the audio samples.
5. Retiming decisions follow `PRODUCTION_RUNBOOK.md`. No per-word waveform stretching; no invented forced timestamps.

## Mix targets (verify on the delivered file)

- Speech remains intelligible on a phone speaker and in mono. No stereo phase tricks on VO.
- Aim final programme around -14 to -16 LUFS integrated; true peak <= -1 dBTP. These are production targets, not measurements already achieved.
- Start music approximately 18–24 dB below concurrent VO level, then judge actual masking by listening. Do not interpret this as a universal fixed fader setting.
- Lower music by another ~4–6 dB for the joke and the Stories pivot; smooth 150–250 ms ramps. Avoid pumping around each syllable.
- Existing `score_loop.ogg` is only a candidate. Listen first; if unsuitable, use restrained ambience/foley rather than an unrelated stock beat.
- Key sounds: card contact, one night transition, paper movement. No gunshot, scream, laugh track, continuous whooshes, or sound on every text entrance.
- Author VO, music, room tone and foley as separate tracks so fixes don't require regenerating speech.

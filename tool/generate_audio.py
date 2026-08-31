#!/usr/bin/env python3
"""Synthesises the non-narration audio cues from design system doc 01, §8.

Run from the project root:

    python tool/generate_audio.py

## What this does and does not produce

Everything here is *sound*, and nothing here is *speech*.

The functional cues — chime, timer end, drum hit, card flip, timer tick, win
sting — are pure synthesis and are final. `night_falls` and `morning` are the
ambient beds that sit underneath the narration, which is also just sound, so
they ship too.

What is not written is a word of Arabic. A synthesised or placeholder voice
sitting in `assets/audio` looking like a finished asset is worse than an
obviously missing one, and the director is built so the two are independent: the
bed plays from this file, the narrator line plays from
`AudioDirector.narratorLines` if a recording has been registered, and a
transition with neither still works because it falls back to its on-screen text.

## The constraint that shaped these sounds

Doc 05 rule 4 and L-11: audio only ever plays with the phone flat on the table,
heard by everyone at once. So these cues carry no role information and must not
*sound* like they do. In particular `eliminationReveal` is a plain drum hit with
no tonal centre — a minor chord here would colour how the table reads a death
before anyone has spoken.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import wave

import numpy as np

SR = 44_100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")


def _env(n: int, attack: float, decay: float) -> np.ndarray:
    """Percussive envelope: fast linear attack, exponential decay."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    return a * np.exp(-t / decay)


def _fade_edges(x: np.ndarray, ms: float = 4.0) -> np.ndarray:
    """Removes the click a hard start or stop puts on a speaker."""
    k = int(SR * ms / 1000.0)
    if k * 2 >= len(x):
        return x
    ramp = np.linspace(0.0, 1.0, k)
    x[:k] *= ramp
    x[-k:] *= ramp[::-1]
    return x


def _write(name: str, x: np.ndarray, *, fade: bool = True,
           peak_level: float = 0.708) -> str:
    """Normalises and writes one cue.

    `fade=False` is for material that loops. Ramping the first and last few
    milliseconds to silence is what stops a one-shot clicking on a speaker, and
    it is exactly what must *not* happen to a loop — it would put an audible
    dip at the seam every time round.

    `peak_level` defaults to -3 dBFS, which leaves headroom so a phone speaker
    at full volume does not clip a cue into a rasp that carries further across a
    room than the sound itself is meant to. The score sits far below that: it
    plays continuously under people talking, and a bed you notice is a bed
    that is too loud.
    """
    x = x.astype(np.float64)
    if fade:
        x = _fade_edges(x)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * peak_level
    pcm = (x * 32767.0).astype("<i2")

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return path


def speaker_change() -> np.ndarray:
    """Short neutral chime, < 1s (doc 01: 'short neutral chime')."""
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    # A single pitch plus its octave and twelfth. No third anywhere, so the
    # chime has no major/minor colour to read into.
    x = (
        1.00 * np.sin(2 * np.pi * 880.0 * t) * _env(n, 0.004, 0.13)
        + 0.34 * np.sin(2 * np.pi * 1760.0 * t) * _env(n, 0.003, 0.07)
        + 0.18 * np.sin(2 * np.pi * 2640.0 * t) * _env(n, 0.002, 0.04)
    )
    return x


def timer_end() -> np.ndarray:
    """Two ascending tones (doc 01)."""
    seg, gap = int(SR * 0.20), int(SR * 0.07)
    out = np.zeros(seg * 2 + gap)
    for i, f in enumerate((659.26, 987.77)):  # E5 -> B5, a rising fifth
        t = np.arange(seg) / SR
        tone = (
            np.sin(2 * np.pi * f * t) * _env(seg, 0.006, 0.09)
            + 0.25 * np.sin(2 * np.pi * f * 2 * t) * _env(seg, 0.004, 0.05)
        )
        start = i * (seg + gap)
        out[start:start + seg] += tone
    return out


def elimination_reveal() -> np.ndarray:
    """Single deep drum hit (doc 01)."""
    n = int(SR * 0.9)
    t = np.arange(n) / SR

    # Pitch sweeping downwards is what makes a sine read as a drum skin rather
    # than as a bass note: 105 Hz falling to 42 Hz over the first ~80 ms.
    f = 42.0 + 63.0 * np.exp(-t / 0.055)
    phase = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(phase) * _env(n, 0.002, 0.20)

    # Short filtered-noise transient for the beater, otherwise the hit has no
    # attack and sounds like a hum starting.
    rng = np.random.default_rng(11)
    noise = rng.normal(0, 1, n)
    kernel = np.ones(24) / 24.0            # crude low-pass
    noise = np.convolve(noise, kernel, mode="same") * _env(n, 0.001, 0.012)

    return body + 0.30 * noise


def card_flip() -> np.ndarray:
    """A page turning. Short, papery, and quiet enough to be almost subliminal.

    No tone at all — a card has no pitch, and anything pitched here would read
    as a *result* rather than a movement.

    # Why this is not the whoosh it used to be

    The first version was a 0.42s symmetric noise sweep: slow in, slow out, no
    transient. That is the sound of something large passing, and at the speed a
    thumb turns a card it read as a swoosh rather than as paper. Paper is three
    things this now has and that did not:

      * **a transient** — the moment the sheet releases. Everything after it is
        decay, so the envelope is fast-attack rather than symmetric;
      * **rustle** — paper does not make one sound, it makes a few hundred tiny
        ones. The noise is amplitude-jittered at audio rate so the texture is
        granular instead of smooth;
      * **brightness that dies fast** — the crackle is high and short-lived
        while the body of the sheet is low and lasts a little longer, so the
        two are enveloped separately and summed.

    # Why it is short

    This now fires on a surface a player is holding, once per turn plus once
    per look (see AudioDirector.playCardTurn). A long cue there would still be
    sounding when the next thing happens, and a cue that overlaps the next
    moment is a cue the table can time. 0.18s is over before anyone can begin
    to.
    """
    n = int(SR * 0.18)
    t = np.arange(n) / SR
    rng = np.random.default_rng(5)

    # The rustle: white noise whose amplitude is itself noisy, which is what
    # turns a smooth hiss into a granular one.
    grain = np.abs(rng.normal(0, 1, n)) ** 1.5
    grain /= grain.max()
    noise = rng.normal(0, 1, n) * (0.35 + 0.65 * grain)

    # Split it into a bright crackle and a duller body by subtracting a running
    # average from the signal (high part) and keeping the average (low part).
    body = np.convolve(noise, np.ones(24) / 24.0, mode="same")
    crackle = noise - body

    # Fast attack, exponential decay, the crackle dying about twice as fast as
    # the body. `1 - exp` rather than a step so there is no click on the front.
    attack = 1.0 - np.exp(-t / 0.004)
    return (crackle * attack * np.exp(-t / 0.035)
            + body * 1.4 * attack * np.exp(-t / 0.070))


def timer_warning() -> np.ndarray:
    """A soft tick for the last ten seconds of a phase timer.

    Deliberately quieter and duller than [timer_end]. It fires ten times in a
    row, so anything with a tail would smear into a drone, and anything bright
    would dominate a room that is meant to be talking over it.
    """
    n = int(SR * 0.09)
    t = np.arange(n) / SR
    x = (
        np.sin(2 * np.pi * 1200.0 * t) * _env(n, 0.001, 0.012)
        + 0.4 * np.sin(2 * np.pi * 600.0 * t) * _env(n, 0.001, 0.020)
    )
    return x * 0.55


def win() -> np.ndarray:
    """The match result. The *same* sting for both outcomes.

    Two files would be a leak of a different kind — the table would hear who won
    before the screen said so, and a player who had already stopped watching
    would learn it from the room's reaction rather than the reveal.

    A rising open fifth, no third: it resolves without being either triumphant
    or funereal, because half the table is about to feel each way.
    """
    seg, gap = int(SR * 0.34), int(SR * 0.02)
    out = np.zeros(seg * 3 + gap * 2)
    for i, f in enumerate((196.00, 293.66, 392.00)):  # G3 -> D4 -> G4
        t = np.arange(seg) / SR
        tone = (
            np.sin(2 * np.pi * f * t) * _env(seg, 0.010, 0.30)
            + 0.30 * np.sin(2 * np.pi * f * 2 * t) * _env(seg, 0.008, 0.16)
            + 0.12 * np.sin(2 * np.pi * f * 3 * t) * _env(seg, 0.006, 0.09)
        )
        start = i * (seg + gap)
        out[start:start + seg] += tone
    return out


def _bed(seconds: float, base: float, rising: bool, seed: int) -> np.ndarray:
    """A low ambient swell under a phase announcement.

    # Why these exist when the narration files still do not

    `nightFalls` and `morning` are spoken lines, and this file's standing rule is
    that a synthesised voice is worse than an obviously missing one. That rule
    still holds — nothing here says a word.

    What these are is the *bed*: the ambient layer doc 01 describes underneath
    the narration. It carries no language, so it can ship now, and the narrator
    slot stays empty until there is a real recording to put in it. The two are
    independent by design (see `AudioDirector.narratorLines`).
    """
    n = int(SR * seconds)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)

    # Two detuned low sines a fifth apart, plus heavily smoothed noise for air.
    tone = (
        np.sin(2 * np.pi * base * t)
        + 0.6 * np.sin(2 * np.pi * base * 1.4983 * t + 0.7)
        + 0.25 * np.sin(2 * np.pi * base * 2.0 * t + 1.9)
    )
    air = np.convolve(rng.normal(0, 1, n), np.ones(600) / 600.0, mode="same")

    ramp = t / seconds
    shape = ramp if rising else (1.0 - ramp)
    # Never start or end at nothing: a bed that fades fully out reads as a fault.
    env = 0.35 + 0.65 * shape
    # And always open and close smoothly regardless of direction.
    env *= np.sin(np.pi * np.clip(ramp, 0.0, 1.0)) ** 0.35

    return (tone * 0.5 + air * 6.0) * env


def night_falls() -> np.ndarray:
    """Darkening ambience — falls away as the village goes to sleep."""
    return _bed(4.0, 55.0, rising=False, seed=17)


def morning() -> np.ndarray:
    """Brightening ambience — the same material, opening out."""
    return _bed(4.0, 82.41, rising=True, seed=23)


def score_loop() -> np.ndarray:
    """The bed that runs under the whole game. Seamless, and always the same.

    # The constraint that shapes every choice here

    This plays while the phone is in someone's hand. Article I's rule 2 bans a
    sound from *firing* during a turn, and the reason is that a sound which
    arrives at a particular moment marks that moment. A loop that never starts,
    never stops and never changes marks nothing: it is the room's acoustic
    floor, indistinguishable from a fan or traffic, and it is identical for the
    mafioso and the citizen holding the phone one after the other.

    That makes it safe, and it also makes it *useful* — a steady bed masks the
    small incidental noises a turn produces (a thumb on glass, a held breath),
    which silence does not.

    So: no swells, no phase-dependent layers, no ducking under a cue. Anything
    that responds to the game would be a tell, and would be the only tell nobody
    thought to test for.

    # Making it intense without making it loud

    Focus, not adrenaline. The tools used here are all *steady*:

    * a low drone on a bare fifth (55 Hz and 82.5 Hz), no third, so the harmony
      never resolves and never commits to a mood;
    * a slow binaural-ish beat from two detuned partials a fraction of a hertz
      apart, which produces a very slow amplitude pulse the ear reads as tension
      without hearing a rhythm;
    * a heartbeat at 50 bpm — below resting rate, so it pulls attention down
      rather than up;
    * filtered noise for air, so the bed has a texture and does not sound like a
      test tone.

    # Why it loops perfectly

    Every component's frequency is chosen so that a whole number of cycles fits
    the loop length. A crossfade would work too, but a crossfade over a drone
    audibly dips every time it comes round, and this file plays for hours.
    """
    seconds = 32.0
    n = int(SR * seconds)
    t = np.arange(n) / SR

    def cycles(freq: float) -> float:
        """Nudges `freq` to the nearest value that completes whole cycles."""
        return max(1.0, round(freq * seconds)) / seconds

    out = np.zeros(n)

    # The drone: a bare fifth, plus one partial detuned by a third of a hertz so
    # the pair beats slowly against itself.
    for freq, gain in ((55.0, 1.00), (82.5, 0.55), (110.0, 0.30)):
        out += gain * np.sin(2 * np.pi * cycles(freq) * t)
    out += 0.45 * np.sin(2 * np.pi * cycles(55.33) * t + 1.1)

    # A dim upper partial keeps it from sounding muffled on a phone speaker,
    # which reproduces almost nothing below 200 Hz.
    out += 0.13 * np.sin(2 * np.pi * cycles(220.0) * t + 0.4)
    out += 0.07 * np.sin(2 * np.pi * cycles(330.0) * t + 2.2)

    # Air. Generated at loop length and smoothed with a wrapping convolution, so
    # the texture is continuous across the seam as well as inside it.
    rng = np.random.default_rng(31)
    noise = rng.normal(0, 1, n)
    k = 400
    kernel = np.ones(k) / k
    air = np.real(np.fft.ifft(np.fft.fft(noise) * np.fft.fft(kernel, n)))
    out += 3.2 * air

    # Heartbeat at 50 bpm — slower than resting, which settles attention rather
    # than raising it. Two thumps per beat, the second softer.
    beats = round(seconds * 50 / 60)
    period = n / beats
    beat = np.zeros(n)
    for i in range(beats):
        for offset, gain in ((0.0, 1.0), (0.22, 0.55)):
            start = int((i + offset) * period) % n
            length = int(SR * 0.16)
            env = _env(length, 0.004, 0.055)
            tone = np.sin(2 * np.pi * 48.0 * np.arange(length) / SR) * env
            idx = (np.arange(length) + start) % n     # wraps across the seam
            beat[idx] += gain * tone
    out += 0.9 * beat

    # A very slow tremolo across the whole loop, exactly one cycle long so the
    # seam is continuous in level as well as in phase.
    out *= 0.86 + 0.14 * np.sin(2 * np.pi * t / seconds)

    return out


# Cues that repeat forever. They are normalised quieter and are *not* edge-faded,
# because a fade to silence at each end is an audible dip at the seam.
LOOPS = {"score_loop"}

# Cues that want a level of their own, as a peak in dBFS-ish linear terms. The
# default is 0.708 (-3 dBFS), which is right for something the whole table is
# meant to hear across a room.
#
# `card_flip` is the exception and it is a large one: -15 dBFS against -3, a
# factor of six down. It is the only cue that sounds while somebody is holding
# the phone, and what it has to be is *felt* rather than heard — the audible
# edge of a gesture, not an announcement that a gesture happened. It still
# carries, because it is a transient and the bed it sits over is not; the level
# is set so it reads as paper in the holder's hand rather than as the app
# making a noise at the table.
PEAK = {"card_flip": 0.18}

# `score_loop` is NOT here, and running this script does not touch it. The
# shipped bed is supplied music, prepared by `tool/normalise_score.py` from
# whatever is in `raw_assets/audio/` — currently `Unresolved Room`, 309.5s,
# cross-faded closed and gained to -20 dBFS RMS. Before that it was a 120.000s
# synthesised bare-fifth drone with a 13 dB notch at 2.2 kHz, which is what the
# `score_loop()` function below still produces; it is kept as a reference
# implementation and as the thing to fall back on if there is ever no music to
# ship. Regenerating the shipped file from it would silently replace the score.
CUES = {
    "speaker_change": speaker_change,
    "timer_end": timer_end,
    "elimination_reveal": elimination_reveal,
    "card_flip": card_flip,
    "timer_warning": timer_warning,
    "win": win,
    "night_falls": night_falls,
    "morning": morning,
}


def main() -> None:
    ffmpeg = shutil.which("ffmpeg")

    # Naming cues does only those. One cue at a time matters here for the same
    # reason it does in `normalise_video.py`: these files are shipped assets,
    # and a full run rewrites every one of them to re-tune a single sound.
    wanted = [a for a in sys.argv[1:] if not a.startswith("-")]
    unknown = [w for w in wanted if w not in CUES]
    if unknown:
        sys.exit("FAIL: no such cue(s): " + ", ".join(unknown)
                 + "\n  known: " + ", ".join(sorted(CUES)))
    cues = {k: v for k, v in CUES.items() if not wanted or k in wanted}

    print("synthesising cues")

    wavs = []
    for name, fn in cues.items():
        looping = name in LOOPS
        wavs.append(_write(
            name, fn(),
            fade=not looping,
            # The score plays for the length of a match under a table of people
            # talking. -20 dBFS is present without competing.
            peak_level=PEAK.get(name, 0.10 if looping else 0.708),
        ))

    if not ffmpeg:
        print("\nffmpeg not found — leaving .wav files in place.")
        sys.exit(0)

    print("\nencoding to ogg vorbis")
    for wav in wavs:
        ogg = wav[:-4] + ".ogg"
        r = subprocess.run(
            [ffmpeg, "-y", "-loglevel", "error", "-i", wav,
             "-c:a", "libvorbis", "-q:a", "3", "-ar", str(SR), ogg],
            capture_output=True, text=True,
        )
        if r.returncode != 0:
            print(f"  FAILED {os.path.basename(ogg)}: {r.stderr.strip()[:160]}")
            continue
        os.remove(wav)
        print(f"  {os.path.relpath(ogg, ROOT):<44} {os.path.getsize(ogg):>7,} B")

    print("\nStill missing (needs an Arabic voice actor, cannot be synthesised):")
    print("  assets/audio/mafia_wake.ogg   — narration only, no ambient bed")
    print("  assets/audio/narrator/*.ogg   — the spoken lines over the beds")
    print("\nA cue with no file plays nothing and the transition falls back to "
          "its on-screen text, so the app is complete without them.")


if __name__ == "__main__":
    main()

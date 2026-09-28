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


# ── 1.1 cues (BIG-UPDATE-1.1-FINAL §9) ───────────────────────────────────────
#
# Objects on an investigator's desk: paper, wax, brass, wood and thread. Each
# cue is built from how one of those materials physically sounds — struck
# solids ring as damped modes, paper is granular band-limited noise, a thread is
# a plucked delay line — rather than from a musical idea, so the set sounds like
# one room. The few musical ones (the stings) keep this file's rule: fifths and
# octaves, never a third, so no cue reads as good news for one side. No cue
# varies by live role; each file is the same for every seat.


def _noise(n: int, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).normal(0.0, 1.0, n)


def _band(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    """Band-limits [x] with an octave-wide raised-cosine skirt on each edge.

    A brick-wall mask rings audibly on transients; a soft skirt does not.
    """
    spec = np.fft.rfft(x)
    f = np.log2(np.maximum(np.fft.rfftfreq(len(x), 1.0 / SR), 1e-3))
    mask = np.ones_like(f)
    if lo > 0:
        r = np.clip(f - np.log2(lo / 2.0), 0.0, 1.0)
        mask *= 0.5 - 0.5 * np.cos(np.pi * r)
    if hi < SR / 2:
        r = np.clip(np.log2(hi * 2.0) - f, 0.0, 1.0)
        mask *= 0.5 - 0.5 * np.cos(np.pi * r)
    return np.fft.irfft(spec * mask, len(x))


def _modal(seconds: float, modes: tuple) -> np.ndarray:
    """A struck solid: damped sines, one per (frequency, decay s, amplitude).

    Wood has few, low, fast-dying modes; brass has more, higher, slower ones.
    The half-millisecond ramp is the strike itself, without a click.
    """
    n = int(SR * seconds)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f, d, a in modes:
        out += a * np.sin(2 * np.pi * f * t) * np.exp(-t / d)
    return out * (1.0 - np.exp(-t / 0.0005))


def _click(seconds: float, lo: float, hi: float, decay: float, seed: int) -> np.ndarray:
    """The contact transient every impact starts with."""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    return _band(_noise(n, seed), lo, hi) * np.exp(-t / decay)


def _paper(seconds: float, seed: int, lo: float = 900.0, hi: float = 7000.0) -> np.ndarray:
    """Paper: a few hundred tiny crackles, not one smooth hiss (see card_flip)."""
    n = int(SR * seconds)
    rng = np.random.default_rng(seed)
    grain = np.convolve(np.abs(rng.normal(0, 1, n)) ** 2, np.ones(40) / 40.0, mode="same")
    grain /= grain.max()
    return _band(rng.normal(0, 1, n) * (0.25 + 0.75 * grain), lo, hi)


def _swell(seconds: float, rise: float, fall: float) -> np.ndarray:
    """Smooth rise over [rise] seconds, then exponential fall."""
    t = np.arange(int(SR * seconds)) / SR
    up = np.sin(0.5 * np.pi * np.clip(t / max(rise, 1e-6), 0.0, 1.0)) ** 2
    return up * np.exp(-np.maximum(t - rise, 0.0) / fall)


def _pluck(freq: float, seconds: float, *, smooth: float = 0.5,
           damp: float = 0.995, seed: int = 0) -> np.ndarray:
    """Karplus–Strong: a noise burst circulating in a one-period delay line.

    [smooth] is how much each pass averages neighbours: 0.5 is a dull thread,
    lower keeps the upper partials longer, which is what makes a plucked oud
    string bright at the front.
    """
    n = int(SR * seconds)
    p = max(2, int(round(SR / freq)))
    buf = np.random.default_rng(seed).uniform(-1.0, 1.0, p)
    buf -= buf.mean()
    out = np.empty(n)
    for i in range(n):
        j = i % p
        out[i] = buf[j]
        buf[j] = damp * ((1.0 - smooth) * buf[j] + smooth * buf[(j + 1) % p])
    return out


def _bell(freq: float, seconds: float, decay: float) -> np.ndarray:
    """A small brass bell: inharmonic partials, the high ones dying first."""
    return _modal(seconds, (
        (freq, decay, 1.0),
        (freq * 2.0, decay * 0.6, 0.42),
        (freq * 2.76, decay * 0.4, 0.22),
        (freq * 5.40, decay * 0.2, 0.07),
    ))


def _mix(seconds: float, *parts: tuple) -> np.ndarray:
    """Lays (start seconds, signal) parts on one timeline."""
    out = np.zeros(int(SR * seconds))
    for at, x in parts:
        i = int(SR * at)
        j = min(len(out), i + len(x))
        if j > i:
            out[i:j] += x[: j - i]
    return out


def _conv(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    m = len(a) + len(b) - 1
    size = 1 << (m - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(a, size) * np.fft.rfft(b, size), size)[:m]


def _room(x: np.ndarray, *, mix: float, seconds: float = 0.30, seed: int = 3) -> np.ndarray:
    """A small wood-panelled room, so the desk objects are not heard in a void.

    The dry cue convolved with band-limited decaying noise, returned at the
    dry cue's length so every cue keeps its designed duration.
    """
    n = int(SR * seconds)
    t = np.arange(n) / SR
    ir = _band(_noise(n, seed), 250.0, 5500.0) * np.exp(-t / (seconds / 5.0))
    wet = _conv(x, ir)[: len(x)]
    rms = lambda s: float(np.sqrt(np.mean(s ** 2))) or 1.0
    return x + wet * (mix * rms(x) / rms(wet))


def _tail(x: np.ndarray, seconds: float = 0.06) -> np.ndarray:
    """Closes the last [seconds] with a cosine so no cue stops on a cut."""
    k = min(len(x), int(SR * seconds))
    x = x.copy()
    x[-k:] *= 0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, k))
    return x


def casebook_wax_press() -> np.ndarray:
    """Warm wax giving under a thumb: a soft squish, then the press lands."""
    squish = _band(_paper(0.42, 21), 150.0, 1400.0) * _swell(0.42, 0.05, 0.10)
    thump = _modal(0.30, ((92.0, 0.07, 1.0), (184.0, 0.04, 0.35), (410.0, 0.02, 0.18)))
    return _tail(_room(_mix(0.42, (0.0, 0.6 * squish), (0.045, thump)), mix=0.12))


def casebook_paper_slide() -> np.ndarray:
    """A page drawn across the desk, the rustle brightening as it speeds up."""
    d = 0.34
    t = np.arange(int(SR * d)) / SR
    slide = _paper(d, 22, 700.0, 3200.0) * (1 - t / d) + _paper(d, 23, 2200.0, 9000.0) * (t / d)
    body = _band(_noise(len(t), 24), 120.0, 600.0) * 0.3
    return _tail(_room((slide + body) * _swell(d, 0.10, 0.09), mix=0.08))


def casebook_string_pluck() -> np.ndarray:
    """The red thread pulled taut between two pins: a short, dull pluck."""
    # A thread has no sparkle: the excitation's top end is taken off, or the
    # first few periods of raw noise read as a hiss rather than a string.
    thread = _band(_pluck(196.0, 0.6, smooth=0.45, damp=0.992, seed=31), 80.0, 2500.0)
    pin = _modal(0.03, ((2400.0, 0.004, 0.3), (3900.0, 0.003, 0.2)))
    return _tail(_room(_mix(0.6, (0.0, thread), (0.0, pin)), mix=0.10), 0.12)


def casebook_level_sting() -> np.ndarray:
    """A casebook level: three small bells on an open fifth, D–A–D."""
    return _tail(_room(_mix(
        1.0,
        (0.00, _bell(293.66, 1.0, 0.45)),
        (0.09, 0.8 * _bell(440.00, 0.9, 0.45)),
        (0.18, 0.7 * _bell(587.33, 0.8, 0.50)),
        (0.00, 0.25 * _paper(0.12, 41) * _swell(0.12, 0.01, 0.04)),
    ), mix=0.18), 0.15)


def case_accuse_gavel() -> np.ndarray:
    """One gavel on its sound block. Decisive, wooden, and the same for any answer."""
    wood = _modal(0.7, (
        (210.0, 0.090, 1.0), (540.0, 0.050, 0.6), (930.0, 0.035, 0.45),
        (1570.0, 0.020, 0.30), (2650.0, 0.012, 0.20),
    ))
    thud = _modal(0.3, ((70.0, 0.08, 0.5),))
    return _tail(_room(wood + _mix(0.7, (0.0, thud), (0.0, 0.8 * _click(0.02, 2000.0, 8000.0, 0.003, 51))),
                       mix=0.22), 0.15)


def case_wrong_crack() -> np.ndarray:
    """A dry crack, as if a wax seal split. Short and never harsh: a wrong
    answer is information, not a punishment."""
    rng = np.random.default_rng(61)
    parts = [(0.0, _click(0.08, 600.0, 5000.0, 0.018, 62))]
    for k in range(5):
        parts.append((0.012 + rng.uniform(0.0, 0.06),
                      (0.5 ** (k + 1)) * _click(0.03, 900.0, 6000.0, 0.004, 63 + k)))
    parts.append((0.0, 0.6 * _modal(0.25, ((140.0, 0.05, 1.0), (330.0, 0.03, 0.4)))))
    return _tail(_room(_mix(0.45, *parts), mix=0.12))


def case_reveal_swell() -> np.ndarray:
    """The answer turning over: air and a low fifth rising, settling on one bell."""
    d = 1.4
    t = np.arange(int(SR * d)) / SR
    rise = np.clip(t / 1.15, 0.0, 1.0) ** 2 * (t < 1.15) + (t >= 1.15) * np.exp(-(t - 1.15) / 0.05)
    air = _band(_noise(len(t), 71), 300.0, 4000.0) * 0.35
    low = np.sin(2 * np.pi * 73.42 * t) + 0.6 * np.sin(2 * np.pi * 110.0 * t + 0.8)
    land = 0.9 * _bell(293.66, 0.3, 0.30) + 0.6 * _bell(440.0, 0.3, 0.25)
    return _tail(_room(_mix(d, (0.0, (air + 0.5 * low) * rise), (1.12, land)), mix=0.2), 0.1)


def chapter_envelope_open() -> np.ndarray:
    """A sealed flap peeling up, then the letter sliding out."""
    peel = _paper(0.14, 81, 2000.0, 9000.0) * _swell(0.14, 0.10, 0.02)
    out = _paper(0.28, 82, 800.0, 5000.0) * _swell(0.28, 0.08, 0.08)
    return _tail(_room(_mix(0.6, (0.0, 0.7 * peel), (0.22, out)), mix=0.1))


def chapter_seal_press() -> np.ndarray:
    """A brass seal pressed into wax: the squish, the thump, the metal ringing."""
    squish = _band(_paper(0.2, 91), 150.0, 1400.0) * _swell(0.2, 0.03, 0.06)
    thump = _modal(0.3, ((88.0, 0.06, 1.0), (176.0, 0.035, 0.3)))
    brass = _modal(0.45, ((720.0, 0.08, 0.25), (1830.0, 0.05, 0.15), (3050.0, 0.03, 0.08)))
    return _tail(_room(_mix(0.5, (0.0, 0.5 * squish), (0.04, thump), (0.04, brass)), mix=0.14))


def academy_token_place() -> np.ndarray:
    """A small wooden token set down on the board."""
    tok = _modal(0.18, ((620.0, 0.030, 1.0), (1480.0, 0.018, 0.5), (2600.0, 0.010, 0.3)))
    return _tail(tok + _mix(0.18, (0.0, 0.4 * _click(0.01, 2500.0, 9000.0, 0.0015, 101))), 0.03)


def academy_wrong_return() -> np.ndarray:
    """The token slides back to its place. Gentle: the lesson simply resets."""
    scrape = _band(_paper(0.2, 111), 400.0, 2500.0) * _swell(0.2, 0.05, 0.05)
    tok = _modal(0.16, ((480.0, 0.025, 1.0), (1150.0, 0.015, 0.4)))
    return _tail(_mix(0.4, (0.0, 0.5 * scrape), (0.2, tok)), 0.04)


def academy_graduation() -> np.ndarray:
    """Four bells climbing fifths and octaves, D4 to A5, and a paper flourish."""
    notes = ((0.00, 293.66), (0.12, 440.00), (0.24, 587.33), (0.36, 880.00))
    parts = [(at, (1.0 - 0.1 * i) * _bell(f, 1.1, 0.55)) for i, (at, f) in enumerate(notes)]
    parts.append((0.36, 0.25 * _bell(1760.0, 0.8, 0.35)))
    parts.append((0.0, 0.3 * _paper(0.2, 121) * _swell(0.2, 0.02, 0.06)))
    return _tail(_room(_mix(1.5, *parts), mix=0.2), 0.2)


def share_paper_eject() -> np.ndarray:
    """A printed card pushed out: a quick bright fwip, then a little flutter."""
    d = 0.45
    t = np.arange(int(SR * d)) / SR
    fwip = (_paper(d, 131, 900.0, 3500.0) * (1 - np.clip(t / 0.08, 0, 1))
            + _paper(d, 132, 2500.0, 9000.0) * np.clip(t / 0.08, 0, 1))
    flutter = 0.5 + 0.5 * np.sin(2 * np.pi * 28.0 * t) ** 2
    env = _swell(d, 0.02, 0.07) + 0.25 * flutter * _swell(d, 0.10, 0.08)
    return _tail(_room(fwip * env, mix=0.08))


def scenario_token_drop() -> np.ndarray:
    """A heavier token dropped on the table, bouncing twice before it settles."""
    hit = lambda a: a * _modal(0.25, ((380.0, 0.05, 1.0), (900.0, 0.03, 0.6),
                                      (1700.0, 0.02, 0.35), (2900.0, 0.012, 0.2)))
    return _tail(_room(_mix(
        0.6, (0.0, hit(1.0)), (0.0, 0.5 * _click(0.01, 2000.0, 8000.0, 0.002, 141)),
        (0.16, hit(0.45)), (0.26, hit(0.2)), (0.31, hit(0.08)),
    ), mix=0.14))


def series_score_peg() -> np.ndarray:
    """A peg pushed into a scoring board: one tight knock."""
    return _tail(_modal(0.14, ((1150.0, 0.015, 1.0), (2300.0, 0.010, 0.4),
                               (3400.0, 0.006, 0.2), (500.0, 0.020, 0.3))), 0.02)


def series_final_sting() -> np.ndarray:
    """The end of a سهرة. Bigger than a level, still no side: a soft drum, an
    open fifth G–D–G, and a pad that swells under it."""
    d = 1.8
    t = np.arange(int(SR * d)) / SR
    f = 50.0 + 40.0 * np.exp(-t / 0.06)
    drum = np.sin(2 * np.pi * np.cumsum(f) / SR) * _env(len(t), 0.002, 0.25)
    pad = (np.sin(2 * np.pi * 98.0 * t) + 0.6 * np.sin(2 * np.pi * 146.83 * t + 0.5)) * _swell(d, 0.35, 0.6)
    return _tail(_room(_mix(
        d, (0.0, 0.8 * drum), (0.0, 0.35 * pad),
        (0.05, _bell(196.0, 1.6, 0.8)), (0.15, 0.8 * _bell(293.66, 1.5, 0.8)),
        (0.25, 0.7 * _bell(392.0, 1.4, 0.8)),
    ), mix=0.22), 0.3)


def thursday_sting() -> np.ndarray:
    """ليلة الخميس: an oud-like pluck climbing D–E♭–F♯–G (Hijaz), the sound of
    the café, and one glass touched at the end."""
    notes = ((0.00, 293.66), (0.11, 311.13), (0.22, 369.99), (0.33, 392.00))
    parts = [(at, _band(_pluck(f, 1.1, smooth=0.3, damp=0.996, seed=150 + i), 150.0, 3500.0))
             for i, (at, f) in enumerate(notes)]
    parts.append((0.50, 0.9 * _band(_pluck(293.66, 1.0, smooth=0.3, damp=0.996, seed=160), 150.0, 3500.0)))
    parts.append((0.50, 0.6 * _band(_pluck(440.0, 1.0, smooth=0.3, damp=0.996, seed=161), 150.0, 3500.0)))
    parts.append((1.05, 0.12 * _modal(0.4, ((2900.0, 0.12, 1.0), (4150.0, 0.08, 0.6)))))
    return _tail(_room(_mix(1.5, *parts), mix=0.2), 0.2)


def title_equip() -> np.ndarray:
    """A brass clasp closing on a nameplate, with a short shimmer."""
    clasp = _modal(0.1, ((1800.0, 0.012, 1.0), (4200.0, 0.008, 0.5), (6100.0, 0.005, 0.25)))
    shimmer = 0.35 * _bell(1318.5, 0.4, 0.22) + 0.25 * _bell(1975.5, 0.4, 0.18)
    return _tail(_room(_mix(0.45, (0.0, clasp), (0.03, shimmer)), mix=0.12))


def lobby_ready_tick() -> np.ndarray:
    """One neutral wooden tick when a seat is ready — identical for every seat."""
    return _tail(_modal(0.1, ((900.0, 0.012, 1.0), (2100.0, 0.006, 0.35))), 0.02)


def founder_letter_open() -> np.ndarray:
    """A letter unfolded twice, the second fold the crisper one."""
    fold = lambda s, lo, hi: _paper(0.22, s, lo, hi) * _swell(0.22, 0.06, 0.06)
    return _tail(_room(_mix(0.75, (0.0, 0.7 * fold(171, 600.0, 5000.0)),
                               (0.28, fold(172, 1000.0, 7500.0))), mix=0.1))


def partner_pick() -> np.ndarray:
    """A portrait card slid forward and a soft string answering it."""
    slide = _paper(0.15, 181, 900.0, 6000.0) * _swell(0.15, 0.04, 0.04)
    string = _band(_pluck(392.0, 0.4, smooth=0.5, damp=0.993, seed=182), 120.0, 3500.0)
    return _tail(_room(_mix(0.45, (0.0, 0.5 * slide), (0.08, 0.8 * string)), mix=0.12), 0.08)


def invite_seal() -> np.ndarray:
    """An invitation sealed: a light wax press and one small bell."""
    squish = _band(_paper(0.2, 191), 150.0, 1400.0) * _swell(0.2, 0.03, 0.06)
    thump = _modal(0.25, ((96.0, 0.05, 1.0), (200.0, 0.03, 0.3)))
    return _tail(_room(_mix(0.55, (0.0, 0.5 * squish), (0.03, thump),
                               (0.12, 0.3 * _bell(1174.66, 0.43, 0.18))), mix=0.14))


def season_pass_unlock() -> np.ndarray:
    """A small brass lock: two clicks of the mechanism, the latch, a shimmer."""
    click = lambda s: (_modal(0.05, ((2200.0, 0.006, 1.0), (3700.0, 0.004, 0.5), (5300.0, 0.003, 0.3)))
                       + 0.4 * _click(0.05, 3000.0, 10000.0, 0.0015, s))
    latch = _modal(0.2, ((320.0, 0.03, 1.0), (780.0, 0.02, 0.5)))
    return _tail(_room(_mix(
        0.9, (0.0, 0.6 * click(201)), (0.09, 0.7 * click(202)), (0.16, latch),
        (0.25, 0.25 * _bell(880.0, 0.65, 0.3)), (0.35, 0.2 * _bell(1318.5, 0.55, 0.25)),
    ), mix=0.14), 0.12)


def brand_motif() -> np.ndarray:
    """The sonic mark (F19), shared with every marketing video: a desk lamp
    clicks on, a card turns under it, and the lit room settles in low.

    It is the lamp and the card, nothing tonal enough to belong to a side."""
    lamp = _mix(0.08, (0.0, _modal(0.08, ((3100.0, 0.008, 1.0), (4700.0, 0.005, 0.5), (180.0, 0.02, 0.4)))),
                (0.0, 0.6 * _click(0.02, 1000.0, 8000.0, 0.0015, 211)))
    d = 0.95
    t = np.arange(int(SR * d)) / SR
    room = (np.sin(2 * np.pi * 73.42 * t) + 0.5 * np.sin(2 * np.pi * 110.0 * t + 0.6)) * _swell(d, 0.25, 0.35)
    unit = lambda x: x / (np.max(np.abs(x)) or 1.0)
    return _tail(_room(_mix(d, (0.0, unit(lamp)), (0.24, 0.7 * unit(card_flip())),
                            (0.12, 0.35 * unit(room))), mix=0.15), 0.15)


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

# The 1.1 desk objects that fire on every tap are small sounds and stay small:
# a token, a peg, a ready tick and a clasp are gestures, not announcements.
PEAK.update({
    "academy_token_place": 0.45, "academy_wrong_return": 0.45,
    "series_score_peg": 0.45, "lobby_ready_tick": 0.35,
    "title_equip": 0.5, "partner_pick": 0.5, "casebook_paper_slide": 0.5,
})

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
    # 1.1 (BIG-UPDATE-1.1-FINAL §9).
    "casebook_wax_press": casebook_wax_press,
    "casebook_paper_slide": casebook_paper_slide,
    "casebook_string_pluck": casebook_string_pluck,
    "casebook_level_sting": casebook_level_sting,
    "case_accuse_gavel": case_accuse_gavel,
    "case_wrong_crack": case_wrong_crack,
    "case_reveal_swell": case_reveal_swell,
    "chapter_envelope_open": chapter_envelope_open,
    "chapter_seal_press": chapter_seal_press,
    "academy_token_place": academy_token_place,
    "academy_wrong_return": academy_wrong_return,
    "academy_graduation": academy_graduation,
    "share_paper_eject": share_paper_eject,
    "scenario_token_drop": scenario_token_drop,
    "series_score_peg": series_score_peg,
    "series_final_sting": series_final_sting,
    "thursday_sting": thursday_sting,
    "title_equip": title_equip,
    "lobby_ready_tick": lobby_ready_tick,
    "founder_letter_open": founder_letter_open,
    "partner_pick": partner_pick,
    "invite_seal": invite_seal,
    "season_pass_unlock": season_pass_unlock,
    "brand_motif": brand_motif,
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

    print("\nSpeech is not made here: the F16 narrator is rendered by "
          "tool/voice/generate_kratos.mjs.")
    print("A cue with no file plays nothing and the transition falls back to "
          "its on-screen text, so the app is complete without them.")


if __name__ == "__main__":
    main()

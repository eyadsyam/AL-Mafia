"""Turn a supplied piece of music into the game's looping score.

    python tool/normalise_score.py --check     # measure and report, write nothing
    python tool/normalise_score.py             # write assets/audio/score_loop.ogg

Source goes in `raw_assets/audio/` and the shipped bed is always written to
`assets/audio/score_loop.ogg`, which is the path `AudioDirector.scoreLoop`
names. Swapping the music is therefore a source file plus one run of this
script, and nothing in `lib/` changes.

# Why a piece of music cannot just be dropped in

The score in this app is not background music in the usual sense. It is the
only sound allowed to be audible while a player is holding the phone, and it is
allowed *because* it never changes — see the long note on `AudioDirector.syncScore`.
A bed that reacts to anything is a channel that reports on the game. Three
properties follow from that, and a normal music file has none of them:

**It must not have an audible seam.** Every piece of recorded music ends by
stopping, and most of them end by fading out. Looped raw, `Unresolved Room`
dropped from -19 dBFS at its head to -58 dBFS across its last half second: the
room would go quiet for a moment every five minutes and then the music would
start again, which is the single most conspicuous thing a background bed can
do. The outro is therefore cut off and the new tail is cross-faded into the
head, so the loop closes at constant level and the join is a blend rather than
a stop.

**It must sit at a known level.** `AudioDirector.scoreVolume` is 0.5 on the
documented assumption that the file is -20 dBFS RMS, which puts the bed at
about -26 dBFS in the room. A mastered track arrives far louder than that —
this one at -12.5 dBFS, peaking a tenth of a decibel *over* full scale — and
dropping it in without regauging would make the score roughly twice as loud as
the level the volume constant was chosen for. So the body is gained to the
target RMS here rather than compensated for in the app: the constant is the
contract, and the asset meets it.

**It must leave room for talking.** The bed this replaces was a synthesised
drone with a literal hole in it — 0.00% of its energy between 1 and 4 kHz,
where consonants live. Real music does not have that hole and cannot be given
one without becoming a different piece, so this script does not try; what it
does is *measure* the band and print it, so the trade is visible rather than
discovered at a table. `Unresolved Room` carries 0.92% of its energy there,
which at the shipped level is around -46 dBFS in the speech band — quiet enough
that the notch is not missed. A brighter piece would measure several percent
and would need either a notch or a lower `scoreVolume`, and that decision
should be made by whoever supplies it.

# What it does not do

No fade-in, no fade-out, no ducking, no phase-aware edit. The loop is one file
that plays from app start to app exit; anything that varied it would have to be
argued past L-11 first.
"""

import os
import shutil
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "raw_assets", "audio")
OUT = os.path.join(ROOT, "assets", "audio", "score_loop.ogg")

# Everything is decoded and measured at the source's own rate. 48 kHz because
# that is what both the supplied piece and the synthesised cues already use, and
# resampling a bed nobody will hear the top octave of buys nothing.
SR = 48000

# What the shipped file must measure, in dBFS RMS. `AudioDirector.scoreVolume`
# is chosen against this number; changing one without the other silently moves
# the score's level in the room.
TARGET_RMS_DB = -20.0

# Seconds of equal-power cross-fade closing the loop. Long enough that two
# unrelated moments of the piece blend rather than collide, short enough that
# the blur is over before anyone works out what they are listening to. Four
# seconds is comfortable for ambient material; a piece with a strong metre
# would want a length that is a whole number of bars instead.
CROSSFADE_SECONDS = 4.0

# How far below the body's median level a half-second window has to sit before
# it counts as intro or outro rather than music. Generous on purpose: the cost
# of trimming a little real music is nothing, and the cost of leaving a fade in
# is the seam this script exists to remove.
TRIM_TOLERANCE_DB = 4.0
WINDOW_SECONDS = 0.5

# The most the level may change across the wrap, in dB, before the loop counts
# as having a seam. This is the number the whole script exists to hold: the
# supplied piece measured 38.80 dB and the synthesised bed it replaces measures
# 0.51 dB. Three is chosen to sit above ordinary bar-to-bar variation in music
# and well under anything a room would hear as the music stopping.
#
# It FAILS the run rather than warning. A score that dips once every five
# minutes is the one defect nobody notices while testing for ten and everybody
# notices on the third evening.
SEAM_MAX_DB = 3.0

# Vorbis quality for the shipped file. 3 is about 112 kbps stereo, which is
# roughly what the supplied source itself carries — re-encoding lossy material
# below its own bitrate is where reverb tails start to swirl, and an ambient bed
# is nothing but reverb tails.
VORBIS_QUALITY = 3


def db(x):
    return 20.0 * np.log10(max(float(x), 1e-12))


def decode(path):
    """Source -> float64 stereo array. ffmpeg does the container and the codec."""
    result = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le",
         "-acodec", "pcm_f32le", "-ar", str(SR), "-ac", "2", "-"],
        capture_output=True,
    )
    if result.returncode != 0:
        sys.exit("FAIL: ffmpeg could not decode "
                 f"{os.path.relpath(path, ROOT)}\n"
                 + result.stderr.decode(errors="replace")[:500])
    return np.frombuffer(result.stdout, dtype="<f4").reshape(-1, 2).astype(np.float64)


def envelope(x):
    """Half-second window RMS of the mono mixdown, in dBFS."""
    mono = x.mean(axis=1)
    win = int(SR * WINDOW_SECONDS)
    n = len(mono) // win
    return np.array([
        db(np.sqrt((mono[i * win:(i + 1) * win] ** 2).mean())) for i in range(n)
    ]), win


def trim(x):
    """Cut the intro and the outro back to where the piece is at level.

    Walks in from each end while the window is more than [TRIM_TOLERANCE_DB]
    under the median. That is deliberately not a silence detector: a fade that
    stops 10 dB down is still a fade, and looping it still produces a dip.
    """
    env, win = envelope(x)
    floor = np.median(env) - TRIM_TOLERANCE_DB

    head = 0
    while head < len(env) and env[head] < floor:
        head += 1
    tail = len(env)
    while tail > head and env[tail - 1] < floor:
        tail -= 1

    return x[head * win:tail * win], head * win / SR, (len(env) - tail) * win / SR


def close_loop(x):
    """Fold the tail over the head so the file's end runs into its own start.

    Equal power (`sqrt` of the linear ramp), not equal amplitude: two
    uncorrelated pieces of music summed with linear ramps dip about 3 dB in the
    middle of the crossfade, which is a small version of exactly the hole this
    is here to remove.
    """
    n = int(SR * CROSSFADE_SECONDS)
    if len(x) < 4 * n:
        sys.exit("FAIL: the source is too short to cross-fade "
                 f"{CROSSFADE_SECONDS}s at each end")

    ramp = (np.arange(n, dtype=np.float64) + 0.5) / n
    up = np.sqrt(ramp)[:, None]
    down = np.sqrt(1.0 - ramp)[:, None]

    head, tail, body = x[:n], x[len(x) - n:], x[n:len(x) - n]
    blend = head * up + tail * down

    # The blend goes at the **end**, not the start, and the difference is only
    # audible once — on the very first play. The blend opens on tail material
    # and closes on head material, so wherever it sits the wrap is continuous:
    # it ends on `head` and the file that follows it begins at `body`, which is
    # what `head` ran into in the source. Putting it last means the app opens on
    # real music rather than on four seconds of the piece overlapping itself.
    return np.concatenate([body, blend])


def gain(x, target_db):
    rms = np.sqrt((x ** 2).mean())
    g = 10 ** ((target_db - db(rms)) / 20.0)
    return x * g, db(rms), g


def band_share(x, lo, hi):
    """Fraction of total energy in [lo, hi) Hz. Speech lives at 1-4 kHz."""
    mono = x.mean(axis=1)
    n = 1 << 18
    window = np.hanning(n)
    acc = None
    for i in range(0, len(mono) - n, n):
        spectrum = np.abs(np.fft.rfft(mono[i:i + n] * window)) ** 2
        acc = spectrum if acc is None else acc + spectrum
    if acc is None:
        return 0.0
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    return float(acc[(freqs >= lo) & (freqs < hi)].sum() / acc.sum())


def seam_step(x):
    """Level difference across the wrap, in dB. The number that matters."""
    half = SR // 2
    head = np.sqrt((x[:half] ** 2).mean())
    tail = np.sqrt((x[len(x) - half:] ** 2).mean())
    return abs(db(head) - db(tail))


def encode(x, path):
    """Write float samples out through ffmpeg as Ogg Vorbis."""
    pcm = np.clip(x, -1.0, 1.0).astype("<f4").tobytes()
    result = subprocess.run(
        ["ffmpeg", "-y", "-v", "error",
         "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
         "-c:a", "libvorbis", "-q:a", str(VORBIS_QUALITY), path],
        input=pcm, capture_output=True,
    )
    if result.returncode != 0:
        sys.exit("FAIL: ffmpeg could not encode\n"
                 + result.stderr.decode(errors="replace")[:500])
    return os.path.getsize(path)


def sources():
    if not os.path.isdir(RAW):
        sys.exit(f"FAIL: no {os.path.relpath(RAW, ROOT)} directory")
    found = [f for f in sorted(os.listdir(RAW))
             if f.lower().endswith((".ogg", ".mp3", ".wav", ".flac", ".m4a"))]
    if len(found) != 1:
        sys.exit(f"FAIL: expected exactly one audio file in "
                 f"{os.path.relpath(RAW, ROOT)}, found {len(found)}: "
                 + ", ".join(found or ["nothing"])
                 + "\n\nThe score is one file. Two sources means nothing can "
                   "say which one ships.")
    return os.path.join(RAW, found[0])


def main():
    if not shutil.which("ffmpeg"):
        sys.exit("FAIL: ffmpeg is not on PATH, and it is what decodes and "
                 "encodes here.")

    dry_run = "--check" in sys.argv[1:]
    src = sources()
    print(f"score source: {os.path.relpath(src, ROOT)}\n")

    raw = decode(src)
    print(f"  as supplied    {len(raw) / SR:8.2f} s   "
          f"rms {db(np.sqrt((raw ** 2).mean())):7.2f} dBFS   "
          f"peak {db(np.abs(raw).max()):7.2f} dBFS   "
          f"seam step {seam_step(raw):5.2f} dB")

    body, cut_head, cut_tail = trim(raw)
    print(f"  trimmed        {len(body) / SR:8.2f} s   "
          f"({cut_head:.1f}s intro, {cut_tail:.1f}s outro removed)")

    looped = close_loop(body)
    looped, raw_rms, g = gain(looped, TARGET_RMS_DB)
    peak = np.abs(looped).max()

    print(f"  closed+gained  {len(looped) / SR:8.2f} s   "
          f"rms {db(np.sqrt((looped ** 2).mean())):7.2f} dBFS   "
          f"peak {db(peak):7.2f} dBFS   "
          f"seam step {seam_step(looped):5.2f} dB   (gain {g:.3f}x)")

    speech = band_share(looped, 1000, 4000)
    # 10*log10, not 20: `speech` is a share of *energy* and `db()` converts
    # amplitude. Getting that backwards reports the speech band twice as far
    # down as it is, which is the direction that would wave a bright piece
    # through.
    speech_db = 10.0 * np.log10(max(speech, 1e-12))
    print(f"\n  energy 1-4 kHz {speech * 100:5.2f}%  "
          f"-> about {TARGET_RMS_DB + speech_db:.0f} dBFS in the speech band, "
          f"{TARGET_RMS_DB + speech_db - 6:.0f} dBFS at scoreVolume 0.5")

    if peak > 1.0:
        sys.exit("\nFAIL: the gained file clips. Lower TARGET_RMS_DB or supply "
                 "a source with more headroom.")

    seam = seam_step(looped)
    if seam > SEAM_MAX_DB:
        sys.exit(f"\nFAIL: the loop still steps {seam:.2f} dB at the wrap, over "
                 f"the {SEAM_MAX_DB:.1f} dB budget — the room will hear the "
                 f"music stop and start.\n\nThe usual cause is a piece that "
                 f"changes level across its length, so the trimmed head and "
                 f"tail are simply at different volumes; a longer "
                 f"CROSSFADE_SECONDS helps a little and a different excerpt "
                 f"helps more. Do NOT raise the budget: it is the one property "
                 f"that makes a bed safe to leave running in a player's hand.")

    if dry_run:
        print("\n  (dry run — nothing written)")
        return

    size = encode(looped, OUT)
    print(f"\n  wrote {os.path.relpath(OUT, ROOT)}  {size:,} B")
    print("\nNext:\n  python tool/generate_asset_constants.py\n  flutter test")


if __name__ == "__main__":
    main()

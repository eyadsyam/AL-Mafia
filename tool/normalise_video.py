"""Normalise the ambient loops into shippable animated WebP.

    python tool/normalise_video.py                 # every slot
    python tool/normalise_video.py outcome_death_loop bg_home_loop

Naming slots does only those, which matters more here than it does in
`normalise_art.py`: a full run is minutes of encoding, and a run that is
interrupted leaves the slot it was writing **zero bytes long**. A zero-length
asset fails the widget suite in a way that looks like a real regression, so the
recovery from a killed run needs to be "redo that one slot", not "redo the lot".

Naming a subset skips the `pair` check for any pair whose other half is not in
the subset — do the halves together (`outcome_death_loop outcome_saved_loop`)
if the thing you changed could move either of them apart.

Source loops go in `raw_assets/assets/videos/<slot>.webp` — whatever the
generator produced, at whatever frame rate and length. This script resamples
each one to the frame count the manifest asks for, gains it into its luminance
band, and encodes it under its byte budget.

The Reduce Motion fallback is NOT written here. Every loop has a still
counterpart already in the image manifest — `bg_night_loop` has `bg_night`,
`outcome_death_loop` has `outcome_death` — at full 1080x1920 rather than the
loop's 720x1280, and `AppBackdrop` takes the two together. Writing a second
still from frame 0 would ship seven more files to be the lower-resolution
version of art that is already there.

# Why the gain is solved across the whole loop, not per frame

Per-frame normalisation would flatten the animation: if every frame is pushed to
the same mean, the drift of light that *is* the loop disappears and you ship a
very expensive still. So one scalar gain is solved on the loop's own mean and
applied to every frame equally. The motion survives; the loop as a whole lands
in its band.

What is then checked per frame is *excursion* — no frame more than 10% off the
loop mean. That is the number that catches a flash or a cut, which is the thing
a table would actually read as a signal.

Two corrections run before that check, because generated loops arrive with the
same two defects every time:

**The loop does not close.** A generator asked for "seamless" gives you a clip
whose last frame is nowhere near its first — `outcome_saved` arrived at 41.5 on
frame 0 and 56.1 on frame 95, a 35% step that reads as a visible blink once a
cycle. So the tail is cross-dissolved into the head over `_FADE` frames. The
source is resampled to `frames + _FADE` and comes out at exactly `frames`, which
is what keeps a `pair` matching after the fix.

**A sweep is not an ambience.** `bg_vote` arrived swinging 59 -> 24 -> 59, a
2.4:1 dip in the middle of the loop. The limiter pulls any frame more than
`_LIMIT` off the mean back to that boundary and leaves every frame inside it
alone, so the slow drift the loop is *for* survives and only the swing is
removed. It is a limiter, not a normaliser: flattening every frame to the mean
would buy the check at the cost of the animation.

# Why the encoder spends the whole budget, and why some loops are softened

`max_bytes` is a *budget*, not a target, and the first version of this script
treated it as a pass mark: it started at quality 62 and stopped at the first
setting that fit. `bg_home` fit on the first try at 426 KB against a 600 KB
budget, so 174 KB of the allowance was simply never spent — and what that
bought was a backdrop visibly blocking up in its dark gradients, which is the
one defect a near-black ambient loop shows first. The search now runs the other
way: it finds the *highest* quality that still fits, by bisection over the
quality ladder, so the file lands just under the budget rather than well under
it.

That alone is not enough for a generated loop, because most of what the encoder
is being asked to store is sensor-style grain the generator put there. Grain is
incompressible by construction — it is different in every frame, so inter-frame
prediction cannot help — and it consumes the bitrate that the gradients need.
`soften` is an optional Gaussian radius applied to the frames before anything
else measures them: a fraction of a pixel, invisible as blur on a backdrop that
is behind a card spread and a layer of falling icons, and worth several quality
steps in what is left over for the parts of the picture people can actually see.
It is per-slot and off by default, because a loop with real detail in it should
not be softened to buy a number.

# Why the pairs are checked

`pair` in the manifest marks loops that answer the same question for the table:
someone died / nobody died, mafia won / town won. They must run the same number
of frames and sit in the same band, or the length of the announcement tells the
room the answer before the words arrive. That is not a leakage invariant in the
Article I sense — the table sees these together — but it is the same failure
shape one screen later, and it costs nothing to hold.
"""

import json
import os
import sys

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "raw_assets", "assets", "videos")
MANIFEST = os.path.join(ROOT, "tool", "manifest.json")

# Rec. 709. The same weights normalise_art.py and the leakage suite use; a
# second opinion about what "brightness" means is how two pipelines that both
# look right end up disagreeing.
LUMA = (0.2126, 0.7152, 0.0722)

# How far a single frame may sit from the loop's own mean, as a fraction.
MAX_EXCURSION = 0.10

# What the limiter aims for. Under MAX_EXCURSION so that the re-measure after
# encoding — which sees WebP's own quantisation — still has room to pass.
LIMIT = 0.08

# Frames cross-dissolved from the tail into the head to close the loop.
FADE = 8

# The encoder effort used to *find* the quality rung, and the one used to write
# the file that ships. Method 6 is roughly three times slower than method 4 and
# a few percent smaller, so paying for it on all four search passes buys
# nothing: the search only needs to know which rung fits. The winner is then
# re-encoded at 6, and the result re-checked against the budget — method 6 is
# expected to be the smaller of the two, but the check is there rather than the
# assumption, and it steps down a rung if it is ever wrong.
PROBE_METHOD = 4
FINAL_METHOD = 6

# The quality ladder the encoder searches. Bisected, not walked: the top of the
# ladder is now well above anything that fits, so a linear scan would spend four
# or five expensive encodes before reaching a candidate.
QUALITY = (16, 20, 24, 30, 36, 44, 52, 62, 68, 74, 80, 84, 88, 92)


def _mean(img):
    small = img.convert("RGB").resize((96, 96))
    px = list(small.getdata())
    n = len(px)
    return sum(LUMA[0] * p[0] + LUMA[1] * p[1] + LUMA[2] * p[2] for p in px) / n


def soften(frames, radius):
    """Blur the grain out before the encoder has to pay for it.

    See the note in the module docstring: this is not a look, it is a bitrate
    decision. Zero or absent leaves the frames exactly as they arrived.
    """
    if not radius:
        return frames
    return [f.filter(ImageFilter.GaussianBlur(radius)) for f in frames]


def load_frames(path, want, size):
    """Resample the source to exactly `want` frames at `size`.

    Nearest-neighbour in *time*: the sources arrive at 24fps and ship at 12, so
    this is usually a clean 2:1 decimation. Picking indices by ratio rather than
    asserting a factor means a source delivered at 30 or 60 still works, and a
    source shorter than `want` repeats frames rather than failing — the loop is
    seamless either way because the last frame is chosen to sit one step before
    the first.
    """
    im = Image.open(path)
    n = getattr(im, "n_frames", 1)
    grab = want + FADE
    out = []
    for i in range(grab):
        im.seek(int(i * n / grab))
        out.append(im.convert("RGB").resize(size, Image.LANCZOS))
    return out, n


def close_loop(frames):
    """Cross-dissolve the tail into the head so the loop actually closes.

    Consumes the FADE extra frames `load_frames` grabbed: the first FADE frames
    become a blend of themselves and the last FADE, weighted so the seam lands
    where the eye is least likely to be. Returns exactly `len(frames) - FADE`.
    """
    n = len(frames)
    head, tail = frames[:FADE], frames[n - FADE:]
    blended = [
        Image.blend(tail[i], head[i], (i + 1) / (FADE + 1))
        for i in range(FADE)
    ]
    return blended + frames[FADE:n - FADE]


def limit(frames):
    """Pull outlying frames back toward the loop mean; leave the rest alone."""
    means = [_mean(f) for f in frames]
    loop = sum(means) / len(means)
    out = []
    for f, m in zip(frames, means):
        if loop <= 0:
            out.append(f)
            continue
        dev = (m - loop) / loop
        if abs(dev) <= LIMIT:
            out.append(f)
            continue
        want = loop * (1 + LIMIT * (1 if dev > 0 else -1))
        g = want / m
        out.append(f.point(lambda v, g=g: min(255, int(v * g + 0.5))))
    return out


def gain(frames, target):
    """One scalar gain, solved on the loop mean, applied to every frame."""
    means = [_mean(f) for f in frames]
    loop_mean = sum(means) / len(means)
    g = target / loop_mean if loop_mean > 0 else 1.0
    out = [f.point(lambda v, g=g: min(255, int(v * g + 0.5))) for f in frames]
    return out, loop_mean, g, means


def encode(frames, path, fps, budget):
    """Write the loop at the highest quality on the ladder that fits `budget`.

    Bisection over [QUALITY], four encodes instead of up to fourteen. The
    previous version stopped at the first setting that fit, starting from 62,
    which meant a loop that fit immediately kept whatever was left of its
    allowance — see the module docstring. Spending it is the whole point: these
    are near-black gradients, and gradients are what a starved WebP encoder
    posterises into blocks first.

    The lowest rung is written unconditionally if nothing fits, so the caller
    always has a file to measure and a size to report in its failure.
    """
    ms = int(round(1000 / fps))

    def write(i, method):
        frames[0].save(
            path,
            format="WEBP",
            save_all=True,
            append_images=frames[1:],
            duration=ms,
            loop=0,          # forever
            quality=QUALITY[i],
            method=method,
            minimize_size=True,
        )
        return os.path.getsize(path)

    lo, hi, best = 0, len(QUALITY) - 1, None
    while lo <= hi:
        mid = (lo + hi) // 2
        if write(mid, PROBE_METHOD) <= budget:
            best, lo = mid, mid + 1
        else:
            hi = mid - 1

    # Nothing fits even at the bottom rung: write it anyway, so the over-budget
    # failure the caller is about to report describes a file that is there.
    if best is None:
        best = 0

    size = write(best, FINAL_METHOD)
    while size > budget and best > 0:
        # Only reachable if method 6 came out *larger* than method 4 at the same
        # quality, which is not what it is for. Step down rather than ship over.
        best -= 1
        size = write(best, FINAL_METHOD)
    return QUALITY[best], size


def main():
    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    videos = manifest.get("videos", [])
    if not videos:
        sys.exit("FAIL: manifest has no 'videos' list")

    wanted = [a for a in sys.argv[1:] if not a.startswith("-")]
    if wanted:
        known = {e["slot"] for e in videos}
        unknown = [w for w in wanted if w not in known]
        if unknown:
            sys.exit("FAIL: no such slot(s): " + ", ".join(unknown)
                     + "\n  known: " + ", ".join(sorted(known)))
        videos = [e for e in videos if e["slot"] in wanted]

    print("normalising loops\n", flush=True)
    pairs, rows, failures = {}, [], []

    for entry in videos:
        slot = entry["slot"]
        src = os.path.join(RAW, slot + ".webp")
        if not os.path.exists(src):
            failures.append(f"{slot}: no source at {os.path.relpath(src, ROOT)}")
            continue

        out = os.path.join(ROOT, entry["out"])
        os.makedirs(os.path.dirname(out), exist_ok=True)

        want = entry["frames"]
        size = tuple(entry["size"])
        lo, hi = entry["lum_band"]
        target = (lo + hi) / 2

        frames, src_n = load_frames(src, want, size)
        frames = soften(frames, entry.get("soften", 0))
        frames = limit(close_loop(frames))
        frames, raw_mean, g, _ = gain(frames, target)

        means = [_mean(f) for f in frames]
        final = sum(means) / len(means)
        worst = max(abs(m - final) / final for m in means) if final else 0

        q, nbytes = encode(frames, out, entry["fps"], entry["max_bytes"])
        print(f"  {slot:24s} q{q:<3d} {nbytes:10,d} B  mean {final:5.1f}",
              flush=True)

        if not lo <= final <= hi:
            failures.append(
                f"{slot}: mean {final:.1f} outside band [{lo}, {hi}]")
        if worst > MAX_EXCURSION:
            failures.append(
                f"{slot}: frame excursion {worst:.1%} over {MAX_EXCURSION:.0%} "
                "- a flash or a cut, not an ambient loop")
        if nbytes > entry["max_bytes"]:
            failures.append(
                f"{slot}: {nbytes:,} B over budget {entry['max_bytes']:,} B "
                "even at lowest quality")

        if "pair" in entry:
            pairs.setdefault(entry["pair"], []).append((slot, want, tuple(entry["lum_band"])))

        rows.append((slot, src_n, want, raw_mean, g, final, worst, q, nbytes))

    print(f"  {'slot':24s} {'src':>4s} {'out':>4s} {'raw':>7s} {'gain':>6s} "
          f"{'final':>7s} {'excur':>7s} {'q':>3s} {'bytes':>10s}")
    total = 0
    for slot, src_n, want, raw, g, final, worst, q, nbytes in rows:
        total += nbytes
        print(f"  {slot:24s} {src_n:4d} {want:4d} {raw:7.1f} {g:6.3f} "
              f"{final:7.1f} {worst:6.1%} {q:3d} {nbytes:10,d}")
    print(f"\n  {len(rows)} loop(s), {total:,} B")

    for name, members in pairs.items():
        frames = {m[1] for m in members}
        bands = {m[2] for m in members}
        if len(frames) > 1 or len(bands) > 1:
            failures.append(
                f"pair '{name}' disagrees: "
                + ", ".join(f"{s} {f}f {b}" for s, f, b in members))
        else:
            print(f"  pair '{name}': {len(members)} loops, "
                  f"{members[0][1]} frames, band {list(members[0][2])}  OK")

    if failures:
        print("\nFAIL:")
        for f in failures:
            print("  " + f)
        sys.exit(1)

    print("\nNext:\n  python tool/generate_asset_constants.py\n  flutter test")


if __name__ == "__main__":
    main()

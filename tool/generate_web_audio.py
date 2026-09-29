"""Generate Safari-compatible MP3 siblings for every shipped Ogg asset.

Requires ffmpeg on PATH. Existing up-to-date outputs are left untouched.
"""

from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
FOLDERS = (ROOT / "assets" / "audio", ROOT / "assets" / "voice")


def main() -> None:
    converted = 0
    for folder in FOLDERS:
        for source in sorted(folder.rglob("*.ogg")):
            target = source.with_suffix(".mp3")
            if target.exists() and target.stat().st_mtime >= source.stat().st_mtime:
                continue
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-loglevel",
                    "error",
                    "-i",
                    str(source),
                    "-codec:a",
                    "libmp3lame",
                    "-q:a",
                    "4",
                    str(target),
                ],
                check=True,
            )
            converted += 1
    print(f"web audio: {converted} converted")


if __name__ == "__main__":
    main()

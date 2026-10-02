# Play Store assets

Latest upload package: see `GOOGLE-PLAY-SUBMISSION.md` and
`../docs/PLAY-RELEASE-2026-09-21.md`. Developer: Eyad Syam;
support: eyadsyam124@gmail.com. The screenshot inventory below is historical.
Do not upload every file automatically (Play allows at most eight phone
screenshots); `09-privacy-release.png` predates the final settings-only privacy
revision and is review evidence, not current store marketing.

Everything here is uploaded by hand in the Play Console. Nothing in this folder
is bundled into the app.

| File | What it is | Play's requirement |
|---|---|---|
| `icon-512.png` | App icon, 512×512 PNG | 512×512, 32-bit PNG, no transparency, no rounded corners baked in |
| `feature-graphic-1024x500.png` | Feature graphic | exactly 1024×500 PNG or JPEG |
| `screenshots/play-ar/*.png` | Connected Arabic marketing set, 1080×1920 | Upload all six in numeric order |
| `screenshots/*.png` | Raw phone captures and review evidence | Keep for evidence; do not upload the whole folder |
| `listing-ar.md` | Arabic listing — the default locale | name ≤30, short ≤80, full ≤4000 |
| `listing-en.md` | English listing, plus the Data safety answers | same limits |
| `permissions.md` | The RECORD_AUDIO justification, and the full permission set | free text |

Regenerate the two images with:

```bash
python tool/generate_store_assets.py
```

Regenerate the connected screenshot set with:

```bash
python tool/generate_play_screenshots.py
```

Its campaign backdrop is `raw_assets/store/connected-play-panorama.png`; the
phones inside it are real release captures. The final files are
`screenshots/play-ar/01.png` through `06.png`.

---

## Screenshots — what is here, and what is not

Captured on the `Pixel_9_Pro_2` emulator from the **release** build
(`app-x86_64-release.apk`, version 1.0.0+1), 4 September 2026, with the system
UI in demo mode so the status bar reads a clean 9:00 rather than a laptop's
clock and a stack of debug icons.

| File | Screen |
|---|---|
| `01-home.png` | Home — the card spread and «ابدأ اللعبة» |
| `02-mode.png` | «هتلعبوا إزاي؟» — one phone, or each on their own |
| `03-players.png` | Adding the roster |
| `04-roles.png` | The role split, with the validity line |
| `05-settings.png` | Match settings |
| `06-handoff.png` | The handoff pad — «دوس واستنى عشان تشوف كارتك» |
| `07-reveal.png` | The card in hand, before the flip |

`01`–`11` are raw captures and review evidence. The separate `play-ar` set is the store-ready campaign: it uses real screens from this inventory and the latest online-enabled release capture. User-owned full-match acceptance remains outside this automated release pass.

To finish the set, install the release build on the emulator and walk a match:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.mafiamaster.mafia_master/.MainActivity
```

Two things that cost time the first time round:

* **The identity pad is a five-second hold.** `adb shell input tap` does
  nothing to it, and neither does a two-second swipe. What works is
  `adb shell input touchscreen swipe X Y X+2 Y+2 6500` — a real press with a
  little travel, held past the full duration.
* **`adb shell input text` cannot type Arabic**, which is why the roster in
  `03`–`07` reads *Eyad, Nour, Omar…* in Latin. If Arabic names matter for the
  final store images, type them on the emulator's own keyboard, or capture on a
  physical phone.

### Play upload order

Play shows screenshots in the order they are uploaded, and the first two are
what appear in search results. Upload `screenshots/play-ar/01.png` through `06.png` in numeric order. The gold line and burgundy glow continue across the row, while each frame communicates a single benefit.



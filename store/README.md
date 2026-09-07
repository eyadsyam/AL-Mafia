# Play Store assets

Everything here is uploaded by hand in the Play Console. Nothing in this folder
is bundled into the app.

| File | What it is | Play's requirement |
|---|---|---|
| `icon-512.png` | App icon, 512×512 PNG | 512×512, 32-bit PNG, no transparency, no rounded corners baked in |
| `feature-graphic-1024x500.png` | Feature graphic | exactly 1024×500 PNG or JPEG |
| `screenshots/*.png` | Phone screenshots, 1280×2856 | 2–8 per form factor, 320–3840px per side |
| `listing-ar.md` | Arabic listing — the default locale | name ≤30, short ≤80, full ≤4000 |
| `listing-en.md` | English listing, plus the Data safety answers | same limits |
| `permissions.md` | The RECORD_AUDIO justification, and the full permission set | free text |

Regenerate the two images with:

```bash
python tool/generate_store_assets.py
```

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

**Seven of the eight requested screens are not here yet.** Role reveal (the
face, not the back), the night grid, morning with a trace, the confrontation,
the result, analytics and the online lobby all need a match played through on
the emulator, and that run was stopped part-way. `01`–`07` are real captures
of the shipped build; nothing here is a mock-up or a render.

To finish the set, install the release build on the emulator and walk a match:

```bash
adb install -r build/app/outputs/flutter-apk/app-x86_64-release.apk
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
what appear in search results. Recommended order once the set is complete:

1. `06-handoff` — the one image that says *pass the phone* without a caption
2. morning + trace — the thing no other Mafia app does
3. `01-home`
4. night grid
5. confrontation
6. result
7. analytics
8. online lobby

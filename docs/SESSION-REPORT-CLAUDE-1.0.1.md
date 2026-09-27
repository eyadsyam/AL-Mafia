# تقرير جلسة Claude — تحديث 1.0.1 (للتسليم لـ Codex)

> **Codex: read this first.** It is the full state of update 1.0.1 at the end of Claude's session (2026-09-25 → 2026-09-28).
> Everything below is verified by commands that were actually run. Nothing is claimed that was not run.

---

## 0. فين الشغل بالظبط

| البند | القيمة |
|---|---|
| الـ worktree | `D:\Flutter Data\Projects\AL Mafia\.claude\worktrees\epic-roentgen-094f21` |
| الـ branch | `claude/epic-roentgen-094f21` (متعملش push على GitHub، والمالك هو اللي يقرر) |
| آخر commit | `19dce18` |
| النسخة | `1.0.1+9` (versionCode 9) |
| نقطة البداية | `7dc16b0`: snapshot لشغلك القديم في worktree phase-99 (المراحل 102–107)، اتنقل هنا كما هو |
| نسخ احتياطية | `refs/backup/update101-20260925` و`refs/backup/update101-snapshot2` (في repo الـ phase-99 worktree) |
| حجم التغيير | 725 ملف، +122k / −17k سطر من `7dc16b0^` لحد `HEAD` |

**اقرا بالترتيب:** `HANDOFF.md`، ثم `docs/PROGRESS.md` (المراحل 102–113 في الآخر)، ثم `build/update101/status.md` (أوامر تشغيل كل فيتشر)، ثم الملف ده.

### الـ commits بالترتيب

```
7dc16b0 WIP: update 1.0.1 phases 102-107 (monetization, economy, Council Life)   ← شغلك
7cd0d7a Council Life client, Ads v2 and match awards for 1.0.1
b883292 Ads review fixes: offline-safe banner, uncropped sizing, lobby clearance
bd03100 Result screens scroll instead of overflowing; 1.0.1+9
0071b59 Docs: 1.0.1 checkpoint and the art request for Codex
778b583 Docs: point the art request at this worktree
61a95c3 Vault design pass: one engraved card system across the 1.0.1 surfaces
d8e604b Tool: one-shot Telegram order-notification setup
8089ab8 Tool: Telegram setup waits for the owner's first message
c45e472 Ads v3 per match and Payments v2 transfer with admin review
b1f7d7e Review fixes: forward-only session ads, order before payment link
3330123 Deploy 1.0.1 server dark; owner setup tools for Play verification and admin
80a8741 Fix Play key secret quoting; refund sync logs its failure code
e41ec2d Play verification works end to end up to Google's permission check
e531baf Email link fallback for account protection and admin; SMTP templates and setup guide
337bd06 PROGRESS phase 113, HANDOFF last-verified, redirect note
19dce18 Art request: one sheet per icon family plus a slicer, ~85 generations down to 25
```

---

## 1. قرارات المالك (نهائية، اتفقنا عليها بجلسة أسئلة وأجوبة)

### الإعلانات: "لكل ماتش"، مش عدد في اليوم

المالك رفض صراحةً "3 إعلانات في اليوم". القاعدة: الإعلانات مربوطة بالماتش، و**ممنوع أي إعلان جوه الماتش**.

| المكان | القاعدة |
|---|---|
| App-open | على شاشة اللوجو وقت فتح التطبيق |
| Pre-match interstitial | قبل الدخول للّوبي من Create / Join / «روم جديدة للشلة»، ويتخطّى لو إعلان الفتح لسه ظاهر |
| Post-match interstitial | بعد كل ماتش |
| Rewarded بعد الماتش | x2، وبعدها x3 اختياري (أغلى وأطول إعلان) |
| Pass-and-play | إعلان قبل توزيع الأدوار وبعد النتيجة |
| Session interstitial | كل 5 دقايق في القوايم بس |
| Banners | في شاشات الانتظار بس: اللوبي، قايمة الرومات، السجل، الخزنة، تعديل البروفايل |
| Rewarded extras | مضاعفة الصندوق اليومي، لفّة عجلة تانية، تبديل المهمة |
| الحدود | مفيش سقف عملي. أمان: 40 في اليوم، و90 ثانية بين أي إعلانين full-screen، وقابل للتغيير من السيرفر |
| لاعب جديد | أول ماتش من غير إعلانات |
| Quiet Pass | بـ 199.99 ج.م، بيشيل كل الإعلانات الأوتوماتيك (الـ rewarded الاختيارية تفضل) |

### الدفع: هجين
- **Google Play Billing** و**إنستا باي / فودافون كاش** جوه نسخة أندرويد (Play) والويب.
- المالك قَبِل مخاطرة سياسة جوجل. Claude **رفض يخبّي الفيتشر عن مراجعة جوجل أو يزوّر Data safety**، وكل حاجة مكتوبة بصدق في الـ submission doc.
- **نفس السعر بالظبط** في كل طرق الدفع.
- **الإثبات:** سكرين شوت + اسم المحوِّل. أقصى حد طلبين pending، والطلب ينتهي بعد 72 ساعة، والرفض لازم بسبب يظهر للاعب.
- **الموافقة:** إشعار تيليجرام للمالك، والموافقة من صفحة `/admin` على الويب (للمالك بس).
- **Kill switches:** `transfer_enabled_android` / `transfer_enabled_web`، والاتنين OFF.
- لينكات الدفع (secrets على السيرفر، ماتتكتبش في الكود):
  - `COIN_PAY_INSTAPAY_URL` = https://ipn.eg/S/eyadsyammisr/instapay/6EKrjh
  - `COIN_PAY_VODAFONE_CASH_URL` = نسخة https من http://vf.eg/vfcash?id=mt&qrId=n9pXrW

---

## 2. اللي اتبنى (ملخص كل مرحلة، والتفاصيل في `docs/PROGRESS.md`)

| المرحلة | اللي اتبنى |
|---|---|
| **102** | الامتثال والموافقة: صفحة خصوصية AR/EN، و UMP consent مكتوب من جديد، والـ store listings اتحدّثت |
| **103 / 103b** | اقتصاد السيرفر: `economy_config`، والـ ledger بـ `source_key` idempotency، و AdMob SSV registry، والصندوق اليومي، والعجلة (10/20/35/60/100)، والـ streak، و Play products، والـ refund claw-back، والـ debt offset، والـ tombstones |
| **104 / 105 / 104c** | الكلاينت: capability negotiation (أي فشل = OFF)، والـ rewarded بخطوتين، وطبقة Play Billing، وتاب عروض Play، وتاب المكافآت |
| **106** | نسخة مراجعة 1.0.1+8 |
| **107** | Council Life: مهام يومية وأسبوعية، ورتب (10 tiers، مستوى 1–50)، ولوحة صدارة أسبوعية مع opt-out، ودعوات، و Starter Bundle، وكل الرسم بالكود لحد ما صورك توصل |
| **108** | Ads v2: app-open، و banners، و rewarded extras |
| **109** | جوايز آخر الماتش (7، بتتحسب بعد النتيجة العامة بس)، و 8 reactions (في اللوبي والنتيجة بس)، و welcome-back، و Founder badge |
| **110** | Ads v3: نظام "لكل ماتش" اللي فوق، و full-screen ledger واحد مشترك، وخطوات x2 ثم x3 |
| **111** | Payments v2: التحويل + بيانات الإثبات + bucket خاص `payment-proofs` + `/admin` + تيليجرام + مسح الإثبات بعد 90 يوم |
| **(design)** | `lib/ui/economy/vault_kit.dart`: نظام كروت محفورة واحد لكل شاشات 1.0.1 (commit `61a95c3`) |
| **112** | نشر السيرفر live، وكل الفيتشرز dark (مقفولة) |
| **113** | Email-link fallback، و SMTP templates، وتيستات على الـ DB الحقيقية بـ rollback، و rebuild، ونشر الويب |

### تفاصيل مهمة في آخر المراحل
- **Email-link fallback (113):**
  - Supabase من غير custom SMTP بيبعت إيميلات فيها لينك بس، مش كود.
  - زرار «فتحت اللينك من الإيميل» في حماية الحساب بيعمل refresh للـ session ويتأكد إن الإيميل اتأكد.
  - في الاسترجاع على جهاز جديد، الكود بس اللي بيشتغل.
  - `/admin` بيسمع `onAuthStateChange`.
  - القوالب في `supabase/templates/*.html`، والدليل في `docs/EMAIL-SMTP-SETUP.md` (Resend).
- **Result screen:** كان بيعمل overflow (scroll غير محدود جوه Column)، واتصلح بـ scroll + زرار rematch ثابت تحت.

---

## 3. حالة السيرفر الـ LIVE (Supabase `hezjbrnveajypfqmjfnh`)

**كل حاجة منشورة، وكل الفيتشرز OFF.** التشغيل بيكون فيتشر فيتشر من `build/update101/status.md`، وبعد موافقة المالك بس.

### الداتابيس
- **Migrations اتطبّقت بالترتيب:**
  - `20260924000500_coin_orders`
  - `20260925000100_update101_economy`
  - `20260925000200_coin_order_debt_offset`
  - `20260925000300_council_life`
  - `20260925000400_web_quiet_pass`
  - `20260925000500_ads_v2`
  - `20260925000600_awards_reactions`
  - `20260927000100_ads_v3`
  - `20260927000200_payments_v2`
- **الحالة بعد النشر:**
  - `economy_config` صف واحد، كل الـ flags `false`.
  - 27 جدول جديد.
  - 0 functions متاحة لـ anon/authenticated.
  - الـ bucket `payment-proofs` خاص.
  - أسعار `coin_packs` بالقروش: 2999 / 19999 / 4999 / 9999 / 18000.
- **Backup قبل النشر:** `build/update101/backup/`.
- **Fingerprint (قبل وبعد كل حاجة، متطابق):** 687 user، 8 wallets، إجمالي الرصيد 850، 10 ledger rows، 0 orders.
- **تيستات على الـ DB الحقيقية:**
  - 8 suites PASS جوه transactions عملت rollback.
  - `council_life*.sql` و`awards_reactions.sql` مااشتغلوش على السيرفر، لأنهم بيعملوا `ALTER auth.users` والـ role مش مالك الجدول (42501). دول PASS محليًا.

### Edge functions منشورة
`economy`، `play_purchase`، `coin_orders`، `admob_ssv` (`--no-verify-jwt`)، `play_voided_sync` (`--no-verify-jwt`، محمية بهيدر `x-sync-secret`).

### Secrets (الأسامي بس، وممنوع تطبع القيم)
`COIN_PAY_INSTAPAY_URL`، `COIN_PAY_VODAFONE_CASH_URL`، `ADMOB_REWARDED_ANDROID_ID`، `ADMOB_REWARDED_V2_ANDROID_ID`، `TELEGRAM_BOT_TOKEN`، `TELEGRAM_ADMIN_CHAT_ID`، `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (**base64** للـ JSON، و`_shared/play_auth.ts` بيقبل JSON أو base64)، `PLAY_SYNC_SECRET` (موجود كمان في Vault باسم `play_sync_secret`).

### Cron
- `purge-room-reactions`
- `play-voided-sync`: بيشتغل كل 6 ساعات (`23 */6 * * *`) عن طريق `net.http_post`.

### Auth
- Site URL = `https://almafia.vercel.app`، و Redirect = `https://almafia.vercel.app/**`.
- القوالب ماتتعدلش غير بعد custom SMTP.

### الأدمن
- المالك هو الأدمن الوحيد في `commerce_admins` (`tool/make_me_admin.ps1`).
- إشعارات تيليجرام شغالة: البوت `@mafia_master_orders_bot`، والإعداد بـ `tool/setup_telegram_admin.ps1`.

### Play verification
- السلسلة كلها شغالة: المفتاح اتقرا، والـ JWT اتعمل، و Google OAuth نجح.
- بس Google Play API بيرد **401**، لأن صلاحية الـ service account في Play Console لسه بتنتشر (بتاخد لحد 36 ساعة).
- الـ cron بيجرّب لوحده. لما يبقى 200 يبقى خلاص.
- **الفحص يدوي:** من Git Bash، اعمل `net.http_post` للـ function، وبعدين اقرا `net._http_response`.

---

## 4. الحسابات الخارجية

### AdMob
- التطبيق: `ca-app-pub-9179063936085117~7320479940`.
- كل الوحدات SSV، والـ SSV بتروح على `admob_ssv`.

| النوع | الاسم | الـ unit id |
|---|---|---|
| rewarded | `rewarded_match_bonus` | `/8711609352` |
| rewarded v2 | `rewarded_steps_v2` | `/9448608978` |
| interstitial | `post_match_interstitial` | `/5836667020` |
| app open | `app_open_launch` | `/9527218766` |
| banner | `lobby_banner` | `/3131088967` |

### Play Console
- الحساب: developer `8516115344939721781`، التطبيق `4973103045227664588`، مسار Alpha المغلق `4698930525049701953`.
- **المنتجات الخمسة Active** (purchase option `buy`):

| المنتج | السعر (ج.م) |
|---|---|
| `mm_remove_interruptions` | 199.99 |
| `mm_coins_500` | 49.99 |
| `mm_coins_1200` | 99.99 |
| `mm_coins_2500` | 180 |
| `mm_starter_bundle` | 29.99 |

- **Alpha:** 1.0.0 (1) متاحة للمختبرين. اتعمل draft لإصدار رقم 2، والمالك بيرفع `Mafia-Master-1.0.1+9.aab` بإيده (Chrome upload حدّه 10MB).

### Vercel
`https://almafia.vercel.app` عليه البيلد الحالي من `e531baf`. الـ md5 بتاع `main.dart.js` مطابق، و`/`، `/admin`، `/privacy/`، `/app-ads.txt` كلهم 200.

---

## 5. البيلدات (`build/release-1.0.1+9/`)

| الملف | ملاحظات |
|---|---|
| `Mafia-Master-1.0.1+9.aab` | موقّع بالـ upload key، وفيه وحدات AdMob الخمسة الحقيقية. Play Billing لـ 1.0.1 شغال بشكل افتراضي (بيتقفل بـ `PLAY_PRODUCTS_DISABLED` بس)، والـ scenario store القديم مقفول |
| `Mafia-Master-1.0.1+9.apk` | نفس المصدر، APK كامل |
| `Mafia-Master-1.0.1+9-test-ads.apk` | package `.adstest` وإعلانات جوجل التجريبية. للتجربة بس، **ماينفعش يتنشر** |
| `Mafia-Master-1.0.1+9-web.zip` | `WEB_COIN_SALES=true`، و `sw.js` build `20260927-084218` |
| `symbols/`، `symbols-test-ads/` | لفك الـ crash stacks |
| `SHA256SUMS.txt` | اتراجع `sha256sum -c` وكله OK |

**أوامر البناء:**
```
powershell -File tool/build_apk.ps1 -Bundle
powershell -File tool/build_apk.ps1
powershell -File tool/build_test_ads.ps1
powershell -File tool/build_web.ps1 -CoinSales
```
- قبل ما تبني الويب انسخ `build/web/.vercel` في مكان تاني، ورجّعه بعد البناء.
- النشر: `npx vercel deploy --prod --yes` من جوه `build/web`.

---

## 6. آخر تحقق (commit `e531baf`، والـ commits اللي بعده docs/tool بس)

| الفحص | النتيجة |
|---|---|
| `flutter analyze` | 0 errors، 0 warnings (90 infos قديمة) |
| `flutter test --concurrency=2` | **1384 passed، 1 skipped** |
| `node tool/test_sql_without_docker.mjs` | **42/42** |
| `supabase/tests/*.test.mjs` | **11/11** |

---

## 7. شغلك انت يا Codex: الصور

**الملف:** `docs/ART-REQUEST-CODEX-1.0.1.md`. اتغيّر عشان يوفّر الكريدت:
- بدل ~85 صورة لوحدها، بقوا **8 شيتات** (كل عيلة أيقونات في صورة واحدة، grid منتظم) + **17 صورة لوحدها** = **25 صورة**.
- **التقطيع:** `python tool/slice_art_sheet.py --list` يعرض الشيتات، و`python tool/slice_art_sheet.py <ID> <sheet.png>` يقطّع.
  - بيشيل الخلفية، سواء كانت شفافة أو أخضر `#00FF00`.
  - بيقصّ على حدود العنصر، ويظبط المقاس، ويحفظ WebP تحت الحد (40KB للأيقونة و120KB للغلاف).
  - الأصل بيتحفظ في `raw_assets/update101b/`.
- **الشيتات:**

| الشيت | الشبكة | اللي فيه |
|---|---|---|
| `A_ranks` | 5×2 | الرتب |
| `B_contracts` | 3×3 | المهام |
| `C_council_small` | 3×3 | أيقونات المجلس والبروفايل |
| `D_store_covers` | 3×2 | أغلفة المتجر، وكل خانة لازم ≥768 |
| `E_store_small` | 3×2 | أيقونات المتجر الصغيرة |
| `F_daily` | 3×3 | المكافآت اليومية |
| `G_awards` | 4×2 | الجوايز |
| `H_reactions` | 4×2 | الريأكشنز |

- **بعد كل ملف:**
  1. ضيفه في `CouncilRaster.delivered` في `lib/ui/economy/council_art.dart`.
  2. شغّل `flutter test test/widget/council_raster_test.dart`.
  3. املا جدول التسليم في آخر ملف الطلب.
- **بعد ما الصور تخلص:** `flutter analyze` + `flutter test`، ثم rebuild (1.0.1+10 لو 9 اترفعت على Play)، ثم نشر الويب.
- **قواعد الهوية:** نوار، فحمي وعاجي وذهبي عتيق وعنابي. ممنوع نص جوه الصورة، وممنوع شعارات جهات تانية، وممنوع أي صورة تكشف دور (Doc 05).

---

## 8. اللي فاضل

### على المالك
1. **رفع الـ AAB على Alpha:** الـ draft جاهز، فاضل سحب الملف وإرساله للمراجعة.
2. **Resend SMTP:** المالك يعمل الحساب ويمشي على `docs/EMAIL-SMTP-SETUP.md`، وبعدين تتلصق القوالب في Supabase → Auth → Emails. ماحصلش إيميل حقيقي من أوله لآخره لسه.
3. **التجربة على الموبايل وتشغيل الفيتشرز بالترتيب:**
   1. المكافآت اليومية
   2. الإعلانات
   3. Play Billing
   4. التحويل
   
   الـ SQL لكل خطوة في `build/update101/status.md`.
4. **Play verification:** يستنى الـ 401 تبقى 200 (لوحدها).
5. **سياسة Google Payments:** بيع حاجات رقمية بتحويل جوه نسخة Play ممكن يحتاج alternative billing. المالك قَبِل المخاطرة، والـ switch `transfer_enabled_android` مقفول لحد ما يقرر.

### على Codex
الصور (قسم 7)، ثم البيلد النهائي.

### معروف ومفتوح
- مسح الإثبات بعد 90 يوم بيحصل لما الأدمن يفتح القايمة (مفيش cron ليه).
- الـ image picker مااتجرّبش على جهاز حقيقي.
- المكتبات الجديدة `image_picker` و`image` اتضافت (والمالك عارف).

---

## 9. دروس وفخاخ (عشان ماتقعش فيها)

- **Flutter path فيه مسافة:** `D:/Flutter Data/Futter/flutter/bin/flutter.bat`. بيكسر native-asset hooks و Kotlin incremental.
- **PowerShell على ويندوز بيشيل علامات التنصيص** من JSON/SQL اللي بيتبعت لـ `npx`. الحل: Git Bash، أو `-f file.sql`، أو base64 للـ secrets.
- **`supabase db query`** محتاج `--linked --project-ref hezjbrnveajypfqmjfnh` الاتنين مع بعض.
- **Google Voided Purchases API** بترفض startTime ≥ 30 يوم بالظبط (400)، فبنستخدم 29.
- **Brave فيه ad blocker** بيكسر AdMob و Play Console، فاستخدم Chrome.
- **Play Console:**
  - Claude مايقدرش يكتب أسعار (classifier)، فالمالك هو اللي يكتبها.
  - الضغط بالـ ref مابيعملش focus على الـ inputs، فاضغط بالإحداثيات.
- **Line endings:** الـ agents ممكن يقلبوا CRLF، فراجع `git diff --stat` قبل الـ commit.
- **PGlite test harness** اتصال واحد بس، وده محاكاة محلية ومش بديل عن السيرفر.
- **ممنوع تطبع** `dart_defines.json` أو أي secret. اعرض أسامي المفاتيح بس.
- **الـ Artwork:** ماتقراش bytes صور كبيرة في الـ context غير بعد تصغير (≤420px).
- **الـ git stash** مشترك بين كل الـ worktrees، فماتستخدمش `git stash pop` على الفاضي.

## 10. قواعد ثابتة (من `CLAUDE.md`)
- Doc 05 (zero role leakage) فوق أي حاجة.
- محرك واحد، وممنوع `if (isOnline)` في الـ widgets.
- `lib/engine/**` pure.
- ممنوع ألوان أو مقاسات أو مدد hardcoded برا `design_tokens.dart`.
- العربي: line-height 1.6، و letter-spacing صفر، و text scale 1.0.
- ممنوع مكتبات جديدة من غير إذن المالك.
- ممنوع push أو نشر غير لما المالك يطلب.
- كل الفيتشرز الجديدة OFF بشكل افتراضي وبتتشغل من السيرفر.

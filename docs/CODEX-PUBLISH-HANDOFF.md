# تسليم النشر إلى Codex — سيد المافيا 1.0.1 (23 سبتمبر 2026)

> **أحدث نسخة: 1.1.0+3 — راجع §9 (المراحل 87–91). الدفع هناك بمراجعة يدوية وليس تأكيدًا تلقائيًا.**

> Claude نفّذ الكود والاختبارات والبناء المحلي فقط. **لم يُنشر أي شيء**: لا Supabase ولا Vercel ولا Play Console ولا AdMob. لم يُفتح أي حساب لتعديله، ولم يُنشأ تطبيق أو وحدة إعلانية أو منتج أو مفتاح.
> لا توجد أي قيمة سرية في هذا الملف.

## 0. الخلاصة

| البند | الحالة |
|---|---|
| سبب كراش البداية | **مثبت ومصلح** — R8 full mode حذف مُنشئ `WorkDatabase_Impl` (انظر §1) |
| الإصلاح على المحاكي (x86_64 + ترجمة arm64) | PASS |
| الإصلاح على جهاز المستخدم Samsung ARM64 | **NOT VERIFIED** — لم يتصل الجهاز |
| قائمة الأوض العامة (تحديث تلقائي، أعداد، لا دخول آلي) | PASS محليًا؛ **تحتاج نشر migration + function** لتظهر السعة والحد الأدنى الحقيقيين |
| الرجوع/اللغة/الألوان/اسم الأيقونة | PASS (اختبارات + محاكي) |
| الإعلانات والمشتريات | **معطلة في RC عمدًا**؛ الكود مصلح لكن التفعيل يحتاج حسابات، وسيناريو الشراء يحتاج قرار منتج (§5) |
| إعلانات الويب | **غير منفذة** — تحتاج أهلية حساب (§5.3) |
| جاهز للنشر بالكامل؟ | **لا.** راجع §7 |

## 1. الكراش — السبب المثبت

- **الملفان الفاشلان** (من `build/deliverables/SHA256SUMS.txt`):
  - `Mafia-Master-1.0.0-rc.apk` — `5dfdd50cb0181ee87bd122ddf26f4b83887d2cf440ec74bd9552753dddd48949`
  - `Mafia-Master-1.0.0-test-ads.apk` — `cbcf0a47665bbc55b64a3a2badb4e2ff46bf53f66ff1e105dde2d1426cbd4a71`
- **إعادة الإنتاج**: تثبيت نظيف على Pixel_9_Pro_2 (Android 16، Play services موجودة)، بـ ABI x86_64 وبـ `--abi arm64-v8a`؛ الاثنين يموتوا قبل Flutter:
  ```
  FATAL EXCEPTION: main
  RuntimeException: Unable to get provider androidx.startup.InitializationProvider:
    Failed to create an instance of androidx.work.impl.WorkDatabase
  ```
- **السبب**: AGP 9.0.1 يفعّل R8 full mode افتراضيًا. `google_mobile_ads` يسحب WorkManager 2.7.0 وRoom 2.2.5، وقواعدهم القديمة (`-keep class * extends RoomDatabase`) تحفظ الكلاس بدون المُنشئ في full mode. `build/app/outputs/mapping/release/usage.txt` للنسخة الفاشلة يذكر صراحة إزالة `WorkDatabase_Impl.<init>()` و`OverwritingInputMerger.<init>()` و`ArrayCreatingInputMerger.<init>()`. يحدث على **كل** جهاز وقت أول تشغيل — الإصدار 79 لم يكن فيه مكتبة الإعلانات، لذلك لم يظهر قبل الإصدار 80.
- **الإصلاح**: `android/app/proguard-rules.pro` (keep للمُنشئات) ومربوط في `build.gradle.kts`.
- **Regression**: `tool/check_android_r8.py` يقرأ تقرير R8 نفسه بعد كل build ويفشل السكربت لو المُنشئات اتشالت. أظهر FAIL على البناء القديم وPASS على الجديد. مربوط في `tool/build_apk.ps1` و`tool/build_test_ads.ps1`.
- **تحقق بعد الإصلاح (محاكي)**: تثبيت نظيف x86_64 ✔، تثبيت نظيف arm64 (ترجمة) ✔، ترقية فوق RC 1.0.0 الفاشل (versionCode 1→2) ✔، إعادة فتح ✔، تشغيل بارد بدون شبكة (wifi+data مقفولين) ✔، الميكروفون غير ممنوح افتراضيًا ✔. لا FATAL في logcat.
- **لم يُختبر**: جهاز Samsung ARM64 حقيقي، Android 12/13 فعلي، جهاز بدون Google Play services. المطلوب من المستخدم: تثبيت `Mafia-Master-1.0.1-rc.apk` فوق القديم وفتحه؛ لو ظهر أي توقف، إرسال موديل الجهاز وإصدار Android و`adb logcat -b crash`.

### إصلاحات تشغيل أخرى في نفس المرحلة
- ترتيب المشتريات: كان `app.dart` يفتح `purchaseStream` قبل أن يستمع `ScenarioPurchaseController`، فمشتريات Play المستعادة وقت الفتح كانت تضيع. الآن الاستماع يسبق التهيئة (`scenario_store.dart`) + اختبار.
- الخدمات الاختيارية (إعلانات/مشتريات) تمر عبر `runOptionalService`: خطأ لا يسقط اللعبة، يُسجَّل نوعه فقط، ويقبل إعادة المحاولة (لم يعد `_initializing`/`_started` يعلق للأبد).
- إعلان يصل بعد انتهاء المهلة يُتخلص منه (`dispose`) بدل تسريبه.

## 2. ملفات تغيّرت في هذه الجولة

**Android/بناء**: `android/app/proguard-rules.pro` (جديد)، `android/app/build.gradle.kts`، `android/app/src/main/AndroidManifest.xml` (aliases للأيقونة)، `android/app/src/main/kotlin/.../MainActivity.kt`، `pubspec.yaml` (1.0.1+2)، `tool/build_apk.ps1`، `tool/build_test_ads.ps1`، `tool/check_android_r8.py` (جديد)، `tool/check_store_listing.py` (جديد).

**Dart**: `lib/main.dart`، `lib/app/{app,router,locale_controller}.dart`، `lib/app/l10n/*`، `lib/platform/{optional_service,launcher_label}.dart` (جديد)، `lib/platform/monetization/rewarded_ads_mobile.dart`، `lib/transport/game_snapshot.dart`، `lib/ui/screens/online/{online_entry_screen,online_session,rewarded_reward_button,result_share_button}.dart`، `lib/ui/screens/setup/{profile_screen,scenario_store}.dart`، `lib/ui/theme/{design_tokens,mafia_theme}.dart`، `lib/ui/widgets/language_picker.dart`.

**Supabase**: `migrations/20260923000100_public_room_listing.sql` (جديد)، `migrations/20260923000200_play_purchase_integrity.sql` (جديد)، `functions/browse_rooms/index.ts`، `functions/admob_ssv/{index,verify}.ts`، `functions/play_purchase/index.ts`، `functions/play_voided_sync/index.ts` (جديد)، `functions/_shared/{api,play_auth}.ts`، `tests/{public_room_listing,play_purchase_integrity}.sql` (جديد)، `tests/admob_ssv_verify.test.mjs` (جديد).

**ويب/متجر/وثائق**: `web/index.html` (noscript قابل للفهرسة)، `web/robots.txt`، `web/sitemap.xml`، `web/privacy/index.html`، `store/listing-{ar,en}.md`، `docs/GROWTH-FREE-PLAN.md`.

**اختبارات**: `test/app/optional_services_startup_test.dart`، `test/widget/{online_entry,online_lobby,language_picker,rewarded_reward_button}_test.dart`، `test/platform/haptics_call_site_test.dart`، `test/transport/server_surface_test.dart`.

> ملاحظة مسار: العمل تم في worktree `.claude/worktrees/crash-fixes-and-testing-b6c2f5` بعد نسخ حالة main غير الملتزمة إليه كما هي. لا commit ولا push. لنقل التغييرات إلى النسخة الرئيسية انسخ الملفات أعلاه (أو خذ الـ worktree كله).

## 3. ترتيب النشر المطلوب (Codex) والتوافق

الترتيب مهم؛ كل خطوة متوافقة مع السابقة ومع العملاء القديمة:

1. **Migrations** (بالترتيب):
   - `20260923000100_public_room_listing.sql` — تضيف `public_room_listing(uuid)` فقط؛ `public_rooms()` القديمة باقية كما هي.
   - `20260923000200_play_purchase_integrity.sql` — أعمدة جديدة لها defaults، جدول `play_sync_state`، `create or replace commit_play_purchase` (نفس التوقيع)، ودالة `revoke_voided_play_purchases`. آمنة والمشتريات معطلة.
   - نفّذ قبلها dry-run، ثم الاختبارات داخل transaction بـ rollback: `supabase/tests/public_room_listing.sql` و`supabase/tests/play_purchase_integrity.sql`. **هذه الاختبارات لم تُشغّل محليًا** (Docker Desktop لم يعمل على الجهاز) — أول تشغيل لها عند Codex.
2. **Functions**:
   - `browse_rooms` — تستدعي الدالة الجديدة، وترجع للقديمة تلقائيًا لو لم تُطبّق (PGRST202). آمنة بأي ترتيب، لكن السعة/الحد الأدنى الحقيقيين يظهروا فقط بعد الخطوة 1.
   - `admob_ssv` — (مع `verify.ts`) 400 للتوقيع الخاطئ/المشوه، **503 لفشل جلب مفاتيح Google** (AdMob يعيد المحاولة)، 400 للرفض الحتمي من الدفتر. `--no-verify-jwt` كما كانت.
   - `play_purchase` — نفس السلوك + رفض `REBIND_LIMIT` (409).
   - `play_voided_sync` — **جديدة**، `--no-verify-jwt`، تتطلب secret `PLAY_SYNC_SECRET` في header `x-sync-secret`. جدولها (كل 6 ساعات مثلًا) عبر pg_cron+pg_net أو scheduler خارجي بعد ضبط الأسرار. لا تجدولها قبل تفعيل البيع.
   - `quick_match` — **لم يعد العميل يستدعيها**. لا تحذفها قبل أن يختفي العملاء القدامى (1.0.0)؛ غير ضارة.
3. **الويب** — انشر `build/web` من 1.0.1 (تفاصيل §6). لا تستخدم `tool/build_web.ps1 -Publish`.
4. **Play** — ارفع AAB 1.0.1 (versionCode 2) لمسار اختبار داخلي أولًا.

**تراجع**: الـ migrations إضافية فقط؛ التراجع = إعادة نشر النسخ السابقة من functions (`browse_rooms` القديمة تعمل مع أو بدون الدالة الجديدة). `commit_play_purchase` القديمة موجودة في `20260921000900_paid_scenario.sql` لو احتجت استرجاعها. لا تعدّل migrations منشورة سابقًا.

## 4. الإعدادات المطلوبة (أسماء فقط)

| الاسم | المكان | متى |
|---|---|---|
| `ADS_ENABLED`, `ADMOB_TEST_MODE`, `ADMOB_APP_ID`, `ADMOB_REWARDED_ANDROID_ID` | `dart_defines.json` (محلي، git-ignored) | عند تفعيل الإعلانات؛ `build_apk.ps1` يرفض ADS_ENABLED بدون IDs صحيحة الشكل |
| `ADMOB_REWARDED_ANDROID_ID` | Supabase function secret لـ `admob_ssv` | مع SSV |
| `PLAY_BILLING_ENABLED`, `PLAY_SCENARIO_PRODUCT_ID` | `dart_defines.json` | بعد قرار §5.2 |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Supabase secret (`play_purchase`, `play_voided_sync`) | قبل أي بيع |
| `PLAY_SYNC_SECRET` | Supabase secret + الـ scheduler | مع جدولة `play_voided_sync` |

الحالة الحالية في `dart_defines.json`: `ADS_ENABLED=false`, `ADMOB_TEST_MODE=false`, `PLAY_BILLING_ENABLED=false`، ولا توجد AdMob IDs. **لم تتسرب أي معرفات تجريبية إلى AAB** (§6).

## 5. الإعلانات والمشتريات — ما يلزم من الحسابات

### 5.1 AdMob (الحساب موجود على eyadsyam124@gmail.com — لا تنشئ حسابًا آخر)
1. افحص حالة إنشاء التطبيق فعليًا (آخر مشاهدة: نموذج غير مرسل). أنشئ تطبيق Android مرتبط بالحزمة `com.mafiamaster.mafia_master` **بعد** إنشاء التطبيق في Play.
2. وحدة Rewarded واحدة؛ فعّل SSV عليها بـ callback: `https://hezjbrnveajypfqmjfnh.supabase.co/functions/v1/admob_ssv` ثم «Verify URL».
3. رسالة موافقة UMP (GDPR + US states) من Privacy & messaging.
4. `app-ads.txt`: أضف السطر الذي يعطيه AdMob إلى `web/app-ads.txt` وانشره على جذر almafia.vercel.app، واضبط موقع المطوّر في Play على نفس النطاق. **لم يُنشأ الملف** لأنه يحتاج publisher ID الحقيقي.
5. ضع القيم في `dart_defines.json` + secret الـ function، ثم أعد البناء.
- **مخاطر معروفة**: التحقق يعتمد SSV الموقّعة فقط؛ حدث العميل لا يمنح شيئًا. مطالبة واحدة لكل لاعب/مباراة؛ معاملة واحدة لكل مطالبة؛ إعادة المحاولة بعد إلغاء/no-fill آمنة.
- ما تم اختباره: توقيع صحيح/خاطئ/معبث/مشوه، تدوير المفتاح (إعادة جلب مرة واحدة)، فشل الشبكة → 503، cache ومعدل الجلب (`node supabase/tests/admob_ssv_verify.test.mjs`). **لم يُختبر** callback حقيقي من AdMob (لا توجد وحدة إنتاج).

### 5.2 المشتريات — يوجد عائق منتج
- **السيناريو المدفوع «مجلس الظلال» ليس محتوى إضافيًا حقيقيًا**: هو preset لإعدادات متاحة مجانًا لأي مضيف (نقاش منظّم، همسات، مواجهة، تصويت سري، دلائل). بيعه بصيغته الحالية يعني بيع شيء متاح مجانًا. لم يخترع Claude قواعد لعب جديدة (يتطلب تصميم ومواصفة وتوافق doc 05). **المطلوب قرار من المالك**: تصميم محتوى حقيقي، أو إلغاء المنتج. حتى ذلك: `PLAY_BILLING_ENABLED=false` ولا تنشئ المنتج في Console.
- الجاهز لو قُرر البيع: التحقق الخادمي، استعادة بإعادة ربط محدودة (3 مرات/30 يومًا)، سحب الاسترداد تلقائيًا عبر Voided Purchases API (`play_voided_sync`)، واختبار SQL مكتوب لكل ذلك (لم يُشغّل). يلزم: منتج non-consumable، service account بصلاحية «View financial data / Manage orders»، ربطه في Play Console → API access، واختبار بحساب licensed tester: شراء/pending/إلغاء/استعادة/إعادة تثبيت/استرداد/تكرار.

### 5.3 إعلانات الويب — غير منفذة
- AdMob mobile SDK لا يعمل على الويب؛ الويب يستخدم stub يُخفي زر الإعلان تمامًا (لا زر وهمي).
- الخيارات الرسمية: **H5 Games Ads (Ad Placement API, `adBreak` type `reward`)** عبر AdSense، أو **Ad Manager rewarded (GPT)**. الاثنين يحتاجوا أهلية حساب (AdSense/Ad Manager) لم يُتحقق منها. العائق المحدد: لا يوجد publisher ID ويب ولا موافقة على برنامج H5 Games.
- نموذج المخاطر: مزود الويب لا يقدم SSV موقّعة مكافئة؛ لو فُعّل، المكافأة لازم تكون غير قابلة للتحويل وبسقف يومي على الخادم، ولا يُدّعى تكافؤها مع Android.

## 6. الملفات المسلّمة

مجلد: `.claude/worktrees/crash-fixes-and-testing-b6c2f5/build/deliverables-1.0.1/`

| الملف | الحجم | SHA-256 | الوصف |
|---|---|---|---|
| `Mafia-Master-1.0.1-rc.apk` | 118.3 MB | `5c59ec61b9ad49d27512d31dd9070e71569f2ad51f2ebde417ea43142a9ffb4a` | APK عادي، `com.mafiamaster.mafia_master`، 1.0.1/2، أونلاين مفعّل، إعلانات/مشتريات OFF |
| `Mafia-Master-1.0.1-test-ads.apk` | 118.6 MB | `4f74dca7a6a88a4c9164ddce16845fcf4b8b021df779f81e22753f8012bd05d2` | `…adstest`، `ADS_ENABLED=true` + `ADMOB_TEST_MODE=true` (معرفات Google التجريبية)، billing OFF |
| `Mafia-Master-1.0.1-play.aab` | 102.1 MB | `8f27f6a3a885b7eba72ac5ab544991aa74c272fedad804cfc171bc5609f7680c` | حزمة Play، نفس defines الـ RC |
| `Mafia-Master-1.0.1-web.zip` | 36.4 MB | `43638f00d299889e954defffad54d38877f9bb5e41035704390c4f4e2872a6ae` | `build/web` مضغوط؛ `main.dart.js` md5 `0d9d95ff5662cbb224f9cfde56e2b005`؛ `sw.js` build `20260923-030241` |

- التوقيع (APK وAAB): SHA-256 `082c07a46ef50b63f6f1acf440806c16c614762d8dce3b4e9bc3d41f07a19e11` — نفس المفتاح الأصلي (apksigner verify ✔، jarsigner ✔).
- minSdk 26، targetSdk 36، ABIs: arm64-v8a / armeabi-v7a / x86_64؛ 12 مكتبة 64-bit كلها ≥16KB LOAD alignment (`tool/check_android_native.py`).
- `tool/check_android_r8.py`: PASS للثلاثة.
- تسرب المعرفات التجريبية: كود Dart في RC وAAB **لا يحتوي** وحدة الإعلان التجريبية (فحص `libapp.so`). الـ manifest فيه **App ID العينة من Google** (`ca-app-pub-3940256099942544~3347511713`) كقيمة احتياطية فقط لأن SDK الإعلانات ينهار بدونه؛ لا وحدات، ولا طلب إعلان يخرج لأن `ADS_ENABLED=false`. عند التفعيل يستبدله `build_apk.ps1` بالمعرف الحقيقي تلقائيًا.
- `android:enableOnBackInvokedCallback="false"` مضاف: بدونه زر/إيماءة الرجوع في Android 16 كان يقفل التطبيق من قائمة الأونلاين بدل الرجوع لاختيار الوضع (خطأ قديم، اتصلح وتم التحقق عليه).

- **لا ترفع** `test-ads.apk` للمتجر؛ حزمته `com.mafiamaster.mafia_master.adstest` ويستخدم معرفات Google التجريبية الرسمية. `app-release.apk` في مجلد البناء **ليس** نسخة الإعلانات التجريبية (السكربت ينقلها لـ `build/test-ads/`).
- ملفات 1.0.0 القديمة في `build/deliverables/` **مرفوضة** (تنهار عند الفتح). لا تستخدمها.
- **versionCode**: 2. لم يُتحقق من Console (لم يُفتح). لو رُفع أي build سابق بـ versionCode ≥ 2، ارفع الرقم في `pubspec.yaml` وأعد البناء.
- **الويب بعد النشر، تحقق من**: `main.dart.js` md5 على الإنتاج = المحلي؛ `sw.js` يحمل طابع البناء الجديد والمتصفح يحدّث (hard reload مرة)؛ `/privacy/` و`/delete-data/` 200؛ `/join/ABCDEF` يفتح اللعبة بالكود؛ `/.well-known/assetlinks.json` يطابق SHA-256 التوقيع؛ `robots.txt` و`sitemap.xml` 200؛ `app-ads.txt` بعد إضافته. عنوان الصفحة يتبع لغة اللعبة (`onGenerateTitle`)، لكن اسم الـ PWA المثبت يظل ما خزّنه المتصفح.

## 7. ما لم يُحسم / على Codex والمالك

1. **تشغيل RC على جهاز Samsung ARM64 للمستخدم — NOT VERIFIED.**
2. اختبارات SQL الجديدة لم تُشغّل (لا Docker محليًا) — شغّلها في transaction قبل التطبيق.
3. قرار منتج السيناريو المدفوع (§5.2).
4. حسابات AdMob/Play/الويب (§5)؛ Play Console: إنشاء التطبيق، Data safety، IARC، App signing fingerprint (حدّث `assetlinks.json` بمفتاح App Signing من Play)، مسار الاختبار الداخلي.
5. **Data safety وAD_ID**: الـ manifest يحتوي `com.google.android.gms.permission.AD_ID` لأن مكتبة الإعلانات مضمّنة حتى وهي معطلة. إما تعلن ذلك في Console، أو تحذف الإذن بـ `tools:node="remove"` طالما الإعلانات معطلة. `store/GOOGLE-PLAY-SUBMISSION.md` يصف الإعلانات والمشتريات كمستقبل — لا تعلنها كمتاحة في هذا الإصدار.
6. **اسم الأيقونة**: يتبدل بين aliases. الترقية من 1.0.0 تغيّر المكوّن من `MainActivity` إلى `LauncherArabic`، وبعض الـ launchers تشيل اختصار الشاشة الرئيسية القديم مرة واحدة. تبديل اللغة قد يشيل اختصار الشاشة الرئيسية عند بعض الـ launchers (درج التطبيقات يعرض الاسم الجديد دائمًا، أحيانًا بعد ثوانٍ). Launcher Pixel لا يتبع per-app locale (تم فحصه)، لذلك aliases هي الطريقة الوحيدة.
7. الماتش البشري الكامل والصوت بين الناس: مسؤولية المستخدم.
8. `quick_match` على الخادم غير مستخدمة من 1.0.1.

## Codex continuation — 89a (2026-09-23)

Latest work remains in this worktree; no merge, deployment or release build.
Stages 87/88 are recorded in PROGRESS. Stage 89 was interrupted; this continuation
verified its existing 11-item catalog/client and fixed presentation regressions:
private phase entry immediately drops an outgoing public caption; reduced motion
hides an active transition; classic tables do not mount the optional consumer
layer; seat_cosmetics execution is explicitly revoked from client roles.

Evidence: focused store/presentation 20 PASS; full suite initially 1077 PASS,
1 skipped, 15 FAIL; the complete affected regression suites then 62 PASS after
fixes (no assertions removed). Full analyze: zero errors/warnings, 78 infos.
Node cosmetic_access and room_configuration PASS. New cosmetic_catalog.sql
and updated coin_economy.sql are NOT RUN: Docker engine unavailable.
The latter now tests an active item instead of buying the retired guide.

Remaining before closing 89: the requested catalog target is 18, but only 11
items currently exist (6 identity, 2 presentation, 1 narrator, 2 bundles).
Complete and verify the remaining real content, not placeholder products.
Run database tests against all pending migrations and review refund/seat
propagation behavior before applying them. No new image was needed for this
regression pass; generated coin artwork is already integrated by Claude.
Stage 90 web manual-transfer orders/account recovery/admin verification and
stage 91 device verification/new signed deliverables remain unimplemented.
Follow main docs/CLAUDE-UX-ECONOMY-NEXT.md latest payment section; its web-only
manual-transfer instructions override the older Play coin-purchase directions.
Existing 1.0.1 artifacts do not contain stages 87 onward.

## 89e — Revote candidates (pending deployment)

Review and test `20260924000400_revote_candidates.sql` after the existing pending
20260924 migrations. It preserves the phase/round/kicked-member guards and adds
candidate validation under the same room-state lock for INSERT and UPDATE.
Run `supabase/tests/revote_candidates.sql`, `action_epoch.sql`, `kicked_moves.sql`
and existing vote-resolution contracts before applying it. SQL is NOT RUN here:
Docker daemon unavailable. Do not infer DB verification from the client tests.

Deploy `submit_vote` and `resolve_vote` with `_shared/ballot_candidates.ts` only
after database verification. Submit preflight and atomic DB guard reject
non-tied targets; resolution excludes historical invalid targets while keeping
the complete row fingerprint for optimistic concurrency. Existing abstention,
living-seat and round rules are retained. Client reads public revote.tiedSeats
and offers only those living opponents; no invented candidate list.

Evidence: 119 Flutter regressions PASS; 9 Node helper assertions PASS; changed
Dart analysis clean; three changed TypeScript files parse using Node strip-types
(not a Deno type check). No production deployment, migration application or
release build in this phase. Phases 89b–89e remain local to this worktree.

## 8. نتائج الاختبارات

| الفحص | النتيجة |
|---|---|
| `flutter test` (المجموعة كاملة) | **PASS** — 1056 نجح، 1 متخطى، 0 فشل |
| `flutter analyze` | 0 errors، 0 warnings، 78 info (نفس العدد قبل الجولة) |
| اختبارات مركزة جديدة/معدلة | entry list (تحديث 15 ث، backoff، خلفية/عودة، dispose، تمرير، رفض امتلاء، كارت الأوضة الجديدة، الرجوع)، ترتيب المشتريات، زر المكافأة (pending قابل لإعادة المحاولة، مكافأة متأخرة، كتم الصوت أثناء الإعلان)، لون اللغة، إزالة اللغة من البروفايل — PASS |
| `node supabase/tests/admob_ssv_verify.test.mjs` | PASS |
| `node supabase/tests/room_configuration.test.mjs` | PASS |
| `supabase/tests/public_room_listing.sql`, `play_purchase_integrity.sql` | **NOT RUN** (لا Docker) |
| esbuild parse للـ edge functions المعدلة | PASS (7 ملفات) — لا يوجد Deno محليًا لفحص الأنواع |
| `tool/check_android_r8.py` | FAIL على 1.0.0 (سبب الكراش)، PASS على 1.0.1 (rc/test-ads/aab) |
| `tool/check_store_listing.py` | PASS (عربي 25/73/1414، إنجليزي 26/76/1700) |
| محاكي Pixel_9_Pro_2 (Android 16) | تشغيل نظيف x86_64 وarm64، ترقية فوق 1.0.0، إعادة فتح، بدون شبكة، قائمة الأونلاين الجديدة، الرجوع online→mode→home، ar→en→ar مع إعادة التشغيل واسم الأيقونة في الدرج، test-ads: UMP يعمل بلا كراش — PASS |
| الإعلان التجريبي بعد نتيجة مباراة فعلية | NOT VERIFIED (يحتاج مباراة أونلاين كاملة بلاعبين) |
| ويب محلي (Chrome في التطبيق، 375×812 و1280×800) | القائمة تتحدث كل ~15 ث (11/27/43/58 ث)، الرجوع → mode، التخطيط سليم — PASS |
| جهاز المستخدم | **NOT VERIFIED** |

## 9. الإصدار 1.1.0+3 — المراحل 87–91 (Claude، 23 سبتمبر 2026)

> **الدفع: مراجعة يدوية فقط؛ لا بوابة دفع ولا webhook ولا تأكيد تلقائي.** العملات لا تُضاف إلا بموافقة مدير بعد مطابقة الفلوس في كشف الحساب الحقيقي. فتح الرابط أو الرجوع منه أو «أرسلت التحويل» أو صورة إيصال ليست إثبات دفع.

هذا القسم يحل محل §3–§6 للنسخة 1.1.0. ملفات 1.0.1 في `build/deliverables-1.0.1` لا تحتوي المراحل 87 وما بعدها.

### 9.1 ما تغيّر (ملخص؛ التفاصيل في PROGRESS §87–§91)
- **87**: شاشة إعداد أولى واحدة: اللغة ← الاسم والصورة ← الصوت/الموسيقى/تقليل الحركة ← 18+ ← «قرأت الشروط والأحكام وأوافق عليها» (غير محددة مسبقًا، روابط شروط وخصوصية داخل التطبيق). الموافقة محفوظة بالإصدار (`currentTermsVersion = 2026-09-23`) والوقت، وتُرسل للسيرفر بعد دخول أوضة (لا تمنع اللعب). بعد الموافقة لا يوجد حوار قواعد قبل الأوض. تغيير اللغة لا يقفل اللعبة: تبديل اسم الأيقونة الذي كان يعطّل الـ alias الذي فُتحت منه اللعبة صار مؤجلًا حتى إغلاق اللعبة (`MainActivity.onDestroy`) مع ملاحظة للاعب.
- **88**: إزالة كارت «أوضة عامة جديدة». أوضة انتظار واحدة يملكها السيرفر لكل pool عند الحاجة فقط، أول من يدخل يصبح المضيف ذريًا. مشاركة الدعوة عبر قائمة مشاركة النظام (share_plus)، والويب Web Share أو نسخ الرابط؛ اللوبي لا ينقطع.
- **89**: «عملات المافيا» (العملة من `raw_assets/store/economy-v1/mafia-coin.png`)، متجر فيه معاينات حقيقية، و11 عنصرًا فعليًا (3 إطارات، 3 لافتات، القصر الليلي 600، المدينة القديمة 900، الحكّاء 1200، باقتان). مذكرة الاستراتيجية أصبحت مجانية في المساعدة، ومن اشتراها استرد 400 مرة واحدة.
- **90**: شراء العملات بالفلوس **من الويب فقط** (إنستا باي/فودافون كاش)، طلب محفوظ على السيرفر، «أرسلت التحويل» = بلاغ للمراجعة، لوحة مدير `/admin/coins` محمية من السيرفر، حماية الحساب بإيميل وكود لمرة واحدة. نسخة Play لا تحتوي أي رابط أو زر أو رسالة دفع خارجي، وروابط الدفع ليست في الكود أصلًا.

### 9.2 ترتيب النشر (بعد موافقة المالك)
حالة الاستضافة الحالية حسب جلسة أخرى (al-mafia-36، بطلب المالك، **ليست من هذه الجلسة**): طُبّقت `20260923000100`, `20260923000200`, `20260924000100`, `20260924000200`, `20260924000300`, `20260924000400_revote_candidates`، ونُشرت كل الدوال حوالي 10:36 بما فيها `coin_orders` (بدون الـ migration الخاصة بها، ومن غير `COIN_SALES_ENABLED`، فلا تبيع ولا تضيف شيئًا). تحقق من `supabase_migrations.schema_migrations` قبل أي خطوة.

1. **Migration** `20260924000500_coin_orders.sql` (أُعيد ترقيمها من 0400 لأن revote_candidates تحمل 0400). إضافية فقط: جداول `coin_packs` (غير مفعّلة وبدون سعر)، `commerce_admins`، `coin_orders`، `coin_order_events`، أعمدة `purchased_balance/lifetime_purchased/purchase_debt`، و`create or replace buy_reward_item` و`complete_data_deletion`. شغّل أولًا: `node tool/test_sql_without_docker.mjs` (كل الملفات) ثم dry-run على الاستضافة داخل transaction.
2. **أعد نشر الدوال** التي عُدّلت بعد 10:36: `coin_orders` و`economy` و`browse_rooms` و`player_safety` و`create_room` و`room_settings` مع `_shared/{api,coin_payments,room_configuration,purchase_access}.ts`. قارن بمحتوى الـ worktree.
3. **الويب**: `powershell -File tool/build_web.ps1 -CoinSales` (بدون `-Publish`) ثم انشر `build/web`. زر شراء العملات يظهر لكن يقول «مش متاح دلوقتي» حتى الخطوة 5.
4. **Play**: ارفع AAB 1.1.0 (versionCode 3) لاختبار داخلي. لا يحتوي شراء عملات بالفلوس.
5. **تفعيل البيع لاحقًا فقط بعد**: قرار المالك بالأسعار، ضبط SMTP وقوالب بريد الكود، إضافة حساب المالك في `commerce_admins`، واختبار الروابط على موبايل حقيقي بدون تحويل.

**تراجع**: كل الـ migrations الجديدة إضافية. لإيقاف البيع فورًا: احذف `COIN_SALES_ENABLED` (أو اجعلها غير `true`)؛ الطلبات الموجودة تبقى للمراجعة. لإخفاء الأوضة الجاهزة: أعد نشر `browse_rooms` السابقة.

### 9.3 الإعدادات (أسماء فقط، بدون قيم)
| الاسم | المكان | ملاحظة |
|---|---|---|
| `COIN_SALES_ENABLED` | secret لـ `coin_orders` | `true` فقط عند التفعيل؛ غير مضبوطة الآن |
| `COIN_PAY_INSTAPAY_URL` | secret لـ `coin_orders` | رابط المالك الموجود في `docs/CLAUDE-UX-ECONOMY-NEXT.md` (main)؛ https فقط |
| `COIN_PAY_VODAFONE_CASH_URL` | secret لـ `coin_orders` | رابط المالك الحالي **http** ⇒ سيظهر «مش متاح» حتى يتوفر رابط **https** تم التحقق منه من فودافون. لا تخترع رابطًا |
| `coin_packs.price_piastres` + `active` | جدول | قرار المالك؛ الباقات مزروعة غير مفعلة وبدون سعر (500 / 1200 / 2500 عملة) |
| `commerce_admins` | جدول | `insert` لمعرّف حساب المالك بعد ربطه بإيميل |
| Auth: Email OTP، SMTP، قالب «Change email» و«Magic link» يحتويان `{{ .Token }}` | لوحة Supabase | بدونها لا يصل كود الحماية |
| `WEB_COIN_SALES` | `--dart-define` لبناء الويب فقط (`-CoinSales`) | يتجاهله أندرويد دائمًا |

### 9.4 المراجعة اليدوية (تشغيل)
- المالك يسجّل دخول على `/admin/coins` بإيميله (كود لمرة واحدة). يطابق المبلغ والطريقة ورقم العملية ووقتها **من كشف البنك/المحفظة بنفسه**. الموافقة تطلب رقم العملية من الكشف والمبلغ الواصل بالظبط؛ المبلغ المختلف يُرفض آليًا (اطلب توضيح أو ارفض). رقم عملية واحد لا يموّل طلبين.
- لا تطلب ولا تقبل رقمًا سريًا أو OTP أو صورة بطاقة. لا يوجد رفع إيصالات.
- الاسترداد بعد الإضافة: يُسحب فقط الجزء غير المصروف من العملات المشتراة، والباقي دين يُخصم من مشتريات مستقبلية فقط؛ العملات المكتسبة لا تُلمس واللعب المجاني لا يتوقف.
- **حد التوسع**: كل طلب يحتاج إنسانًا عنده صلاحية على الحساب البنكي. هذا عبء تشغيلي وليس دفعًا فوريًا. للتوسع لاحقًا: مزود دفع رسمي يدعم المحافظ المصرية مع webhook موقّع، يُركّب خلف نفس `coin_orders` (لم يُبنَ الآن).

### 9.5 نقاط لسياسات Play (على Codex مراجعتها)
- المحفظة واحدة للعملات المكتسبة والمشتراة من الويب؛ استخدام عملات مدفوعة من الويب داخل تطبيق Play يحتاج مراجعة سياسة (لم يُفترض أنه مسموح). التطبيق نفسه لا يوجّه لأي دفع خارجي.
- بيانات Data safety: إيميل اختياري لاستعادة الحساب، سجل الموافقة، وعلى الويب فقط بيانات طلبات الدفع.

### 9.6 الملفات المسلّمة (build/deliverables-1.1.0)
| الملف | SHA-256 | ملاحظات |
|---|---|---|
| `Mafia-Master-1.1.0-rc.apk` | `37581b0185556ed594421ed19fae6ffd5074816419c371c8c4b0b35a7fd181dc` | للتجربة على الموبايل؛ ترقية مباشرة فوق 1.0.1/1.0.0 |
| `Mafia-Master-1.1.0-test-ads.apk` | `9ec43655893ccddd25e6aeec1925f25983030542ab4834d0e8dfe09663b942f5` | `.adstest`، إعلانات Google التجريبية؛ لا يُرفع |
| `Mafia-Master-1.1.0-play.aab` | `4ce085327faa07f177abeace05f67580f5823197163d62c4ce9de1e4e28c0414` | Play، versionCode 3، بدون شراء عملات بالفلوس |
| `Mafia-Master-1.1.0-web.zip` | `64ea31a2c1df3d392a2b754d981dedaee516b1b62cbcb4ccca85f7b37448ae0a` | مبني بـ `-CoinSales`؛ غير منشور |

كل الملفات موقعة بـ `082c07…9e11`. 12 مكتبة native بمحاذاة 16KB في RC وAAB. فحص R8 (WorkDatabase_Impl وInputMergers محفوظة) PASS في الثلاثة. لا يوجد `ipn.eg`/`vf.eg`/`vfcash` في `libapp.so` ولا في `main.dart.js`.

### 9.7 نتائج الاختبارات
| الفحص | النتيجة |
|---|---|
| `flutter test` كاملة | **PASS** — 1120 نجح، 1 متخطى، 0 فشل (بعد إصلاح أدوات المضيف) |
| `flutter analyze` | 0 errors، 0 warnings، 83 info (زيادة 4 تنبيهات deprecation لـ Radio + 1) |
| SQL محليًا (`node tool/test_sql_without_docker.mjs`, PGlite) | 76 migration تعمل بدون تعديل، **30/30 ملف PASS** بما فيها `terms_acceptance`, `system_waiting_rooms`, `cosmetic_catalog`, `coin_orders` — محاكاة باتصال واحد، ليست Postgres مستضاف ولا تزامن حقيقي |
| node: room_configuration, cosmetic_access, coin_payments, admob_ssv_verify | PASS |
| `deno check` (coin_orders, economy, browse_rooms, player_safety, create_room, room_settings) | PASS — شغّلته جلسة al-mafia-36 وأبلغت النتيجة |
| محاكي Pixel_9_Pro_2 (Android 16) بالـ RC 1.1.0 | ترقية فوق 1.0.1 بدون كراش → نافذة الشروط المختصرة (زر كمل مقفول) → صفحة الشروط وBack يرجع للفورم → موافقة → الرئيسية. تغيير اللغة من الإعدادات: **نفس PID والـ activity فضلت شغالة**، الواجهة اتغيرت فورًا وظهرت ملاحظة الأيقونة؛ بعد الخروج بـ Back اتفعل LauncherEnglish واتقفل LauncherArabic، والفتح من جديد اشتغل بالإنجليزي. المتجر حمّل الكتالوج الحقيقي من السيرفر المستضاف، ومعاينة القصر الليلي شغالة، ومفيش تبويب شراء عملات على أندرويد. logcat crash فارغ |
| ويب محلي 375×812 | نافذة الشروط والرئيسية سليمة؛ تبويب «شراء عملات» موجود؛ على السيرفر الحالي (بدون migration الطلبات) يظهر «مش متاح دلوقتي» + إعادة المحاولة (مغطى باختبار) |
| جهاز Samsung / دفع حقيقي / بريد الكود / ماتش بشري كامل | **NOT VERIFIED** |

### 9.8 غير محسوم
- **جهاز Samsung للمالك**: الكراش وتغيير اللغة وعدم الخروج **NOT VERIFIED** على جهاز حقيقي.
- الدفع الحقيقي: لم يُجرَ أي تحويل؛ سلوك روابط إنستا باي/فودافون على الموبايل **NOT VERIFIED**؛ رابط فودافون http.
- وصول بريد الكود: يحتاج SMTP **NOT VERIFIED**.
- الكتالوج 11 من هدف 18 (ناقص ثيمين، تأثيرين، راوٍ ثانٍ). الأجواء أونلاين فقط.
- أوضة الانتظار: التزامن مثبت بالقفل والاختبار أحادي الاتصال فقط.
- الماتش البشري الكامل عند المالك.
- الشروط والخصوصية مسودة تحتاج مراجعة المالك/قانونية.

### 9.9 إعادة البناء بعد إصلاح أدوات المضيف (12:21)
جلسة al-mafia-36 لقت على المحاكي bug حقيقي: تحديث realtime لـ `room_state` كان بيمسح host/code/settings فالمضيف بيفقد «ابدأ التصويت» وباقي أدواته في نص المرحلة (موجود كمان في main وفي النسخة المنشورة). الإصلاح في `online_backend.dart` و`supabase_backend.dart` و`online_transport.dart` + اختبارين. راجعته وأعدت بناء الأربع ملفات من نفس المصدر؛ الجدول في §9.6 فيه البصمات الجديدة. **ملفات 1.1.0 السابقة (قبل 12:21) مرفوضة.** بعد الإصلاح: flutter test 1120/0 فشل، analyze 0/0 (83 info)، SQL 30/30، التوقيع و16KB وR8 PASS، ولا روابط دفع في الملفات.

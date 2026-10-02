# Claude Code — final closure of Mafia Master online

انسخ هذا الملف كاملًا إلى Claude Code. المطلوب ليس تقريرًا جديدًا فقط؛ المطلوب تنفيذ كل إصلاح يمكن تنفيذه، ثم اختبار الأونلاين من الدخول حتى النتيجة، وإغلاق المشروع بأدلة حقيقية. تواصل مع المستخدم بالمصرية.

## المشروع والقيود

المشروع موجود هنا:

`D:\Flutter Data\Projects\AL Mafia`

ابدأ بقراءة `docs/PROGRESS.md`، ثم `AGENTS.md`، ثم اقرأ الأقسام المطلوبة من:

- `05-zero-leakage-spec.md` في جذر المشروع، وهو المرجع الملزم للخصوصية.
- `docs/09-information-engine.md`
- `docs/10-online-architecture.md`
- `docs/11-edge-cases-and-tests.md`
- `docs/PROMPT-build-online-and-information-engine.md`
- هذا الملف.

اقرأ نص طلب المستخدم الأصلي من attachment عند الحاجة فقط، باستخدام قراءة محددة وليس طباعة الملف كاملًا:

`C:\Users\LENOVO\.codex\attachments\0f1c8e66-a0a6-4e74-844d-6cda76eba6ec\pasted-text.txt`

حافظ على كل التغييرات الحالية غير الملتزمة. ممنوع:

- `git reset --hard`, `git checkout --`, `git clean` أو حذف واسع.
- استبدال المعمارية أو حذف ميزات قائمة.
- commit أو push للكود.
- استخدام `tool/build_web.ps1 -Publish`؛ هذا يعمل force-push إلى gh-pages.
- طباعة أي قيمة من `dart_defines.json` أو أي secret/token في output أو logs أو docs أو build.

المستخدم أعطى موافقة صريحة سابقة لرفع كود وظائف السيرفر إلى Supabase project:

- `AL MAFIA`
- `hezjbrnveajypfqmjfnh`

استخدم هذه الوجهة فقط، ولا تطلب الموافقة مرة أخرى. افحص الوجهة قبل أي mutation، واستخدم migrations وdeployments مع verify_jwt الصحيح، وسجّل النسخ والحالة فقط.

## الحالة المعلنة من Claude — تعامل معها كحالة تحتاج reconciliation

Claude أرسل تقريرًا يقول إن `PHASE 64` أغلقت توحيد العقد، وأصلحت معظم Section C، ونشرت Web على `almafia.vercel.app` وبنت APK. الأرقام المعلنة تقريبًا:

- `e2e_match.py` 91/91 في آخر تشغيل، بعد baseline سابق 93/93.
- `roster_match.py` 48/48.
- `recovery_match.py` 40/40.
- `concurrency_match.py` 46/46 في تشغيل لاحق.
- `kick_flow_match.py` 60/60.
- Flutter حوالي 1023 passed / 1 skipped / 0 failed، وanalyze بلا errors/warnings مع infos موجودة.
- Hosted functions تضمنت resolve_night v13، resolve_vote v11، set_presence v6، saw_role v7، my_team v7، claim_floor v7، release_floor v8، record_speaking v7، ghost_say v7، remove_player v7، room_settings v8، heartbeat v9، submit_vote v9، submit_night_action v10، claim_host v8، send_whisper v7، start_match v11، open_phase v12، مع نسخ أخرى قديمة/محدّثة.
- `20260914001400_strike_absent.sql` ومجموعة اختبارات الطرد/الغياب أُضيفت.
- Web production deployment كان READY، وAPK حديث بــ 3 ABIs أُعلن نجاحه.

لا تعتمد على هذه الأرقام أو النسخ بالاسم. اقرأ logs الفعلية، افحص git diff الحالي، افحص migration history و`list_edge_functions` في المشروع الصحيح، وأعد كل اختبار تأثر بآخر تغيير.

## أول خطوة إلزامية: وحّد Hosted مع Local

قبل تشغيل أي full-flow:

1. افحص تعريفات Hosted الحالية لـ:
   - `night_fingerprint`
   - `vote_fingerprint`
   - `roster_fingerprint`
   - `apply_match_deal`
   - `commit_resolution`
   - `commit_phase_open`
   - `commit_room_settings`
   - `kick_member`
   - `strike_absent_member` إن كان موجودًا
2. تأكد أن migrations التالية مطبقة وبالترتيب الصحيح، ولا تطبق نسخة مكررة عمياء:
   - `20260914000600_kicked_seats.sql`
   - `20260914000700_public_room_active_count.sql`
   - `20260914000800_atomic_room_settings.sql`
   - `20260914000900_kicked_moves.sql`
   - `20260914001000_kick_eliminates.sql`
   - `20260914001100_lobby_departures.sql`
   - `20260914001200_resolution_population.sql`
   - `20260914001300_deal_preserves_settings.sql`
   - `20260914001400_strike_absent.sql`
3. مهم جدًا: migration `20260914001200_resolution_population.sql` جعلت fingerprints تشمل population. يجب أن تكون النسخ المنشورة من `resolve_night` و`resolve_vote` تبني نفس fingerprint بالضبط، وإلا resolution سيُرفض دائمًا كأنه stale. افحص ثم انشر النسخ المتوافقة قبل أي E2E.
4. افحص كل استدعاءات RPC في الوظائف مقابل `pg_proc`. لا تترك اسمًا غير موجود مثل `lower_hand` إلا إذا كان تعريفه موجودًا Hosted وLocal وله grant مناسب. إذا كان release_floor يستدعي RPC غير موجود، أصلحه باستخدم الوظيفة الصحيحة أو أضف migration موثقة واختبار rollback.
5. راجع `_shared/api.ts`، خصوصًا `loadMembership`: kicked ليس membership، وأخطاء القراءة لا تتحول إلى `null` أو نجاح فارغ. انشر كل function تعتمد على النسخة المعدلة بعد مقارنة source hash؛ لا تفترض أن shared file تغير تلقائيًا في deployment قديم.
6. بعد كل deployment تحقق من `ACTIVE`, `version`, `verify_jwt`، ولا تعتبر deployment ناجحًا من غير receipt.

## تعريف الاستقرار المطلوب

لا تقل إن الأونلاين مستقر إلا إذا أثبتت الأدلة الآتية:

- لاعب profile محفوظ يدخل بدون login screen وبلا إعادة إدخال الاسم/النوع كل مرة.
- public rooms تظهر، private code يعمل، إعدادات الروم تُحفظ atomically، وcapacity تستخدم نفس السكان الذين يقبلهم الباب والتوزيع.
- create/join/start/kick/leave تحت locks وcompare-and-set، ولا يوجد double driver أو duplicate action أو lost action.
- لاعب lobby kicked لا يُحسب ولا يُوزّع له role، لكن إشعار طرده يصل له. البديل يدخل مكانًا صحيحًا بلا seat collision.
- kick بعد بدء الماتش يطبق semantics الموثقة في المواصفة: neutral elimination ذريًا، `alive=false`، void للهمسات، elimination public المسموح، win check مرة واحدة، ومنع كل أفعال المقعد بعد ذلك.
- role reveal لا يفتح قبل الشروط، ولا يمكن لمطرود تعطيله، ولا يصل أي role أو saved target عبر public state أو Realtime أو logs.
- كل night/vote/confrontation/phase transition يعيد رفضًا مفهومًا عند stale deadline أو stale fingerprint أو duplicate retry، ولا يكتب نصف نتيجة.
- غياب المضيف/لاعب، refresh، reconnect، tab close/reopen، وtemporary network loss لا يترك الغرفة عالقة ولا يرمي فعل اللاعب بصمت.
- history/result تُحفظ بدون private leakage، وفشل التخزين يظهر warning ويمسح pointer بشكل مستقل.
- الماتش يصل إلى result حتى مع voice متوقف بالكامل.
- الصوت يحافظ على architecture الحالية فقط: `Metered SignallingClient → VoiceLink → VoiceController → WebRtcVoiceEngine → per-peer RTCPeerConnection` مع `micPolicyFor` و`setAudiblePeers`.

## مسار التنفيذ الإلزامي

### A — إصلاحات Hosted والعقد الذري

نفّذ أولًا ما يظهره الفحص، وبالأخص:

- fingerprint population في resolver/commit.
- `lower_hand` أو أي RPC غير موجود.
- فشل read/write في الوظائف القديمة التي ما زالت تستخدم `api.ts` قديمًا.
- start settings: لا يستبدل payload قديم إعدادات الغرفة المحفوظة.
- `room_settings`: host-only، lobby-only، room lock، capacity race، SQL merge، ورفض أي update بعد start.
- `strike_absent_member`: لا يضرب لاعبًا عاد إلى heartbeat، لا يضرب kick، يستخدم phase الحالية، يسجل neutral elimination ويعمل win check ذريًا.
- kicked actor لا يستطيع heartbeat أو presence أو floor أو whisper أو vote أو night action أو accusation أو prediction بعد طرده.

أضف أو حدّث SQL tests لكل إصلاح، واعمل dry-run داخل transaction قبل `apply_migration` ثم أعد الاختبار بعد التطبيق.

### B — full online flow وconcurrency

شغّل بعد توحيد Hosted:

```text
supabase/tests/e2e_match.py
supabase/tests/recovery_match.py
supabase/tests/concurrency_match.py
supabase/tests/roster_match.py
supabase/tests/kick_flow_match.py
```

واشغل كل SQL tests التي تمس room entry/deal/kick/absence/settings/action epoch/resolution/privacy/host migration. إذا ظهر 429 من anonymous sign-in استخدم retry/backoff محدودًا أو users الاختبار المتاحة، ولا تخفف assertions ولا تسمي الجزء غير المشغّل PASS.

يجب أن تحتوي الاختبارات على:

1. kick في lobby، دخول بديل، start، reveal، night، morning، vote، result.
2. kick أثناء night قبل resolution وأثناء resolution: fingerprint القديم يُرفض والمحاولة الجديدة تنجح.
3. kick أثناء vote، host departure، last player، reconnect، duplicate resolver، duplicate action، وlate request.
4. settings/start/join race.
5. مستخدم يطلب create أو join في غرفتين في نفس الوقت.
6. public list/lobby/deal/result كلها ترى نفس population الصحيح.
7. result standings تشمل dealt participants فقط، وتحافظ على تاريخ المشارك الذي أُزيل بعد deal.

لا تعدّل harness ليخفي فشلًا. أصلح المصدر أو اشرح blocker حقيقي.

### C — Flutter وواجهة الأونلاين

راجع `docs/CLAUDE-PARALLEL-REVIEW.md` واصلح العيوب التي لم تُغلق أو ظهرت بعد آخر build:

- lobby landscape 844×390 يجب أن يظل قابلًا للعب.
- entry/lobby على desktop داخل max-width column.
- on-state switches لها thumb واضح.
- gender chips وtouch targets لا تقل عن 48px.
- fallback آمن عند غياب `navigator.share`.
- `join_chime.ogg` لا يكون load-bearing، ولا يسبب uncaught error.
- لا horizontal overflow، لا empty lobby بعد refresh/deep link، وResume/Forget يعملان.

لا تستخدم ألوانًا/أحجامًا خارج design tokens، ولا تغيّر شجرة الواجهة بطريقة تكشف role أو timing. استخدم l10n للعربي والإنجليزي.

### D — voice والتحقق الواقعي

اختبر كل ما يمكن بعميلين حقيقيين:

استخدم الأجهزة الموجودة على جهاز المستخدم بدل الاكتفاء بـ headless:

- افحص `adb devices` و`emulator -list-avds` أولًا. شغّل الـ AVD الموجود، وفضّل `Pixel 9 pro (2)` إذا كان مسجلًا. إذا كان اسم الـ AVD مختلفًا، استخدمه بعد التحقق من أنه جهاز Android فعلي داخل المحاكي. انتظر اكتمال الإقلاع (`sys.boot_completed=1`) قبل الاختبار.
- شغّل نسخة Flutter على المحاكي، واختبر onboarding/profile/online entry/lobby/reveal/table/vote/result، ثم refresh/resume/leave/kick والمايك. لا تكتفِ ببناء APK أو بفحص الملفات.
- شغّل Web release على متصفح headed حقيقي. استخدم Chrome أو Brave أو Edge حسب المتاح؛ اكتشف executable والمسار بنفسك ولا تفترض أن واحدًا بعينه هو الافتراضي. افتح production بعد النشر، وافتح build محليًا قبل النشر عند الحاجة.
- اختبر 390×844 portrait و844×390 landscape و1280×800 desktop على متصفح واحد على الأقل، ثم كرر المسارات الحرجة على متصفح ثانٍ إن كان متاحًا. استخدم devtools/console/network فقط لتشخيص بلا طباعة أسرار.
- افتح عميلين منفصلين في بروفايلين/نوافذ منفصلتين على الويب، أو عميل Android ومحاكي/ويب، حتى لا تختبر الجلسة نفسها مرتين. تحقق من deep link وF5 وtab close/reopen.
- لو كان الـ AVD غير مسجل أو لا يقلع، أو لم يتوفر متصفح headed قابل للتشغيل، سجّل ذلك صراحةً `NOT VERIFIED` مع الأمر والسبب. لا تحوّل headless/fake media إلى PASS لجهاز حقيقي.

- mic permission، sender، offer/answer، early/late ICE، TURN/relay، candidate type، remote track، mute/unmute، reconnect، background/resume.
- A→B وB→A، day audibility، night privacy، Android↔Web إذا توفر جهاز.
- عطّل الصوت كليًا وأثبت أن الماتش يكتمل.

fake microphone وRTP counters و`totalAudioEnergy` تثبت media path فقط، ولا تثبت أن إنسانًا سمع الصوت. أي بند لم يسمعه شخص فعليًا يظل `NOT VERIFIED`. لا تطلب من المستخدم ادعاء تجربة لم تحدث.

### E — builds والنشر

بعد آخر source fix فقط:

1. شغّل localization/dependency check إن أمكن، ثم analyze والـ full Flutter suite.
2. ابنِ APK release حديثًا، وافحص التوقيع و`arm64-v8a`, `armeabi-v7a`, `x86_64`.
3. ابنِ Web release حديثًا، وتحقق من `main.dart.js`, `manifest`, `favicon`, `sw.js` stamp، وعدم وجود beta site حقيقي.
4. لا تستخدم `tool/build_web.ps1 -Publish`.
5. استخدم مسار Vercel الحالي المصرح به فقط. تحقق من production:
   - root = 200
   - main bundle = 200
   - manifest/favicon/assetlinks = 200
   - `/online/lobby` deep link يذهب لمسار entry/resume الصحيح
   - `/beta` ليس صفحة beta حقيقية حتى لو أعاد SPA fallback 200
6. لا تعتبر production أحدث من local إلا بعد مقارنة hash للـ bundle.
7. لا commit ولا push.

## أوامر البيئة

استخدم PowerShell والمسار المباشر السابق إذا علق wrapper:

```powershell
$flutterDart = 'D:\Flutter Data\Futter\flutter\bin\cache\dart-sdk\bin\dart.exe'
$flutterTool = 'D:\Flutter Data\Futter\flutter\bin\cache\flutter_tools.snapshot'
& $flutterDart $flutterTool analyze --no-pub lib test *> build/final-analyze.log
& $flutterDart $flutterTool test --no-pub *> build/final-flutter-tests.log
```

Node:

```powershell
& 'D:\Programms\node.js\node.exe' supabase/tests/room_configuration.test.mjs
& 'D:\Programms\node.js\node.exe' supabase/tests/roster_fingerprint.test.mjs
```

Python harnesses تقرأ `dart_defines.json` داخل process فقط. لا تستخدم `Get-Content` أو logging يطبع القيم، ولا تضعها في command output.

## تحديث التقدم والتقرير النهائي

بعد كل gate أضف block في `docs/PROGRESS.md` يذكر Built / Files / Verified / Gate / Open. لا تمسح السجلات القديمة، ولا تكتب PASS لشيء لم تشاهده.

في التقرير النهائي استخدم أقسام الطلب الأصلي حرفيًا، ومنها:

`ROOT CAUSE`, `PERSISTENCE`, `ONLINE FLOW`, `ROLE REVEAL`, `HOST MIGRATION`, `PRESENCE`, `WEB RESPONSIVENESS`, `VOICE ARCHITECTURE`, `LOCAL MICROPHONE`, `AUDIO SENDER`, `OFFER / ANSWER`, `REMOTE ICE`, `ICE CONFIGURATION`, `ICE CANDIDATE TYPE`, `REMOTE AUDIO TRACK`, `AUDIBILITY POLICY`, `ANDROID AUDIO`, `WEB AUDIO`, `AUDIO A → B`.

ضع لكل بند واحدة فقط من:

- `PASS` مع log/test count/version/screenshot أو client combination واضح.
- `PARTIAL` مع ما ثبت وما لم يثبت.
- `FAIL` مع السبب وخطوة الإصلاح.
- `NOT VERIFIED` فقط لما يحتاج جهازًا/شخصًا/شبكة غير متاحة فعلًا.

لا تتوقف بعد كتابة خطة، ولا تعلن أن المشروع “جاهز للنشر” إذا بقي failure أو إذا كانت fingerprints المنشورة لا تطابق Local أو إذا كان الصوت/الجهاز مجرد synthetic evidence. أكمل كل الإصلاحات والاختبارات التي يمكن تنفيذها، ثم سجّل القيود المتبقية بدقة.

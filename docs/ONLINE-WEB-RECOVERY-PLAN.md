# Mafia Master — خطة إصلاح الأونلاين والويب وتسليم العمل

آخر تحديث: 2026-09-08. هذه خطة تنفيذ واستكمال، وليست شهادة أن النسخة جاهزة.

## ابدأ من هنا عند استكمال الشغل

1. اقرأ هذا الملف، ثم آخر مراحل `docs/PROGRESS.md`.
2. افحص `git status --short` و`git diff --stat` والتغييرات في الملفات المعنية بالخطوة التالية. **اشتغل على الشجرة الحالية بكل التعديلات غير الملتزم بها؛ لا تبدأ من HEAD نظيف.**
3. لا تعمل commit أو push أو reset أو clean، ولا تلغِ عملًا سابقًا. لا تنشر الموقع من خلال Git قبل تصريح بالنشر يتجاوز منع الـpush الحالي.
4. راجع `05-zero-leakage-spec.md` الموجود في **جذر المشروع**؛ المسار القديم داخل docs غير موجود. راجع القسم اللازم فقط من `docs/10-online-architecture.md` و`docs/11-edge-cases-and-tests.md`.
5. نفّذ الأولويات P0 بالترتيب. اختبر كل مجموعة قبل توسيع النطاق. عند الفشل، أصلح أول طبقة فاشلة، ولا تعلن نجاح الصوت لأن الإذن أو signalling نجح.
6. بعد كل نقطة توقف، حدّث جدول الحالة أدناه: ماذا تغيّر، ماذا جرى تشغيله فعلًا، النتيجة، وأول خطوة تالية. لا تترك علامات نجاح افتراضية.

## الهدف والحدود

- أونلاين قابل للعب: الدخول، إعداد الأوضة، بدء الماتش، استمرار المراحل، المغادرة، والصوت عندما تسمح قواعد اللعبة.
- إصلاح تحميل وعرض فيديو الشرح على كمبيوتر ومتصفح موبايل، وتحسين الرسم دون حذف الفيديو أو المشاهد أو المؤثرات أو خصائص اللعبة.
- بروفايل بلا تسجيل دخول: الاسم والشخصية يُحفظان على هذا الجهاز بعد الشرح، ولا يُطلبان كل مرة عند دخول أونلاين. لا نجمع بيانات شخصية غير لازمة.
- الأوض العامة تظهر في صفحة الأونلاين الافتراضية، وإنشاء أو دخول أوضة في الأعلى بأيقونة ونص. إعدادات الإنشاء تُراجع **قبل** دخول الأوضة.
- الصور **مؤجلة بطلب المستخدم**: أداة التوليد أعادت خلفيات مربعات بدل alpha؛ المستخدم اختار «اترك الصور مؤقتًا وكمل باقي الإصلاحات». لا تستخدم الصور المولدة البديلة في اللعبة ولا تعِد فتح هذا الفرع الآن.
- لا تغيير لمحرك الأدوار أو تصميم مراحل الليل. لا MeteredPeer. حافظ على `SignallingClient → VoiceController/VoiceLink → WebRtcVoiceEngine → RTCPeerConnection`.
- الأسرار تبقى في Supabase فقط. ممنوع قيم المفاتيح في الخطة أو الملفات أو APK أو logs. مسميات متغيرات البيئة مسموحة في الباك إند فقط.
- لا أجهزة AVD جديدة. اختبر المتصفحات المتاحة؛ اختبار جهازين وسماع حقيقي يُسجل NOT VERIFIED إن لم يتوفر.
- كل الملفات المؤقتة داخل المشروع وتُحذف بعد الخطوة التي تحتاجها.

## الحالة الحالية: ما الذي يمكن الاعتماد عليه؟

| العمل | الحالة | الدليل / التحفظ |
|---|---|---|
| فحص الشجرة الحالية | تم | توجد تعديلات سابقة كثيرة للصوت وMetered لم تُحذف ولم يُعمل commit |
| مشروع Supabase | تم التحقق | `hezjbrnveajypfqmjfnh`، AL MAFIA، ACTIVE_HEALTHY |
| ضغط فيديو الشرح | تم محليًا | من 51,151,509 إلى 8,993,180 بايت؛ H.264 baseline، AAC، faststart؛ مدة 54 ثانية؛ اختبار فك كامل للصورة والصوت نجح |
| ضبط إطار الفيديو وتشغيل الويب بزر صريح | كود + اختبارات widget | تسعة اختبارات في `test/widget/onboarding_video_test.dart` بأربعة مقاسات وتغيير مقاس أثناء التشغيل، برفض play مزيّف؛ **لا فحص متصفح بعد**، والتزامن البصري/الصوتي غير مؤكد |
| البروفايل وحفظه | تم واختُبر | SharedPreferences، الاسم والشخصية فقط؛ `test/widget/profile_flow_test.dart` يغطي أول تشغيل وإعادة التشغيل والدعوة كأول شاشة؛ fixtures التدفق أُصلحت |
| الصفحة الافتراضية للأوض العامة | تم واختُبر | `test/widget/online_entry_test.dart` (7 اختبارات): القائمة أولًا، لا خانة اسم، فارغ ≠ غير متاح، كل الإعدادات داخل create بلا room_settings لاحق |
| استقبال حالة الصوت الأولية | تم واختُبر | `watch()` تغير إلى بث الحالة الحالية؛ تسبب اختلاف توقيت في اختبار إشعار رفض المايك ويحتاج إصلاحًا صحيحًا |
| جاهزية peer المتأخر | كود مكتوب + اختبارات envelope | `ready` داخل نفس envelope المربوط بالجلسة؛ إعادة إرسال العرض عند تأخر الطرف الآخر؛ لم يثبت في المتصفح بعد |
| تشغيل audio element في الويب | كود مكتوب | await لـplay بدل اعتبار إسناد srcObject نجاحًا؛ زر تشغيل منفصل؛ يحتاج تحقق runtime |
| منع استرجاع سياسة قديمة بعد await | كود مكتوب | revision guard وتسلسل connect؛ اختبارات الصوت الحالية كشفت حالات تحتاج مراجعة |
| صلاحية إعدادات الإنشاء | كود مكتوب محليًا | helper مشترك `room_configuration.ts`؛ لم يُنشر حتى تجتاز الاختبارات |
| إعدادات بداية الماتش | أصلحت محليًا | lobby يأخذ snapshot، وstart_match يحتفظ بإعدادات rooms؛ مدة discuss تستخدم discussionSeconds. Node regression نجح؛ hosted لم يُنفذ |
| flutter analyze | نجح عند التوقف | 0 errors/0 warnings، 74 info؛ exit0 باستخدام --no-fatal-infos |
| flutter test الشامل | **نجح عند التوقف** | 920 passed، 1 skipped؛ الأخير اختبار WebRTC المخصص للمتصفح، وليس نجاحًا للصوت الفعلي |
| اختبار WebRTC حقيقي | **NOT VERIFIED** | تشغيل Chrome علق في تحميل runner قبل بدء الاختبار؛ أوقفناه ونظفنا عملياته؛ لا يوجد دليل سماع بشري أو شبكة خلوية |
| الموقع المنشور / APK السابق | قديمان بالنسبة لهذا العمل | لا تقدمهما كنسخة تشمل هذه الإصلاحات؛ يلزم بناء جديد بعد النجاح |

## P0.1 — الصوت: إصلاح أول طبقة تمنع الميديا

### ملفات البداية

`lib/platform/voice/voice_controller.dart`، `voice_engine.dart`، `webrtc_voice_engine.dart`، `voice_diagnostics.dart`، `web_playout*.dart`؛ `lib/transport/metered_voice_link.dart`، `voice_link.dart`، `voice_envelope.dart`؛ `lib/ui/screens/online/voice_session.dart`؛ `lib/ui/widgets/voice_controls.dart` و`voice_mic_button.dart`.

### تنفيذ وفحوص لازمة

- [ ] إصلاح اختبارات الصوت الفاشلة قبل أي توسيع آخر. FakeVoiceLink يعيد roster فارغًا افتراضيًا في بعض الاختبارات القديمة، بينما start يأخذ peers صريحًا؛ اجعل fixture يمثل roster الفعلي بدل إضعاف إخراج المغادرين من الصوت.
- [x] تأكد أن اشتراك حالة الصوت لا يفقد إشعار رفض المايك أثناء تسليم الحالة الأولى. لا تغير توقع «إشعار واحد» لتخفي العيب.
- [x] إن كانت قائمة اللاعبين تتغير أثناء getUserMedia أو connect، يجب إعادة مزامنة آخر roster بعد انتهاء المحاولة، دون عدة connect متداخلة.
- [x] وصول night أو voice=false أو kicked/closed أثناء محاولة اتصال يلغيها ويُبقي المايك والـreceive مغلقين. day قديم لا يُطبق بعد night أحدث.
- [x] الحصول على المايك مرة لكل جلسة عادية، وإعادة المحاولة فقط بطلب المستخدم بعد رفض الإذن. نفس track يُضاف إلى كل peer مسموح.
- [ ] عرض sender count وoffer/answer states وICE queue وonTrack وpacket counters بأمان. إسناد stream أو تشغيل UI ليس دليل صوت.
- [x] اختبر `ready` لطرف يتأخر في منح المايك: العرض الأول الضائع يُستعاد، ولا يُنشأ اتصال مع لاعب خارج roster. افحص ألا تدخل رسائل قديمة بعد teardown.
- [x] تأكد أن envelope يتحقق من session/from/to/version/nonce/time، وأن ready لا يحتوي إلا نوع الرسالة. أضف اختبار قبول/رفض ready الآمن، مع بقاء اختبارات cross-match والspoofing.
- [x] onTrack: كتم المسار قبل ربط audio element إن لم يكن مسموحًا، وعدم إطلاق الصوت للحظة قبل وصول verdict. غياب streams في حدث track يُعالج أو يُبلّغ بوضوح.
- [ ] Web: نتيجة play() الفعلية تُرصد، والـautoplay المرفوض يُحل بزر واضح. صلاحية الإرسال منفصلة عن تشغيل السماعة.
- [ ] Native: RECORD_AUDIO وMODIFY_AUDIO_SETTINGS ومسار السماعة/Bluetooth تُراجع مع إصدار flutter_webrtc الحالي. لا تغيّر صوت باقي التطبيق.
- [ ] TURN من welcome يصل فعليًا لكل RTCConfiguration. سجّل عدد السيرفرات وأنواع STUN/TURN/TURNS فقط؛ لا أسماء مستخدمين/credentials/IPs/SDP/JWTs.
- [ ] إعادة الاتصال، تبديل الشبكة، ICE restart مرة، ترك الأوضة، وإغلاق الماتش تنظف الموارد ولا توقف اللعب.
- [x] حذف log الذي كان يطبع exception كاملًا من Metered تم؛ راجع بقية السجلات بنفس القاعدة.

### اختبار القبول

1. تشغيل اختبارات `test/voice/` و`test/transport/voice_*`؛ كلها خضراء.
2. تشغيل `voice_web_runtime_test.dart` في Chrome باستخدام ميكروفون اصطناعي: الطرفان connected، audio sender موجود، onTrack وصل، RTP packets > 0 في الاتجاهين، mute/night closes media، ثم cleanup.
3. اختبار Metered + Supabase الحقيقيين: مستخدمان منفصلان، نفس session، TURN متاح، token scoped، وتجربة إعادة الدخول. لا تطبع bearer tokens.
4. تجربة متصفح فعلية للتشغيل الناتج: مؤشرات التشغيل/التعافي صادقة. راقب trace عند الفشل وحدد أول طبقة.
5. سماع A→B وB→A على جهازين: لا تسجل PASS إلا بسماع مؤكد. فحص RTP الاصطناعي لا يكفي لهذا البند.

## P0.2 — إعدادات الأوضة يجب أن تحكم الماتش فعليًا

### ملفات البداية

`supabase/functions/create_room/index.ts`، `room_settings/index.ts`، `_shared/room_configuration.ts`، `start_match/index.ts`، `join_room/index.ts`؛ `lib/ui/screens/online/lobby_screen.dart`، `online_session.dart`، `room_settings_panel.dart`؛ `lib/transport/room_codec.dart`.

- [ ] **الأول:** `_start()` في lobby يستخدم snapshot.settings، لا setupDraftProvider الخاص بالجهاز.
- [ ] **الثاني:** start_match يقرأ إعدادات الأوضة ويحافظ عليها عند status=playing. لا يستبدلها بكائن ناقص من العميل. تحقق server-side من أي مفاتيح legacy مسموحة.
- [ ] تحقق أنواع وقيم maxPlayers، speechSeconds، discussionSeconds وكل switches. رفض قيم malformed أو أدوار مجهولة/أعداد سالبة قبل الكتابة.
- [ ] إنشاء الأوضة يحفظ كل إعداداتها في نفس create request؛ لا تنشئ أوضة عامة افتراضية ثم تعدّلها بعد ظهورها للآخرين.
- [ ] تحرير الإعدادات host-only، يتوقف عند بدء الماتش، ومقعد اللاعب المطرود لا يتحول إلى عضو بالصوت من بقايا roster.
- [ ] `muteAllAtNight` لا يُعرض كزر يوحي بإلغاء الصمت الإجباري بينما الخادم يفرضه: وضّح/اقفل التحكم مع تفسير الخصوصية. لا تُلغِ قاعدة صمت الليل.
- [ ] اختبر voice=false: لا التقاط ميكروفون ولا playout؛ اللعبة تستمر.
- [ ] خفض capacity تحت عدد اللاعبين الموجودين يُرفض. الأوض الممتلئة تعطي سببًا واضحًا.
- [ ] public browse يحسب الموجودين فقط، يستبعد left، ويخفي الغرف الجارية والخاصة. لا polling للصفحة العامة.
- [ ] تأكد أن مدة النقاش المستخدمة في Edge Functions تقرأ نفس مفتاح وقيمة الواجهة.
- [ ] واجهة lobby تعرض snapshot الحالية من Realtime، ولا تحتفظ بنسخة محلية تتغلب عليها.
- [ ] Backend tests للإنشاء والتعديل والبداية: إعدادات ما قبل الإنشاء = إعدادات lobby = إعدادات الماتش بعد البداية.

## P0.3 — دورة الأونلاين كاملة، بلا توقف للماتش

- [ ] role reveal: كمل يتوقف حتى saw_role للجميع، قائمة الانتظار صحيحة، gate على الخادم.
- [ ] إنشاء/دخول/دعوة/كود خاطئ/أوضة ممتلئة/مطرود/ماتش منتهٍ: رسائل واضحة، لا spinner بلا نهاية، والمحاولة المكررة لا تُنشئ أوضتين.
- [ ] lifecycle للويب: hidden يعامل كخلفية، والـheartbeat لا يعيد اللاعب connected وهو مخفي. الرجوع يعيد connected.
- [ ] away / left / connected وhost migration تعمل دون إنهاء الماتش. افحص room_players بعد reconnect.
- [ ] اخراج لاعب يمنع رجوع نفس العضوية ويمنع صوته؛ host mute يمنعه من الإرسال والاستماع له وفق السياسة القائمة.
- [ ] إغلاق الأوضة صريح ومؤكد؛ المغادرة العادية لا تساويه.
- [ ] ماتش E2E من خمسة لاعبين على الأقل، مع نسخة صوت مكسورة تمامًا، ينتهي بشكل صحيح.
- [ ] تحقق من الحمايات: non-member، wrong room، ended room، caller غير host، محاولة الوصول للأسرار.

## P0.4 — الويب والفيديو والأداء

### تم بالفعل

- الفيديو أُعيد ترميزه بنفس المدة إلى H.264 baseline + AAC مع faststart وbitrate محدود. تحقق decode كامل نجح. لم تُحذف مشاهد.
- أُضيف بدء صريح للويب وانتظار تثبيت الإطار قبل التشغيل، وحساب عرض/ارتفاع يحترم حدود النافذة.
- الخلفية والtexture أُحيطتا بـRepaintBoundary لعزلهما عن إعادة رسم المحتوى المتغير؛ المؤثرات باقية.

### المتبقي

- [ ] اختبر مقاسات 360×640، 390×844، 844×390، 1366×768، والتغيير أثناء الفيديو والتوقف/الاستئناف.
- [ ] اختبر فتح أول مرة ثم reload: تحميل البداية، وصول الصورة، عدم خروج الفيديو من الإطار، تزامن الصورة والصوت. قِس التحميل بدل «شكله أسرع».
- [x] اختبر error/slow loading: زر تخطي ظاهر دائمًا، ورسالة/إعادة تشغيل عند خطأ فعلي؛ لا صوت يتيم بعد مغادرة شاشة الشرح.
- [ ] المتصفح يستقبل MP4 مع Range وContent-Type المناسبين من الاستضافة. افحص 206 لا تفترض دعم السيرفر المحلي.
- [ ] افحص Home، صفحة الأوض، Lobby، Table أثناء resize: overflow، تمرير، clipping، touch targets، وDPR.
- [ ] حافظ على animations والمحتوى. حسّن decode sizes وrepaint boundaries والثبات، لا تحذف تأثيرات لإخفاء ضعف الأداء.
- [ ] افحص خدمة cache/version بعد بناء الويب؛ لا تقدّم للمستخدم bundle قديمًا على أنه الإصلاح.
- [ ] تشغيل وبناء web release بنجاح، ثم فحصه في المتصفح قبل أي نشر.

## P1 — البروفايل وتدفق اختيار الأوض

### ملفات معدلة/جديدة

`lib/data/player_profile.dart`، `lib/ui/screens/setup/profile_screen.dart`، `lib/app/onboarding_gate.dart`، `lib/app/router.dart`، `lib/ui/screens/setup/home_screen.dart`، `lib/ui/screens/online/online_entry_screen.dart`، ملفات l10n، pubspec.

- [x] بروفايل الاسم والشخصية يُطلب بعد الشرح، مرة واحدة لكل تثبيت/متصفح؛ لا شاشة تسجيل دخول ولا طلب بريد.
- [ ] تعديل البروفايل من الرئيسية ومن صفحة الأونلاين. تغيير الاسم لا يغيّر الهوية الأمنية في Supabase.
- [ ] reload يحفظ البروفايل وonboardingSeen؛ تلف/منع التخزين يعرض طريقة واضحة للتعافي ولا يسبب crash.
- [x] دعوة لأول زائر تحتفظ بالكود خلال الشرح والبروفايل، ثم تعرض دخول الأوضة المقصودة. لا دخول تلقائي بلا تأكيد.
- [x] صفحة الأونلاين تعرض public rooms مباشرة، ثم create/join أعلى الصفحة بأيقونة ونص؛ لا خانة اسم متكررة.
- [x] إعدادات الإنشاء تستخدم نفس نموذج إعدادات lobby حتى لا يختلفا. الخطأ في الإنشاء يبقي draft.
- [ ] refresh وحالات فارغ/خطأ/تحميل منفصلة، وضغط صف أثناء طلب قائم لا يكرر join.
- [x] تحديث اختبارات الواجهة القديمة لتبدأ من بروفايل محفوظ عندما تختبر لعبة عائدة. لا حذف لاختبارات رفض الكود أو امتلاء الأوضة أو offline fallback.
- [x] اختبارات جديدة لإنشاء profile وحفظه، العودة بعد reload، ظهور public rooms تلقائيًا، وإرسال كل إعدادات الإنشاء قبل الانضمام.

## P2 — الصور والتحسينات غير المانعة للعب

- [ ] الصور: **متوقف بطلب المستخدم**. بعد طلب لاحق فقط: إزالة الخلفية الفعلية مع alpha، الحفاظ على الشخصيات، واختبار نفس الأصول offline/online. لا تستخدم صورة بها checkerboard مرسوم على أنها شفافة.
- [ ] تنظيف الكلمات المكررة والمحاذاة وحالات focus/keyboard وتفاصيل الأيقونات، مع إبقاء معاني الأفعال غير الواضحة بالنص.
- [ ] أي إضافة أخرى تظهر أثناء المراجعة تُسجّل هنا مع سببها واختبارها؛ لا إعادة كتابة غير لازمة للمحرك أو التنقل.

## أوامر الاختبار والبناء وخطوات التسليم

- Flutter موجود في PATH كـflutter.bat. استخدم مسارات نسبية لـdart_defines.json لتجنب المسافات في مسار المشروع.
- `flutter pub get`
- `flutter analyze --no-fatal-infos`، ثم سجّل errors/warnings/infos بصدق.
- `flutter test --reporter expanded`؛ اقرأ failures كاملًا عند الحاجة. 871 هو رقم تاريخي، **ليس نتيجة الشجرة الحالية**.
- `node supabase/tests/run_golden_vectors_node.mjs` واختبارات backend الحالية ذات الصلة؛ Deno tests إن توفرت البيئة.
- اختبار المتصفح `flutter test --platform chrome test/voice/voice_web_runtime_test.dart` يحتاج flags ميكروفون اصطناعي وسماح autoplay للاختبار فقط، لا تغيّر إعدادات المتصفح الشخصي أو كود الإنتاج لهذا الغرض.
- بناء الويب: `flutter build web --release --base-href /AL-Mafia/ --dart-define-from-file=dart_defines.json`؛ لو Git Bash استخدم MSYS_NO_PATHCONV=1.
- APK واحد فقط بعد النجاح: `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define-from-file=dart_defines.json`.
- بعد نجاح الاختبارات المحلية، انشر وظائف Supabase المطلوبة فقط إلى المشروع الموجود، ثم أعد اختبارات hosted. لا تغيّر/تطبع الأسرار.
- لا تضف صور اختبار أو tokens أو logs أو أدوات مؤقتة إلى ملفات التسليم. راجع Git diff وفحص التسريب دون إخراج القيم.
- لا تنشر الموقع أو تعمل commit/push إلا بتصريح مناسب. البناء المحلي لا يعني أن المستخدم يشاهد الإصلاح على الرابط المنشور.

## بوابة القبول النهائية

يُسجل كل بند PASS / PARTIAL / FAIL / NOT VERIFIED مع الدليل:

1. المايك وsender الفعلي، offer/answer، early ICE، TURN داخل RTCConfiguration.
2. PC connected، remote track، RTP في الاتجاهين، playout، mute/unmute، reconnect.
3. الصوت المسموع على جهازين وشبكتين إن أمكن؛ السمع لا يُستنتج من counters.
4. خصوصية الليل، الاستبعاد، المضيف، عدم تسريب الأدوار/credentials.
5. إعدادات الأوضة محفوظة ومطبقة في lobby وعند البداية؛ public/private صحيحان.
6. ماتش كامل قابل للإنهاء مع الصوت وبدونه.
7. فيديو يعمل ضمن الإطار وبصورة متزامنة على المقاسات المطلوبة.
8. بروفايل محفوظ وتدفق دعوة أول مرة سليم، وكل اختبارات المشروع خضراء.
9. APK واحد وبناء web من نفس الشجرة، وإعلان واضح لما نُشر وما لم يُنشر.

## أول خطوة تالية وقت كتابة الخطة

ابدأ من ملحق التسليم أدناه؛ هو أحدث من جدول الحالة التاريخي أعلاه. المستخدم طلب إنهاء التحقق الحالي والتوقف لتوفير الرصيد، وليس بدء مرحلة جديدة.

## ملحق التسليم الدقيق — نقطة توقف 2026-09-08

### تعليمات الاستكمال دون إعادة اكتشاف المشروع

- كل العمل محفوظ في الشجرة الحالية، وليس commit. لا تعمل reset/clean/checkout للملفات. لا commit أو push.
- الصور مؤجلة صراحة؛ لا تنفذ إزالة خلفية ولا تستبدل الأصول المولدة.
- لا تعتبر APK أو الموقع المنشور شاملين لهذه التغييرات. لم ننشر وظائف السيرفر المعدلة في هذه الجولة أيضًا.
- نتيجة التحقق الختامية تُسجل في نهاية هذا الملحق. الصفوف القديمة التي تقول «32 إخفاقًا» أو «إعدادات البداية لم تصلح» تاريخية وقد تجاوزناها بالتغييرات أدناه.

### ما تغيّر فعلًا، مع نقاط الدخول

1. `lib/platform/voice/voice_controller.dart`: اشتراك `watch()` أصبح `Stream.multi` يسلم الحالة الحالية ويربط المستمع فورًا؛ هذا يصلح فقد إشعار رفض المايك. أضيفت revision guards بعد await، وتسلسل connect عبر `_connecting/_connectAgain`، ومنع الاستقبال بعد disposal أو الخروج من roster. `enableAudio()` يعيد تشغيل playout بطلب المستخدم؛ `sampleDiagnostics()` يقرأ العدادات. أصلحنا fixture في `test/voice/voice_controller_test.dart`: يجب أن يعيد FakeVoiceLink نفس peers المستخدمة في start، لا قائمة فارغة تمحو roster لاحقًا. اختبارات الصوت المركزة مرت بعد الإصلاح.
2. `lib/platform/voice/webrtc_voice_engine.dart`: يحافظ على mesh وprivacy؛ يرسل ready آمنًا بعد إنشاء peers، والطرف صاحب المعرف الأصغر يعيد العرض المفقود عند تأخر إذن ميكروفون الآخر. `_offering` يمنع offer متزامنًا. onTrack يعطل track غير المسموح قبل ربط playout. `setAudiblePeers` يحدّث renderer.muted أيضًا. teardown يمسح authorized قبل الإغلاق. `sampleMediaStats()` يسجل packets الصوت inbound/outbound فقط.
3. `lib/platform/voice/web_playout{,_browser,_stub}.dart`: bridge ويب ينتظر `HTMLAudioElement.play()` بدل اعتبار srcObject دليل تشغيل. معرف العنصر مأخوذ من تطبيق flutter_webrtc المثبت: `audio_RTCVideoRenderer-$textureId`. واجهة `VoicePlayout` اختيارية في voice_engine.dart، فلا يحتاج fake/native-null تطبيقها قسرًا.
4. `lib/transport/voice_envelope.dart`: أضيف kind=ready، والـpayload المسموح له `{kind: ready}` فقط. version/session/from/to/nonce/time والـroster admission موجودة. لا تضف roles أو phase secrets إلى envelope.
5. `lib/transport/online_transport.dart`: roster الصوت يستبعد left/kicked؛ `_foreground` يمنع heartbeat بالخلفية. `online_session.dart` يعامل hidden كـaway. `voice_session.dart` يراقب transport فقط حتى لا يهدم controller بسبب busy/error لا علاقة لهما بالجلسة.
6. `voice_mic_button.dart` و`voice_controls.dart`: زر صريح لإعادة تشغيل الصوت؛ ضغط مطول على المايك يفتح تشخيصًا آمنًا، ويجمع stats قبل عرضه. لا تعتبر ظهور المايك أو counters إثبات سماع بشري.
7. `supabase/functions/_shared/room_configuration.ts`: allow-list للأرقام والأعلام؛ title<=40، visibility valid، القيم الخاطئة ترفض. كتم الليل مفروض true وفق spec. enums: discussionMode=structured/free، dayTieRule=noElimination/revote. لا تستخدم random كقيمة tie.
8. `create_room/index.ts`: التكوين يدخل مع إنشاء rooms قبل الانضمام. `room_settings/index.ts`: نفس validator مع host/lobby checks ومنع سعة أقل من عدد غير المغادرين. `start_match/index.ts`: تحقق role counts، settings المحفوظة في rooms لها أولوية على legacy client settings فلا تضيع إعدادات الإنشاء.
9. `lobby_screen.dart`: start يأخذ snapshot.settings بدل setupDraft؛ openVoting يكتب السيرفر ويقرأ snapshot بدل متغير محلي. **عيب فقد الإعدادات أصلح محليًا، يحتاج hosted verification.**
10. `_shared/phases.ts`: أصلح durationFor('discuss') ليقرأ discussionSeconds مع default300 بدل speechSeconds×3. أضيفت تأكيدات 180/300/420 في `supabase/tests/room_configuration.test.mjs` ومرت. يجب نشر كل وظيفة تستورد phases مباشرة/غير مباشرة، لا الملف المشترك وحده.
11. `lib/data/player_profile.dart`: ProfileStore يحفظ name/gender فقط في SharedPreferences بمفتاح mafia.playerProfile.v1، وintroSeen بمفتاح منفصل؛ AsyncNotifier للتحميل/الحفظ. `profile_screen.dart`: ProfileRequired + إدخال الاسم والجنس مرة واحدة بلا login. اختبارات persistence/malformed/invalid مضافة.
12. `router.dart` و`onboarding_gate.dart`: gate للبروفايل، route /profile؛ الحفاظ على دعوة /join/CODE عبر onboarding/how-to-play عبر next آمن. `home_screen.dart`: زر تعديل profile.
13. `online_entry_screen.dart`: public browse افتراضي، create/join دائمًا بالأعلى، code دون تكرار الاسم، إعدادات قبل create عبر draft وRoomSettingsPanel، خطأ browse مختلف عن empty. `RoomSettingsPanel` يدعم onChanged للـdraft وfooter؛ night switch يبدأ true ويمكن للهوست تغييره ويحفظ الاختيار في إعدادات الأوضة. **اختيار discussionMode ما زال يحتاج مراجعة/إضافة إن لزم.**
14. فيديو assets/video/onboarding.mp4 أصبح 8,993,180 بدل51,151,509 بايت؛ نفس54 ثانية، H264baseline/yuv420p/AAC/faststart؛ فك كامل نجح. الشاشة تحدد العرض والارتفاع معًا وتبدأ الويب بزر بعد تركيب العنصر؛ native autoplay بقي. `textured_surface.dart` يعزل رسم الخلفية في RepaintBoundary؛ لم تُحذف مؤثرات.
15. l10n: مفاتيح profile/videoPlay/voiceRetry/onlineNightPrivacyHint. آخر فشل شامل كان لأن gen-l10n لم يكن أعاد توليد onlineNightPrivacyHint، وليس سبع مشاكل مستقلة؛ أعدنا التوليد بالفعل.

### أول المتبقي — الصوت، بدون تبديل معمارية

أ. أكمل اختبار المتصفح الفعلي `test/voice/voice_web_runtime_test.dart`. يستخدم محركين حقيقيين وميكروفون Chrome اصطناعي؛ يؤخر B ثانية لإسقاط أول offer، ثم يتوقع ready يعيد التفاوض وRTP counters بالاتجاهين. لا يختبر Metered نفسه ولا السماع البشري ولا TURN. المحاولات الحالية علقت في **تحميل test runner قبل تشغيل الاختبار**؛ لا تنسب ذلك إلى WebRTC negotiation.

ب. لا تستخدم cmd wrapper لChrome: جرّبناه وWindows كسر &debug=false في URL. جُرب launcher C# executable أيضًا؛ حافظ على الرابط كاملًا لكنه بقي loading. نغلق عمليات الاختبار الخاصة بنا فقط عند التوقف؛ لا تقتل Chrome/Brave الشخصي. flags الاختبار: --use-fake-device-for-media-stream، --use-fake-ui-for-media-stream، --autoplay-policy=no-user-gesture-required. لا تضعها في كود الإنتاج. البديل العملي التالي: build web محلي وتشغيل مرئي عبر أداة المتصفح، أو تشخيص تحميل runner أولًا بحد زمني؛ لا تستهلك ساعات في نفس محاولة معلقة.

ج. **تم (2026-09-08).** `_live` كان يُضبط في مكان واحد فقط — بعد أول connect — ويُصفَّر عند كل disconnect. الـSDK يعيد الاتصال ويعيد تشغيل الاشتراكات وحده، فيرجع السوكيت ولا ترجع الراية: من أول انقطاع شبكة، كل offer/answer/candidate يمر عبر Postgres لبقية الماتش، بلا أي بلاغ لأن الـfallback يعمل. الآن `handleConnected` يرفع `_live` عند `isReconnect`، و`handleDisconnected` منفصل، وفشل connect/subscribe يصفّر الراية صراحة. أُضيف `clientFactory` كـ`@visibleForTesting` لحقن SignallingClient وهمي، وثلاثة اختبارات في `voice_ticket_test.dart`: السوكيت يحمل الإشارات بعد الرجوع، welcome الرجوع يحدّث بيانات TURN، وwelcome بعد dispose لا يحيي رابطًا انتهى.

د. **تم (2026-09-08).** السباق مؤكد وأُصلح بـepoch مستقل في الطبقتين. `_tornDown` حالة والليل رحلة ذهاب وعودة: تسلّق بدأ قبل الليل واستيقظ بعد رجوع النهار كان يقرأ `_tornDown == false`، يعلن `live` لشبكة أغلقها teardown، وداخل المحرك يكمل حلقة `_createPeer` فيبني اتصالات **بعد** أن أغلقها الليل — وهي ثغرة V6 مباشرة. الآن `WebRtcVoiceEngine._generation` يُلتقط قبل أول await ويُفحص بعد كل واحد، وteardown/dispose يرفعانه أولًا؛ الدورة المتقاعدة تنظّف ما بنته هي فقط (`_discard` يقارن بالهوية حتى لا تُغلق شبكة الجيل الجديد). و`VoiceController._mediaEpoch` يفعل الشيء نفسه لما يُعرض على اللاعب. اختباران في `voice_controller_test.dart` يمسكان الحالتين: الوضع لا يقول live قبل الليل أو خلاله، والمايك يبقى مغلقًا.

هـ. **تم (2026-09-08).** المسارات البعيدة صارت في `_remoteTracks` بدل قراءتها من الـstream الذي وصلت داخله، و`setAudiblePeers` يمشي عليها. المسار الذي يصل عاريًا — بلا `event.streams` — كان يُفعَّل مرة واحدة عند الوصول ثم لا يُراجَع أبدًا: لاعب سُمح له في نهار مفتوح يبقى مسموعًا إلى الليل، ولاعب كُتم عند الوصول يبقى صامتًا لبقية الماتش. اخترنا الاحتفاظ بالـtrack بدل تركيب stream صناعي؛ على الويب لا يمكن ربط playout بلا stream، فيُسجَّل `no-remote-stream` في التشخيص بدل ادعاء نجاح التشغيل. الاختبار الفعلي لهذا المسار يحتاج محرك حقيقي في متصفح، فهو مغطى منطقيًا لا runtime.

و. **تم (2026-09-08).** مجموعة `the ready frame` في `voice_envelope_test.dart`: الشكل الصحيح الوحيد يُقبل، الجسم بأي مفتاح إضافي يُرفض (مكان لإخفاء مفتاح هو مكان لإخفاء دور أو مقعد)، الجسم الفارغ يُرفض، ready من ماتش آخر أو بمرسل منتحل أو من لاعب غادر أو موجّه لغيرنا يُرفض، وready ملتقط لا يُعاد تشغيله. وفي `online_transport_test.dart`: roster الصوت يستبعد left/kicked ويُبقي away، ويتبع الغرفة عبر closure لا نسخة؛ والheartbeat يتوقف مع الخلفية ويعود مع الرجوع، وleft ليس خلفية. وصول TURN إلى كل RTCConfiguration مغطى أصلًا في `voice_media_path_test.dart`.

ز. بعد نجاح الاختبارات المحلية جرّب مستخدمين Supabase فعليين في روم اختبار واحد مع Metered، ثم candidate type فقط وPC connected/onTrack/RTP. حتى مع نجاح counters اكتب السماع الحقيقي NOT VERIFIED ما لم يسمعه المستخدم/أجهزة فعلية. التشخيص متاح من ضغط مطول على المايك على الهاتف.

### ثاني المتبقي — سيرفر الماتش والإعدادات

1. أضف discussionMode للتحكم في free/structured إن كان مطلوبًا للحديث المتبادل؛ `micPolicyFor` قد يسمح activeSpeakerOnly في structured، فلا تختبر شخصين صامتين وتسميها مشكلة شبكة. Lobby مفتوح، night/reveal صامتان للجميع وفق spec.
2. راجع roster start_match وعدّاد lobby والسعة: rows left ما زالت قد تُحسب. لا تعد توزيع المقاعد أثناء الماتش. استبعد left/kicked من صلاحية البدء والعداد حيث يلزم؛ تحقق من minimum players وعدم بدء ماتش بهم.
3. room_settings check lobby ثم update منفصل؛ اجعل update مشروطًا بحالة lobby لمنع سباق start. راجع create_room partial inserts وstart role writes: لا تعلن atomicity غير موجودة. إن احتجت RPC transaction فليكن تغييرًا محددًا باختبار rollback وليس إعادة تصميم قاعدة البيانات.
4. local Node tests ثم نشر create_room/room_settings/start_match والوظائف المستوردة phases. استخرجها بـrg 'phases.ts' supabase/functions. حافظ على verify_jwt الحالي ولا تطبع الأسرار. connector مشروع hezjbrnveajypfqmjfnh متاح؛ deploy يحتاج index وكل shared imports المستخدمة.
5. hosted smoke: public/private، حفظ كل settings، منع nonhost، start يحتفظ settings، مدة discuss تطابق القيمة، رفض تعديل بعد start. اجعل tokens بذاكرة العملية فقط. احذف غرف الاختبار بأرقامها التي أنشأتها فقط.
6. نفذ match E2E بخمسة مستخدمين: reveal gate، night، morning، discussion، vote، host transfer، kick، النهاية، مع voice معطلة بالكامل أيضًا. لا تعتبر unit tests بديلًا لهذا.

### ثالث المتبقي — المتصفح والبروفايل

1. build web محليًا بعد analyzer/tests؛ قدمه عبر server يدعم Range للفيديو، وليس SimpleHTTPRequestHandler الافتراضي بلا Range. استخدم build/ لأي سكربت مؤقت واحذفه عند نهاية الخطوة.
2. افحص مقاسات360/390/768/1440 وتغيير المقاس أثناء الفيديو. يجب أن يبقى كاملًا داخل الإطار وأن يظهر skip دائمًا. اختبر أول تحميل، play/pause، مغادرة الشاشة، وreload. لا تقل إن AV sync مؤكد من نجاح ffmpeg وحده.
3. أصلح مسار فشل play: الشاشة تضع _failed لكن _ready قد يبقى true فلا يظهر error؛ اعرض إعادة المحاولة دون إخفاء skip. أضف buffering/loading state إذا اختبارات المتصفح أثبتت الحاجة، دون تشغيل صوت قبل ظهور الصورة.
4. profile: اختبر أول تشغيل onboarding→how-to-play→profile→home، ثم reload دون طلب الاسم؛ edit يحفظ؛ invite لأول مرة يحافظ على code بعد كل gates. افحص فلاش profile قبل redirect للشرح واستئناف ماتش محفوظ قبل اكتمال profile.
5. Online UI tests إضافية: public list تلقائية، الفرق بين empty/network error، create payload بكل settings قبل room join، اختيار روم عام لا يطلب الاسم ثانية، وcreation error لا يفقد draft.
6. لا تغير صور الشخصيات الآن؛ المستخدم أجّلها. البروفايل يعمل بالأصول الحالية.

### أدوات وأوامر معروفة لتوفير وقت الاستكمال

- Flutter على PATH: `D:/Flutter Data/Futter/flutter/bin/flutter.bat`؛ Node: `D:/Programms/node.js/node.exe`؛ Python: `C:/Users/LENOVO/AppData/Local/Python/bin/python.exe`.
- Chrome: `C:/Program Files/Google/Chrome/Application/chrome.exe`؛ Edge كذلك مثبت. لا يوجد دليل جهاز Android متصل.
- ffmpeg/ffprobe: `C:/Users/LENOVO/AppData/Local/Microsoft/WinGet/Links/`.
- package cache: `C:/Users/LENOVO/AppData/Local/Pub/Cache/hosted/pub.dev/`. اقرأ API المثبت عند تعديل playout. الإصدارات: flutter_webrtc1.6.1، dart_webrtc1.8.1، metered_realtime0.2.0، video_player_web2.4.0.
- `flutter gen-l10n` قبل analyze/tests بعد أي ARB. `flutter analyze --no-fatal-infos`؛ 73 info قديمة ليست أخطاء لكن دوّن العدد الفعلي.
- `flutter test --reporter expanded` ثم Node `supabase/tests/room_configuration.test.mjs` و`run_golden_vectors_node.mjs` (35 حالة نجحت سابقًا في هذه الجولة).
- بيئة الأدوات قد تحتاج escalation لقراءة Flutter/cache وتشغيله؛ لا تكتب secrets أو تتجاوز رفضًا أمنيًا. لا تنشر غصبًا إذا منع push قائم.
- البناء النهائي لاحقًا: APK واحد arm64 وweb، بعد اختبار آخر تعديل. لا تسلم split APKs متعددة، ولا تعيد beta المحذوفة، ولا تصف بناء قديم بأنه جديد.

### جولة ثانية على نفس الطبقة — تداخلات التوقيت المتبقية

بعد إغلاق ج/د/هـ/و جرى مسح ثانٍ على كل `await` في سلسلة الميديا بسؤال واحد: ماذا لو استيقظ هذا السطر في دورة أخرى؟ أربعة عيوب حقيقية ظهرت وأُصلحت:

1. **عرض/إجابة قديمة تصل إلى السلك.** `_offer` و`_handleSignal` كانا يكتبان `setLocalDescription` ثم يرسلان دون التأكد أن الاتصال ما زال هو نفسه. الإجابة أخطر من العرض: الطرف الآخر لا ينتظر إذنًا لتطبيقها — الإجابة هي نهاية التفاوض — فتهبط على العرض المفتوح عنده، وهو بحلول تلك اللحظة عرض الاتصال الجديد الذي كان سينجح. أُضيف `_current(peerId, pc, generation)` ويُفحص بعد كل await وقبل كل إرسال.
2. **`_offering` لا يُنظَّف عند teardown.** `_offer` يرفض العمل مرتين لنفس الطرف، فبقاء معرّف من تفاوض قطعه الليل يجعل عرض النهار **لا يحدث أصلًا**: الشبكة تُعاد، صاحب الدور يمتنع بصمت، والزوج صامت لبقية الماتش وكل الحالات تقول سليم. يُمسح الآن في `_closeConnections` وفي `_dropPeer`.
3. **`_restartIce` يمسح حالة اتصال غيره.** بعد `await pc.restartIce()` كان يمسح `_remoteDescribed` و`_pendingCandidates` بلا فحص. وإعادة تشغيل ICE تحدث عند اتصال **فاشل** — وهي بالضبط اللحظة التي يُعاد فيها بناء الزوج — فكان يفرّغ طابور مرشحات الاتصال الجديد ويُنسيه أن له وصفًا بعيدًا، فيظل يكدّس مرشحات لن يطبقها أبدًا، بلا أي بلاغ.
4. **مسارَان في المتحكم يرميان في وجه المستخدم.** `enableAudio()` و`sampleDiagnostics()` كانا يستدعيان `resumePlayout`/`sampleMediaStats` خارج `_quietly`. `enableAudio` تبدأ من ضغطة إصبع، واستثناء من مكدّس الميديا يصل إلى الواجهة يكسر «الصوت ليس حاملًا» في الطريق الوحيد الذي يبدؤه المستخدم.

اختبارات هذه الجولة في `voice_controller_test.dart` تحت «the room moves while the call is being made»: لاعب ينضم أثناء التسلّق فيلتقطه تسلّق تالٍ لا هذا، أربعة انضمامات متتالية تنهار إلى تسلّق واحد إضافي، `peakConcurrentConnects == 1` في الحالتين (تسلّقان متوازيان يبنيان شبكتين لنفس الأطراف وتتقاطع عروضهما، والنتيجة غرفة متصلة صامتة)، والطرد وإغلاق الأوضة وvoice=false كلها تصل وسط التسلّق فتلغيه وتترك المايك والسماع مغلقين، والمايك يُطلب مرة واحدة مهما تعدّدت التسلّقات.

**ما زال بلا اختبار runtime:** كل ما سبق مبرهن بالمنطق وبالاختبارات على محرك مزيّف. لا شيء منه دليل على صوت مسموع.

### النتيجة النهائية عند التوقف — المرجع الأحدث

آخر جولة: 2026-09-08، بعد إصلاحات ج/د/هـ/و أعلاه.

- `flutter analyze --no-fatal-infos`: **0 errors / 0 warnings / 74 infos**، exit0. العدد لم يتغير عن الجولة السابقة.
- `flutter test`: **900 passed / 1 skipped / 0 failed**. الزيادة 25 اختبارًا جديدًا: سباق night→day من الوضع ومن المايك، رجوع السوكيت يحمل الإشارات، welcome الرجوع يحدّث TURN، welcome بعد dispose، تسعة اختبارات لظرف `ready`، roster الصوت يستبعد left/kicked، والheartbeat مع الخلفية، ومجموعة «الغرفة تتحرك أثناء إجراء المكالمة» الست. التخطي ما زال اختبار المتصفح على VM.
- `node supabase/tests/room_configuration.test.mjs`: PASS.
- `node supabase/tests/run_golden_vectors_node.mjs`: 35 حالة، Dart وTypeScript متفقان.
- **اختبار Chrome الفعلي: ما زال NOT VERIFIED — لكن العَرَض تغيّر.** لم يعد يعلّق في تحميل الـrunner: Chrome يبدأ، DevTools يستمع على السوكيت، ثم `Failed to load: Connection closed before test suite loaded` خلال ثانية. هذا فشل سريع قابل للتشخيص وليس تعليقًا. لم يُلاحق أبعد من ذلك بطلب المستخدم. الخطوة التالية المقترحة: تقسيم السبب باختبار متصفح تافه ثم واحد يستورد `webrtc_voice_engine.dart` فقط — إن سقط الثاني وحده فالمشكلة تحميل flutter_webrtc في بيئة `flutter test --platform chrome`، لا التفاوض.
- لا deployment، لا APK/web build جديد، لا commit، لا push. الشجرة كما هي وHEAD ما زال 2cfc8cd.
- الصوت المسموع بين جهازين: NOT VERIFIED، ولا يُستنتج من أي عدّاد أعلاه.

### أول خطوة تالية بعد هذه الجولة

بند الصوت المتبقي كله يحتاج runtime حقيقي — لا يوجد إصلاح منطقي آخر معروف في السلسلة `SignallingClient → VoiceController → WebRtcVoiceEngine`. فالتالي هو الواجهات والبروفايل والفيديو وخطوات البناء في P0.4 وP1، ثم النشر والتحقق المستضاف، ثم بناء APK وweb من نفس الشجرة.

## جولة الواجهات والبروفايل والفيديو والبناء — 2026-09-08 (الأحدث)

هذه الجولة هي «الخطوة التالية» التي انتهت إليها الجولة السابقة: P0.4 وP1 وخطوات البناء، بعد أن استنفد الصوت كل ما يمكن إثباته بلا runtime.

### العيب الذي سمّته الخطة، وما وجدناه بجانبه

- **`_failed` في شاشة الشرح كانت لا تُقرأ.** الحالة تُضبط ولا يعرضها شيء: فيلم يرفض المتصفح تشغيله كان يترك مستطيلًا ساكنًا بلا رسالة ولا طريقة إعادة. الآن `_overlay` تعرض رسالة + زر إعادة (`videoFailed`/`videoRetry` في `app_en.arb` و`app_ar.arb`)، وحالة buffering منفصلة، وزر التخطي ظاهر في كل الحالات بما فيها غياب الـplugin.
- **الصوت كان ينجو من الشاشة.** `_finish()` صارت تُوقف المشغّل قبل `onFinished()`، ومحمية من الاستدعاء المزدوج.
- **وميض شاشة الاسم في أول تشغيل.** قراءة البروفايل من التخزين تنتهي قبل قرارات البوابة الثلاث، فكان النموذج يظهر لإطارات ثم يُستبدل بالفيلم. الحل جزآن: `lib/app/intro_gate.dart` (InheritedWidget، لأن Riverpod يمنع الكتابة داخل دورة حياة الودجة، ونهاية أول إطار متأخرة أصلًا)، ثم إمساك الباب طوال `context.motion.standard` عندما تنقّلت البوابة — لأن go_router يُبقي الصفحة المغادِرة في الشجرة طوال زمن الانتقال، فكانت مرئية بعد أن «انتهى» القرار.
- **`discussionMode` لم يكن له تحكّم أصلًا** في `room_settings_panel.dart`. غيابه ليس تجميليًا: سياسة المايك تقرأ منه، فينتهي بلاعبَين صامتَين يُقرآن كمكالمة مكسورة. أُضيف كـsegments قبل `openVoting`، والافتراضي `structured` صار جزءًا من payload الإنشاء في `online_entry_screen.dart`.
- **بلاطات الأوض العامة بلا Material فوق الخلفية المزخرفة** — كشفها الاختبار الجديد كـassertion حقيقية، لا كضجيج اختبار. أُصلحت في كود الإنتاج.
- **فحص interop كان يمنع wasm** في `web_playout_browser.dart`: `is` ضد نوع interop صحيح دائمًا ولا يفحص شيئًا. صار السؤال للـDOM عبر `tagName`.

### ما جرى تشغيله فعلًا

- `flutter analyze --no-fatal-infos`: **0 errors / 0 warnings / 74 infos**، exit0. العدد لم يتغير رغم الإضافات (ارتفع إلى 77 مؤقتًا ثم أُعيد: import غير مستخدم، وحزمتان اختباريتان أُعلنتا في dev_dependencies).
- `flutter test`: **920 passed / 1 skipped / 0 failed**. الزيادة 20: تسعة لشاشة الشرح، أربعة لتدفق البروفايل، سبعة لصفحة الأونلاين. التخطي ما زال اختبار المتصفح نفسه.
- `flutter build web --release --base-href /AL-Mafia/ --dart-define-from-file=dart_defines.json`: نجح، وتجربة wasm الجافة نظيفة بعد إصلاح interop.
- تقديم `build/web` عبر سيرفر مؤقت يدعم Range فعلًا (لا `SimpleHTTPRequestHandler`، فهو يرد 200 على Range): `HTTP/1.0 206 Partial Content`، `Content-Type: video/mp4`، `Content-Range: bytes 0-99/8993180`، `Accept-Ranges: bytes`. السيرفر وملفه وسجلّه حُذفت بعد الخطوة.

### أدوات اختبار جديدة تستحق المعرفة قبل إعادة الاكتشاف

- `test/support/fake_video_platform.dart`: `VideoPlayerPlatform` مزيّف مع `MockPlatformInterfaceMixin` و`install({refusePlay})` يعيد الأصلي في teardown. تحت `flutter test` لا يوجد plugin فيديو إطلاقًا، فكل شيء يسقط في فرع «تعذّر التحميل» — وهو ليس الفرع المهم. **الـStreamController مفرد الاشتراك عمدًا**: البث يُسقط حدث `initialized` قبل أن يشترك `initialize()`.
- `MafiaApp({initialLocation})` و`buildRouter(..., initialLocation)`: يمرّرها اختبار فقط؛ في الإنتاج `Routes.home` (وSTART_ROUTE في debug). بها صار سيناريو «الدعوة هي أول ما رآه هذا الجهاز» قابلًا للاختبار.
- `pumpAndSettle` لا يعمل على شاشة الشرح ولا لوحة الإعدادات: الخلفية تتنفس بلا نهاية. استخدم ضخّات ثابتة و`AmbientMotion(enabled: false)`.
- ضخّ شجرة ثانية من نفس نوع الودجة **يحدّثها ولا يعيد تركيبها**، فلا يعمل `initState`. افصل الحالتين إلى اختبارين، أو اضخّ `SizedBox.shrink()` بينهما.
- لوحة الإعدادات تحتاج سطحًا بارتفاع 2200 حتى يبني الـListView كل بنودها.

### ما زال NOT VERIFIED بعد هذه الجولة

- **فحص المتصفح للنسخة المبنية لم يتم.** لا فتح أول مرة ولا reload ولا resize لـHome/الأوض/Lobby/Table ولا console. كل تغطية المقاسات في هذه الجولة على مستوى widget فقط، ولهذا بقيت بنود 118/119/122 في P0.4 بلا علامة.
- **Range وContent-Type من الاستضافة الفعلية**: ما تحقق هو سيرفر محلي قادر على Range، لا الاستضافة.
- **cache/version بعد بناء الويب**: لم يُفحص.
- **الصوت المسموع بين جهازين**: NOT VERIFIED كما كان. لم يُلمس شيء في سلسلة الصوت هذه الجولة.
- **لا نشر Supabase، ولا APK، ولا commit، ولا push.** HEAD ما زال `2cfc8cd` والشجرة كما هي.
- تحرير البروفايل من الرئيسية/صفحة الأونلاين، ومسار تلف التخزين، وضغط صف أثناء طلب join قائم: كود موجود بلا اختبار، ولهذا بقيت بنودها في P1 بلا علامة.

### أول خطوة تالية

جولة متصفح على `build/web` المبني: أول تحميل مقابل reload، الفيديو داخل الإطار، ظهور التخطي، أخطاء console، ثم resize على Home وصفحة الأوض وLobby وTable — ثم فحص cache/version. بعدها النشر المستضاف بتصريح صريح، ثم APK وweb من نفس الشجرة.

## ملحق الصوت — إغلاق جولة التشخيص المستضاف — 2026-09-09

### سبب الجولة

المشكلة الأصلية runtime وليست مشكلة واجهة: إذن الميكروفون يظهر، وMetered Realtime signalling يتصل، لكن لا يوجد صوت مسموع. لذلك لا يكفي نجاح unit tests أو وصول رسائل Metered. الفحص يجب أن يمر بالترتيب: microphone ثم sender ثم offer ثم answer ثم remote description ثم ICE candidates ثم ICE/PC connected ثم onTrack ثم RTP ثم playout. محرك الوسائط بقي هو `WebRtcVoiceEngine` المخصص، وسياسة `micPolicyFor` و`setAudiblePeers` لم تتغير.

### ما ثبت محليًا

`tool/voice_runtime_probe.dart` يشغّل محركين حقيقيين في Chrome بميكروفون اصطناعي، وليس fake engine. النتيجة PASS للمسار المحلي: لكل طرف مسار audio واحد وsender واحد؛ الاتجاه `SendRecv`؛ offer/answer وremote descriptions اكتملت؛ ICE وPC وصلا `connected`؛ `onTrack` وصل بمسار audio؛ counters أظهرت 150 حزمة داخلة و150 خارجة لكل طرف؛ playout في Chrome نجح؛ وعند `setAudiblePeers({})` تعطل المسار البعيد. هذا يثبت أن المحرك قادر على نقل RTP، ويحافظ على receive privacy. لا يثبت سماعًا بشريًا ولا يثبت عبور Metered.

### إصلاح ترتيب Metered

في `lib/transport/metered_voice_link.dart` كان `_live` يصبح true بعد `connect()` و`subscribe()`. welcome كان يصل قبل اكتمال subscribe ومعه ICE، ولذلك كان أول offer ممكنًا يُرسل إلى Postgres fallback أو يخرج قبل أن يعتبر النقل جاهزًا، مع أن محرك WebRTC أخذ ICE مبكرًا. صار `handleConnected()` يعلن Metered signalling حيًا فور welcome، مع استمرار subscribe المطلوب للـchannel presence. هذا تعديل ترتيب فقط؛ لا يغيّر شبكة الوسائط ولا يسمح ب peer غير مصرح.

أضيف اختبار في `test/transport/voice_ticket_test.dart` يعلق subscribe ثم يرسل أول رسالة بعد welcome ويتأكد أنها تمر من Metered. النتيجة: 17 اختبارًا ناجحًا، صفر فشل.

### نتيجة الفحص المستضاف

`tool/voice_probe_hosted.dart` ينشئ مستخدمين anonymous، ينشئ room مؤقتة، يدخل اللاعب الثاني، يقرأ roster Supabase، يطلب `realtime_token` لكل لاعب، ويستخدم نفس `MeteredVoiceLink` الإنتاجي. نجحت المصادقة، ونجح grant لكل طرف، وظهر channel وsessionId لكل طرف، ووصلت قائمة ICE فيها 5 خوادم وبها STUN وTURN وTURNS.

توقف الفحص قبل negotiation بسبب خصائص بيئة الاختبار: العميلان داخل نفس صفحة Chrome، وGoTrue ينشر تغييرات auth عبر `BroadcastChannel` مشترك؛ بعد نجاح sign-in مرتين تزامنت الجلسة فأصبح الطرفان نفس الهوية. الدليل الآمن كان `distinctAfterAuthorization: false`. المحرك رفض الاتصال بنفسه كما يجب، لذلك هذه النتيجة ليست دليل فشل Metered أو WebRTC. يجب إعادة التجربة بنافذتين أو browser profiles منفصلين فعليًا، أو بجهازين، مع التأكد من اختلاف الهويتين قبل إنشاء الاتصال.

### تعليمات الاستكمال الدقيقة

1. ابدأ بقراءة هذا الملحق ثم `git status`. حافظ على كل التعديلات. لا commit ولا push ولا reset ولا clean.
2. لا تعتبر `flutter test --platform chrome` الحالي runtime proof؛ مشغّل Windows فشل أحيانًا بسبب path/CanvasKit قبل تحميل suite. استخدم build probe أو integration runner مستقل.
3. أصلح أداة الفحص فقط: شغّل كل عميل Supabase في browser profile مختلف أو نافذة مستقلة لا تشترك في auth BroadcastChannel. تحقق من boolean `distinctIdentities` و`distinctAfterAuthorization`، وأوقف الاختبار إن كان false.
4. أنشئ room من اللاعب A ثم اجعل B يدخل نفس code. تحقق من `rosterSizeA/B` ومن أن كل roster يحوي عضوين. لا تطبع UUID أو code أو token.
5. لكل لاعب أنشئ `MeteredVoiceLink` من roster Supabase. انتظر grant وwelcome، ثم اطلب `iceServers()` قبل `WebRtcVoiceEngine.connect()`. مرر نفس القائمة إلى `IceConfig` ثم إلى كل `createPeerConnection`. لا تستخدم MeteredPeer ولا endpoint TURN القديم.
6. اربط `OutboundSignal` بـ`link.send(to, payload)` و`link.incoming` بـ`engine.acceptSignal(from, payload)`. يجب أن تظل envelopes محتوية version/session/from/to/type/payload، ويجب رفض cross-match، wrong recipient، spoofed sender، removed roster، stale/replayed frame.
7. شغّل `acquireMicrophone()` قبل connect لكل طرف. تحقق فقط من counts وbooleans: mic granted، local track count، sender count، direction، remote track، candidate type، RTP، playout. ممنوع SDP أو IP أو credentials أو JWT.
8. في نفس الجهاز قد يظهر candidate `host`؛ هذا لا يثبت TURN. لإثبات الشبكة استخدم طرفين مستقلين وعلى شبكتين مختلفتين، ويجب أن يظهر selected candidate type `srflx` أو `relay`.
9. إذا فشل الفحص، أصلح أول طبقة فاشلة فقط. `sender=0` يعني lifecycle أو track attachment؛ لا تعالج ذلك بزيادة volume. لا تضعف `setAudiblePeers` أو `micPolicyFor`.
10. اختبر day/public: A يسمع B وB يسمع A عندما تسمح السياسة. اختبر night: لا يتم إنشاء/تمكين مسار غير مصرح به. وجود الجميع في Metered channel لا يساوي audio admission.
11. اختبر disconnect/reconnect: welcome جديد، tokenProvider جديد، ICE جديد، `_live` يعود true، وICE restart مرة واحدة فقط. بعد إزالة العضوية من Supabase يجب رفض refresh.
12. اختبر mute/unmute، خروج اللاعب، إغلاق الماتش، وvoice=false. نفّذ cleanup في `finally` للـroom المؤقتة بعد التأكد أنها تحمل أسماء الفاحص فقط؛ لا تحذف غرفًا بالبحث العام دون تحقق من الاسم والزمن.
13. بعد إصلاح الفحص شغّل `flutter gen-l10n` عند الحاجة، ثم `flutter analyze --no-fatal-infos`، ثم `flutter test`، ثم اختبارات Node backend. انشر Edge Functions فقط إذا تغيرت، وبعد نجاح الاختبارات.
14. لا تكتب PASS للصوت المسموع حتى يسمع شخص فعلي A صوت B والعكس. `connectionState=connected` و`onTrack` وRTP لا تكفي وحدها.

### الحالة عند الإيقاف

- محرك WebRTC المحلي مع RTP وChrome playout: PASS.
- authorization وTURN injection في الفحص المستضاف: PASS جزئيًا؛ grant وTURN ظهرا للطرفين، لكن selected candidate عبر طرفين مستقلين لم يثبت.
- Metered signalling إلى تفاوض WebRTC كامل: NOT VERIFIED بسبب تزامن هويتي Supabase في نفس صفحة الاختبار.
- صوت A→B وB→A وسماع بشري: NOT VERIFIED.
- سياسة الليل: لم تُغيّر؛ اختبارات policy وreceive revocation ناجحة.
- أدوات الفحص في `tool/voice_runtime_probe.dart` و`tool/voice_probe_hosted.dart` و`tool/run_voice_runtime_probe.mjs` تشخيصية فقط ولا تُضمّن في APK أو website الإنتاج.
- لا commit ولا push. آخر HEAD معروف `2cfc8cd`.

# دليل الاستكمال الحرفي — 2026-09-09

> اقرأ هذا القسم وحده أولًا. كُتب ليمنعك من إعادة اكتشاف المشروع: كل أمر بصيغته النهائية، كل ملف بمسار كامل، وكل نتيجة معروفة بقيمتها. لا تفتح `docs/PROGRESS.md` إلا إن احتجت تاريخ مرحلة قديمة.

## 0. الحالة المقيسة الآن، لا المنقولة

جرى تشغيلها فعلًا في هذه الجلسة بعد جولة Codex، على الشجرة الحالية:

- `flutter analyze --no-fatal-infos` → **0 errors / 0 warnings / 74 infos**، exit 0.
- `flutter test` → **921 passed / 1 skipped / 0 failed**، exit 0. الزيادة عن 920 هي اختبار Metered الجديد. التخطي الوحيد ما زال `test/voice/voice_web_runtime_test.dart` لأنه يحتاج متصفحًا.
- HEAD ما زال `2cfc8cd`. لا commit، لا push، لا reset. الشجرة تحمل كل التعديلات.

خلاصة القراءة: **كل ما يمكن إثباته بلا متصفح حقيقي مثبت الآن.** المتبقي كله runtime أو نشر أو بناء.

## 1. ابدأ من هنا حرفيًا

```bash
cd "D:/Flutter Data/Projects/AL Mafia"
git status --short          # تأكد أن التعديلات موجودة. لا تنظّف شيئًا.
flutter analyze --no-fatal-infos 2>&1 | tail -5
flutter test 2>&1 | tail -5
```

إن اختلفت الأرقام عن (74 info / 921 ناجح + 1 متخطى) فشيء تغيّر بعد كتابة هذا الملف: أصلحه قبل أي عمل جديد.

## 2. لماذا لا يوجد صوت مسموع حتى الآن؟ خريطة الطبقات

السلسلة الفعلية، ولا يجوز استبدالها:

```
SignallingClient / MeteredVoiceLink   → نقل الإشارة (Metered Realtime، وPostgres كاحتياطي)
        ↓ VoiceEnvelope               → غلاف موقّع: session/from/to/version/nonce/time
VoiceController                       → السياسة: مين مسموح يتكلم ومين مسموح يُسمَع
        ↓
WebRtcVoiceEngine                     → RTCPeerConnection، المايك، المسارات، ICE
        ↓
web_playout_browser.dart              → تشغيل audio element في الويب
```

الترتيب الذي يجب أن يفشل عنده التشخيص، بهذا التسلسل بالضبط، ولا تقفز فوق طبقة:
`microphone → sender → offer → answer → remoteDescription → ICE candidates → ICE/PC connected → onTrack → RTP counters > 0 → playout`.

**ما تعنيه كل نتيجة، حتى لا تُقرأ خطأ:**

- `connectionState = connected` **لا يعني صوتًا**. يعني أن هناك قناة، لا أن فيها صوتًا.
- `onTrack` وصل **لا يعني صوتًا**؛ يعني وصف مسار.
- `receivedPackets > 0` **لا يعني سماعًا**؛ يعني RTP، وقد يكون صمتًا مشفّرًا أو مسارًا مكتومًا أو عنصر audio لم يبدأ.
- ولذلك: **PASS للسماع لا يُكتب إلا بأذن إنسان** سمع A من جهاز B وB من جهاز A. هذه قاعدة الملف منذ البداية ولا تُخفّف.
- `sender = 0` مشكلة lifecycle أو ربط track، **لا تُعالج برفع volume**.
- candidate من نوع `host` على نفس الجهاز **لا يثبت TURN**. إثبات الشبكة يحتاج `srflx` أو `relay` بين طرفين على شبكتين مختلفتين.

## 3. حالة الفاحص: ما بُني، ما نجح، وأين توقف بالضبط

ثلاثة ملفات تشخيصية (لا تدخل الإنتاج أبدًا، ولا تُبنى داخل APK أو موقع):

| الملف | ماذا يفعل |
|---|---|
| `tool/voice_runtime_probe.dart` | نقطة الدخول. يشغّل **محركين حقيقيين** `WebRtcVoiceEngine` في نفس الصفحة، ويكتب النتيجة كـJSON داخل `<pre id="voice-runtime-result">`. يتحول للوضع المستضاف بـ`--dart-define=VOICE_PROBE_HOSTED=true`. |
| `tool/voice_probe_hosted.dart` | `HostedVoiceProbe`: مستخدمان anonymous حقيقيان، `create_room` خاصة باسم `VoiceProbeA`، ثم `join_room` باسم `VoiceProbeB`، ثم `realtime_token` لكل طرف، ثم `MeteredVoiceLink` الإنتاجي من roster `room_players_public`. `dispose()` يستدعي `leave_room` للطرفين بالعكس. |
| `tool/run_voice_runtime_probe.mjs` | مشغّل Node: يقدّم `build/voice-probe` عبر سيرفر محلي، يفتح Chrome headless بميكروفون اصطناعي وprofile مؤقت داخل `build/`، يقرأ النتيجة عبر DevTools، ثم يقتل Chrome ويحذف الـprofile الذي أنشأه هو وحده. |

**نتيجة الفحص المحلي: PASS حقيقي.** مسار audio واحد وsender واحد لكل طرف، اتجاه `SendRecv`، offer/answer اكتملا، ICE وPC `connected`، `onTrack` بمسار audio، 150 حزمة داخلة و150 خارجة لكل طرف، playout نجح، و`setAudiblePeers({})` عطّل المسار البعيد فعلًا. هذا يثبت أن المحرك ينقل RTP ويحترم خصوصية الاستماع. **لا يثبت Metered ولا السماع البشري.**

**أين توقف المستضاف ولماذا — وهذه أهم فقرة في الملف:**
عميلا Supabase كانا داخل **نفس صفحة Chrome**. مكتبة GoTrue تزامن الجلسات بين التبويبات عبر `BroadcastChannel` باسم `sb-<ref>-auth-token`. بعد نجاح تسجيل الدخول مرتين، تزامنت الجلستان فصار الطرفان **نفس الهوية**، فرفض المحرك الاتصال بنفسه — وهو السلوك الصحيح. الدليل الآمن الذي أظهر ذلك: `distinctAfterAuthorization: false`. **هذا فشل في أداة الفحص، وليس دليل عطل في Metered ولا في WebRTC.** لا تفسّره كعيب في المنتج ولا تُضعف المحرك لتجاوزه.

**الإصلاح كُتب بالفعل ولم يُشغَّل بعده أي فحص** (انتهى حد الاستخدام عند هذه النقطة تحديدًا):

1. في `tool/run_voice_runtime_probe.mjs`: `Page.addScriptToEvaluateOnNewDocument` يعطي كل عميل اسم قناة auth مختلفًا ويمنع `postMessage` على قنوات `sb-*-auth-token`. التقسيم محصور في هذا المتصفح المؤقت فقط.
2. في `tool/voice_probe_hosted.dart`: `distinctIdentities` و`distinctAfterAuthorization` صارا شرطين يرميان `StateError` قبل أي تفاوض.

**ما نجح مستضافًا قبل التوقف:** المصادقة للطرفين، grant لكل طرف، channel وsessionId موجودان، وقائمة ICE فيها 5 خوادم تحتوي STUN وTURN وTURNS. أي أن `realtime_token` وحقن TURN يعملان.

**إصلاح إنتاجي حقيقي خرج من هذه الجولة** — `lib/transport/metered_voice_link.dart:281` `handleConnected`: كان `_live` لا يصير true إلا بعد اكتمال `connect()` ثم `subscribe()`. لكن welcome (ومعه ICE) يصل قبل اكتمال subscribe، فكان أول offer قد يخرج عبر مسار Postgres الاحتياطي أو قبل اعتبار النقل جاهزًا. الآن Metered يُعلن حيًا فور welcome مع بقاء subscribe لأجل presence. **تعديل ترتيب فقط**؛ لا يغيّر شبكة الوسائط ولا يقبل peer غير مصرح به. يحرسه اختبار في `test/transport/voice_ticket_test.dart` يعلّق subscribe ويتأكد أن أول رسالة بعد welcome مرّت من Metered (17 اختبارًا ناجحًا).

## 4. الخطوة (أ) — أعد تشغيل الفحص المستضاف. هذه أول خطوة تالية

```bash
cd "D:/Flutter Data/Projects/AL Mafia"

# 1) ابنِ الفاحص المحلي أولًا وتأكد أنه ما زال PASS (خط الأساس).
flutter build web -t tool/voice_runtime_probe.dart --output build/voice-probe --base-href /
node tool/run_voice_runtime_probe.mjs

# 2) ثم الوضع المستضاف بنفس البناء + المفاتيح من الملف، بلا طباعة قيم.
flutter build web -t tool/voice_runtime_probe.dart --output build/voice-probe --base-href / --dart-define-from-file=dart_defines.json --dart-define=VOICE_PROBE_HOSTED=true
node tool/run_voice_runtime_probe.mjs
```

كيف تقرأ الـJSON الناتج:

- `hostedEvidence.distinctIdentities` و`distinctAfterAuthorization` **يجب أن يكونا true**. إن ظهر false فتقسيم `BroadcastChannel` لم يعمل: تحقق أن السكربت حُقن قبل `Page.navigate` (ترتيب السطور في المشغّل)، وإلا انتقل إلى نافذتين/بروفايلين مستقلين فعلًا بدل صفحة واحدة.
- `checks.meteredA/meteredB` تعني أن `link.connected` صار true بعد welcome.
- `checks.turnA/turnB` تعني أن القائمة تحوي `turn:` أو `turns:`.
- `failedStage` يسمي أول طبقة سقطت: `hosted-authorization` أو `negotiation` أو `media` أو `receive-revocation` أو `cleanup`. **أصلح هذه الطبقة وحدها.**
- `humanAudibility` مكتوب `NOT VERIFIED` دائمًا بالتصميم؛ لا تعدّله برمجيًا.

قواعد أثناء ذلك: لا تطبع SDP ولا IPs ولا credentials ولا JWT ولا room code ولا UUID. الفاحص يستبدل الهويات بـ`probe-A`/`probe-B` في التقرير — أبقِ هذا. ولا تستخدم أعلام Chrome الاصطناعية (`--use-fake-device-for-media-stream` وأخواتها) خارج المشغّل التشخيصي؛ ممنوعة في كود الإنتاج، وممنوع تعديل متصفح المستخدم الشخصي.

## 5. الخطوة (ب) — طرفان مستقلان فعلًا، ثم أذن إنسان

بعد نجاح (أ) على نفس الجهاز، يبقى إثباتان لا يُشتريان بأي عدّاد:

1. **شبكة**: طرفان على شبكتين مختلفتين (مثلًا واحد على Wi‑Fi وواحد على بيانات الهاتف). المطلوب: نوع الـcandidate المختار `srflx` أو `relay`. `host` هنا لا يثبت شيئًا.
2. **سماع**: شخص يسمع A من جهاز B، وشخص يسمع B من جهاز A، في وضع النهار حيث تسمح السياسة. ثم اختبار الليل: **لا يُنشأ ولا يُفعَّل مسار غير مصرح به**، ووجود الجميع في قناة Metered لا يساوي إذن الصوت.

وبعدها في نفس الجلسة: mute/unmute، خروج لاعب، طرد لاعب، إغلاق الأوضة، `voice=false` (اللعبة تكمل بلا صوت)، ثم قطع الشبكة وعودتها: welcome جديد، token جديد، ICE جديدة، `_live` يعود true، وICE restart **مرة واحدة فقط**. بعد حذف العضوية من Supabase يجب أن يُرفض refresh.

## 6. الخطوة (ج) — نشر Edge Functions (يحتاج تصريح صريح من المستخدم)

المشروع: `hezjbrnveajypfqmjfnh` (AL MAFIA، ACTIVE_HEALTHY). لم يُنشر أي شيء من هذه الجولات.

المعدّل محليًا: `create_room`، `room_settings`، `start_match`، `ice_servers`، و`_shared/phases.ts`. الجديد: `_shared/room_configuration.ts`، `_shared/metered_realtime.ts`، ودالة `realtime_token`.

الدوال التي تستورد من هذه المشتركات ويجب نشرها معها وإلا صارت النسخ متضاربة:
`advance_phase`، `create_room`، `generate_confrontation`، `open_phase`، `realtime_token`، `resolve_vote`، `room_settings`، `start_match`، `submit_accusation`.

قبل النشر: `node supabase/tests/room_configuration.test.mjs` و`node supabase/tests/run_golden_vectors_node.mjs` (35 حالة، Dart وTS متفقان). بعد النشر: أعد الفحص المستضاف، وتحقق أن إعدادات ما قبل الإنشاء = إعدادات lobby = إعدادات الماتش بعد `start_match`.

## 7. الخطوة (د) — جولة المتصفح لـP0.4 (لم تحدث بعد إطلاقًا)

كل تغطية الفيديو والمقاسات حتى الآن على مستوى widget فقط. المطلوب فعليًا:

```bash
flutter build web --release --base-href /AL-Mafia/ --dart-define-from-file=dart_defines.json
```

ثم قدّم `build/web` عبر سيرفر **يدعم Range فعلًا**. `python -m http.server` لا يصلح: `SimpleHTTPRequestHandler` يرد 200 على طلب Range، فيظهر الفيديو وكأنه يعمل بينما الاستضافة الحقيقية تتصرف غير ذلك. اكتب سيرفر Range صغيرًا داخل `build/`، **واحذفه وسجلّه فور انتهاء الخطوة**. القيمة المرجعية المثبتة سابقًا للملف: `206 Partial Content`، `Content-Type: video/mp4`، الحجم `8993180`.

ثم في المتصفح: أول تحميل مقابل reload، الفيديو داخل الإطار، زر التخطي ظاهر دائمًا، رسالة/إعادة تشغيل عند خطأ فعلي، لا صوت يتيم بعد مغادرة الشاشة، أخطاء console، ثم resize على Home وصفحة الأوض وLobby وTable عند 360×640 و390×844 و844×390 و1366×768 مع تغيير المقاس أثناء الفيديو: overflow، تمرير، clipping، أهداف اللمس، DPR. وأخيرًا cache/version: تأكد أن المتصفح لا يقدّم bundle قديمًا فتظن أن الإصلاح ظهر.

## 8. الخطوة (هـ) — البناء النهائي

بعد نجاح ما سبق فقط: `tool/build_apk.ps1` لبناء arm64 واحد، و`tool/build_web.ps1`، **من نفس الشجرة**. لا تقدّم الموقع المنشور القديم ولا APK القديم كأنهما يحتويان هذه الإصلاحات.

## 9. قواعد لا تُكسر، وأخطاء ثبت أنها تضيّع الوقت

القواعد: لا commit/push/reset/clean/checkout. لا نشر للموقع عبر Git قبل تصريح صريح. الأسرار في Supabase فقط ولا تُطبع؛ `dart_defines.json` يُشار إليه بالمسار ولا تُطبع محتوياته. `05-zero-leakage-spec.md` في **جذر المشروع** ويكسب كل خلاف. محرك واحد ونقلان؛ لا `OnlineGameEngine` ولا `MeteredPeer`. `lib/engine/**` نقي. الصوت ليس حاملًا. لا ألوان/مقاسات/مُدد خارج design tokens. **الصور مؤجلة بطلب المستخدم — لا تفتح هذا الفرع.** لا AVD جديدة، ولا تقتل متصفح المستخدم الشخصي — فقط عمليات الاختبار التي أنشأتها أنت.

الأخطاء المكلفة التي وقعت فعلًا، لا تكررها:

- `flutter test --platform chrome` على Windows يفشل قبل تحميل الـsuite (مسار بشرطات معكوسة + أخطاء تحميل CanvasKit). **لا تعتبره دليل runtime ولا تضيّع الوقت في إصلاحه**؛ استخدم بناء الفاحص المستقل أعلاه.
- `pumpAndSettle` يعلّق على شاشة الشرح ولوحة الإعدادات لأن الخلفية تتنفس بلا نهاية: استخدم ضخّات ثابتة و`AmbientMotion(enabled: false)`.
- ضخّ شجرة ثانية من نفس نوع الودجة يحدّثها ولا يعيد تركيبها، فلا يعمل `initState`: افصل الحالتين إلى اختبارين أو اضخّ `SizedBox.shrink()` بينهما.
- لوحة الإعدادات تحتاج سطح اختبار بارتفاع 2200 حتى يبني الـListView كل بنودها.
- `test/support/fake_video_platform.dart` يستخدم `StreamController` **مفرد الاشتراك عمدًا**: البث يُسقط حدث `initialized` قبل أن يشترك `initialize()`. لا تحوّله إلى broadcast.
- `MafiaApp({initialLocation})` يمرّرها اختبار فقط؛ الإنتاج `Routes.home`.
- `is` ضد نوع JS interop صحيح دائمًا ويكسر wasm: اسأل الـDOM (`tagName`) كما في `lib/platform/voice/web_playout_browser.dart`.

## 10. المتبقي بالترتيب، وما يُعد إنجازًا لكل بند

| # | البند | يُعد منجزًا عندما |
|---|---|---|
| 1 | إعادة الفحص المستضاف بعد إصلاح عزل الهوية | `distinctAfterAuthorization: true` ثم PASS لكل الطبقات حتى `receive-revocation` |
| 2 | طرفان مستقلان + سماع بشري + الليل | أذن إنسان في الاتجاهين، وcandidate `srflx`/`relay`، ولا مسار غير مصرح ليلًا |
| 3 | reconnect وmute وطرد وإغلاق وvoice=false | كلها تنظّف الموارد ولا توقف اللعب، وICE restart مرة واحدة |
| 4 | نشر Edge Functions (بتصريح) | Node tests تمر، ثم الإعدادات متطابقة عبر إنشاء/lobby/بداية على المستضاف |
| 5 | ماتش E2E بخمسة لاعبين مع صوت مكسور تمامًا | ينتهي صحيحًا من البداية للنهاية |
| 6 | جولة متصفح P0.4 + cache/version | لا overflow ولا clipping في المقاسات الأربعة، الفيديو داخل الإطار، console نظيف |
| 7 | بناء APK وWeb من نفس الشجرة | البناءان ينجحان ويُفحصان قبل أي نشر |

## 11. تنظيف هذه الجلسة، وما بقي منه

- حُذف ناتج البناء التشخيصي `build/voice-probe` (58 ميجابايت) وأي `build/voice-probe-profile-*` متبقٍ. يُعاد بناؤه بأمر الخطوة (أ) عند الحاجة.
- سيرفر Range المؤقت وسجلّه من جولة الويب حُذفا سابقًا.
- **بقي في Supabase**: أوضتا اختبار في `lobby` من جولة الفاحص المستضاف بتاريخ 2026-09-08، كل واحدة بلاعب واحد اسمه `VoiceProbeA` (21:13:21 و21:15:19 بتوقيت UTC) — أُنشئتا قبل أن يفشل الفحص، فلم يصل `leave_room` للمضيف. لم تُحذفا هنا لأن حذف صفوف قاعدة البيانات لا رجعة فيه ويحتاج قرار المستخدم. تُحذف بالتحقق من الاسم **والزمن** معًا، ولا يجوز حذف غرف بالبحث العام. الغرف الأقدم في نفس الفترة تحمل أسماء لاعبين حقيقيين وليست من الفاحص.

## الفحص المستضاف اكتمل — 2026-09-09 (يحدّث القسم السابق)

### ما تغيّر: الفاحص وحده، لا كود اللعبة

الجولة السابقة توقفت لأن العميلين كانا في **صفحة واحدة**، وGoTrue يزامن الجلسات بين تبويبات نفس الأصل عبر `BroadcastChannel`، فصار الطرفان هوية واحدة. الحل الذي كان مكتوبًا (تعديل `BroadcastChannel` من داخل الصفحة) رُفض واستُبدل: **الفاحص لا يجوز أن يرقّع عزلًا هو نفسه موضوع الاختبار.** الآن:

- `tool/voice_runtime_probe.dart` صار ثلاثة أوضاع حسب باراميتر `role` في الرابط: بلا role = الوضع المحلي (محركان في صفحة واحدة، أظرف يدًا بيد)، و`A`/`B` = **لاعب واحد لكل صفحة** يتفاوض عبر `MeteredVoiceLink`.
- `tool/voice_probe_hosted.dart` صار **جانبًا واحدًا**: مصادقة، إنشاء أو دخول، انتظار roster من عضوين من Supabase، `realtime_token`، ثم `MeteredVoiceLink`. الهوية تُنشر كـ`String.hashCode` بالست عشري فقط — تكفي للمطابقة ولا تكشف معرّفًا.
- `tool/run_voice_runtime_probe.mjs` يشغّل **متصفحين منفصلين**، لكل واحد `user-data-dir` خاص، فلا يتشاركان تخزينًا ولا قناة بث. `--hosted` يفعّل هذا الوضع. كود الأوضة ينتقل من صفحة المضيف إلى صفحة الضيف عبر السكربت ولا يُطبع أبدًا.
- عيب توقيت في الفاحص: المضيف كان ينشر الكود **بعد** انتظار الضيف — قفل متبادل. الآن يُنشر لحظة إنشاء الأوضة عبر `onRoomCreated`، قبل الانتظار.
- عيبان آخران في الفاحص لا في المنتج: مقارنة `RTCPeerConnectionStateConnected` كانت حساسة لحالة الأحرف فتقرأ FAIL على اتصال ناجح؛ وأنواع candidate كانت تُقرأ **بعد** `dispose()` فتخرج فارغة. الاثنان أُصلحا.

### النتيجة: PASS للطرفين عبر Metered

متصفحان مستقلان، هويتان مختلفتان من Supabase، غرفة خاصة واحدة:

- `twoDistinctPlayers: true` — تحقق متقاطع: هوية كل طرف هي peer الطرف الآخر.
- `rosterSize == 2` للطرفين، والعضوية من Supabase لا من presence.
- grant لكل طرف: token وchannel وsessionId موجودة، **ولا يحمل الرد أي role أو team أو alive** (فحص صريح `grantCarriesNoGameState`).
- ICE من welcome: 5 خوادم، STUN وTURN وTURNS كلها موجودة.
- التفاوض الحقيقي عبر Metered: العارض أنشأ وأرسل العرض واستقبل الإجابة وثبّتها، والمجيب استقبل العرض وثبّته وأنشأ الإجابة وأرسلها. (الجانبان يتبادلان الدورين حسب الحسم الحتمي للمحرك؛ الفاحص يشترط نصف الخطوات الخاص بكل جانب فقط.)
- `signaling = stable`، `ice = connected`، `pc = connected`، `direction = SendRecv`، sender = 1، `onTrack` وصل، مسار صوت بعيد = 1، RTP ≈ 200 داخلة و201 خارجة لكل طرف، playout مربوط، ولا candidate مرفوض.
- mute يوقف المسار المحلي وunmute يعيده **وsender يبقى 1** — لا إعادة تفاوض ولا فقدان مرسل.
- `setAudiblePeers({})` عطّل الاستماع فعلًا بعد أن كان يعمل.
- `roomCleanup: true` للطرفين: غرفة الفحص تُترك فارغة، ولا عضوية باقية.

**ما لا تثبته هذه النتيجة:** الجهازان واحد، فنوع الـcandidate المختار `host`. TURN **معروض** في الإعداد لكن مسار relay **لم يُختر ولم يُثبت**. ولا يوجد سماع بشري: الميكروفونات اصطناعية.

### أوامر التشغيل

```bash
MSYS_NO_PATHCONV=1 flutter build web -t tool/voice_runtime_probe.dart \
  --output build/voice-probe --base-href / --dart-define-from-file=dart_defines.json
node tool/run_voice_runtime_probe.mjs            # الوضع المحلي
node tool/run_voice_runtime_probe.mjs --hosted   # متصفحان + Metered
```
ملاحظة بيئة: Git Bash يحوّل `/` إلى مسار Windows فيرفضه `--base-href`. `MSYS_NO_PATHCONV=1` يمنع ذلك، أو استخدم PowerShell.

### إعادة الاتصال وتحديث التذكرة

مغطاة على مستوى الوحدة في `test/transport/voice_ticket_test.dart`: سوكيت سقط وعاد يحمل الإشارة، وreconnect يحدّث اعتماد الترحيل الذي يصل معه، وwelcome بعد dispose لا يحيي رابطًا ميتًا، وبلا اعتماد realtime يسقط على Postgres. **runtime لهذه الحالات: NOT VERIFIED** — تحتاج قطع شبكة حقيقيًا وليس محاكاة داخل الفاحص.

### تنظيف

حُذفت خمس غرف اختبار بعد تحقق قراءة أولًا من المعرّف والحالة والاسم والزمن: الأوضتان القديمتان باسم `VoiceProbeA` (2026-09-08 21:13 و21:15 UTC) وثلاث غرف فارغة تمامًا من تشغيلات هذه الجولة (21:45، 21:52، 21:53). الغرف التي تحمل أسماء لاعبين حقيقيين لم تُمس. `build/voice-probe` وبروفايلات المتصفح المؤقتة حُذفت بعد التشغيل.

**ملاحظة سلوك قائم** (ليست عيبًا أُصلح هنا): مغادرة آخر لاعب تترك صف الأوضة في `lobby` بصفر لاعبين بدل حذفه. لا يظهر في `browse_rooms` لأنه خاص وفارغ، لكنه يتراكم.

---

## لينك الدعوة والنشر على النطاق الجديد — 2026-09-09

### المشكلة اللي اتحلت
اللينك المتبعوت كان `https://eyadsyam.github.io/AL-Mafia/#/join/CODE`. تلات عيوب في لينك واحد:
1. النطاق قديم ومش مربوط بالنشر الحالي.
2. الـ`#` بيمنع App Links نهائيًا — أندرويد بيقص الـfragment قبل ما يقارن الـintent filter، فاللينك عمره ما هيفتح التطبيق، هيفتح المتصفح بس.
3. مافيش أي Open Graph tags، فالواتساب والتليجرام بيرسموا مستطيل رمادي فاضي جنب اللينك.

### اللي اتعمل
| الملف | التغيير |
|---|---|
| `lib/ui/screens/online/room_invite.dart` | `site` بقى `https://almafia.vercel.app/`، و`webLink` بقى مسار حقيقي `/join/CODE` من غير hash |
| `lib/main.dart` | `usePathUrlStrategy()` تحت `kIsWeb` — لازم عشان المسار يبقى مسار |
| `pubspec.yaml` | `flutter_web_plugins` (SDK) عشان `url_strategy` |
| `android/app/src/main/AndroidManifest.xml` | intent-filter جديد `autoVerify="true"` لـ `https://almafia.vercel.app/join/`؛ الـcustom scheme فضل زي ما هو |
| `web/.well-known/assetlinks.json` | بصمة شهادة التوقيع للـrelease keystore، package `com.mafiamaster.mafia_master` |
| `web/index.html` | Open Graph + Twitter card بروابط مطلقة |
| `web/og-image.jpg` | 1200×630، اتعملت بـheadless Chrome من `build/og/og.html` (PIL من غير raqm بتكسر تشكيل العربي) |
| `web/vercel.json` | اتنقل من `build/web` (اللي بيتمسح مع كل build) لمصدر الويب عشان يتنسخ لوحده |
| `tool/build_web.ps1` | `-BaseHref` الافتراضي بقى `/` |
| `test/online/room_invite_test.dart` | جديد: بيقرا الـmanifest و assetlinks كنص ويقارنهم بالـDart |

### السلوك المطلوب: التطبيق أو الموقع
لينك واحد، والمستقبِل مش بيختار. أندرويد بيجيب `assetlinks.json` وقت التثبيت ويقارن الشهادة؛ لو طابقت، اللينك بيفتح التطبيق على طول من غير chooser. لو مافيش تطبيق (أو التحقق فشل)، نفس اللينك بيفتح الأوضة على الموقع.

**مهم لو اتغيّر مفتاح التوقيع أو اتنشر على Play App Signing:** لازم تضيف بصمة Play للـ`sha256_cert_fingerprints` كمان، وإلا التحقق هيفشل والتطبيق هيرجع يفتح في المتصفح.

### اللي اتأكد فعليًا
- `flutter analyze --no-fatal-infos`: 0 errors / 0 warnings / 74 infos.
- `flutter test`: 926 passed / 1 skipped / 0 failed.
- النشر: production على مشروع Vercel `almafia`.
- `/`، `/join/K7M2QP`، `/.well-known/assetlinks.json` (application/json)، `/og-image.jpg` (image/jpeg)، `/assets/assets/video/onboarding.mp4` (video/mp4، 206) — كلها بترد صح.
- Google Digital Asset Links API: بيقرا **statement واحد صحيح، من غير أخطاء**.
- بصمة توقيع الـAPK (`apksigner --print-certs`) = البصمة المنشورة في `assetlinks.json`.
- الـmanifest جوه الـAPK نفسه فيه `autoVerify=true` + host + `pathPrefix=/join/` (اتقرا بـaapt2).
- متصفح حقيقي على 390×844: `/join/K7M2QP` بيوصل التطبيق ويحوّل لـ`/onboarding?next=/join/K7M2QP` — يعني الكود عاش عبر الـpath strategy.
- الفيديو على الموقع: 720×1280، `readyState 4`، اتشغّل واتقدّم لـ2.9s وبيـbuffer قدام. بيستنى ضغطة زر لأن ده شرط المتصفح للتشغيل بصوت، مش عطل.

### مفتوح
- **`assets/audio/join_chime.ogg` مش بيتفك تشفيره على Chrome web** — `DEMUXER_ERROR_COULD_NOT_PARSE: PTS is not defined`. الخطأ ده كان موجود على الموقع القديم كمان، يعني قديم مش جديد. الصوت مش load-bearing فاللعبة شغالة، بس الـchime عمره ما بيسمع على الويب. الحل: إعادة ترميز الملف.
- على 1366×768 الإطار الأول للفيديو بيفضل غامق لحد ما تضغط. باقي من جولة P0.4.
- السماع الفعلي A↔B لسه NOT VERIFIED.

## فيديو الشرح: من غير نت، ومن غير تقطيع — 2026-09-09

المطلوب كان تلات حاجات في حاجة واحدة: الفيلم يشتغل من غير إنترنت، ما يقفش
يحمّل كل شوية، والشاشة تبقى مظبوطة على الويب.

### الموبايل

كان متحقق أصلاً. `assets/video/` مذكورة في `pubspec.yaml`، و
`VideoPlayerController.asset` بيقرا من التطبيق المتثبّت مش من الشبكة. اتأكدنا
من الـAPK نفسه: `assets/flutter_assets/assets/video/onboarding.mp4` جوّه
الحزمة، ٨٬٩٩٣٬١٨٠ بايت، مخزّن **من غير ضغط** (وده اللي بيخلّي القفز في
الفيديو رخيص).

### الويب — التقطيع

`<video>` اللي بياخد رابط بيعمل streaming: على خط بطيء الفيلم بيقف كل شوية.
دلوقتي الصفحة بتنزّل الملف كامل الأول (`lib/platform/media/video_download*.dart`)
وبتشغّله من `blob:` — يعني `buffered = 54s` من أول لحظة تشغيل، فمافيش وقفة
ممكنة في النص. النسبة المئوية بتبان وإحنا بننزّل، عشان الانتظار يبقى معروف
مش مجهول. على الموبايل الدالة دي بترجّع `null` فوراً ومافيش حاجة بتتغيّر.

### الويب — من غير نت

فلاتر بقى بيولّد `flutter_service_worker.js` كـstub بيشيل نفسه — يعني البناء
الافتراضي مالوش أي offline. وكمان الـloader مابيسجّلش worker أصلاً على متصفح
مالوش واحد قبل كده. فبقى عندنا:

- `web/flutter_bootstrap.js` — bootstrap مكتوب بإيدنا، بينادي `_flutter.loader.load()`
  من غير أي إعدادات worker، وبيسجّل `sw.js` بنفسه بعد `load`.
- `web/offline_service_worker.js` — الكاش. بيـprecache الـshell والفيلم بـ
  `cache: 'reload'` (لأن الأصول متقدّمة بـ`immutable` لسنة، والعادي كان هيجيب
  فيلم البناء اللي فات)، وبيكاش أي طلب تاني أول ما يتطلب. التنقّل network-first
  عشان أي نشر جديد يكسب.
- `tool/build_web.ps1` — بيختم الملف بتوقيت البناء وبيكتبه `build/web/sw.js`.
  الختم ضروري: الـworker مابيتسطّبش تاني غير لما بايتاته تتغيّر، وworker
  cache-first مابيتسطّبش تاني بيثبّت الموقع على نسخته للأبد.

**متحقق فعلياً:** بعد الزيارة التانية كل الـ٣٦ ملف اللي الصفحة طلبتهم موجودين
في الكاش (صفر ناقص)، وبعدين مع قطع الشبكة من المتصفح الموقع فتح والفيلم اشتغل
(٥٤ ثانية buffered، ٧٢٠×١٢٨٠).

### الويب — الشاشة

الفيلم **ما كانش بيبان خالص** على الويب، والسبب مش الـlayout: المحرّك بيحطّ
الـplatform view كصندوق `position: absolute` من غير `left`، وبعدين بيزحلقه
بـtranslate. صندوق من غير offsets بيبدأ من مكانه الساكن، واللي في سياق RTL هو
الحافة **اليمنى** — فالفيديو اتحسب عند `x = 1435` على نافذة عرضها ١٣٦٦ وطلع
برّه الشاشة. البانل اللي حواليه فلاتر بيرسمه على الـcanvas، فكان في مكانه
الصح، وده اللي خلّى الشكل «صندوق فاضي».

العلاج قاعدة واحدة في `web/index.html`: `flt-glass-pane { direction: ltr; }`.
المستند نفسه فاضل `dir="rtl"`، و`flt-text-editing-host` أخ مش ابن فبيفضل RTL،
يعني الكتابة بالعربي ما اتلمستش.

وبعدها اتظبط الإطار: كان البانل بيتقاس الأول (بعرض عمود نص) والفيديو بيتحطّ في
نصّه، فعلى شاشة كمبيوتر كان صندوق طويل فاضي وفيلم صغير في وسطه. بقى `AspectRatio`
تحت `Center`: بياخد البُعد اللي بيخلص الأول ويحسب التاني، فالإطار على حرف
الصورة بالظبط في أي مقاس ومن غير breakpoints. متحقق على ١٣٦٦×٧٦٨ و٣٩٠×٨٤٤
و٨٤٤×٣٩٠.

### مفتوح

- تشغيل الفيلم على تليفون حقيقي ما اتعادش اختباره في الجولة دي — مافيش جهاز
  موصّل، والتحقق هنا كان من محتوى الـAPK ومن الاختبارات.
- أول زيارة للموقع لسه بتنزّل من الشبكة. الـoffline بيشتغل من الزيارة اللي
  بعدها، لأن الـworker مابيسمعش الطلبات اللي اتعملت قبل ما يتفعّل.

---

## 09-09-2026 — تسليم الجولة الحالية حرفيًا (صوت الويب + الهوست + السجل + responsive)

### نقطة البدء للـmodel التالي

لا تعيد اكتشاف المعمارية ولا تغيّرها. المطلوب إكمال نفس الشجرة الحالية وهي
غير committed؛ `HEAD` ما زال `2cfc8cd`. لا تعمل reset/clean/checkout، ولا commit
ولا push. الإصلاحات التالية موجودة بالفعل في الـworking tree، وبعضها من جولات
سابقة، لذلك راجع diff الملف المقصود فقط قبل لمسه.

أول خطوة فقط: أعد تشغيل الاختبارات الكاملة **بـconcurrency=1 وreporter expanded**
حتى تحصل على أسماء السبعة failures التي ظهرت في آخر تشغيل. التشغيل الأخير وصل
إلى `930 passed / 1 skipped / 7 failed` ثم أوقفه المستخدم قبل النهاية. الإخراج
المضغوط لم يحتفظ بأسماء failures، لذلك لا تخمّن أسبابها ولا تغيّر production code
قبل قراءة كل failure كاملًا. مجموعة التركيز المذكورة أدناه PASS، وبالتالي افحص
أولًا هل failures ناتجة عن تداخل الاختبارات المتوازية/global state أم عن regression
حقيقي:

```powershell
flutter test --no-pub --concurrency=1 --reporter expanded
```

لو السبعة ما ظهروش بالتسلسل، أعد التشغيل الكامل العادي مرة واحدة للتأكد. لو ظهر
failure: شغّل ملفه منفردًا، أصلح أول سبب مثبت فقط، ثم أعد الملف منفردًا، ثم المجموعة
الكاملة. لا تعدّل test لمجرد إسكات عيب في التطبيق.

### سبب صوت الويب المثبت وما اتعمل

الميديا نفسها سليمة: فاحص مستضاف بعميلين منفصلين وصل Metered الحقيقي وSupabase
الحقيقي، وتفاوض WebRTC كامل، و`onTrack`، وقرابة 200 RTP packet داخلة وخارجة لكل
طرف. سبب الصمت الذي يختلف بين APK والويب هو مسار **تشغيل الصوت في المتصفح**:

1. `RTCVideoRenderer.srcObject` كان يُلحق ثم يحصل `play()` مرة واحدة فقط. لو
   المتصفح رفض autoplay، لا توجد محاولة موثوقة داخل user gesture، فيظل المايك
   والاتصال أخضرين بينما الصوت صامت.
2. `onTrack` قد يصل في Chrome بـ`event.streams` فارغة. الكود القديم كان يسجل
   الحالة فقط ولا يبني stream للـtrack، لذلك لا يوجد `srcObject` قابل للتشغيل.

التغييرات الحالية:

- `lib/platform/voice/web_playout_browser.dart`: يحتفظ فقط بمعرّفات outputs التي
  منعها autoplay، ويسجل `pointerdown`/`keydown` واحدًا على document. داخل الـtrusted
  gesture يعيد `play()` مباشرة، ثم يزيل الـlistener عند نجاح كل pending output.
  لا يغيّر track ولا audibility policy. `forgetWebPlayout` يمنع أي listener قديم
  من إحياء peer انتهى.
- `lib/platform/voice/web_playout_stub.dart`: no-op مطابق للواجهات غير الويب.
- `lib/platform/voice/webrtc_voice_engine.dart`: لو `onTrack` وصل بلا stream،
  ينشئ `MediaStream` محليًا للعرض فقط، يضيف remote track إليه، ويربطه بنفس sink.
  يحتفظ به في `_playoutStreams` ويحرره مع peer. عند إعادة السماح عبر
  `setAudiblePeers` يعيد محاولة playout للـsink الحالي. لا تغيّر
  `micPolicyFor` أو `setAudiblePeers` أو topology.
- `lib/ui/widgets/voice_mic_button.dart`: على الويب يظهر زر واضح «تشغيل الصوت»
  في lobby ليعطي gesture صريحة؛ native يحتفظ بأيقونة المايك.
- `lib/ui/widgets/voice_controls.dart`: نفس زر التشغيل على الويب أثناء match؛
  native كما هو.
- `tool/web_playout_probe.dart`: regression probe صغير لا يدخل في production.
  مع `--autoplay-policy=document-user-activation-required` أثبت أن التشغيل يُرفض
  أولًا ثم ينجح بعد gesture.

أدلة الجولة الحالية:

- `node tool/run_voice_runtime_probe.mjs --hosted` → `PASS` للطرفين، هويتان
  مختلفتان، roster=2، Metered=true، 5 ICE servers، STUN/TURN/TURNS كلها true،
  ICE/PC connected، SendRecv، sender=1، remote track=true، playout=true،
  RTP تقريبًا 200/200 لكل طرف، candidates rejected=0، mute/unmute يحافظ على sender،
  وإلغاء `setAudiblePeers` يعطّل remote track. candidate المختار `host` لأن الطرفين
  على نفس الجهاز؛ relay الفعلي يحتاج شبكتين.
- `node tool/run_voice_runtime_probe.mjs --strict-autoplay` → `PASS`،
  `autoplayInitiallyBlocked=true` و`recoveredOnUserGesture=true`.
- السماع البشري على الويب ما زال NOT VERIFIED؛ المستخدم هو الذي سيجرب النسخة.

مهم: نتيجة trace النهائية في الفاحص تكتب `audible by policy FAIL` وremote enabled
false **بعد** أن يكون check `audible=true` قد نجح، لأن آخر خطوة في الفاحص متعمدة:
`setAudiblePeers({})` لإثبات إغلاق الاستماع. لا تشخّصها كفشل اتصال.

### Responsive web الموجود

- `online_entry_screen.dart`: محتوى مدخل الأونلاين يأخذ المساحة المتاحة كاملة.
- `lobby_screen.dart`: أزيل max-width الضيق، والمجلس يستخدم العرض الكامل.
- `match_flow.dart`: عمود المشهد والصوت `stretch`.
- `online_lobby_test.dart`: المقاسات `360x640` و`844x390` و`1366x768` PASS،
  ويتأكد أن council band يملأ الشاشة بدل عمود ضيق.
- إصلاح قديم لازم يظل: `web/index.html` يجعل `flt-glass-pane` LTR كي لا يخرج
  platform-view الخاص بالفيديو خارج الشاشة مع document RTL.

### خروج الهوست الموجود

- `lobby_screen.dart` و`online_table_flow.dart`: الهوست يرى sheet فيها أول اختيار
  «اخرج والأوضة تكمل» ثم اختيار إغلاق الغرفة للجميع. الأول هو المسار الافتراضي.
- `scene_sheet.dart`: عناصر `ListTile` صارت داخل `Material` شفاف؛ بدون هذا كان
  الاختبار ينهار قبل اختبار الاختيارات. `online_lobby_test.dart` المنفرد PASS
  (18 tests).
- migration جديدة: `supabase/migrations/20260909000100_host_departure.sql`.
  trigger server-side ينقل host لأقل seat متصل وحديث عند left/delete، ويحذف lobby
  الفارغة عند خروج آخر لاعب. migration نُشرت فعلًا على project
  `hezjbrnveajypfqmjfnh` باسم `host_departure`.
- transaction runtime check على hosted DB كان PASS ثم rollback: lobby handover
  لأقل seat، playing handover مع بقاء status=playing، وحذف lobby الفارغة.
- فقدان النت لا يقفل الغرفة: presence/claim-host القديم يظل fallback بعد timeout.

### سجل الماتشات الأونلاين الموجود

- `lib/data/online_match_history.dart`: يحفظ summary محليًا فقط بعد outcome:
  roomId، أسماء عامة، winner mafia/town، day count. لا roles ولا actions. dedupe
  حسب roomId وحد أقصى 200.
- `online_session.dart`: يشترك في snapshot بعد connect ويحفظ النتيجة مرة واحدة،
  ويلغي الاشتراك عند leave/dispose.
- `history_screen.dart`: يعرض online summaries مع offline history. استخدم
  `onlineMatchMeta` لأن `matchMeta` القديمة تقول nights بينما القيمة هنا day.
- `test/data/online_match_history_test.dart`: durability/dedupe/corrupt storage PASS.

### نتائج الفحص الحالية

- `flutter gen-l10n` PASS.
- `flutter analyze --no-pub --no-fatal-infos` → exit 0، **0 errors / 0 warnings / 74 infos**.
- focused suite:
  `flutter test --no-pub test/data/online_match_history_test.dart test/widget/online_lobby_test.dart test/widget/online_entry_test.dart test/voice test/transport/voice_ticket_test.dart`
  → **97 passed / 1 skipped / 0 failed**.
- `test/widget/online_lobby_test.dart` منفردًا → **18 passed**.
- full suite الأخير غير مقفول: **930 passed / 1 skipped / 7 failed** قبل الإيقاف.
  هذا هو أول عمل للـmodel التالي؛ لا تدّعي PASS قبله.

### الترتيب الحرفي المتبقي

1. شغّل full suite بـ`--concurrency=1 --reporter expanded` والتقط أسماء failures.
2. لكل failure: ملف منفرد → أول root cause → أصغر إصلاح → ملف منفرد. ثم full suite.
3. شغّل backend config test:
   `node --test supabase/tests/room_configuration.test.mjs`.
4. أعد `flutter analyze --no-pub --no-fatal-infos`، ويجب 0 errors/0 warnings.
5. بعد PASS فقط ابنِ production web من نفس الشجرة عبر `tool/build_web.ps1`؛ الـbase
   الصحيح لـVercel هو `/`. تأكد أن `web/vercel.json` و`web/offline_service_worker.js`
   نُسخا وأن `build/web/sw.js` موجود.
6. انشر `build/web` على مشروع Vercel الموجود `almafia`. الربط الحالي داخل
   `build/web/.vercel/project.json`: project
   `prj_dReXJpHNF2whJenHBfte3oxQvW3l` وorg
   `team_IoLnUMXyz0TVL7vLTp8opjpx`. هذه identifiers وليست أسرارًا. لا تنشئ مشروعًا
   جديدًا. تحقق من `/` و`/join/K7M2QP` وmp4 وservice worker بعد النشر.
7. ابنِ **APK واحد arm64 فقط**:
   `flutter build apk --release --target-platform android-arm64 --dart-define-from-file=dart_defines.json`.
   تحقق بـaapt/apksigner أنه arm64 فقط وموقّع، واحذف APKs القديمة الأخرى داخل
   `build/app/outputs/flutter-apk` مع تحديد المسارات صراحة بعد listing.
8. نظافة DB: probe المستضاف أعاد `roomCleanup=true` للطرفين، وقبل الجولة لم توجد
   `VoiceProbe%` rooms. لا تحذف غرفًا حقيقية. يمكن حذف orphan lobby فقط بعد query
   يثبت أنها بلا أي `room_players` وبلا outcome؛ migration الجديدة تمنع تكرارها.
9. احذف generated `build/voice-probe` بعد انتهاء الفحوص. هو موجود الآن لأن المستخدم
   طلب التوقف فورًا. لا تحذف ملفات `tool/voice_*`؛ هي أدوات regression مقصودة.
10. أعط المستخدم رابط Vercel وpath APK واحد، واطلب منه فقط الاختبار التالي:
    عميلان على جهازين/شبكتين، lobby ثم day match؛ اضغط «تشغيل الصوت» مرة على الويب؛
    جرّب A→B وB→A وmute/unmute؛ أغلق host بدون اختيار close وتأكد انتقال الهوست؛
    أكمل match وتأكد ظهوره في السجل. سجّل candidate type فقط host/srflx/relay.

### ممنوعات الاستكمال

- لا MeteredPeer، لا تغيير mesh، لا حذف privacy policy، لا نقل roles إلى Metered.
- لا تضع/تطبع JWT أو TURN credentials أو secrets أو SDP/IPs.
- لا commit ولا push إلا بطلب صريح جديد من المستخدم.
- لا تعمل workaround للـtests ولا تغيّر architecture بسبب failure واحد.
- لا تنشر قبل إغلاق السبعة failures والتحليل/backend test.

---

## 09-09-2026 — إغلاق الجولة

الفشل السبعة كانوا كلهم `test/integration/history_test.dart`، وسبب واحد: `_load`
في `history_screen.dart` بقى ينتظر `OnlineMatchHistory.load()` — أي تخزين المنصّة —
قبل أول `setState`. في بيئة الاختبار القراءة دي تظل معلّقة، فيفضل `_summaries` null
والشاشة فاضية، فتفشل حتى حالة «لا يوجد ماتشات». الإصلاح: يُرسم السجل الأوفلاين أولًا
ثم يُقرأ سجل الأونلاين بعده. نفس المنطق يحمي المتصفح الذي عطّل تخزين الموقع.

المجموعة الكاملة بعد الإصلاح: 937 passed / 1 skipped / 0 failed. قاعدة البيانات
اتنضفت (11 غرفة اختبار متبقية وكل ما يتبعها). الويب منشور على almafia.vercel.app.
السماع البشري على الويب ما زال NOT VERIFIED — ده اختبار المستخدم.

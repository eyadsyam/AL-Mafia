# Claude Code final continuation — Mafia Master online release

انسخ هذا الملف كاملًا إلى Claude Code. أنت تعمل داخل نفس المشروع:

`D:\Flutter Data\Projects\AL Mafia`

الهدف هو إنهاء الأونلاين والتحقق منه فعليًا ثم إغلاق المشروع للنشر. لا تبدأ من الصفر، ولا تستبدل المعمارية، ولا تحذف أي ميزة أو شغل غير متعلق بالمهمة.

## قاعدة مهمة قبل أي شيء

التزم بملفات `AGENTS.md` و`docs/PROGRESS.md` وبالمواصفات الأصلية. اقرأ `docs/PROGRESS.md` أولًا، ثم اقرأ هذا الملف، ثم اقرأ من المواصفة الأصلية ما تحتاجه فقط باستخدام `rg` وقراءات محددة:

- `05-zero-leakage-spec.md` في جذر المشروع هو المرجع الملزم للخصوصية.
- `docs/09-information-engine.md`
- `docs/10-online-architecture.md`
- `docs/11-edge-cases-and-tests.md`
- `docs/PROMPT-build-online-and-information-engine.md`
- نص الطلب الأصلي إذا احتجت تفاصيل المراحل: `C:\Users\LENOVO\.codex\attachments\f5cf6f17-f724-4104-8e9a-135db8fabf26\pasted-text.txt`

لا تستخدم أبدًا:

- `git reset --hard`
- `git checkout --`
- `git clean`
- حذفًا واسعًا أو إعادة بناء للمعمارية
- commit أو push للكود
- `tool/build_web.ps1 -Publish`

لا تطبع قيمة أي key أو token من `dart_defines.json` أو متغيرات البيئة أو سجلات Supabase. استخدم أسماء الأسرار فقط، ولا تغيّرها أو تدورها.

المستخدم سبق أن وافق صراحةً على رفع وظائف السيرفر إلى مشروع Supabase:

- الاسم: `AL MAFIA`
- project ref: `hezjbrnveajypfqmjfnh`

لا تطلب هذه الموافقة مرة أخرى. هذا لا يسمح بطباعة الأسرار أو نشر وجهة مختلفة.

## حالة Claude السابقة

Claude أعلن أن `PHASE 63b` أُغلقت جزئيًا:

- Section B للحفظ والاسترجاع: معلنة done.
- أجزاء Section C: إعدادات الغرفة atomically، منع المطرود من الأفعال، kick أثناء الماتش كـ neutral elimination، presence ageing، وإعادة ترتيب مقاعد الـ lobby.
- Browser/build/publish: أعلن أن Chrome pass، APK وWeb build تمّا، وأن `almafia.vercel.app` نُشرت له نسخة Web عبر Vercel deployment READY.
- سجلاته المعلنة: `roster_match.py` 48/48، `e2e_match.py` 93/93، `recovery_match.py` 40/40، Flutter 1018 passed / 1 skipped / 0 failed، analyze 75 infos و0 errors/warnings.
- `concurrency_match.py` لم يكتمل: 41 ok / 0 fail قبل توقف بسبب anonymous sign-in rate limit 429.
- الصوت بين عميلين أثبت RTP صناعيًا، وليس سماعًا بشريًا. A→B وB→A، خصوصية الليل، TURN/relay، Android↔Web، background/resume، موبايل حقيقي وoffline لم تثبت بشريًا.

هذه أرقام وسجلات يجب قراءتها وإعادة ما تأثر بالتعديلات الحالية؛ لا تحول ادعاءً سابقًا إلى PASS من غير دليل مطابق للنسخة الحالية.

## تنبيه عاجل: حالة Hosted يجب توحيدها قبل أي اختبار

في آخر جلسة Codex، أُضيفت مهاجرتان إلى Supabase قبل توقف النشر:

- `supabase/migrations/20260914001200_resolution_population.sql` — أُطبقت.
- `supabase/migrations/20260914001300_deal_preserves_settings.sql` — أُطبقت.

المهاجرة الأولى غيّرت `night_fingerprint` و`vote_fingerprint` لتضمين بصمة السكان الأحياء/المقاعد. النسخ المحلية من الوظائف صارت تضيف نفس الجزء في:

- `supabase/functions/resolve_night/index.ts`
- `supabase/functions/resolve_vote/index.ts`

لكن نشر هاتين الوظيفتين بعد هذا التغيير لم يكتمل بسبب توقف الجلسة. **ابدأ بفحص النسخ الحالية، ثم انشر النسختين المتوافقتين مع كل ملفات `_shared` اللازمة، وبعدها اختبر resolution. لا تشغّل E2E أو تعلن أن الأونلاين سليم قبل توحيد هذا العقد.**

كذلك توجد تغييرات محلية لم تُنشر بالضرورة في:

- `supabase/functions/_shared/api.ts` — أخطاء القراءة تُرمى بدل أن تتحول إلى عضوية غير موجودة؛ اللاعب kicked ليس membership.
- `supabase/functions/heartbeat/index.ts`
- `supabase/functions/set_presence/index.ts`
- `supabase/functions/saw_role/index.ts`
- `supabase/functions/my_team/index.ts`
- `supabase/functions/claim_floor/index.ts`
- `supabase/functions/release_floor/index.ts`
- `supabase/functions/record_speaking/index.ts`
- `supabase/functions/submit_prediction/index.ts`
- وظائف resolve أعلاه.

راجع الفرق بين كل ملف محلي والنسخة المنشورة، ثم انشر فقط ما يلزم وبـ verify_jwt الموجود أصلًا. بعد كل نشر استخدم `list_edge_functions` وسجّل الاسم والنسخة وACTIVE. لا تفترض أن `_shared` تغيّر في وظيفة منشورة لمجرد أنه تغيّر محليًا.

## ما تم إصلاحه في جلسة Codex الأخيرة

### kicked seats / deal / roster

- `20260914000600_kicked_seats.sql` مطبقة، واختبار `supabase/tests/kicked_seats.sql` نجح.
- `20260914000700_public_room_active_count.sql` مطبقة، وعدد public rooms يستبعد kicked rows.
- `start_match` المحلي يفحص أخطاء قراءة الغرفة واللاعبين ويستبعد `kicked=false`؛ النسخة المنشورة وقتها كانت ACTIVE v11، ثم تحقق من النسخة الحالية قبل إعادة النشر.
- `open_phase` المحلي والـ RPC يستبعدان kicked rows من reveal gate؛ النسخة المنشورة وقتها كانت ACTIVE v12.
- `apply_match_deal` يحتفظ بصف المطرود لإظهار رسالة الإزالة، لكنه لا يعطيه role ولا يعدّه من السكان الفعليين، وينشر `public_data.rosterSeats` للمقاعد التي استلمت أدوارًا.
- `room_codec.dart` يخفي kicked row في الـ lobby، يحافظ على viewerKicked من roster الكامل، ويحافظ على المقعد المطرود بعد deal كي يظل participant في التاريخ. راجع أي اختلاف من Claude قبل تغيير هذا السلوك.
- `20260914001300_deal_preserves_settings.sql` يجعل إعدادات الغرفة المحفوظة هي المرجع عند start تحت lock، فلا يستبدل start payload إعدادات host المحفوظة.

اختبارات Codex السابقة:

- `build/phase63-codex-recovery.log`: 37 passed / 0 failed.
- `build/phase63-codex-targeted.log`: 174 passed.
- `build/phase63-codex-analyze.log`: focused analyze بلا issues.
- Hosted rollback tests: `kicked_seats`, `atomic_room_entry`, `single_seat`, `atomic_kick`, `atomic_phase_open`, `resolution_population` و`deal_preserves_settings` PASS.

### stale resolution population

البصمة الجديدة تمنع نتيجة محسوبة قبل kick/neutral elimination من أن تُحفظ بعد تغيّر السكان. اختبار:

- `supabase/tests/resolution_population.sql`

يجب أن يظل PASS بعد نشر الوظائف وإعادة تشغيل full resolution flow. أُضيف أيضًا اختبار Node صغير:

- `supabase/tests/roster_fingerprint.test.mjs`

### لا تعكس تغييرات محلية قديمة بلا دليل

المشروع dirty منذ البداية وفيه تغييرات كثيرة للمستخدم. حافظ عليها كلها. راجع التغييرات الحديثة فقط، ولا تستخدم git لإرجاع شغل لم تكتبه أنت.

## أولوية العمل بالترتيب

### 1. توحيد ونشر العقد الحالي

1. اعرض حالة migrations والـ Edge Functions من المشروع الصحيح فقط، من غير أسرار.
2. راجع تعريفات hosted لـ `night_fingerprint`, `vote_fingerprint`, `apply_match_deal` و`commit_resolution`.
3. انشر resolve_night وresolve_vote بالنسخ المحلية المتوافقة مع fingerprint الجديد، مع `_shared`.
4. راجع وانشر الوظائف المحلية التي تعتمد على `loadMembership` أو تغيّرناها، خصوصًا heartbeat وset_presence وsaw_role وmy_team وfloor/speaking وsubmit_prediction، إذا أثبت diff أنها أقدم من الكود المحلي.
5. تحقق من ACTIVE/version/verify_jwt لكل وظيفة. لا تنشر وظيفة عمياء لمجرد أن اسمها موجود.

### 2. اختبارات Section C بعد التوحيد

شغّل وأصلح، بدون إضعاف أي assertion:

- `supabase/tests/recovery_match.py`
- `supabase/tests/e2e_match.py`
- `supabase/tests/concurrency_match.py`
- `supabase/tests/roster_match.py`
- `supabase/tests/kicked_seats.sql`
- `supabase/tests/resolution_population.sql`
- `supabase/tests/atomic_room_settings.sql`
- `supabase/tests/kicked_moves.sql`
- `supabase/tests/kick_eliminates.sql`
- `supabase/tests/lobby_departures.sql`
- كل SQL test يمس `apply_match_deal`, `join_room_atomic`, `commit_resolution`, fingerprints، أو phase transitions.

إذا حصل 429 من anonymous sign-in، لا تخفّف الاختبار ولا تعتبره PASS. استخدم retry/backoff محدودًا أو staging users الموجودين حسب harness، وسجّل الجزء الذي تعذر تشغيله. الهدف بعد آخر إصلاح هو 93/93 للـ E2E و48/48 roster و40/40 recovery، مع concurrency مكتمل لا مجرد 41/0.

أضف حالة كاملة واحدة على الأقل تثبت:

- kick في الـ lobby → replacement يدخل → start → reveal → night → vote → result.
- المطرود قبل deal لا يظهر في standings ولا يؤثر في الفوز.
- kick لمشارك بعد deal يظل participant تاريخيًا، يُزال من alive، تُلغى whisper الخاصة به، ويُعاد حساب الفوز مرة واحدة.
- kick أثناء حساب resolution يرفض fingerprint القديم، والمحاولة الجديدة بالحالة الحالية تنجح.
- إعدادات host لا ترجع إلى start payload قديم.

### 3. راجع race في إعدادات الغرفة

Claude أصلح `commit_room_settings`، لكن افحص المصدر والـ migration والنسخة المنشورة. يجب أن تكون:

- host-only
- lobby-only
- تحت room lock
- capacity محسوبة من نفس السكان الذين يقبلهم الباب والتوزيع (`not kicked`، مع اتفاق واضح حول `left`)
- merge SQL لا read-modify-write
- لا تعيد تحديث غرفة بدأت بسبب سباق start/join/settings

أي read أو update خطأ يجب أن يصبح refusal/generic error، لا نجاحًا فارغًا.

### 4. راجع Section B والحفظ

تحقق من الكود والاختبارات، ولا تعلن Section B كاملة إلا بعد إثبات:

- refresh / deep link / tab close / reopen لا يرسم lobby أو match فارغًا.
- resume pointer يحتوي المسموح فقط: room id/code والبيانات الضرورية، بلا role أو private facts.
- يوجد Resume وForget/Discard من شاشة online entry، وفشل التخزين يظهر warning، ولا يمنع دخول الغرفة.
- history save عند result لا يمنع مسح pointer إذا فشل الحفظ.
- transport القديم والvoice resources يتعمل لهم teardown عند leave أو kick أو دخول غرفة ثانية.
- temporary offline يعرض حالة اتصال/resync واضحة ولا يسقط player action بصمت.

### 5. راجع كل online flow

غطِّ entry، profile بعد onboarding، public list، private code، room settings، lobby، start/deal، role reveal retry، night actions، morning، information/confrontation، opening/discussion/floor، vote/revote/verdict، result/history، leave، kick، host migration، refresh/reconnect، close room، new-room rematch.

لكل mutation افحص caller، membership، kicked، alive، phase، server deadline، host/role permission، action id، duplicate retry، stale Realtime event، cross-room isolation، وفشل القراءة/الكتابة.

### 6. أصلح فقط عيوب الواجهات التي لها دليل

اقرأ `docs/CLAUDE-PARALLEL-REVIEW.md`. العيوب المسجلة التي لم تُغلق بالكامل:

- E-3: lobby في phone landscape 844×390 غير مريح.
- E-4: entry/lobby على desktop بلا max-width column.
- E-5: on-state switch thumb غير واضح.
- E-6: gender chips أقل من 48px touch target.
- E-7: `join_chime.ogg` demuxer error في headless، courtesy وغير load-bearing؛ افحص headed browser قبل تعديل.
- E-8: خطأ JS بعد مشاركة في headless، افحص `navigator.share` fallback.

لا تعيد تصميمًا واسعًا ولا تحذف عناصر. استخدم design tokens وl10n، واحترم Doc 05. افحص mobile portrait/landscape وdesktop، ولقطة واحدة مصغرة لكل شاشة نهائية.

### 7. الصوت

حافظ على:

`Metered SignallingClient → VoiceLink → VoiceController → WebRtcVoiceEngine → per-peer RTCPeerConnection`

مع `micPolicyFor` و`setAudiblePeers` وfallback الموجود. لا تنقل إلى MeteredPeer ولا تجعل الصوت شرطًا لاستمرار الماتش.

اختبر فعليًا، حسب المتاح:

- permission/mic، sender attachment، offer/answer، early/late ICE، TURN/relay، candidate type، remote track، mute/unmute، reconnect، browser gesture/autoplay، background/resume.
- Chrome profile A ↔ Chrome profile B أو Android ↔ Web.
- day audibility، night privacy، الاتجاهين A→B وB→A.
- تعطيل الصوت بالكامل مع إكمال الماتش.

الصوت الصناعي أو ارتفاع `totalAudioEnergy` ليس سماعًا بشريًا. أي جزء لم يسمعه شخص فعليًا = `NOT VERIFIED`.

### 8. البناء والنشر

بعد آخر تعديل فقط:

1. شغّل localization/dependency checks إذا كانت الأدوات متاحة. `pub get` كان يعلق سابقًا؛ لا تعتبره نجحًا من غير output واضح.
2. شغّل Flutter analyze والاختبارات الكاملة واحفظ logs جديدة.
3. ابنِ APK release حديثًا من آخر source، وتحقق من التوقيع وABIs (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
4. ابنِ Web release حديثًا وتحقق أن build يحتوي آخر الكود، وراجع `sw.js` stamp.
5. لا تستخدم `tool/build_web.ps1 -Publish` إطلاقًا لأنه يعمل force-push إلى gh-pages.
6. استخدم مسار Vercel المسموح فقط إذا كانت إعداداته الحالية واضحة؛ تحقق من `almafia.vercel.app` بعد النشر: root، main bundle، manifest، favicon، assetlinks، deep link `/online/lobby`، و`/beta` ليس صفحة beta حقيقية. لا تعتبر SPA fallback وحده دليلًا.
7. لا تضع `dart_defines.json` أو أي key في output أو APK أو Web JS أو logs أو docs.
8. لا commit ولا push.

## أوامر البيئة

PowerShell. مسار Flutter المباشر المستخدم سابقًا:

```powershell
$flutterDart = 'D:\Flutter Data\Futter\flutter\bin\cache\dart-sdk\bin\dart.exe'
$flutterTool = 'D:\Flutter Data\Futter\flutter\bin\cache\flutter_tools.snapshot'
& $flutterDart $flutterTool test --no-pub
& $flutterDart $flutterTool analyze --no-pub lib test
```

Node:

```powershell
& 'D:\Programms\node.js\node.exe' supabase/tests/roster_fingerprint.test.mjs
```

Python harnesses تحتاج متغيرات البيئة من `dart_defines.json` من غير طباعتها. اقرأ القيم داخل process فقط ولا تعرضها في output.

## التقرير المطلوب

حدّث `docs/PROGRESS.md` بمرحلة جديدة بعد كل gate، وسجّل ما شغّلته فعلًا. في التقرير النهائي استخدم أقسام الطلب الأصلي حرفيًا، ومنها:

`ROOT CAUSE`, `PERSISTENCE`, `ONLINE FLOW`, `ROLE REVEAL`, `HOST MIGRATION`, `PRESENCE`, `WEB RESPONSIVENESS`, `VOICE ARCHITECTURE`, `LOCAL MICROPHONE`, `AUDIO SENDER`, `OFFER / ANSWER`, `REMOTE ICE`, `ICE CONFIGURATION`, `ICE CANDIDATE TYPE`, `REMOTE AUDIO TRACK`, `AUDIBILITY POLICY`, `ANDROID AUDIO`, `WEB AUDIO`, `AUDIO A → B`.

لكل بند اكتب فقط `PASS`, `PARTIAL`, `FAIL`, أو `NOT VERIFIED` ومعه الدليل: log path، test count، hosted function version، screenshot path، أو client combination. لا تكتب “جاهز للنشر” إلا بعد إغلاق الفشل الحقيقي وتوضيح كل NOT VERIFIED.

ابدأ الآن من تنبيه توحيد fingerprints والنشر، ثم أكمل الاختبارات. لا تكتفِ بخطة، ولا تعلن استقرار الأونلاين قبل أن تمر الاختبارات بعد آخر نشر.

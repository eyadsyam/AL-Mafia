# تشغيل إشعارات الدعوات (Push) — خطوات المالك

الإشعارات بتشتغل على **أندرويد والويب** عن طريق Firebase Cloud Messaging.
التطبيق بيتبني وبيشتغل عادي **من غير** أي حاجة من دول: الدعوة بتوصل جوه
التطبيق (البوب أب بالصوت والرعشة) وبس الإشعار وهو مقفول هو اللي مش شغال.

محتاج تعمل الخطوات دي مرة واحدة بس، من الكمبيوتر.

## في Firebase (console.firebase.google.com)

1. **اعمل مشروع**: «Add project» ← سمّيه مثلاً `almafia` ← كمّل (Google
   Analytics مش لازم).
2. **ضيف تطبيق أندرويد**: من ⚙️ «Project settings» ← «Your apps» ← أيقونة
   أندرويد ← في «Android package name» اكتب بالظبط
   `com.mafiamaster.mafia_master` ← «Register app» ← دوس
   **Download google-services.json**.
   - حط الملف ده في: `android/app/google-services.json` (جنب
     `build.gradle.kts`). الملف ده مش سري، عادي يتعمله commit.
3. **ضيف تطبيق ويب**: من نفس المكان ← «Add app» ← أيقونة الويب `</>` ← أي
   اسم ← «Register app». هيظهرلك كود فيه `const firebaseConfig = { … }`.
   - افتح `web/firebase-config.js` وبدّل `self.MAFIA_FIREBASE = null;`
     بالقيم دي، كده:
     ```js
     self.MAFIA_FIREBASE = {
       apiKey: "…", authDomain: "….firebaseapp.com", projectId: "…",
       messagingSenderId: "…", appId: "1:…:web:…",
       vapidKey: "…",   // من الخطوة 4
     };
     ```
4. **مفتاح الويب (VAPID)**: ⚙️ «Project settings» ← تاب «Cloud Messaging» ←
   تحت «Web configuration» ← «Web Push certificates» ← «Generate key pair» ←
   انسخ المفتاح الطويل وحطه مكان `vapidKey` في نفس الملف.
   - في نفس التاب اتأكد إن «Firebase Cloud Messaging API (V1)» مكتوب جنبها
     **Enabled**. لو لأ، دوس على النقط التلاتة ← «Manage API in Google Cloud
     Console» ← «Enable».
5. **مفتاح السيرفر (سري!)**: ⚙️ «Project settings» ← تاب «Service accounts» ←
   «Generate new private key» ← «Generate key». هينزل ملف JSON.
   **الملف ده سري: ماتعملوش commit وماتبعتوش لحد.**

## في Supabase

6. **حوّل الملف لـ base64 وحطه secret** اسمه `FCM_SERVICE_ACCOUNT_B64`.
   على ويندوز، من PowerShell في الفولدر اللي فيه الملف (بدّل اسم الملف):
   ```powershell
   $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("almafia-xxxx.json"))
   supabase secrets set "FCM_SERVICE_ACCOUNT_B64=$b64"
   ```
   (base64 عشان PowerShell بيبوّظ علامات التنصيص اللي جوه الـ JSON لو
   اتحط زي ما هو. الحتة كلها بين علامتين تنصيص زي ما هي فوق.)
   أو من الداشبورد: Project ← «Edge Functions» ← «Secrets» ← «Add new
   secret» والصق قيمة `$b64`.
7. **ارفع السيرفر**: الـ migration الجديدة والـ function:
   ```powershell
   supabase db push
   supabase functions deploy friends
   ```
8. **شغّل الفلاجات** (من «SQL Editor»):
   ```sql
   update public.economy_config
      set friends_enabled = true,        -- لو مش شغال أصلاً
          push_invites_enabled = true;
   ```
   تقدر ترجّع `push_invites_enabled = false` في أي وقت: الدعوات جوه التطبيق
   بتفضل شغالة.

بعد كده ابني الـ APK والويب زي العادة (`tool/build_apk.ps1`،
`tool/build_web.ps1`). مفيش أي خطوة تانية في الكود.

## بيحصل إيه لو حاجة ناقصة؟

| الناقص | اللي بيحصل |
|---|---|
| `google-services.json` | أندرويد: مفيش إشعار وهو مقفول. الدعوة جوه التطبيق شغالة. |
| `web/firebase-config.js` لسه `null` | الويب: مفيش إشعار. الدعوة جوه التطبيق شغالة. |
| الـ secret `FCM_SERVICE_ACCOUNT_B64` | السيرفر بيسجّل سطر «push skipped» ومايبعتش إشعار، والدعوة بتتسجل عادي من غير أي error للاعب. |
| `push_invites_enabled = false` | مفيش إشعارات خالص، والتطبيق مابيطلبش إذن الإشعارات. |

## الإذن والخصوصية

- إذن الإشعارات (أندرويد 13+ والمتصفح) **مابيتطلبش أول ما التطبيق يفتح**.
  بيتطلب أول مرة اللاعب يفتح «ادعي صحابك» أو توصله دعوة جوه التطبيق.
- الإشعار فيه **بس**: كود الأوضة، اسم اللي بيدعي واليوزر بتاعه، ورقم
  الدعوة. عمره ما بيقول أي حاجة عن الأدوار أو اللعب (Doc 05).
- «ناس قريبة» مابتطلبش إذن الموقع خالص: البلد بتتعرف من اسم المنطقة
  الزمنية للتليفون (زي `Africa/Cairo`) ولغة الجهاز، وبيتخزن كود البلد بس
  (حرفين)، من غير إحداثيات ولا IP.

## الحالة دلوقتي (1.1)

الخطوات من 1 لـ 6 اتعملت: `android/app/google-services.json` و`web/firebase-config.js`
فيهم مشروع `mafia-master-e0cf5`، والـ secret متسجّل، و`push_invites_enabled` شغال.
الاختبار `test/platform/push_config_test.dart` بيتأكد إن الملفين موجودين ومكتملين
وبيتقروا بنفس الطريقة اللي التطبيق والـ Gradle بيقروهم بيها، ومافيهمش أي مفتاح سري.

## التحقق المحلي (للمراجِع) — مرة قبل الرفع

الـ APK مااتبناش في بيئة الـ cloud (مفيش Android SDK)، فدي الخطوات بالظبط على جهازك:

### أندرويد

1. ابني: `tool/build_apk.ps1` (أو `flutter build apk --release`).
2. اتأكد إن قيم Firebase دخلت الـ APK (من Android SDK build-tools):
   ```powershell
   aapt2 dump resources build\app\outputs\flutter-apk\app-release.apk | Select-String "google_app_id|gcm_defaultSenderId|project_id"
   ```
   لازم التلاتة يظهروا. لو مش ظاهرين يبقى `google-services.json` مش جنب `build.gradle.kts`.
   وكمان اتأكد إن نسخ الـ mp3 بتاعة الويب مادخلتش الـ APK (الأندرويد بيشغّل الـ ogg):
   ```powershell
   tar -tf build\app\outputs\flutter-apk\app-release.apk | Select-String "\.mp3$"
   ```
   مفروض ماتطلعش ولا سطر. لو طلعت، يبقى الـ Gradle ماطبّقش الاستثناء، والـ APK أكبر بحوالي 5 ميجا بس، وكل حاجة شغالة عادي.
3. نزّله على موبايل أندرويد 13 أو أحدث: `adb install -r build\app\outputs\flutter-apk\app-release.apk`.
   **نسخة الإعلانات التجريبية (`adstest`)** اسم الباكدج بتاعها `com.mafiamaster.mafia_master.adstest`. عشان يوصلها إشعارات:
   في Firebase ← Project settings ← Add app ← أندرويد بالاسم ده بالظبط ← نزّل `google-services.json` تاني
   (الملف الجديد فيه التطبيقين) وحطه مكان القديم. الـ Gradle بيختار تطبيق النسخة لوحده.
4. افتح اللوج وسيبه شغال: `adb logcat -s FirebaseApp FirebaseMessaging flutter`
   وافتح التطبيق. مفروض يظهر `FirebaseApp initialization successful`.
5. القنوات: الإعدادات ← التطبيقات ← سيد المافيا ← الإشعارات. لازم تلاقي قناتين:
   «دعوات اللعب» (بالصوت) و«الأصحاب». أو من الكمبيوتر:
   `adb shell dumpsys notification | Select-String "mafia_invites|mafia_social"`.
6. **الإذن في وقته:** أول فتحة للتطبيق مفيش أي طلب إذن. ادخل أوضة ← «ادعي صحابك»:
   هنا بس يظهر طلب إذن الإشعارات. دوس «سماح».
7. **التوكن اتسجّل:** في Supabase ← SQL Editor:
   ```sql
   select platform, updated_at from public.push_tokens order by updated_at desc limit 5;
   ```
   لازم تلاقي سطر `android` بوقت دلوقتي.
8. **الإشعار والتطبيق مقفول:** اقفل التطبيق خالص (اسحبه من الـ recent). من موبايل تاني أو
   من الويب ادخل أوضة وابعت دعوة للحساب ده (تاب «دوّر بالاسم»). لازم يوصل إشعار
   بصوت الخبطة والرعشة الطويلة واللون الدهبي.
9. **الدوس بيفتح الدخول:** دوس على الإشعار. لازم التطبيق يفتح على شاشة الدخول وكود
   الأوضة مكتوب. جرّب تاني بعد ما الأوضة تبدأ: لازم تظهر «الأوضة بدأت أو اتقفلت» بدل خطأ.
10. لوج السيرفر: `supabase functions logs friends` لازم فيه `push invite: sent=1 dead=0 failed=0`.
    لو فيه `push skipped: FCM_SERVICE_ACCOUNT_B64 not set` يبقى الـ secret مش متسجّل.

### الويب

1. `flutter build web` وبعدين افتح `build/web` على `localhost` (مثلاً
   `python -m http.server 8080` من جوه `build/web`). لازم `localhost` أو https: الـ service
   worker مابيشتغلش على IP عادي.
2. DevTools ← Application ← Service Workers: لازم `firebase-messaging-sw.js` يظهر
   **activated** (بعد أول طلب توكن، يعني بعد الخطوة 3).
3. ادخل أوضة ← «ادعي صحابك» ← المتصفح يطلب إذن الإشعارات ← «Allow».
   في SQL لازم يظهر سطر `web` في `push_tokens`.
4. صغّر التاب أو اقفله، وابعت دعوة من جهاز تاني: لازم يظهر إشعار النظام ويفضل ظاهر
   لحد ما تدوس عليه. الدوس بيفتح `/join/<CODE>`.
5. على الموقع الحقيقي نفس الكلام بعد `tool/build_web.ps1` والرفع على Vercel.

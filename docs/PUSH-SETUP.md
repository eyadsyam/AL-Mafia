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

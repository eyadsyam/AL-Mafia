> **الحالة (2026-09-28):** اتظبط فعلًا بـ **Gmail SMTP** بدل Resend (مفيش دومين): `smtp.gmail.com:465`، المرسل `eyadsyam124@gmail.com` باسم «Mafia Master»، والباسورد App Password من حساب جوجل (المالك لصقه بنفسه). القوالب التلاتة اتلصقت بعناوينها، وطول الكود 6. حد Gmail حوالي 500 إيميل في اليوم؛ لما يبقى فيه دومين، اتبع خطوات Resend تحت.

# إعداد إيميلات الدخول (SMTP عن طريق Resend)

**ليه؟** مشروع Supabase الحالي بيبعت الإيميلات من الخدمة المدمجة، ودي مش بتسمح بتعديل القوالب،
فالإيميل بيوصل فيه **لينك بس** من غير الكود اللي من 6 أرقام. التطبيق شغّال بالطريقتين دلوقتي
(الكود، أو زرار «فتحت اللينك من الإيميل»)، لكن **استرجاع الحساب على موبايل جديد محتاج الكود**.
بعد الخطوات دي الكود هيوصل في كل إيميل، والدخول بالكود هيشتغل في كل مكان.

> المفتاح السري (API key) **صاحب المشروع بس هو اللي يلصقه** في لوحة Supabase. ماتبعتهوش في شات،
> وماتحطهوش في الكود أو في الريبو أو في أي ملف.

---

## 1) حساب Resend

1. ادخل على `https://resend.com` واعمل حساب (Sign up) بإيميل المالك.
2. من القايمة: **Domains**.

### أ) للتجربة بسرعة (من غير دومين)
- استخدم المرسل الجاهز `onboarding@resend.dev`.
- **تحذير:** المرسل ده بيبعت **لإيميل صاحب حساب Resend بس**. ينفع تجرب بيه لوحة الإدارة، لكن
  مش هيوصل لإيميلات اللاعبين. للإطلاق لازم (ب).

### ب) للإطلاق (دومين موثّق)
1. **Domains → Add Domain**، واكتب دومين تملكه (مثلاً `mail.example.com`)، واختار أقرب منطقة.
2. Resend هيطلعلك سجلات DNS (SPF و DKIM، واختياري DMARC). ضيفها عند مزوّد الدومين زي ما هي بالظبط.
3. ارجع لـ Resend ودوس **Verify** واستنى لحد ما الحالة تبقى **Verified** (ممكن تاخد من دقايق لساعات).
4. المرسل هيبقى مثلاً `no-reply@mail.example.com`.

## 2) مفتاح الـ SMTP

1. في Resend: **API Keys → Create API Key**.
2. الاسم: `supabase-smtp`، والصلاحية: **Sending access** (ولو ينفع حدّدها على الدومين بتاعك).
3. انسخ المفتاح (بيبدأ بـ `re_`)، **هيظهر مرة واحدة بس**. ده هو الـ Password.

بيانات الـ SMTP:

| الخانة | القيمة |
|---|---|
| Host | `smtp.resend.com` |
| Port | `465` (SSL) — أو `587` (STARTTLS) لو 465 مش شغال |
| Username | `resend` |
| Password | مفتاح الـ API اللي نسخته |

## 3) لصق البيانات في Supabase (المالك)

1. افتح مشروع Supabase → **Authentication → Emails → SMTP Settings**.
2. فعّل **Enable custom SMTP**.
3. املأ:
   - **Sender email**: `onboarding@resend.dev` للتجربة، أو `no-reply@<دومينك>` للإطلاق.
   - **Sender name**: `Mafia Master`
   - **Host**: `smtp.resend.com`
   - **Port number**: `465`
   - **Username**: `resend`
   - **Password**: الصق مفتاح Resend هنا بنفسك.
   - **Minimum interval between emails**: سيبه على الافتراضي (60 ثانية).
4. **Save**.
5. (مستحسن) **Authentication → Rate Limits**: بعد تفعيل SMTP الخاص، ارفع «emails per hour»
   لرقم مناسب (مثلاً 100) علشان اللاعبين مايتمنعوش.

## 4) القوالب

من **Authentication → Emails → Templates**، لكل قالب: الصق **العنوان (Subject)**، وافتح الملف
من الريبو وانسخ محتواه **كله** في خانة **Body** (Source)، وبعدين **Save**.

| قالب Supabase | الملف | العنوان (Subject) |
|---|---|---|
| **Magic link** (في بعض النسخ اسمه **Magic link or OTP**) | `supabase/templates/magic_link.html` | `كود الدخول لمافيا ماستر · Mafia Master sign-in code` |
| **Change email address** | `supabase/templates/email_change.html` | `أكّد إيميلك في مافيا ماستر · Confirm your Mafia Master email` |
| **Confirm signup** | `supabase/templates/confirmation.html` | `أكّد إيميلك · Confirm your email — Mafia Master` |

ملاحظات:
- كل قالب فيه `{{ .Token }}` (الكود الكبير في النص) و`{{ .ConfirmationURL }}` (زرار اللينك الاحتياطي).
  **ماتغيرش الأسماء دي**، Supabase بيبدّلها وقت الإرسال.
- قالب تغيير الإيميل بيستخدم كمان `{{ .NewEmail }}`.
- اتأكد إن طول الكود 6: **Authentication → Providers → Email → Email OTP Length = 6**
  (التطبيق مستني 6 أرقام).

## 5) لينك لوحة الإدارة (مرة واحدة)

علشان لينك إيميل الإدارة يرجّعك على صفحة الإدارة وانت داخل:
**Authentication → URL Configuration → Redirect URLs → Add URL**:
`https://almafia.vercel.app/admin`
(متضاف فعلًا من 2026-09-27 عن طريق `https://almafia.vercel.app/**` — مفيش حاجة تعملها. الـ Site URL يفضل `https://almafia.vercel.app` زي ما هو.)

## 6) التجربة

1. من صفحة `https://almafia.vercel.app/admin`: اكتب إيميل الإدارة واطلب الكود.
2. الإيميل لازم يوصل من «Mafia Master»، بخلفية داكنة وكود كبير من 6 أرقام وتحته زرار اللينك.
3. اكتب الكود → المفروض يظهر «داخل باسم …» وتظهر الطلبات.
4. على الموبايل: المتجر → حماية الحساب → «احمِ حسابي بإيميل» → الكود يوصل → اكتبه → «حسابك محمي بـ …».
5. على موبايل تاني: «عندي حساب محمي قبل كده» → الكود → ترجع لنفس المحفظة.

لو الإيميل ما وصلش: بص في السبام، وبعدين في Resend → **Emails / Logs** هتلاقي سبب الرفض
(غالباً دومين مش Verified، أو مرسل `onboarding@resend.dev` بيبعت لإيميل غير إيميل صاحب الحساب).

**بعد الحفظ، طريقة الكود في التطبيق بتشتغل في كل مكان**: الربط، والاسترجاع على جهاز جديد، ولوحة
الإدارة. زرار «فتحت اللينك من الإيميل» بيفضل موجود كاحتياطي.

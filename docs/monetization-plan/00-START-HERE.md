# خطة الربح والنمو — سيد المافيا

Prepared: 2026-10-07. Baseline commit: `5bc7ab0`. Scope: planning, read-only audit, local dependency preparation. No application changes, migrations, account changes, ad-unit creation or deployment are authorized by this planning task.

## القرار

نبني على النظام الموجود، ونفصل قياس كل موضع إعلان، ونحسن العودة للعب مع الأصدقاء وجودة أول مباراة. الخطة تضم **24 وحدة AdMob أندرويد مخططة** بأسماء ومواضع محددة، مع تفعيل تدريجي. العدد ليس عدد الإعلانات التي يراها اللاعب ولا وعدًا بعدد مرات الظهور. إنشاء وحدات إضافية وحده لا يضاعف الدخل.

هدف التشغيل هو زيادة **صافي مساهمة اللاعب خلال 30 يومًا** مع الحفاظ على إكمال المباريات والعودة في اليوم التالي والأسبوع التالي. هدف 20× سيناريو يُقاس بعد توفر خط أساس، وليس نتيجة مضمونة. جلسة ست ساعات تصبح اختبار تحمل اختياري، لا شرطًا للمكافآت ولا هدفًا مفروضًا على كل لاعب.

الإعلانات مطلوبة في **تطبيق أندرويد نفسه** وكذلك **ويب Android وiPhone والكمبيوتر**. وحدات AdMob تخص التطبيق؛ الويب له مسار AdSense/H5 وموافقات منفصلة. تعطل موافقة الويب لا يمنع تفعيل التطبيق بعد استيفاء شروطه. إنشاء 24 وحدة جديدة مع الاحتفاظ بالخمس القديمة للتوافق يجعل العدد الانتقالي 29، ولا يعني تشغيلها جميعًا على اللاعب.

## اقرأ بالترتيب

1. [Evidence and blockers](01-AUDIT.md): what was actually observed, what remains unknown.
2. [Product decisions](02-PRODUCT-AND-GROWTH.md): acquisition, activation, retention, monetization.
3. [Ad inventory and pacing](03-AD-INVENTORY.md) + [machine-readable inventory](ad-units.csv).
4. [Implementation contract](04-TECHNICAL-CONTRACT.md): APIs, state, schema, compatibility, security.
5. [Account runbook](05-ACCOUNTS-AND-POLICY.md): AdMob/AdSense inspection and remediation branches.
6. [Responsive web/performance](06-WEB-AND-PERFORMANCE.md).
7. [Measurement and rollout](07-MEASUREMENT-AND-ROLLOUT.md) + [forecast scenarios](revenue-scenarios.csv).
8. [Ordered implementation and gates](08-EXECUTION-AND-TESTS.md).
9. Give the next model [09-IMPLEMENTER-PROMPT.md](09-IMPLEMENTER-PROMPT.md).

`proposed-config.json` is a planning fixture, NOT deployable production configuration. Every new placement is off; IDs for new units remain absent until created and observed. `account-evidence.json` contains the actual account observations; `account-evidence.template.json` specifies remaining follow-up evidence. Do not silently substitute assumptions.

## حدود التسليم

Chrome initially failed, then recovered during this audit. Both requested account emails were verified from the visible account buttons. AdMob has **five** existing units, account approval, an Android app still requiring review with no store link, and no current Policy Center issues. Its last-seven-days dashboard shows 291 requests, 32 impressions, 46.39% match rate and EGP 0.92 estimated revenue. AdSense publisher `pub-5174049351369803` is **not approved**, with only the generic program-policy compliance reason visible; no specific site violation is exposed. See the account evidence and runbook. No checkbox, resubmission, unit creation or account setting was changed.

The repository was mapped across application, transport, economy, web, tests and operations, with targeted source reads; this is not a claim that all 330 Dart files were read line by line. Historical progress entries are not proof of current production state.

Follow repository phase protocol: one requested phase, append evidence to `docs/PROGRESS.md`, report its gate and stop. Do not execute this entire roadmap from a request to execute one phase.

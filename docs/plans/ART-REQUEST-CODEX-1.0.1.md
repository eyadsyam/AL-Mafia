# طلب صور لـ Codex — تحديث 1.0.1 ("حياة المجلس" + المتجر + الإعلانات + المتعة)

> المطلوب من Codex: يعمل **كل** الصور اللي في الملف ده، ويحط كل صورة بنفس الاسم وفي نفس المسار بالظبط.
> المشروع: `D:\Flutter Data\Projects\AL Mafia\.claude\worktrees\epic-roentgen-094f21` (branch `claude/epic-roentgen-094f21`). After adding each file, list it in `CouncilRaster.delivered` in `lib/ui/economy/council_art.dart`, then run `flutter test test/widget/council_raster_test.dart`.
> الكود بيقرا المسارات دي. لحد ما الصورة توصل، فيه رسم بديل بالكود، فأي صورة ناقصة مش هتكسر حاجة، لكن كل صورة بتوصل بتعلّي المستوى.
> Codex: generate **every** asset below at the exact path/name. The app reads these paths and falls back to a code-drawn placeholder until each file exists.

## 0. قواعد الهوية (لكل صورة)

- **الستايل:** Mafia Master بطابع نوار ناضج. الألوان فحمي وعاجي وذهبي عتيق، مع لمسات عنابي هادية. نقش خفيف وتشطيب يدوي، زي `assets/images/economy/mafia_coin_256.webp` و`assets/images/store_v2/*`، ودول المرجع الأساسي.
- **ممنوع:**
  - نيون، أو جو كازينو، أو ماكينات قمار، أو دم صريح.
  - أي نص أو حروف أو أرقام جوه الصورة. النص بيتكتب حي في التطبيق، عربي وإنجليزي.
  - أي شعار لجهة تانية: إنستا باي، فودافون، جوجل.
  - أي صورة بتكشف دور لاعب معيّن.
- **الصيغة:** WebP بخلفية شفافة حقيقية (alpha)، إلا اللي مكتوب قدامه "خلفية". الجسم في النص وحواليه مساحة شفافة كفاية، ولازم يتقري بوضوح على أصغر مقاس عرض مكتوب قدامه.
- **الأحجام القصوى:** الأيقونة 40KB، والغلاف 120KB، والخلفية 250KB. النسخ الأصلية الكبيرة تتحفظ في `raw_assets/update101b/` بنفس الاسم وبصيغة `.png`.
- **التناسق:** كل مجموعة (الرتب، المهام، الجوائز، الريأكشنز) لازم تبان عيلة واحدة: نفس اتجاه الإضاءة (من فوق شمال)، ونفس سُمك الحواف، ونفس الألوان.
- **التسليم:**
  - الشيتات الأصلية نفسها بتكفي كمراجعة، فمش محتاج contact sheet منفصل.
  - واملا جدول التسليم اللي في آخر الملف.

---

## ⚡ توفير الكريدت: كل عيلة في صورة واحدة (اقرا ده الأول)

**متعملش كل أيقونة لوحدها.** كل مجموعة أيقونات صغيرة تتعمل في **صورة واحدة (sheet)**، وبعدين السكريبت بيقطّعها للملفات المطلوبة بالأسامي والمقاسات والأحجام بالظبط. كده بدل ~85 صورة هتعمل **25 بس** (8 شيتات + 17 صورة لوحدها).
**Codex: generate each family below as ONE image (uniform grid, one object per cell), then run the slicer. Do not generate these icons one by one.**

**قواعد الشيت:**
- شبكة منتظمة بالظبط (نفس عدد الأعمدة والصفوف اللي تحت)، والخانات كلها نفس المقاس، والترتيب من الشمال لليمين ومن فوق لتحت (الترتيب اللي في `--list`).
- عنصر واحد في نص كل خانة، وحواليه مسافة فاضية كبيرة (حوالي 15% من الخانة). ممنوع أي عنصر يلمس أو يعدّي على خانة جنبه، وممنوع خطوط شبكة أو إطارات أو ظل واقع على الأرضية.
- الخلفية **شفافة** لو الأداة بتدعم، ولو لأ: **أخضر سادة #00FF00** من غير تدرّج ولا ظل. وممنوع أي لون أخضر جوه الرسومات نفسها.
- كل العيلة في نفس البرومبت، بنفس الإضاءة والحواف والخامة. ده كمان بيحل موضوع التناسق لوحده.
- أكبر مقاس تقدر عليه الأداة (على الأقل 1536 عرض). شيت أغلفة المتجر D محتاج كل خانة 768 أو أكتر (يعني 2304×1536)، ولو الأداة ماتقدرش، اعمله على صورتين: 2×2 + 2×1.
- لو السكريبت طلّع `EMPTY CELL` أو العنصر اتقطع، اعمل الشيت ده تاني بس.

**الأمر:**
```
python tool/slice_art_sheet.py --list
python tool/slice_art_sheet.py A_ranks raw_assets/update101b/_sheet_A_ranks.png
```
احفظ كل شيت أصلي في `raw_assets/update101b/_sheet_<ID>.png`. السكريبت بيحفظ كل عنصر كبير في `raw_assets/update101b/<name>.png`، والـ WebP بالمقاس والحجم المطلوب في مساره على طول.

| الشيت | الشبكة | اللي فيه بالترتيب |
|---|---|---|
| `A_ranks` | 5×2 | `rank_tier_01` … `rank_tier_10` (نفس الختم، والفخامة بتزيد من الشمال لليمين) |
| `B_contracts` | 3×3 | finish, town, mafia, win, host, reunion, weekly, bonus_all3, claimed_check |
| `C_council_small` | 3×3 | podium_1, podium_2, podium_3, invite_reward_badge, council_hub_tab, badge_founder, stat_matches, stat_wins, stat_streak |
| `D_store_covers` | 3×2 | starter_bundle_cover, quiet_pass_cover, coins_pack_small, coins_pack_medium, coins_pack_large, (خانة فاضية) |
| `E_store_small` | 3×2 | invite_illustration, web_pay_transfer, web_pay_pending, web_pay_approved, ad_free_seal, double_coins_badge |
| `F_daily` | 3×3 | daily_coffer_open, wheel_pointer, wheel_hub, streak_day_empty, streak_day_done, streak_day7, ad_reward_film, extra_spin_token, (فاضية) |
| `G_awards` | 4×2 | mvp, sharp_eye, survivor, silver_tongue, lifesaver, perfect_crime, first_blood, (فاضية) |
| `H_reactions` | 4×2 | laugh, shock, suspicious, applause, rose, skull, coffee, crown |

**صور لوحدها (17)**، لأن مقاسها كبير أو شكلها عريض: `rank_levelup_rays`، `leaderboard_header`، `frame_council_seal` (لازم يطابق مكان `frame_gilded` بالظبط)، `vault_hero_v3`، `best_value_ribbon`، `sparkle_sheet` (هو أصلًا شيت)، `wheel_rim`، `launch_backdrop`، `launch_veil`، `welcome_back_card`، `awards_banner`، `banner_frame`، `profile_banner_default`، وصور جوجل بلاي الأربعة. **وفّر أكتر:** `leaderboard_header` و`profile_banner_default` نفس المقاس 1080×360، فاعملهم صورة واحدة 1080×720 فوق بعض واقسمها نصين.

الوصف والمقاس والمسار لكل ملف لسه في الأقسام اللي تحت. الشيت بيغيّر **طريقة الإنتاج** بس، مش المواصفات.

---

## 1. رتب المجلس (10 شارات): `assets/images/council/`

كل 5 مستويات من المستوى 1 للمستوى 50 ليهم شارة (tier). الشارة بتظهر في الأماكن دي:
- كرسي اللاعب في الروم، واللوبي
- شاشة النتيجة، والبروفايل
- لوحة الصدارة، واحتفال الترقية

**المقاس 128×128 وشفافة، ولازم تتقري على 24dp.** كل الشارات ليها نفس شكل الختم الأساسي، والتفاصيل والخامة بتزيد مع كل رتبة:

| الملف | الرتبة | الوصف |
|---|---|---|
| `rank_tier_01.webp` | مبتدئ / Newcomer | ختم شمع بسيط غامق، بحافة رفيعة ومن غير زخرفة |
| `rank_tier_02.webp` | مراقب / Watcher | نفس الختم، وعليه عين صغيرة محفورة |
| `rank_tier_03.webp` | مخبر / Informant | حافة نحاس، وظرف مختوم صغير |
| `rank_tier_04.webp` | محقق / Investigator | نحاس، وعدسة مكبرة منقوشة |
| `rank_tier_05.webp` | مستشار / Counselor | فضة، وريشة وحبر |
| `rank_tier_06.webp` | قاضي / Magistrate | فضة، وميزان صغير |
| `rank_tier_07.webp` | ظل / Shadow | فضة غامقة، وقناع نص وش |
| `rank_tier_08.webp` | نبيل المجلس / Council Noble | ذهب عتيق، وشريطة عنابي |
| `rank_tier_09.webp` | يد المجلس / Council Hand | ذهب، وخاتم ختم ويد |
| `rank_tier_10.webp` | عرّاب / Godfather | **الشارة الوحيدة اللي كلها ذهب:** قناع التنكّر بتاع البراند، ووردة عنابي، وإطار ملوكي بس هادي |

- `rank_levelup_rays.webp`: مقاسها 512×512 وشفافة. أشعة ذهب ناعمة وشرر خفيف بيبانوا ورا الشارة في احتفال الترقية.

## 2. المهام اليومية والأسبوعية: `assets/images/council/`

المقاس 96×96 وشفافة، ولازم تتقري على 32dp. ممنوع تستخدم رسومات كروت الأدوار.

| الملف | المهمة | الفكرة |
|---|---|---|
| `contract_finish.webp` | خلّص ماتش أو أكتر | ساعة رملية خلصت وجنبها ختم |
| `contract_town.webp` | خلّص ماتش في فريق البلد | فانوس شارع قديم |
| `contract_mafia.webp` | خلّص ماتش في فريق المافيا | قبعة فيدورا فوق وردة |
| `contract_win.webp` | اكسب ماتش | كأس أو إكليل عتيق |
| `contract_host.webp` | استضيف ماتش يكمل للآخر | مفتاح باب كبير وشمعدان |
| `contract_reunion.webp` | العب تاني مع حد لعبت معاه قبل كده | كاسين بيخبطوا في بعض |
| `contract_weekly.webp` | المهمة الأسبوعية الكبيرة | لفافة عقد بشريط عنابي وختم ذهب، أكبر وأغنى من الباقي |
| `contract_bonus_all3.webp` | بونص لما تخلّص التلات مهام | 3 أختام شمع جنب بعض |
| `contract_claimed_check.webp` | المهمة اتستلمت | ختم شمع مضغوط، عليه علامة صح محفورة |

## 3. لوحة الصدارة والدعوات: `assets/images/council/`

| الملف | المقاس | الوصف |
|---|---|---|
| `leaderboard_header.webp` | 1080×360 (خلفية) | قاعة المجلس بالليل من بعيد: ترابيزة طويلة وشمع، وفي النص مساحة فاضية للعنوان |
| `leaderboard_podium_1.webp` و `_2` و `_3` | 128×128 شفافة | أوسمة المراكز الأول والتاني والتالت: ذهب وفضة ونحاس، وكلهم من نفس العيلة |
| `invite_illustration.webp` | 256×256 شفافة | ظرف دعوة مختوم بالشمع، طالع منه كارت أسود بإطار ذهبي |
| `invite_reward_badge.webp` | 96×96 شفافة | عملتين مجلس فوق بعض وشريطة، ودي مكافأة الطرفين |
| `council_hub_tab.webp` | 96×96 شفافة | أيقونة تبويب "المجلس" في الخزنة: ختم المجلس، ومطرقة قاضي صغيرة |

## 4. المتجر (الخزنة): `assets/images/store_v3/`

| الملف | المقاس | الوصف |
|---|---|---|
| `frame_council_seal.webp` | نفس مقاس وموضع `store_v2/frame_gilded.webp` بالظبط | إطار أفاتار حصري بييجي مع باقة البداية: ذهب عتيق، وختم المجلس من تحت، ولمسة عنابي. لازم يبان أغلى من الإطار الذهبي الموجود |
| `starter_bundle_cover.webp` | نفس مقاس أغلفة `store_v2/bundle_*.webp` | غلاف باقة البداية: كومة عملات، والإطار الجديد، وشريطة بتقول إنها "مرة واحدة"، من غير كتابة |
| `quiet_pass_cover.webp` | نفس مقاس أغلفة store_v2 | غلاف إزالة الإعلانات: الميدالية الموجودة `economy_v2/quiet_pass.webp` على مخمل أسود، وضي شمعة هادي |
| `coins_pack_small.webp` و `_medium` و `_large` | نفس مقاس `store_v2/coins_500.webp` | كيس جلد صغير، وصندوق خشب، وخزنة حديد مفتوحة. من غير أرقام |
| `vault_hero_v3.webp` | 1080×540 (خلفية) | الصورة الرئيسية للخزنة: غرفة خزنة قديمة، وباب دائري نص مفتوح طالع منه ضي ذهبي، وأرفف عليها عملات. سيب مساحة فاضية للعنوان |
| `best_value_ribbon.webp` | 160×64 شفافة | شريطة عنابي بحواف ذهب لـ"أفضل قيمة". الصورة من غير نص، والنص بيتكتب فوقها في التطبيق |
| `sparkle_sheet.webp` | 512×128 شفافة | 4 لقطات جنب بعض لبريق صغير، بيظهر على المنتج المختار ولحظة الشرا |
| `web_pay_transfer.webp` | 256×256 شفافة | أيقونة التحويل على الويب: موبايل عليه سهم تحويل وعملة، من غير شعارات |
| `web_pay_pending.webp` | 128×128 شفافة | ساعة جيب مفتوحة، ومعناها إن الطلب لسه بيتراجع |
| `web_pay_approved.webp` | 128×128 شفافة | ختم شمع ذهبي عليه علامة صح، ومعناه إن الرصيد اتضاف |

## 5. المكافآت اليومية والعجلة: `assets/images/economy_v2/`

| الملف | المقاس | الوصف |
|---|---|---|
| `daily_coffer_open.webp` | 384×384 شفافة | نفس صندوق المكافأة اليومية وهو مفتوح، طالع منه ضي وعملات |
| `wheel_rim.webp` | 768×768 شفافة | الحلقة الخارجية للعجلة بس: نحاس وذهب محفور وعليها 5 مسامير. القطاعات والأرقام بتترسم في الكود، فسيب النص شفاف |
| `wheel_pointer.webp` | 128×160 شفافة | مؤشر العجلة: خنجر أو ريشة ذهب بتشاور لتحت |
| `wheel_hub.webp` | 192×192 شفافة | الدائرة اللي في نص العجلة: قناع البراند على ختم |
| `streak_day_empty.webp` و `streak_day_done.webp` و `streak_day7.webp` | 96×96 شفافة | خانات كارت الأسبوع: شمعة مطفية، وشمعة والعة، وشمعدان بتلات شمعات لليوم السابع |
| `double_coins_badge.webp` | 128×128 شفافة | شارة مضاعفة العملات: عملتين فوق بعض وسهم لفوق، من غير "x2" |
| `ad_reward_film.webp` | 96×96 شفافة | أيقونة "اتفرج على إعلان واكسب": بكرة فيلم قديمة وعملة |
| `extra_spin_token.webp` | 96×96 شفافة | أيقونة لفة زيادة: عملة نحاس عليها نقش عجلة |

## 6. شاشة الافتتاح وإعلان فتح التطبيق: `assets/images/launch/`

| الملف | المقاس | الوصف |
|---|---|---|
| `launch_backdrop.webp` | 1080×1920 (خلفية) | خلفية شاشة اللوجو: ضباب ليل وضي شمعة، ماشية مع `splash_mask.webp`. إعلان فتح التطبيق بيظهر بعدها على طول، فلازم يبان إنه هدوء قبل العرض |
| `launch_veil.webp` | 1080×1920 شفافة | ستارة مسرح عنابي بتقفل قبل إعلان الافتتاح وتفتح بعده، والحركة بتتعمل في الكود |
| `welcome_back_card.webp` | 720×360 شفافة | كارت "وحشتنا": ظرف بيتفتح وجواه شمعة، بيظهر مع المكافأة اليومية لما اللاعب يرجع |

## 7. جوائز آخر الماتش: `assets/images/awards/`

الجوايز دي بتظهر في شاشة النتيجة بس، بعد ما الماتش يخلص والأدوار تتكشف. المقاس 128×128 وشفافة، وكلها من عيلة واحدة: ميداليات مدورة، كل واحدة بشريطة لونها مختلف.

| الملف | الجائزة | الفكرة |
|---|---|---|
| `award_mvp.webp` | نجم الماتش | ميدالية ذهب بإكليل غار |
| `award_sharp_eye.webp` | العين الحادة: أكتر واحد صوّت صح | عين جوه عدسة |
| `award_survivor.webp` | الناجي | شمعة لسه والعة وسط شمع مطفي |
| `award_silver_tongue.webp` | اللسان الذهبي: أقنع الناس | ريشة وشفايف منقوشة |
| `award_lifesaver.webp` | المنقذ: الدكتور أنقذ حد | ختم عليه صليب طبي قديم |
| `award_perfect_crime.webp` | الجريمة الكاملة: المافيا كسبت من غير ما حد يكشفها | قفاز أسود ووردة |
| `award_first_blood.webp` | أول واحد كشف حد صح | سهم على مخطوطة |
| `awards_banner.webp` | 1080×300 شفافة | شريط عنابي طويل بتترص عليه الجوايز في شاشة النتيجة |

## 8. الريأكشنز: `assets/images/reactions/`

الريأكشنز بتظهر في اللوبي وشاشة النتيجة بس، ومش أثناء الماتش، عشان ماتتحولش لوسيلة تلميح. المقاس 96×96 وشفافة، ولازم تتقري على 28dp، وستايلها أختام شمع ملونة:

| الملف | الشكل |
|---|---|
| `react_laugh.webp` | قناع بيضحك |
| `react_shock.webp` | قناع مصدوم |
| `react_suspicious.webp` | عين بتبص على جنب |
| `react_applause.webp` | إيدين بتسقّف |
| `react_rose.webp` | وردة |
| `react_skull.webp` | جمجمة كرتونية لطيفة |
| `react_coffee.webp` | فنجان قهوة |
| `react_crown.webp` | تاج |

## 9. البانر في اللوبي: `assets/images/ads/`

| الملف | المقاس | الوصف |
|---|---|---|
| `banner_frame.webp` | 1080×200 شفافة | إطار رفيع فحمي وذهبي بيتحط حوالين البانر في اللوبي وشاشات الانتظار، عشان الإعلان يبان منفصل عن أزرار اللعبة، وده من شروط جوجل. النص اللي جوه الإطار فاضي |
| `ad_free_seal.webp` | 128×128 شفافة | ختم "بدون مقاطعة" بيظهر مكان البانر عند اللي شاري إزالة الإعلانات |

## 10. البروفايل: `assets/images/profile/`

| الملف | المقاس | الوصف |
|---|---|---|
| `profile_banner_default.webp` | 1080×360 (خلفية) | خلفية كارت البروفايل: ورق حائط دمشقي غامق وضي شمعة |
| `stat_matches.webp` و `stat_wins.webp` و `stat_streak.webp` | 64×64 شفافة | أيقونات الإحصائيات: كروت فوق بعض، وإكليل، وشعلة شمعة |
| `badge_founder.webp` | 128×128 شفافة | شارة "مؤسس" لأوائل لاعبين 1.0.1: ختم فضي، من غير أرقام |

## 11. متجر جوجل بلاي للتحديث: `store/play-1.0.1/`

| الملف | المقاس | الوصف |
|---|---|---|
| `feature_graphic_1.0.1.png` | 1024×500 (من غير شفافية) | بانر المتجر: الخزنة مفتوحة، والعجلة، وشارة العرّاب. سيب الشمال فاضي للعنوان، والصورة من غير نص |
| `promo_council_life.png` | 1080×1920 | خلفية سكرينشوت ترويجي: ضباب وشمع، وسيب مكان لصورة الشاشة |
| `promo_daily_wheel.png` | 1080×1920 | نفس الفكرة، للعجلة والمكافآت اليومية |
| `promo_rank.png` | 1080×1920 | نفس الفكرة، للرتب ولوحة الصدارة |

---

## جدول التسليم (يملاه Codex)

| المسار | اتعمل؟ | المقاس الفعلي | الحجم (بايت) | ملاحظات |
|---|---|---|---:|---|
| `assets/images/ads/ad_free_seal.webp` | نعم | 128×128 | 7256 | WebP، شفافة |
| `assets/images/ads/banner_frame.webp` | نعم | 1080×200 | 13836 | WebP، شفافة |
| `assets/images/awards/award_first_blood.webp` | نعم | 128×128 | 6546 | WebP، شفافة |
| `assets/images/awards/award_lifesaver.webp` | نعم | 128×128 | 6524 | WebP، شفافة |
| `assets/images/awards/award_mvp.webp` | نعم | 128×128 | 6782 | WebP، شفافة |
| `assets/images/awards/award_perfect_crime.webp` | نعم | 128×128 | 6130 | WebP، شفافة |
| `assets/images/awards/award_sharp_eye.webp` | نعم | 128×128 | 6470 | WebP، شفافة |
| `assets/images/awards/award_silver_tongue.webp` | نعم | 128×128 | 6646 | WebP، شفافة |
| `assets/images/awards/award_survivor.webp` | نعم | 128×128 | 6208 | WebP، شفافة |
| `assets/images/awards/awards_banner.webp` | نعم | 1080×300 | 38710 | WebP، شفافة |
| `assets/images/council/contract_bonus_all3.webp` | نعم | 96×96 | 5220 | WebP، شفافة |
| `assets/images/council/contract_claimed_check.webp` | نعم | 96×96 | 4572 | WebP، شفافة |
| `assets/images/council/contract_finish.webp` | نعم | 96×96 | 5096 | WebP، شفافة |
| `assets/images/council/contract_host.webp` | نعم | 96×96 | 5820 | WebP، شفافة |
| `assets/images/council/contract_mafia.webp` | نعم | 96×96 | 3440 | WebP، شفافة |
| `assets/images/council/contract_reunion.webp` | نعم | 96×96 | 3654 | WebP، شفافة |
| `assets/images/council/contract_town.webp` | نعم | 96×96 | 2910 | WebP، شفافة |
| `assets/images/council/contract_weekly.webp` | نعم | 96×96 | 3946 | WebP، شفافة |
| `assets/images/council/contract_win.webp` | نعم | 96×96 | 7100 | WebP، شفافة |
| `assets/images/council/council_hub_tab.webp` | نعم | 96×96 | 4364 | WebP، شفافة |
| `assets/images/council/invite_illustration.webp` | نعم | 256×256 | 18422 | WebP، شفافة |
| `assets/images/council/invite_reward_badge.webp` | نعم | 96×96 | 5406 | WebP، شفافة |
| `assets/images/council/leaderboard_header.webp` | نعم | 1080×360 | 50548 | WebP، خلفية معتمة |
| `assets/images/council/leaderboard_podium_1.webp` | نعم | 128×128 | 7394 | WebP، شفافة |
| `assets/images/council/leaderboard_podium_2.webp` | نعم | 128×128 | 6836 | WebP، شفافة |
| `assets/images/council/leaderboard_podium_3.webp` | نعم | 128×128 | 7238 | WebP، شفافة |
| `assets/images/council/rank_levelup_rays.webp` | نعم | 512×512 | 38764 | WebP، شفافة |
| `assets/images/council/rank_tier_01.webp` | نعم | 128×128 | 6044 | WebP، شفافة |
| `assets/images/council/rank_tier_02.webp` | نعم | 128×128 | 6718 | WebP، شفافة |
| `assets/images/council/rank_tier_03.webp` | نعم | 128×128 | 7338 | WebP، شفافة |
| `assets/images/council/rank_tier_04.webp` | نعم | 128×128 | 7422 | WebP، شفافة |
| `assets/images/council/rank_tier_05.webp` | نعم | 128×128 | 7426 | WebP، شفافة |
| `assets/images/council/rank_tier_06.webp` | نعم | 128×128 | 7290 | WebP، شفافة |
| `assets/images/council/rank_tier_07.webp` | نعم | 128×128 | 6852 | WebP، شفافة |
| `assets/images/council/rank_tier_08.webp` | نعم | 128×128 | 7826 | WebP، شفافة |
| `assets/images/council/rank_tier_09.webp` | نعم | 128×128 | 8218 | WebP، شفافة |
| `assets/images/council/rank_tier_10.webp` | نعم | 128×128 | 9274 | WebP، شفافة |
| `assets/images/economy_v2/ad_reward_film.webp` | نعم | 96×96 | 5206 | WebP، شفافة |
| `assets/images/economy_v2/daily_coffer_open.webp` | نعم | 384×384 | 38926 | WebP، شفافة |
| `assets/images/economy_v2/double_coins_badge.webp` | نعم | 128×128 | 6454 | WebP، شفافة |
| `assets/images/economy_v2/extra_spin_token.webp` | نعم | 96×96 | 5396 | WebP، شفافة |
| `assets/images/economy_v2/streak_day7.webp` | نعم | 96×96 | 4088 | WebP، شفافة |
| `assets/images/economy_v2/streak_day_done.webp` | نعم | 96×96 | 2368 | WebP، شفافة |
| `assets/images/economy_v2/streak_day_empty.webp` | نعم | 96×96 | 2448 | WebP، شفافة |
| `assets/images/economy_v2/wheel_hub.webp` | نعم | 192×192 | 11884 | WebP، شفافة |
| `assets/images/economy_v2/wheel_pointer.webp` | نعم | 128×160 | 3850 | WebP، شفافة |
| `assets/images/economy_v2/wheel_rim.webp` | نعم | 768×768 | 36296 | WebP، شفافة |
| `assets/images/launch/launch_backdrop.webp` | نعم | 1080×1920 | 122606 | WebP، خلفية معتمة |
| `assets/images/launch/launch_veil.webp` | نعم | 1080×1920 | 172566 | WebP، شفافة |
| `assets/images/launch/welcome_back_card.webp` | نعم | 720×360 | 47438 | WebP، كارت/إطار شفاف |
| `assets/images/profile/badge_founder.webp` | نعم | 128×128 | 8002 | WebP، شفافة |
| `assets/images/profile/profile_banner_default.webp` | نعم | 1080×360 | 57942 | WebP، خلفية معتمة |
| `assets/images/profile/stat_matches.webp` | نعم | 64×64 | 2254 | WebP، شفافة |
| `assets/images/profile/stat_streak.webp` | نعم | 64×64 | 1940 | WebP، شفافة |
| `assets/images/profile/stat_wins.webp` | نعم | 64×64 | 3316 | WebP، شفافة |
| `assets/images/reactions/react_applause.webp` | نعم | 96×96 | 5016 | WebP، شفافة |
| `assets/images/reactions/react_coffee.webp` | نعم | 96×96 | 5012 | WebP، شفافة |
| `assets/images/reactions/react_crown.webp` | نعم | 96×96 | 5222 | WebP، شفافة |
| `assets/images/reactions/react_laugh.webp` | نعم | 96×96 | 5272 | WebP، شفافة |
| `assets/images/reactions/react_rose.webp` | نعم | 96×96 | 5384 | WebP، شفافة |
| `assets/images/reactions/react_shock.webp` | نعم | 96×96 | 5240 | WebP، شفافة |
| `assets/images/reactions/react_skull.webp` | نعم | 96×96 | 5006 | WebP، شفافة |
| `assets/images/reactions/react_suspicious.webp` | نعم | 96×96 | 4882 | WebP، شفافة |
| `assets/images/store_v3/best_value_ribbon.webp` | نعم | 160×64 | 3280 | WebP، شفافة |
| `assets/images/store_v3/coins_pack_large.webp` | نعم | 768×768 | 110612 | WebP، شفافة |
| `assets/images/store_v3/coins_pack_medium.webp` | نعم | 768×768 | 112956 | WebP، شفافة |
| `assets/images/store_v3/coins_pack_small.webp` | نعم | 768×768 | 112042 | WebP، شفافة |
| `assets/images/store_v3/frame_council_seal.webp` | نعم | 768×768 | 109466 | WebP، كارت/إطار شفاف |
| `assets/images/store_v3/quiet_pass_cover.webp` | نعم | 768×768 | 116248 | WebP، شفافة |
| `assets/images/store_v3/sparkle_sheet.webp` | نعم | 512×128 | 13390 | WebP، شفافة |
| `assets/images/store_v3/starter_bundle_cover.webp` | نعم | 768×768 | 117746 | WebP، شفافة |
| `assets/images/store_v3/vault_hero_v3.webp` | نعم | 1080×540 | 146542 | WebP، خلفية معتمة |
| `assets/images/store_v3/web_pay_approved.webp` | نعم | 128×128 | 7950 | WebP، شفافة |
| `assets/images/store_v3/web_pay_pending.webp` | نعم | 128×128 | 8692 | WebP، شفافة |
| `assets/images/store_v3/web_pay_transfer.webp` | نعم | 256×256 | 18068 | WebP، شفافة |
| `store/play-1.0.1/feature_graphic_1.0.1.png` | نعم | 1024×500 | 175341 | PNG، خلفية معتمة |
| `store/play-1.0.1/promo_council_life.png` | نعم | 1080×1920 | 218343 | PNG، خلفية معتمة ومساحة للصورة |
| `store/play-1.0.1/promo_daily_wheel.png` | نعم | 1080×1920 | 245258 | PNG، خلفية معتمة ومساحة للصورة |
| `store/play-1.0.1/promo_rank.png` | نعم | 1080×1920 | 239541 | PNG، خلفية معتمة ومساحة للصورة |

## حالة الربط في التطبيق

**ظاهرة في الشاشات الحالية:** `rank_tier_*`, `contract_*`, `leaderboard_podium_*`, `leaderboard_header`, `invite_illustration`, `rank_levelup_rays`, `frame_council_seal`, `starter_bundle_cover`, `quiet_pass_cover`, `coins_pack_*`, `vault_hero_v3`, `award_*`, `react_*`, `badge_founder`, `welcome_back_card`.

**مولّدة ومضمّنة، وتنتظر ربط الواجهة:** `invite_reward_badge`, `council_hub_tab`, `stat_*`, `daily_coffer_open`, `wheel_*`, `streak_day_*`, `double_coins_badge`, `ad_reward_film`, `extra_spin_token`, `web_pay_*`, `ad_free_seal`, `best_value_ribbon`, `sparkle_sheet`, `launch_backdrop`, `launch_veil`, `awards_banner`, `banner_frame`, `profile_banner_default`.

**ملفات متجر Play:** `feature_graphic_1.0.1.png` و`promo_*.png` جاهزة كخلفيات؛ لقطات التطبيق الحقيقية والنصوص تُضاف عند تجهيز صفحة المتجر. لا تغييرات على الشاشات ضمن تسليم الصور.

## ملاحظات للمطوّر (Claude)

- كل المسارات اللي فوق تتضاف في `pubspec.yaml`.
- لو أي ملف ناقص، التطبيق يرجع لرسم بالكود. ده بيحصل من خلال helper واحد اسمه `CouncilArt.image(path, fallback: …)`، بيتأكد من وجود الملف في `AssetManifest`.
- الحركة كلها بـ Flutter بس (opacity وscale وshimmer)، من غير فيديو أو Lottie جديد.
- احترم إعدادات تقليل الحركة والصوت والاهتزاز.

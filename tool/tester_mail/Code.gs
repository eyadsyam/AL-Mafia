/** Google Form bridge: register testers through tester_signup; Supabase sends welcome email. */

var GROUP_URL = 'https://groups.google.com/g/mafia-master-testers';
var OPT_IN_URL = 'https://play.google.com/apps/testing/com.mafiamaster.mafia_master';
var JOIN_URL = 'https://saidalmafia.com/beta/join/';
var EMAIL = /^[^\s@<>"',;]+@[^\s@<>"',;]+\.[a-z]{2,}$/i;

/* Google Form submissions register through tester_signup; Supabase sends mail. */
var FORM_TITLE = 'سيد المافيا | Mafia Master';
var FORM_NAME = 'اسمك';
var FORM_EMAIL = 'إيميل حساب جوجل اللي على موبايلك الأندرويد';

/** Run once from the editor: creates the form and wires it to the email. */
function createTesterForm() {
  var form = FormApp.create(FORM_TITLE);
  form.setDescription(
    'لعبة مافيا جماعية بالعربي: العبوها على موبايل واحد في القعدة، أو أونلاين بالصوت مع صحابك.\n\n' +
    'اللعبة في الاختبار المقفول على جوجل بلاي، وبندوّر على مختبرين أندرويد (١٦ سنة أو أكتر).\n' +
    'سجّل اسمك وإيميل حساب جوجل اللي على موبايلك، وهيوصلك إيميل على طول فيه لينك التنزيل.\n\n' +
    'بنستخدم الاسم والإيميل بس عشان نبعتلك إيميل واحد بلينك التنزيل.');
  form.setConfirmationMessage(
    'اتسجّلت! هيوصلك إيميل دلوقتي فيه زرار «نزّل اللعبة». ' +
    'لو مش لاقيه، بص في «الترويجات» أو «الرسائل غير المرغوب فيها».');
  form.setShowLinkToRespondAgain(false);
  form.setAllowResponseEdits(false);
  form.addImageItem()
    .setImage(UrlFetchApp.fetch('https://saidalmafia.com/beta/art/mail_header.png').getBlob())
    .setAlignment(FormApp.Alignment.CENTER);
  form.addTextItem().setTitle(FORM_NAME).setRequired(true);
  form.addTextItem()
    .setTitle(FORM_EMAIL)
    .setHelpText('نفس الحساب اللي فاتح بيه جوجل بلاي على موبايلك.')
    .setRequired(true)
    .setValidation(FormApp.createTextValidation()
      .setHelpText('اكتب إيميل صحيح')
      .requireTextIsEmail()
      .build());
  ScriptApp.newTrigger('onTesterForm').forForm(form).onFormSubmit().create();
  PropertiesService.getScriptProperties().setProperty('FORM_ID', form.getId());
  Logger.log('FORM ' + form.getPublishedUrl());
  Logger.log('EDIT ' + form.getEditUrl());
}

function onTesterForm(e) {
  var name = '';
  var email = '';
  e.response.getItemResponses().forEach(function (r) {
    var title = r.getItem().getTitle();
    var value = String(r.getResponse() || '').trim();
    if (title === FORM_NAME) name = value.replace(/[<>&"]/g, '').slice(0, 40);
    if (title === FORM_EMAIL) email = value.toLowerCase();
  });
  // Google collects the address itself (responder input), which is what lets
  // Google send the responder a copy from its own servers.
  register_(name, email || String(e.response.getRespondentEmail() || '').trim().toLowerCase());
}

var SIGNUP_URL = 'https://hezjbrnveajypfqmjfnh.supabase.co/functions/v1/tester_signup';

/** Register through Supabase; only tester_signup sends the welcome email. */
function register_(name, email) {
  if (!EMAIL.test(email) || email.length > 120) return 'bad';
  var signup = UrlFetchApp.fetch(SIGNUP_URL, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({ name: name.length >= 2 ? name : 'مختبر', email: email, source: 'gform' }),
    muteHttpExceptions: true,
  });
  return signup.getResponseCode() === 200 ? 'registered' : 'signup failed (' + signup.getResponseCode() + ')';
}

/** Run once from the editor: puts every earlier form answer on the tester list. */
function backfillFormAnswers() {
  var form = FormApp.openById(PropertiesService.getScriptProperties().getProperty('FORM_ID'));
  form.getResponses().forEach(function (response) {
    var name = '';
    var email = '';
    response.getItemResponses().forEach(function (r) {
      var title = r.getItem().getTitle();
      var value = String(r.getResponse() || '').trim();
      if (title === FORM_NAME) name = value.replace(/[<>&"]/g, '').slice(0, 40);
      if (title === FORM_EMAIL) email = value.toLowerCase();
    });
    Logger.log(register_(name, email || String(response.getRespondentEmail() || '').trim().toLowerCase()));
  });
}

/** Run once from the editor: the thank-you page points to the join steps. */
function setFormThankYou() {
  var form = FormApp.openById(PropertiesService.getScriptProperties().getProperty('FORM_ID'));
  form.setConfirmationMessage(
    'اتسجّلت! الخطوة الجاية من موبايلك الأندرويد، بنفس حساب جوجل اللي كتبته:\n\n' +
    'كمّل خطوات التنزيل: ' + JOIN_URL + '\n\n' +
    'لو الرابط ما فتحش: الجروب ' + GROUP_URL + ' | صفحة Play ' + OPT_IN_URL + '\n\n' +
    'هيوصلك كمان إيميل بنفس اللينكات. لو ملقتوش، بص في Spam ودوس «ليست رسالة غير مرغوب فيها».');
  Logger.log('confirmation updated');
}

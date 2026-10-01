/**
 * Mafia Master — closed-test welcome email.
 *
 * A Google Apps Script web app on the owner's Google account. The
 * tester_signup edge function POSTs { name, email, token } after a NEW
 * sign-up on saidalmafia.com/beta; this sends one email from the owner's Gmail
 * with one main link: the tester join page. The script holds no secret: before
 * sending it asks the server (tester_mail_check) whether the token is an HMAC
 * only the server can make and the address is still unmailed, so nobody else
 * can use this to send mail. Consumer Gmail allows about 100 recipients a day.
 *
 * Deploy: Deploy → New deployment → Web app → Execute as: Me → Who has access:
 * Anyone. Put the /exec URL in the Supabase secret TESTER_MAIL_URL.
 */

var GROUP_URL = 'https://groups.google.com/g/mafia-master-testers';
var OPT_IN_URL = 'https://play.google.com/apps/testing/com.mafiamaster.mafia_master';
var JOIN_URL = 'https://saidalmafia.com/beta/join/';
var STORE_URL = 'https://play.google.com/store/apps/details?id=com.mafiamaster.mafia_master';
var CHECK_URL = 'https://hezjbrnveajypfqmjfnh.supabase.co/functions/v1/tester_mail_check';
var EMAIL = /^[^\s@<>"',;]+@[^\s@<>"',;]+\.[a-z]{2,}$/i;

function doPost(e) {
  var body;
  try {
    body = JSON.parse(e.postData.contents);
  } catch (err) {
    return reply_('bad');
  }
  var email = String(body.email || '').trim().toLowerCase();
  var name = String(body.name || '').replace(/[<>&"]/g, '').trim().slice(0, 40);
  if (!EMAIL.test(email) || email.length > 120) return reply_('bad');
  var check = UrlFetchApp.fetch(CHECK_URL, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({ email: email, token: String(body.token || '') }),
    muteHttpExceptions: true,
  });
  var verdict = {};
  try {
    verdict = JSON.parse(check.getContentText());
  } catch (err) {
    verdict = {};
  }
  if (check.getResponseCode() !== 200 || verdict.valid !== true) return reply_('denied');
  // Already mailed through the Google Form route: answer `sent` so the server
  // records it, and send nothing twice.
  var props = PropertiesService.getScriptProperties();
  if (props.getProperty('sent:' + email)) return reply_('sent');
  if (MailApp.getRemainingDailyQuota() < 1) return reply_('quota');

  send_(email, name);
  props.setProperty('sent:' + email, new Date().toISOString());
  return reply_('sent');
}

function send_(email, name) {
  MailApp.sendEmail({
    to: email,
    name: 'إياد من سيد المافيا',
    subject: 'Your Mafia Master tester invite',
    body: text_(name),
    htmlBody: html_(name),
  });
}

function reply_(status) {
  return ContentService.createTextOutput(JSON.stringify({ status: status }))
    .setMimeType(ContentService.MimeType.JSON);
}

function text_(name) {
  var cleanName = String(name || '').trim();
  return 'سيد المافيا | Mafia Master\nاللعبة مستنياك\n\n' +
    (cleanName ? 'أهلاً ' + cleanName + '،' : 'أهلاً،') + '\n\n' +
    'كمّل خطوات التنزيل: ' + JOIN_URL + '\n\n' +
    'افتح الرابط من موبايلك الأندرويد بنفس حساب جوجل اللي سجّلت بيه. انضم للجروب، وبعدها الصفحة هتوصلك لتنزيل اللعبة.\n\n' +
    'لو الرابط ما فتحش: الجروب ' + GROUP_URL + ' | صفحة Play ' + OPT_IN_URL + '\n\n' +
    'إياد — سيد المافيا';
}

function html_(name) {
  var cleanName = String(name || '').trim();
  var safeName = cleanName.replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  var greeting = cleanName ? 'أهلاً <span dir="auto">' + safeName + '</span>،' : 'أهلاً،';
  var header = 'https://saidalmafia.com/beta/art/mail_header.png';
  return '<table role="presentation" dir="rtl" align="center" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#0F0F0F" style="width:100%;background-color:#0F0F0F;font-family:Tahoma,Arial,sans-serif;letter-spacing:0;line-height:1.6">' +
    '<tr><td align="center" style="padding:24px 10px">' +
    '<table role="presentation" dir="rtl" align="center" width="600" cellpadding="0" cellspacing="0" border="0" bgcolor="#191816" style="width:100%;max-width:600px;background-color:#191816;border:1px solid #3A352C;color:#EDE7DA">' +
    '<tr><td align="center" style="padding:0"><img src="' + header + '" width="600" height="300" alt="سيد المافيا | Mafia Master — اللعبة مستنياك" border="0" style="display:block;width:100%;max-width:600px;height:auto;border:0"></td></tr>' +
    '<tr><td dir="rtl" align="right" style="padding:26px 38px 34px;text-align:right;font-family:Tahoma,Arial,sans-serif;line-height:1.6;letter-spacing:0">' +
    '<p style="margin:0 0 22px;color:#EDE7DA;font-size:22px;font-weight:bold;line-height:1.6;letter-spacing:0">' + greeting + '</p>' +
    '<table role="presentation" dir="rtl" align="center" cellpadding="0" cellspacing="0" border="0" bgcolor="#D6B36A" style="margin:0 auto;background-color:#D6B36A"><tr><td align="center" bgcolor="#D6B36A" style="padding:14px 42px;text-align:center"><a href="' + JOIN_URL + '" style="display:block;color:#17140E;text-decoration:none;font-family:Tahoma,Arial,sans-serif;font-size:20px;font-weight:bold;line-height:1.6;letter-spacing:0">كمّل خطوات التنزيل</a></td></tr></table>' +
    '<p style="margin:20px 0 0;color:#D8D1C3;font-size:14px;line-height:1.6;letter-spacing:0">افتح الرابط من موبايلك الأندرويد بنفس حساب جوجل اللي سجّلت بيه. انضم للجروب، وبعدها الصفحة هتوصلك لتنزيل اللعبة.</p>' +
    '<p style="margin:12px 0 0;color:#D8D1C3;font-size:13px;line-height:1.6;letter-spacing:0">لو الرابط ما فتحش: <a href="' + GROUP_URL + '" style="color:#D6B36A;text-decoration:underline">الجروب</a> · <a href="' + OPT_IN_URL + '" style="color:#D6B36A;text-decoration:underline">صفحة Play</a>.</p>' +
    '<p style="margin:25px 0 0;color:#EDE7DA;font-size:15px;line-height:1.6;letter-spacing:0">إياد — سيد المافيا</p>' +
    '</td></tr></table></td></tr></table>';
}

/** Run once from the editor to grant the mail and fetch permissions. */
function setup() {
  Logger.log(MailApp.getRemainingDailyQuota());
}

/*
 * The Google Form route (for groups that trust a Google Form more than a
 * site). Same welcome email, sent from the form's own submit trigger. Google
 * hosts the form, so there is no token to check; each address is mailed once
 * (remembered in the script properties) and the daily quota is shared with
 * the site.
 */
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

/*
 * A form answer joins the same tester list as the site form: it goes through
 * tester_signup, which records it and sends the welcome email through doPost
 * above. If that route refuses (its hourly per-address limit counts Google's
 * own servers, which many answers share), the email is sent from here instead,
 * so nobody who answered is left without the link.
 */
function register_(name, email) {
  if (!EMAIL.test(email) || email.length > 120) return 'bad';
  var signup = UrlFetchApp.fetch(SIGNUP_URL, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({ name: name.length >= 2 ? name : 'مختبر', email: email, source: 'gform' }),
    muteHttpExceptions: true,
  });
  if (signup.getResponseCode() === 200) return 'registered';
  var props = PropertiesService.getScriptProperties();
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    if (props.getProperty('sent:' + email)) return 'already mailed';
    if (MailApp.getRemainingDailyQuota() < 1) return 'quota';
    send_(email, name);
    props.setProperty('sent:' + email, new Date().toISOString());
    return 'mailed directly (' + signup.getResponseCode() + ')';
  } finally {
    lock.releaseLock();
  }
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

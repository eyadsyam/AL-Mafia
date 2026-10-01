/**
 * Mafia Master — closed-test welcome email.
 *
 * A Google Apps Script web app on the owner's Google account. The
 * tester_signup edge function POSTs { name, email, token } after a NEW
 * sign-up on saidalmafia.com/beta; this sends one email from the owner's Gmail
 * with one link: the Play test page (become a tester, then install). The script holds no secret: before
 * sending it asks the server (tester_mail_check) whether the token is an HMAC
 * only the server can make and the address is still unmailed, so nobody else
 * can use this to send mail. Consumer Gmail allows about 100 recipients a day.
 *
 * Deploy: Deploy → New deployment → Web app → Execute as: Me → Who has access:
 * Anyone. Put the /exec URL in the Supabase secret TESTER_MAIL_URL.
 */

var GROUP_URL = 'https://groups.google.com/g/mafia-master-testers';
var OPT_IN_URL = 'https://play.google.com/apps/testing/com.mafiamaster.mafia_master';
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
  if (MailApp.getRemainingDailyQuota() < 1) return reply_('quota');

  MailApp.sendEmail({
    to: email,
    name: 'سيد المافيا',
    subject: 'سيد المافيا: نزّل اللعبة من هنا',
    body: text_(name),
    htmlBody: html_(name),
  });
  return reply_('sent');
}

function reply_(status) {
  return ContentService.createTextOutput(JSON.stringify({ status: status }))
    .setMimeType(ContentService.MimeType.JSON);
}

function text_(name) {
  var cleanName = String(name || '').trim();
  return 'سيد المافيا | Mafia Master\nاللعبة مستنياك\n\n' +
    (cleanName ? 'أهلاً ' + cleanName + '،' : 'أهلاً،') + '\n\n' +
    'نزّل اللعبة: ' + OPT_IN_URL + '\n\n' +
    'افتح الرابط من موبايلك الأندرويد بنفس حساب جوجل اللي سجّلت بيه، واضغط «أصبح مختبِرًا» ثم «تنزيل».\n\n' +
    'لو ظهر إن اللعبة مش متاحة، «انضم للمختبرين» الأول: ' + GROUP_URL + '\n\n' +
    'إياد — سيد المافيا';
}

function html_(name) {
  var cleanName = String(name || '').trim();
  var safeName = cleanName.replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  var greeting = cleanName ? 'أهلاً <span dir="auto">' + safeName + '</span>،' : 'أهلاً،';
  var header = 'https://saidalmafia.com/beta/art/mail_header.png';
  var background = 'https://saidalmafia.com/beta/art/mail_bg.jpg';
  return '<table role="presentation" dir="rtl" align="center" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#0F0F0F" style="width:100%;background-color:#0F0F0F;font-family:Tahoma,Arial,sans-serif;letter-spacing:0;line-height:1.6">' +
    '<tr><td align="center" style="padding:24px 10px">' +
    '<table role="presentation" dir="rtl" align="center" width="600" cellpadding="0" cellspacing="0" border="0" bgcolor="#191816" background="' + background + '" style="width:100%;max-width:600px;background-color:#191816;background-image:url(\'' + background + '\');background-position:center top;background-repeat:no-repeat;background-size:cover;border:1px solid #3A352C;color:#EDE7DA">' +
    '<tr><td align="center" style="padding:0"><img src="' + header + '" width="600" height="300" alt="سيد المافيا | Mafia Master — اللعبة مستنياك" border="0" style="display:block;width:100%;max-width:600px;height:auto;border:0"></td></tr>' +
    '<tr><td dir="rtl" align="right" style="padding:26px 38px 34px;text-align:right;font-family:Tahoma,Arial,sans-serif;line-height:1.6;letter-spacing:0">' +
    '<p style="margin:0 0 22px;color:#EDE7DA;font-size:22px;font-weight:bold;line-height:1.6;letter-spacing:0">' + greeting + '</p>' +
    '<table role="presentation" dir="rtl" align="center" cellpadding="0" cellspacing="0" border="0" bgcolor="#D6B36A" style="margin:0 auto;background-color:#D6B36A"><tr><td align="center" bgcolor="#D6B36A" style="padding:14px 42px;text-align:center"><a href="' + OPT_IN_URL + '" style="display:block;color:#17140E;text-decoration:none;font-family:Tahoma,Arial,sans-serif;font-size:20px;font-weight:bold;line-height:1.6;letter-spacing:0">نزّل اللعبة</a></td></tr></table>' +
    '<p style="margin:20px 0 0;color:#D8D1C3;font-size:14px;line-height:1.6;letter-spacing:0">افتح الرابط من موبايلك الأندرويد بنفس حساب جوجل اللي سجّلت بيه، واضغط «أصبح مختبِرًا» ثم «تنزيل».</p>' +
    '<p style="margin:12px 0 0;color:#D8D1C3;font-size:13px;line-height:1.6;letter-spacing:0">لو ظهر إن اللعبة مش متاحة، <a href="' + GROUP_URL + '" style="color:#D6B36A;text-decoration:underline">انضم للمختبرين</a> الأول.</p>' +
    '<p style="margin:25px 0 0;color:#EDE7DA;font-size:15px;line-height:1.6;letter-spacing:0">إياد — سيد المافيا</p>' +
    '</td></tr></table></td></tr></table>';
}

/** Run once from the editor to grant the mail and fetch permissions. */
function setup() {
  Logger.log(MailApp.getRemainingDailyQuota());
}

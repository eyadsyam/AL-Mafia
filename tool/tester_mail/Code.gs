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
  return 'أهلاً ' + (name || '') + '،\n\n' +
    'دوس على اللينك ده من موبايلك الأندرويد، وبنفس حساب جوجل اللي سجّلت بيه، ودوس «أصبح مختبِرًا» وبعدها «تنزيل»:\n' +
    OPT_IN_URL + '\n\n' +
    'لو قالك إن اللعبة مش متاحة، انضم للمختبرين الأول من هنا وجرب تاني: ' + GROUP_URL + '\n\n' +
    'إياد — سيد المافيا\nhttps://saidalmafia.com';
}

function html_(name) {
  return '<div dir="rtl" style="background:#0F0F0F;padding:24px 12px;font-family:Tahoma,Arial,sans-serif;line-height:1.7">' +
    '<div style="max-width:520px;margin:0 auto;background:#191816;border:1px solid #2E2C28;border-radius:14px;padding:24px 20px;color:#C9C4B9;text-align:center">' +
    '<div style="color:#D6B36A;font-size:14px">سيد المافيا</div>' +
    '<h1 style="color:#EDE7DA;font-size:22px;margin:6px 0 12px">أهلاً ' + (name || '') + '، اللعبة مستنياك</h1>' +
    '<a href="' + OPT_IN_URL + '" style="display:inline-block;background:#D6B36A;color:#17140E;text-decoration:none;font-weight:700;font-size:18px;padding:14px 28px;border-radius:10px">نزّل اللعبة</a>' +
    '<p style="margin:16px 0 0;font-size:14px;color:#8F8A80">افتحه من موبايلك الأندرويد بنفس الحساب، ودوس «أصبح مختبِرًا» وبعدها «تنزيل».</p>' +
    '<p style="margin:10px 0 0;font-size:13px;color:#8F8A80">لو قالك إن اللعبة مش متاحة، <a href="' + GROUP_URL + '" style="color:#D6B36A">انضم للمختبرين</a> الأول وجرب تاني.</p>' +
    '<p style="margin:16px 0 0;color:#EDE7DA">إياد — سيد المافيا</p>' +
    '</div></div>';
}

/** Run once from the editor to grant the mail and fetch permissions. */
function setup() {
  Logger.log(MailApp.getRemainingDailyQuota());
}

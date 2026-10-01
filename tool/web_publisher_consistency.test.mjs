import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';

const read = p => readFileSync(p, 'utf8');
const html = read('web/index.html');

test('one AdSense publisher id everywhere it must match', () => {
  const meta = html.match(/<meta name="google-adsense-account" content="(ca-pub-\d{16})"/);
  assert(meta, 'index.html needs the google-adsense-account meta tag');
  const id = meta[1];
  const script = html.match(
    /<script async src="https:\/\/pagead2\.googlesyndication\.com\/pagead\/js\/adsbygoogle\.js\?client=(ca-pub-\d{16})" crossorigin="anonymous"><\/script>/);
  assert(script, 'index.html needs the static adsbygoogle.js tag in <head>');
  assert.equal(script[1], id, 'meta tag and script tag disagree');
  const pub = id.replace('ca-pub-', 'pub-');
  for (const file of ['web/ads.txt', 'web/app-ads.txt']) {
    assert(read(file).includes(`google.com, ${pub}, DIRECT, f08c47fec0942fa0`),
      `${file} must list ${pub}`);
  }
  const dart = read('lib/ui/economy/web_ads.dart');
  assert(dart.includes(`defaultValue: '${id}'`),
    'kWebAdsenseClient default in lib/ui/economy/web_ads.dart must be ' + id);
  // The bridge must not hardcode a second copy of the id.
  const bridge = html.split('<script>').slice(1)
    .map(part => part.split('</script>')[0])
    .find(part => part.includes('mafiaH5Break'));
  assert(!/ca-pub-\d{16}/.test(bridge), 'the bridge reads the id from the meta tag');
});

const pages = ['how-to-play', 'roles', 'about'];

test('crawlable content pages exist, link each other and the game', () => {
  for (const page of pages) {
    const file = `web/${page}/index.html`;
    assert(existsSync(file), file);
    const text = read(file);
    assert.match(text, /<title>[^<]{10,}<\/title>/, file);
    assert.match(text, /<meta name="description" content="[^"]{40,}"/, file);
    assert.match(text, /<link rel="canonical" href="https:\/\/saidalmafia\.com\/[a-z-]+\/">/, file);
    assert.match(text, /href="\/"/, `${file} links back to the game`);
    for (const other of pages.filter(p => p !== page)) {
      assert(text.includes(`href="/${other}/"`), `${file} links to /${other}/`);
    }
    assert(text.includes('href="/privacy/"'), file);
    assert(text.includes('lang="en"'), `${file} has an English summary`);
    assert(text.length > 3000, `${file} has real content`);
  }
  assert(read('web/about/index.html').includes('mailto:eyadsyam124@gmail.com'));
  const privacyMail = read('web/privacy/index.html').match(/mailto:([^"]+)"/)[1];
  assert(read('web/about/index.html').includes(privacyMail), 'same support email as privacy page');
});

test('public pages never mention payments, prices or purchase methods', () => {
  const banned = /عملات|عملة|سعر|أسعار|دفع|شراء|اشتري|فودافون|إنستا|انستا|coin|price|payment|purchase|buy|vodafone|instapay|\$|USD|EGP|جنيه/i;
  for (const page of pages) {
    const text = read(`web/${page}/index.html`);
    const m = text.match(banned);
    assert(!m, `web/${page}/index.html mentions "${m && m[0]}"`);
  }
});

test('the roles page lists every role the repo defines', () => {
  const arb = JSON.parse(read('lib/app/l10n/app_ar.arb'));
  const text = read('web/roles/index.html');
  for (const key of ['roleMafiaDescription', 'roleDoctorDescription',
    'roleDetectiveDescription', 'roleCitizenDescription']) {
    const line = arb[key].trim().replace(/\s+/g, ' ');
    assert(text.includes(line), `roles page quotes ${key} from app_ar.arb`);
  }
  const en = JSON.parse(read('lib/app/l10n/app_en.arb'));
  for (const key of ['roleMafiaDescription', 'roleDoctorDescription',
    'roleDetectiveDescription', 'roleCitizenDescription']) {
    assert(text.includes(en[key]), `roles page quotes ${key} from app_en.arb`);
  }
});

test('sitemap lists the content pages and robots admits the AdSense crawler', () => {
  const sitemap = read('web/sitemap.xml');
  for (const page of pages) {
    assert(sitemap.includes(`https://saidalmafia.com/${page}/`), page);
  }
  const robots = read('web/robots.txt');
  assert.match(robots, /User-agent: Mediapartners-Google\s+Allow: \//);
  assert.match(robots, /Sitemap: https:\/\/saidalmafia\.com\/sitemap\.xml/);
  assert.doesNotMatch(robots, /Disallow: \/(how-to-play|roles|about)/);
});

test('the shell has a description, a crawlable intro and a noscript', () => {
  assert.match(html, /<meta name="description" content="[^"]{40,}"/);
  assert.match(html, /class="seo-intro"/);
  assert.match(html, /<noscript>[\s\S]*href="\/how-to-play\/"[\s\S]*<\/noscript>/);
});

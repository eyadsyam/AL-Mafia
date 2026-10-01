import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const html = readFileSync('web/index.html', 'utf8');
const source = html.split('<script>').slice(1)
  .map(part => part.split('</script>')[0])
  .find(part => part.includes('mafiaH5Break'));
assert(source, 'ad bridge script missing');

// A just-enough DOM: elements with style/attributes/children, a head, a body,
// the static adsbygoogle <script> and the publisher <meta>.
function styleBag() {
  const bag = {};
  let text = '';
  Object.defineProperty(bag, 'cssText', {
    enumerable: false,
    get: () => text,
    set(v) {
      text = v;
      for (const decl of v.split(';')) {
        const [k, ...rest] = decl.split(':');
        if (!rest.length) continue;
        const camel = k.trim().replace(/-([a-z])/g, (_, c) => c.toUpperCase());
        bag[camel] = rest.join(':').trim();
      }
    },
  });
  return bag;
}

function element(tag) {
  const el = {
    tagName: tag, style: styleBag(), attrs: {}, children: [], listeners: {},
    setAttribute(k, v) { el.attrs[k] = String(v); },
    getAttribute(k) { return k in el.attrs ? el.attrs[k] : null; },
    appendChild(c) { el.children.push(c); c.parent = el; return c; },
    remove() { if (el.parent) el.parent.children = el.parent.children.filter(c => c !== el); },
    addEventListener(type, fn) { (el.listeners[type] ||= []).push(fn); },
  };
  return el;
}

function page({ staticScript = true, mutationObserver = true } = {}) {
  const head = element('head'), body = element('body');
  const meta = element('meta');
  meta.setAttribute('content', 'ca-pub-1111111111111111');
  const script = element('script');
  const observers = [], polls = { count: 0 };
  const document = {
    head, body,
    createElement: element,
    getElementById: id => body.children.find(c => c.id === id) || null,
    querySelector(selector) {
      if (selector.startsWith('meta[')) return meta;
      if (selector.startsWith('script[')) return staticScript ? script : null;
      return null;
    },
  };
  class MutationObserver {
    constructor(cb) { this.cb = cb; observers.push(this); }
    observe(target) { this.target = target; }
    disconnect() { this.target = null; }
  }
  const window = {};
  runInNewContext(source, {
    window, document, setTimeout, clearTimeout,
    // Polling is only recorded, never scheduled: a live interval would keep
    // the test process open.
    setInterval: () => { polls.count++; return 1; }, clearInterval() {},
    MutationObserver: mutationObserver ? MutationObserver : undefined,
  });
  return {
    window, document, body, head, script, polls,
    // What Google does to the <ins>: sets data-ad-status, observer fires.
    setStatus(unit, status) {
      unit.setAttribute('data-ad-status', status);
      observers.filter(o => o.target === unit).forEach(o => o.cb());
    },
  };
}

const CLIENT = 'ca-pub-5174049351369803';

test('H5 no fill reports false so Flutter keeps the house break', async () => {
  const { window } = page();
  const result = new Promise(resolve => {
    window.mafiaH5Break(CLIENT, 'next', 'afterMatch', resolve);
  });
  window.adBreak = ({ adBreakDone }) => adBreakDone({ breakStatus: 'noAdPreloaded' });
  window.adsbygoogle[0].onReady();
  assert.equal(await result, false);
});

test('H5 beforeAd reports a real fill and suppresses the house break', async () => {
  const { window } = page();
  const result = new Promise(resolve => {
    window.mafiaH5Break(CLIENT, 'start', 'appOpen', resolve);
  });
  window.adBreak = ({ beforeAd }) => beforeAd();
  window.adsbygoogle[0].onReady();
  assert.equal(await result, true);
});

test('a blocked ad library answers no fill at once', async () => {
  const { window, script } = page();
  const result = new Promise(resolve => {
    window.mafiaH5Break(CLIENT, 'next', 'afterMatch', resolve);
  });
  script.listeners.error.forEach(f => f());
  assert.equal(await result, false);
});

test('a break answers once; a late Google callback is ignored', async () => {
  const { window } = page();
  const calls = [];
  window.mafiaH5Break(CLIENT, 'next', 'afterMatch', v => calls.push(v));
  window.adBreak = ({ adBreakDone, beforeAd }) => {
    adBreakDone({ breakStatus: 'noAdPreloaded' });
    beforeAd();
  };
  window.adsbygoogle[0].onReady();
  assert.deepEqual(calls, [false]);
});

test('the display banner does not depend on H5 onReady', () => {
  const { window, body } = page();
  const states = [];
  window.mafiaBannerShow(CLIENT, '1234567890', 10, 700, 400, 90, f => states.push(f));
  const host = body.children.find(c => c.id === 'mafia-google-banner');
  assert(host, 'host created without H5');
  const unit = host.children[0];
  assert.equal(unit.tagName, 'ins');
  assert.equal(unit.getAttribute('data-ad-slot'), '1234567890');
  // Pushed immediately, with no adConfig/onReady in between.
  assert.equal(window.adsbygoogle.length, 1);
  assert.equal(JSON.stringify(window.adsbygoogle[0]), '{}');
});

test('the unit is fixed size and never exceeds the reserved slot', () => {
  const { window, body } = page();
  window.mafiaBannerShow(CLIENT, '1234567890', 10, 700, 1000, 90, () => {});
  const host = body.children.find(c => c.id === 'mafia-google-banner');
  const unit = host.children[0];
  assert.equal(unit.getAttribute('data-ad-format'), null, 'no auto format');
  assert.equal(unit.getAttribute('data-full-width-responsive'), null);
  assert.match(unit.style.cssText, /width:728px;height:90px/);
  assert.equal(host.style.height, '90px');
  assert.equal(host.style.overflow, 'hidden');
  assert.equal(host.style.left, '10px');
  assert.equal(host.style.top, '700px');
  assert.equal(host.style.width, '1000px');
  const phone = page();
  phone.window.mafiaBannerShow(CLIENT, '1234567890', 0, 600, 390, 90, () => {});
  const unit2 = phone.body.children[0].children[0];
  assert.match(unit2.style.cssText, /width:320px;height:100px|width:320px;height:50px/);
  assert.doesNotMatch(unit2.style.cssText, /height:100px/, '100px is taller than the 90px slot');
});

test('a slot too small for any banner size reports unfilled', () => {
  const { window, body } = page();
  const states = [];
  window.mafiaBannerShow(CLIENT, '1234567890', 0, 0, 200, 40, f => states.push(f));
  assert.deepEqual(states, [false]);
  assert.equal(body.children.length === 0 || body.children[0].style.visibility === 'hidden', true);
});

test('house stays until the status says filled, then a late fill switches', () => {
  const p = page();
  const states = [];
  p.window.mafiaBannerShow(CLIENT, '1234567890', 0, 700, 400, 90, f => states.push(f));
  const host = p.body.children[0];
  const unit = host.children[0];
  assert.equal(host.style.visibility, 'hidden');
  assert.equal(host.style.pointerEvents, 'none');
  p.setStatus(unit, 'unfilled');
  assert.equal(host.style.visibility, 'hidden');
  // No single-timeout judgement: a fill after any delay is honoured.
  p.setStatus(unit, 'filled');
  assert.equal(host.style.visibility, 'visible');
  assert.equal(host.style.pointerEvents, 'auto');
  assert.equal(states.at(-1), true);
});

test('hiding makes the overlay inert without destroying the filled unit', () => {
  const p = page();
  p.window.mafiaBannerShow(CLIENT, '1234567890', 0, 700, 400, 90, () => {});
  const host = p.body.children[0];
  const unit = host.children[0];
  p.setStatus(unit, 'filled');
  p.window.mafiaBannerHide();
  assert.equal(host.style.visibility, 'hidden');
  assert.equal(host.style.pointerEvents, 'none');
  // Shown again (the screen beneath takes over): same unit, no second push.
  const states = [];
  p.window.mafiaBannerShow(CLIENT, '1234567890', 0, 500, 400, 90, f => states.push(f));
  assert.equal(host.children[0], unit);
  assert.equal(p.window.adsbygoogle.length, 1);
  assert.equal(host.style.top, '500px');
  assert.equal(host.style.visibility, 'visible');
  assert.deepEqual(states, [true]);
});

test('without a static tag the library is loaded once for both features', () => {
  const p = page({ staticScript: false });
  p.window.mafiaBannerShow(CLIENT, '1234567890', 0, 700, 400, 90, () => {});
  p.window.mafiaH5Break(CLIENT, 'next', 'afterMatch', () => {});
  const loaders = p.head.children.filter(c => c.tagName === 'script');
  assert.equal(loaders.length, 1);
  assert.match(loaders[0].src, /adsbygoogle\.js\?client=ca-pub-1111111111111111/);
});

test('no MutationObserver falls back to polling', () => {
  const p = page({ mutationObserver: false });
  p.window.mafiaBannerShow(CLIENT, '1234567890', 0, 700, 400, 90, () => {});
  assert.equal(p.body.children[0].children.length, 1);
  assert.equal(p.polls.count, 1);
});

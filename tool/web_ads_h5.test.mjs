import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const html = readFileSync('web/index.html', 'utf8');
const source = html.split('<script>').slice(1)
  .map(part => part.split('</script>')[0])
  .find(part => part.includes('mafiaH5Break'));
assert(source, 'H5 bridge script missing');

function bridge() {
  const window = {};
  const document = {
    head: { appendChild() {} },
    createElement: () => ({}),
  };
  runInNewContext(source, { window, document, setTimeout, clearTimeout });
  return window;
}

test('H5 no fill reports false so Flutter keeps the house break', async () => {
  const window = bridge();
  const result = new Promise(resolve => {
    window.mafiaH5Break('ca-pub-9179063936085117', 'next', 'afterMatch', resolve);
  });
  window.adBreak = ({ adBreakDone }) => adBreakDone({ breakStatus: 'noAdPreloaded' });
  window.adsbygoogle[0].onReady();
  assert.equal(await result, false);
});

test('H5 beforeAd reports a real fill and suppresses the house break', async () => {
  const window = bridge();
  const result = new Promise(resolve => {
    window.mafiaH5Break('ca-pub-9179063936085117', 'start', 'appOpen', resolve);
  });
  window.adBreak = ({ beforeAd }) => beforeAd();
  window.adsbygoogle[0].onReady();
  assert.equal(await result, true);
});

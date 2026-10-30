import assert from 'node:assert/strict';
import test from 'node:test';
import { capRows, reviewAllowed, safeConfig, shapeReview } from '../functions/_shared/owner_review.ts';

test('non administrators are refused', () => {
  assert.equal(reviewAllowed(false), false);
  assert.equal(reviewAllowed(true), true);
});

test('rows are capped and remain in source order', () => {
  const rows = Array.from({ length: 80 }, (_, n) => ({ n }));
  assert.deepEqual(capRows(rows), rows.slice(0, 50));
  assert.equal(shapeReview('store', { items: rows, grants: rows }).grants.length, 50);
});

test('config never returns secret-like columns', () => {
  assert.deepEqual(safeConfig({ enabled: true, api_key: 'x', token_count: 2, secretFlag: 'x' }), { enabled: true });
  assert.deepEqual(shapeReview('config', { app: { min_build: 2, privateKey: 'x' } }), {
    app: { min_build: 2 }, economy: {},
  });
});

test('room and tester rows exclude private fields', () => {
  assert.deepEqual(shapeReview('rooms', { items: [{ code: 'ABCDEF', role: 'mafia', whisper: 'private' }] }),
    { items: [{ code: 'ABCDEF' }] });
  assert.deepEqual(shapeReview('testers', { items: [{ name: 'Nour', email: 'private', note: 'private' }] }),
    { items: [{ name: 'Nour' }] });
});

test('usage days keep their counts and nothing else', () => {
  const day = { day: '2026-10-30', newAccounts: 3, onlinePlayers: 9, onlineMatches: 2,
    adsAsked: 5, adsPaid: 4, events: { 'ad_result/daily:earned': 4 }, userId: 'private' };
  assert.deepEqual(shapeReview('usage', { items: [day] }).items[0], {
    day: '2026-10-30', newAccounts: 3, onlinePlayers: 9, onlineMatches: 2,
    adsAsked: 5, adsPaid: 4, events: { 'ad_result/daily:earned': 4 },
  });
});
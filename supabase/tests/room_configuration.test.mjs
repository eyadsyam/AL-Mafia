import assert from 'node:assert/strict';
import { durationFor } from '../functions/_shared/phases.ts';
import { roomConfiguration } from '../functions/_shared/room_configuration.ts';
const chosen = { maxPlayers: 8, voice: true, speechSeconds: 60, discussionSeconds: 420, openVoting: true, muteAllAtNight: true };
const created = roomConfiguration({ visibility: 'public', title: ' Table ', settings: chosen });
assert.equal(created.title, 'Table');
assert.deepEqual(created.settings, chosen);
const edited = roomConfiguration({ settings: { speechSeconds: 30 } }, created.settings);
assert.equal(edited.settings.discussionSeconds, 420);
assert.equal(edited.settings.speechSeconds, 30);
const start = roomConfiguration({ settings: { speechSeconds: 45, discussionSeconds: 180, ...created.settings } });
assert.deepEqual(start.settings, chosen);
assert.equal(durationFor('discuss', start.settings), 420);
assert.equal(durationFor('discuss', { speechSeconds: 30 }), 300);
for (const seconds of [180, 300, 420]) {
  assert.equal(durationFor('discuss', { discussionSeconds: seconds }), seconds);
}
for (const settings of [{ maxPlayers: 9 }, { voice: 'yes' }, { speechSeconds: -1 }, [], { discussionSeconds: 3 }]) {
  assert.throws(() => roomConfiguration({ settings }));
}
assert.throws(() => roomConfiguration({ visibility: 'other' }));
assert.deepEqual(roomConfiguration({ settings: { role: 'forged', secret: 'forged' } }).settings, {});
assert.equal(roomConfiguration({ settings: { muteAllAtNight: false } }).settings.muteAllAtNight, false);
assert.equal(roomConfiguration({ settings: { dayTieRule: 'revote' } }).settings.dayTieRule, 'revote');
const shadows = roomConfiguration({ settings: { scenarioCode: 'shadows', openVoting: true, discussionMode: 'free' } }).settings;
assert.equal(shadows.scenarioCode, 'shadows');
assert.equal(shadows.openVoting, false);
assert.equal(shadows.discussionMode, 'structured');
assert.equal(shadows.whisperEnabled, true);
assert.throws(() => roomConfiguration({ settings: { scenarioCode: 'forged' } }));
const dressed = roomConfiguration({ settings: { presentationPack: 'pack_old_town', narratorPack: 'narrator_storyteller' } }).settings;
assert.equal(dressed.presentationPack, 'pack_old_town');
assert.equal(dressed.narratorPack, 'narrator_storyteller');
assert.throws(() => roomConfiguration({ settings: { presentationPack: 'pack_forged' } }));
assert.throws(() => roomConfiguration({ settings: { narratorPack: 'frame_gilded' } }));
const archive = roomConfiguration({ settings: { presentationPack: 'pack_moonlit_archive', narratorPack: 'narrator_noir' } }).settings;
assert.equal(archive.presentationPack, 'pack_moonlit_archive');
assert.equal(archive.narratorPack, 'narrator_noir');
assert.equal(roomConfiguration({ settings: { narratorPack: 'narrator_keeper' } }).settings.narratorPack, 'narrator_keeper');
assert.throws(() => roomConfiguration({ settings: { presentationPack: 'bundle_nocturne' } }));
// Doc 09 §7: whisper texts after the match — a real boolean or nothing.
assert.equal(roomConfiguration({ settings: { revealWhisperContent: true } }).settings.revealWhisperContent, true);
assert.equal(roomConfiguration({ settings: {} }).settings.revealWhisperContent, undefined, 'off unless chosen');
assert.throws(() => roomConfiguration({ settings: { revealWhisperContent: 'true' } }));
const kept = roomConfiguration({ settings: { speechSeconds: 30 } }, dressed).settings;
assert.equal(kept.presentationPack, 'pack_old_town', 'a later edit keeps the pack');
console.log('PASS room configuration: cosmetics validated; : create, edit, preserve, scenarios, types, unknown fields, night privacy');

import assert from 'node:assert/strict';
import { rosterFingerprint } from '../functions/_shared/roster_fingerprint.ts';
const rows=[{user_id:'b',seat:5,alive:true},{user_id:'a',seat:0,alive:false}];
assert.equal(rosterFingerprint(rows),'a|0|0;b|5|1');
assert.equal(rosterFingerprint([...rows].reverse()),rosterFingerprint(rows));
assert.notEqual(rosterFingerprint(rows.map(p=>({...p,alive:true}))),rosterFingerprint(rows));
assert.equal(rosterFingerprint([]),'');
console.log('PASS roster token ordering, liveness and empty population');

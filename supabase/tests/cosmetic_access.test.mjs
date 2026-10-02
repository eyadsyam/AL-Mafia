// node --experimental-strip-types supabase/tests/cosmetic_access.test.mjs
import assert from 'node:assert/strict';
import { ensureCosmeticAccess } from '../functions/_shared/purchase_access.ts';

function db(owned) {
  const calls = [];
  return {
    calls,
    async rpc(name, args) {
      calls.push([name, args]);
      assert.equal(name, 'user_owns_item');
      return { data: owned.includes(args.p_item), error: null };
    },
  };
}

// Nothing set, or the default: no lookup at all.
let fake = db([]);
assert.equal(await ensureCosmeticAccess(fake, 'u', {}), true);
assert.equal(await ensureCosmeticAccess(fake, 'u', { presentationPack: 'classic' }), true);
assert.equal(await ensureCosmeticAccess(fake, 'u', undefined), true);
assert.equal(fake.calls.length, 0);

// Owned pack: allowed. Unowned: refused, whichever slot.
fake = db(['pack_old_town']);
assert.equal(await ensureCosmeticAccess(fake, 'u', { presentationPack: 'pack_old_town' }), true);
assert.equal(await ensureCosmeticAccess(fake, 'u', { presentationPack: 'pack_midnight_manor' }), false);
assert.equal(await ensureCosmeticAccess(fake, 'u', { narratorPack: 'narrator_storyteller' }), false);

// A database error is not a yes.
await assert.rejects(ensureCosmeticAccess({
  rpc: async () => ({ data: null, error: new Error('down') }),
}, 'u', { narratorPack: 'narrator_storyteller' }));
console.log('PASS cosmetic access: default free, owned allowed, unowned refused, errors propagate');

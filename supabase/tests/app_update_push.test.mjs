// node supabase/tests/app_update_push.test.mjs
// The update notice (20261030005000_app_update_push.sql): what Play counts as
// approved, and a message that carries its kind and the store link only.
import assert from 'node:assert/strict';
import { OPEN_STORE_ACTION, PLAY_STORE_LINK, messageFor } from '../functions/_shared/push.ts';
import { publishedBuild } from '../functions/_shared/play_release.ts';

const published = 'RELEASE_LIFECYCLE_STATE_PUBLISHED';
assert.equal(publishedBuild({
  releases: [{ releaseLifecycleState: published, activeArtifacts: [{ versionCode: 19 }] }],
}), 19);
// Waiting for review is not approved, however new it is.
assert.equal(publishedBuild({
  releases: [
    { releaseLifecycleState: published, activeArtifacts: [{ versionCode: 19 }] },
    { releaseLifecycleState: 'RELEASE_LIFECYCLE_STATE_DRAFT', activeArtifacts: [{ versionCode: 20 }] },
    { releaseLifecycleState: 'RELEASE_LIFECYCLE_STATE_NOT_SENT_FOR_REVIEW', activeArtifacts: [{ versionCode: 21 }] },
  ],
}), 19);
assert.equal(publishedBuild({
  releases: [{ releaseLifecycleState: published, activeArtifacts: [{ versionCode: 19 }, { versionCode: '20' }] }],
}), 20);
for (const nothing of [null, {}, { releases: [] }, { releases: 'x' },
  { releases: [{ releaseLifecycleState: published }] },
  { releases: [{ releaseLifecycleState: published, activeArtifacts: [{ versionCode: 'x' }] }] }]) {
  assert.equal(publishedBuild(nothing), null);
}

const { message } = messageFor({ enabled: true, kind: 'app_update' }, 'x'.repeat(20), 'android');
assert.deepEqual(message.data, { kind: 'app_update', link: PLAY_STORE_LINK });
assert.ok(PLAY_STORE_LINK.includes('com.mafiamaster.mafia_master'));
assert.ok(message.notification.title.length > 0);
assert.equal(message.android.collapse_key, 'app_update');
// A build without OpenStoreActivity gets no click_action: the tap would do nothing.
assert.equal(message.android.notification.click_action, undefined);
for (const old of [null, 19]) {
  assert.equal(messageFor({ enabled: true, kind: 'app_update' }, 'x'.repeat(20), 'android', old).message.android.notification.click_action, undefined);
}
assert.equal(messageFor({ enabled: true, kind: 'app_update' }, 'x'.repeat(20), 'android', 20).message.android.notification.click_action, OPEN_STORE_ACTION);

console.log('app_update_push: ok');

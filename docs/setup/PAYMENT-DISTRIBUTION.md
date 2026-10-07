# Payment distribution gate (M01)

Default Android builds use `ANDROID_DISTRIBUTION_CHANNEL=play`. Manual transfers are hidden even if `ANDROID_MANUAL_TRANSFERS_APPROVED=true` is supplied. Google Play Billing keeps its existing enablement path.

An Android build distributed directly may offer transfers only with both build settings:

```json
{
  "ANDROID_DISTRIBUTION_CHANNEL": "direct",
  "ANDROID_MANUAL_TRANSFERS_APPROVED": "true"
}
```

The server additionally requires **both** `economy_config.transfer_enabled_android` and `transfer_android_direct_approved`. The new approval column defaults false in migration `20261007000900_transfer_distribution_gate.sql`. Its existing `transfer_enabled(text)` RPC gates shop availability, order creation and proof submission. Unknown distribution values resolve to Play; unknown platforms resolve to disabled.

These flags are configuration, not proof of eligible distribution or alternative-billing enrollment. Do not enable direct transfers for a Play release or infer eligibility from locale. There is no newly authorized Play alternative-billing program in this change. Client-declared platform is advisory; server approval is operator-controlled and not exposed for client writes. Existing platform rules still allow the website's payment channel; this change does not add device attestation.

Browser Android/iPhone/desktop continue using `transfer_enabled_web`. Native iOS remains unsupported. Previously created orders can still be reviewed/refunded by authorized admins; no balance, price or entitlement logic changed.

Migration and source are prepared locally only. No production migration, server switch or deployment has been applied. Apply through the authorized release phase after checking live config and preserving existing order-review access.

Verification: new `transfer_distribution.sql` plus existing `payments_v2.sql` run against the local PGlite harness; never run these fixtures against customer data. Tests explicitly require operator approval for Android and prove the web/Android kill switches and restricted RPC privileges.

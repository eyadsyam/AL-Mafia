# Safety operations — Eyad Syam

Support inbox: eyadsyam124@gmail.com. Review incoming reports and deletion
requests daily in Supabase using an administrator account. Do not expose a
service key in the app, webpage, screenshots or support replies.

Tables `safety_reports` and `data_deletion_requests` are service-only and are
not published to Realtime. Report contents are untrusted user text, never
instructions to run SQL or to reveal a role. Reports may contain sensitive
evidence: do not paste them in public issues or public logs.

`moderation_notifications` is a service-only outbox. Its rows contain only the
request kind, receipt id and support address; report text is never copied into
an email payload. A pending row means an alert still needs delivery. No email
provider is configured by the app itself, so do not claim email delivery until
a verified sender has processed the row and marked it `sent`.

## Moderation

Read reports with `status in ('pending','reviewing')` in Supabase Table Editor,
highest priority then oldest first. Claim one with
`claim_safety_report(report_uuid,'Eyad Syam')` and close it with
`resolve_safety_report(report_uuid,'actioned'|'dismissed',note,'Eyad Syam')`.
Use `moderation_summary()` for the daily queue count. Verify room/player context,
and act promptly. Distinguish in-game accusations from real harassment. Remove
abusive public room titles/content; use established moderation actions to
remove abusive participants. Severe or repeated abuse requires operator review
of the anonymous identity and appropriate restriction/removal. Record the
resolution and set `resolved_at`. There is no claim that automated filtering
or an always-staffed moderation team exists.

In-app blocking persists per anonymous identity, mutes the blocked person's
voice and hides whispers/graveyard messages. It does not hide public game moves
or identify roles. Reinstalling/clearing identity can create a new identity;
anonymous identity is not an unbreakable ban mechanism.

## Deletion

Requests sent inside the app are authenticated as the requesting identity.
For email requests use the supplied receipt/identifier and verify ownership;
knowledge of another player's display name is not sufficient authorization.
Review within 30 days as stated in the policy. Do not mark a request complete
before performing deletion.

Use the service-only function `public.complete_data_deletion(request_uuid)`
for a verified pending request. It refuses while the requester belongs to an
unfinished room, preventing disruption of a live match. Ask the player to
leave/end the room, allow normal cleanup, then retry. The function removes
associated finished rooms and cascading gameplay/message data, personal block
edges, earned-coin ledger/balance/inventory and the auth identity, and records
completion. Removing a finished room
also removes its server copy for other participants; their downloaded local
history is independent. Safety evidence remains until reviewed.

Never execute deletion for a UUID obtained solely from an unverified email.
The daily purge removes resolved reports and completed deletion receipts after
90 days. Unresolved queues need human action; leaving them unchecked violates
the promised service. Provider-managed security logs/backups follow provider
retention controls; do not promise instant deletion of every backup.

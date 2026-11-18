/**
 * `proof_sweep` removes due order proofs and abandoned uploads without an
 * admin opening the order list. The database owns the eligibility decisions;
 * only the scheduler holding PLAY_SYNC_SECRET may run this service-key sweep.
 */
import { ok, serviceClient } from "../_shared/api.ts";
import { PROOF_BUCKET } from "../_shared/coin_payments.ts";
import { sameSecret } from "../_shared/same_secret.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("use POST", { status: 405 });
  const secret = Deno.env.get("PLAY_SYNC_SECRET");
  if (!secret || !sameSecret(req.headers.get("x-sync-secret") ?? "", secret)) {
    return new Response("forbidden", { status: 403 });
  }
  try {
    const db = serviceClient();
    const bucket = db.storage.from(PROOF_BUCKET);
    const { data: due, error: dueError } = await db.rpc("payment_proofs_due", { p_limit: 200 });
    if (dueError) throw dueError;
    const duePaths = (due ?? []).map((row: { path: string }) => row.path);
    if (duePaths.length > 0) {
      const removed = await bucket.remove(duePaths);
      if (removed.error) throw removed.error;
      const { error: markError } = await db.rpc("mark_payment_proofs_purged", { p_paths: duePaths });
      if (markError) throw markError;
    }

    const { data: orphans, error: orphanError } = await db.rpc("payment_proof_orphans", { p_limit: 200 });
    if (orphanError) throw orphanError;
    const orphanPaths = (orphans ?? []).map((row: { path: string }) => row.path);
    if (orphanPaths.length > 0) {
      const removed = await bucket.remove(orphanPaths);
      if (removed.error) throw removed.error;
    }
    console.log(`proof_sweep: due=${duePaths.length} orphans=${orphanPaths.length}`);
    return ok({ due: duePaths.length, orphans: orphanPaths.length });
  } catch (_error) {
    console.error("proof_sweep failed");
    return new Response("retry", { status: 500 });
  }
});

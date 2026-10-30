/** The newest build Google Play has approved and published, or null. */
export function publishedBuild(body: unknown): number | null {
  const releases = (body as { releases?: unknown } | null)?.releases;
  if (!Array.isArray(releases)) return null;
  let newest: number | null = null;
  for (const release of releases) {
    if (release?.releaseLifecycleState !== "RELEASE_LIFECYCLE_STATE_PUBLISHED") continue;
    for (const artifact of release?.activeArtifacts ?? []) {
      const code = Number(artifact?.versionCode);
      if (Number.isInteger(code) && code > 0 && (newest === null || code > newest)) newest = code;
    }
  }
  return newest;
}

/** Public lobby configuration. Shared by creation and host edits. */
export function roomConfiguration(body: Record<string, unknown>, current: Record<string, unknown> = {}) {
  const patch: Record<string, unknown> = {};
  if (body.visibility !== undefined) {
    if (!["private", "public"].includes(String(body.visibility))) throw new Error("invalid visibility");
    patch.visibility = body.visibility;
  }
  if (body.title !== undefined) {
    if (body.title !== null && typeof body.title !== "string") throw new Error("invalid title");
    patch.title = String(body.title ?? "").trim().slice(0, 40) || null;
  }
  if (body.settings !== undefined) {
    if (!body.settings || typeof body.settings !== "object" || Array.isArray(body.settings)) throw new Error("invalid settings");
    const incoming = body.settings as Record<string, unknown>;
    const settings = { ...current };
    const numbers: Record<string, number[]> = {
      maxPlayers: [5, 8, 10, 15], speechSeconds: [30, 45, 60], discussionSeconds: [180, 300, 420],
      confrontationSeconds: [30, 45, 60],
    };
    for (const [key, allowed] of Object.entries(numbers)) {
      if (incoming[key] === undefined) continue;
      if (typeof incoming[key] !== "number" || !allowed.includes(incoming[key] as number)) throw new Error(`${key} must be one of ${allowed.join(", ")}`);
      settings[key] = incoming[key];
    }
    for (const key of ["voice", "muteAllAtNight", "openVoting", "traceEnabled", "confrontationEnabled", "whisperEnabled",
      "abstainAllowed", "openingRoundEnabled", "survivorConfrontationEnabled", "bulletsEnabled", "quietNightEnabled", "selfProtectEnabled"]) {
      if (incoming[key] === undefined) continue;
      if (typeof incoming[key] !== "boolean") throw new Error(`invalid ${key}`);
      settings[key] = incoming[key];
    }
    for (const [key, allowed] of Object.entries({discussionMode: ["structured", "free"], dayTieRule: ["noElimination", "revote"]})) {
      if (incoming[key] === undefined) continue;
      if (!allowed.includes(String(incoming[key]))) throw new Error(`invalid ${key}`);
      settings[key] = incoming[key];
    }
    if (incoming.scenarioCode !== undefined) {
      if (!["classic", "shadows"].includes(String(incoming.scenarioCode))) {
        throw new Error("invalid scenarioCode");
      }
      settings.scenarioCode = incoming.scenarioCode;
      if (incoming.scenarioCode === "shadows") {
        Object.assign(settings, {
          discussionMode: "structured", openVoting: false,
          traceEnabled: true, confrontationEnabled: true,
          whisperEnabled: true, muteAllAtNight: true,
          speechSeconds: 45, discussionSeconds: 300,
        });
      }
    }
    patch.settings = settings;
  }
  return patch;
}

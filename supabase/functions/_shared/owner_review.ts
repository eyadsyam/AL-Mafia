export const reviewActions = new Set([
  "overview", "players", "rooms", "store", "config", "push", "testers",
]);

export function reviewAllowed(admin: boolean): boolean {
  return admin === true;
}

const secretColumn = /secret|key|token/i;
export function safeConfig(row: Record<string, unknown> | null | undefined): Record<string, unknown> {
  return Object.fromEntries(Object.entries(row ?? {}).filter(([name]) => !secretColumn.test(name)));
}

export function capRows<T>(rows: T[] | null | undefined): T[] {
  return (rows ?? []).slice(0, 50);
}

const rowFields: Record<string, string[]> = {
  players: ["displayName", "createdAt", "lastSignIn", "level", "allAccess"],
  rooms: ["code", "status", "phase", "playerCount", "createdAt", "hostName"],
  store: ["code", "kind", "coinPrice", "active", "owners"],
  push: ["kind", "status", "count"],
  testers: ["name", "status", "createdAt", "source"],
  grants: ["displayName", "since"],
};

function pick(row: Record<string, unknown>, fields: string[]): Record<string, unknown> {
  return Object.fromEntries(fields.filter((field) => field in row).map((field) => [field, row[field]]));
}

function shapedRows(value: unknown, fields: string[]): Record<string, unknown>[] {
  return capRows(Array.isArray(value) ? value : []).filter((row) =>
    row !== null && typeof row === "object" && !Array.isArray(row)
  ).map((row) => pick(row, fields));
}

export function shapeReview(action: string, raw: Record<string, unknown>): Record<string, unknown> {
  if (action === "config") {
    return {
      app: safeConfig(raw.app as Record<string, unknown> | undefined),
      economy: safeConfig(raw.economy as Record<string, unknown> | undefined),
    };
  }
  if (action === "overview") {
    return pick(raw, ["accountsTotal", "accountsNew7d", "signedIn7d", "roomsOpen",
      "matches7d", "matchesEver", "pushTokens", "safetyOpen", "pendingItems"]);
  }
  const items = shapedRows(raw.items, rowFields[action] ?? []);
  if (action === "store") {
    return { items, grants: shapedRows(raw.grants, rowFields.grants) };
  }
  return { items };
}

export function createClient(_url, _key, options = {}) {
  const token = options.global?.headers?.Authorization?.replace(/^Bearer /, '') ?? null;
  return globalThis.__edgeHarnessClient(token);
}

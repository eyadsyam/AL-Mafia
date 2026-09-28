// Loads Edge Function TypeScript under Node for local contract tests: types
// are stripped by Node itself, the `jsr:` Supabase client is replaced with a
// stub that answers auth for `Bearer good` only, and `Deno.env` is a fixture.
// No network, no keys.
import { register } from 'node:module';
import { pathToFileURL } from 'node:url';

const stub = `
export function createClient(_url, _key, options) {
  const header = options?.global?.headers?.Authorization ?? '';
  return {
    auth: { getUser: async () => header === 'Bearer good'
      ? { data: { user: { id: '11111111-1111-4111-8111-111111111111' } }, error: null }
      : { data: { user: null }, error: { message: 'no' } } },
  };
}`;
register('data:text/javascript,' + encodeURIComponent(`
export async function resolve(specifier, context, next) {
  if (specifier.startsWith('jsr:')) {
    return { url: 'data:text/javascript,' + encodeURIComponent(${JSON.stringify(stub)}), shortCircuit: true };
  }
  return next(specifier, context);
}`));
globalThis.Deno ??= { env: { get: () => 'http://localhost' } };

export function importTs(path) {
  return import(pathToFileURL(path).href);
}

export async function resolve(specifier, context, nextResolve) {
  if (specifier === 'jsr:@supabase/supabase-js@2') {
    return { url: new URL('./supabase.mjs', import.meta.url).href, shortCircuit: true };
  }
  if (specifier.startsWith('jsr:') || specifier.startsWith('https:')) {
    throw new Error(`Edge harness has no local replacement for ${specifier}`);
  }
  return nextResolve(specifier, context);
}

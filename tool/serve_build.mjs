// Serves a Flutter web build on 127.0.0.1 with SPA fallback and byte ranges,
// so /join/CODE and media seeking behave as on the real host.
//
//   node tool/serve_build.mjs [buildDir=build/web] [port=5182]
import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { extname, join, resolve, sep } from 'node:path';

const root = resolve(process.argv[2] ?? 'build/web');
const port = Number(process.argv[3] ?? 5182);
const types = {
  '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm',
  '.html': 'text/html', '.json': 'application/json', '.webp': 'image/webp',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2',
  '.mp4': 'video/mp4', '.css': 'text/css', '.txt': 'text/plain',
};

createServer(async (req, res) => {
  let path = resolve(root, '.' + decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (path !== root && !path.startsWith(root + sep)) return res.writeHead(403).end();
  try { if ((await stat(path)).isDirectory()) path = join(path, 'index.html'); }
  catch { path = join(root, 'index.html'); }
  let size;
  try { size = (await stat(path)).size; } catch { return res.writeHead(404).end(); }
  const headers = { 'Content-Type': types[extname(path)] ?? 'application/octet-stream', 'Accept-Ranges': 'bytes',
    'Cache-Control': 'no-store' };
  const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range ?? '');
  if (range) {
    const start = +range[1];
    const end = range[2] ? Math.min(+range[2], size - 1) : size - 1;
    res.writeHead(206, { ...headers, 'Content-Range': `bytes ${start}-${end}/${size}`, 'Content-Length': end - start + 1 });
    createReadStream(path, { start, end }).pipe(res);
  } else {
    res.writeHead(200, { ...headers, 'Content-Length': size });
    createReadStream(path).pipe(res);
  }
}).listen(port, '127.0.0.1', () => console.log(`serving ${root} on http://127.0.0.1:${port}`));

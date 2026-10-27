// Render video promosi FGMaps: bingkai deterministik (masa dilangkah) dari scenes.html -> ffmpeg.
//   node tools/promo/render.mjs --aspect 9x16 --lang ms --still 1,5,9 --out promo_out/stills
//   node tools/promo/render.mjs --aspect 16x9 --lang en --video promo_out/video/16x9_en_noaudio.mp4
import { createRequire } from 'node:module';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const args = Object.fromEntries(process.argv.slice(2).reduce((a, v, i, all) => (v.startsWith('--') ? [...a, [v.slice(2), all[i + 1]]] : a), []));
const aspect = args.aspect ?? '16x9', lang = args.lang ?? 'ms', fps = Number(args.fps ?? 30);
const [W, H] = aspect === '9x16' ? [1080, 1920] : [1920, 1080];

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.ttf': 'font/ttf', '.jpg': 'image/jpeg' };
const server = http.createServer((req, res) => {
  const p = path.resolve(ROOT, '.' + decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!p.startsWith(ROOT + path.sep) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] ?? 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
page.on('pageerror', e => console.error('PAGE ERROR', e.message));
page.on('response', r => { if (r.status() >= 400) console.error('HTTP', r.status(), r.url()); });
page.on('console', m => { if (m.type() === 'error') console.error('console:', m.text()); });
await page.goto(`${base}/tools/promo/scenes.html?a=${aspect}&l=${lang}`);
await page.evaluate(() => window.__ready);
const dur = await page.evaluate(() => window.DUR);

if (args.still) {
  fs.mkdirSync(args.out, { recursive: true });
  for (const t of args.still.split(',').map(Number)) {
    await page.evaluate(t => window.renderFrame(t), t);
    await page.screenshot({ path: path.join(args.out, `${aspect}_${lang}_${String(t).replace('.', '_')}.png`) });
  }
} else if (args.video) {
  fs.mkdirSync(path.dirname(args.video), { recursive: true });
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '17', '-pix_fmt', 'yuv420p', '-r', String(fps), '-movflags', '+faststart', args.video], { stdio: ['pipe', 'inherit', 'inherit'] });
  const n = Math.round(dur * fps), t0 = Date.now();
  for (let f = 0; f < n; f++) {
    await page.evaluate(t => window.renderFrame(t), f / fps);
    const buf = await page.screenshot({ type: 'jpeg', quality: 94 });
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    if (f % 150 === 0) console.log(`${aspect}/${lang}: ${f}/${n} (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  console.log('selesai', args.video);
}
await browser.close(); server.close();

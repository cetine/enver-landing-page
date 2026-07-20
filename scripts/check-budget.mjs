import { readdirSync, statSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { gzipSync } from 'node:zlib';

const dist = 'dist/_astro';
let total = 0;
for (const f of readdirSync(dist)) {
  if (!f.endsWith('.js')) continue;
  total += gzipSync(readFileSync(join(dist, f))).length;
}
const kb = (total / 1024).toFixed(1);
console.log(`site JS (gzip, excl. pagefind): ${kb} KB`);
if (total > 15 * 1024) { console.error('BUDGET EXCEEDED (15 KB)'); process.exit(1); }

const images = readdirSync(dist).filter((f) => /\.(avif|webp|png|jpg)$/.test(f));
for (const img of images) {
  const size = statSync(join(dist, img)).size;
  if (size > 120 * 1024) { console.error(`IMAGE TOO BIG: ${img} ${(size / 1024).toFixed(0)} KB`); process.exit(1); }
}
console.log('budget ok');

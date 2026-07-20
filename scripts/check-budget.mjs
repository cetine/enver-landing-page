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
  // Carve-out: the 4K industry-art plates (src/assets/work/plate-*) are flat-color
  // technical drawings rendered at up to 3840w. Their optimized variants exceed the
  // default 120 KB per-image cap but stay comfortably under 400 KB; give any file
  // whose name contains `plate-` that higher ceiling. Everything else keeps 120 KB.
  const cap = img.includes('plate-') ? 400 * 1024 : 120 * 1024;
  if (size > cap) {
    console.error(`IMAGE TOO BIG: ${img} ${(size / 1024).toFixed(0)} KB (cap ${(cap / 1024) | 0} KB)`);
    process.exit(1);
  }
}

// Report the industry-art plate output sizes so the carve-out stays honest.
const plates = images.filter((f) => f.includes('plate-')).sort();
if (plates.length) {
  console.log('industry-art plates (dist):');
  for (const p of plates) console.log(`  ${p}: ${(statSync(join(dist, p)).size / 1024).toFixed(0)} KB`);
}
console.log('budget ok');

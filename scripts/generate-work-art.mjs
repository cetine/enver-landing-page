// Generative industry art plates (4K) — one deterministic SVG composition per
// industry, rendered to PNG with sharp. NO stock photos, NO AI-photo look:
// every coordinate is computed, every plate shares ONE technical-drawing style
// derived from the site's design system (blueprint grid, gray strokes, a single
// emerald accent element, a bottom-right title block).
//
// Run: `node scripts/generate-work-art.mjs` → writes src/assets/work/*.png
import sharp from 'sharp';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// ---------------------------------------------------------------------------
// Shared visual system (identical across all five plates)
// ---------------------------------------------------------------------------
const W = 3840;
const H = 2160;
const MARGIN = 240; // composition safe margin
const CELL = 96; // blueprint grid cell at 4K
const X0 = MARGIN;
const X1 = W - MARGIN; // 3600
const Y0 = MARGIN;
const Y1 = H - MARGIN; // 1920
const CX = W / 2; // 1920

const BG = '#0a0a0a';
const GRID = 'rgba(236,236,236,0.05)';
const GRAY = '#9aa1ad';
const EMERALD = '#2fbd8f';
const TITLE_MUTED = 'rgba(236,236,236,0.4)';
const TITLE_BORDER = 'rgba(236,236,236,0.25)';

// Stroke weights at 4K
const W_THIN = 2;
const W_MID = 3;
const W_BOLD = 6;

const r = (n) => Math.round(n * 100) / 100;
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');

// ---- primitive builders (flat strokes only — no blur, no gradients) --------
const line = (x1, y1, x2, y2, stroke, w, op = 1, dash = '') =>
  `<line x1="${r(x1)}" y1="${r(y1)}" x2="${r(x2)}" y2="${r(y2)}" stroke="${stroke}" stroke-width="${w}"` +
  `${op !== 1 ? ` stroke-opacity="${op}"` : ''}${dash ? ` stroke-dasharray="${dash}"` : ''} stroke-linecap="round"/>`;

const circle = (cx, cy, rad, stroke, w, op = 1) =>
  `<circle cx="${r(cx)}" cy="${r(cy)}" r="${r(rad)}" fill="none" stroke="${stroke}" stroke-width="${w}"` +
  `${op !== 1 ? ` stroke-opacity="${op}"` : ''}/>`;

const dot = (cx, cy, rad, fill, stroke = 'none', w = 0) =>
  `<circle cx="${r(cx)}" cy="${r(cy)}" r="${r(rad)}" fill="${fill}"` +
  `${stroke !== 'none' ? ` stroke="${stroke}" stroke-width="${w}"` : ''}/>`;

const poly = (pts, stroke, w, op = 1, fill = 'none') =>
  `<polygon points="${pts.map((p) => `${r(p[0])},${r(p[1])}`).join(' ')}" fill="${fill}" stroke="${stroke}" stroke-width="${w}"` +
  `${op !== 1 ? ` stroke-opacity="${op}"` : ''} stroke-linejoin="round"/>`;

const pline = (pts, stroke, w, op = 1, dash = '') =>
  `<polyline points="${pts.map((p) => `${r(p[0])},${r(p[1])}`).join(' ')}" fill="none" stroke="${stroke}" stroke-width="${w}"` +
  `${op !== 1 ? ` stroke-opacity="${op}"` : ''}${dash ? ` stroke-dasharray="${dash}"` : ''} stroke-linejoin="round" stroke-linecap="round"/>`;

// ---- blueprint grid (single path, 1px lines) -------------------------------
function grid() {
  let d = '';
  for (let x = 0; x <= W; x += CELL) d += `M${x} 0V${H}`;
  for (let y = 0; y <= H; y += CELL) d += `M0 ${y}H${W}`;
  return `<path d="${d}" stroke="${GRID}" stroke-width="1" fill="none"/>`;
}

// ---- title block (bottom-right, constant across plates) --------------------
const TB_W = 1200;
const TB_H = 120;
const TB_X = X1 - TB_W; // 2400
const TB_Y = Y1 - TB_H; // 1800
function titleBlock(label) {
  return [
    // opaque field masks the grid behind for a clean technical title block
    `<rect x="${TB_X}" y="${TB_Y}" width="${TB_W}" height="${TB_H}" fill="${BG}" stroke="${TITLE_BORDER}" stroke-width="1"/>`,
    `<text x="${TB_X + 40}" y="${TB_Y + 58}" font-family="'Courier New', Courier, monospace" font-size="40" letter-spacing="8" fill="${EMERALD}">${esc(label)}</text>`,
    `<text x="${TB_X + 40}" y="${TB_Y + 98}" font-family="'Courier New', Courier, monospace" font-size="26" letter-spacing="6" fill="${TITLE_MUTED}">ENVER CETIN · WORK</text>`,
  ].join('\n');
}

// ---- isometric projection (shared by plates 02 + 04) -----------------------
const RX = Math.cos(Math.PI / 6);
const RY = Math.sin(Math.PI / 6);
const LX = -Math.cos(Math.PI / 6);
const LY = Math.sin(Math.PI / 6);
// point from origin o, moving `rr` px along right axis, `ll` along left, `uu` up
const P = (o, rr, ll, uu) => [o.x + rr * RX + ll * LX, o.y + rr * RY + ll * LY - uu];

// ===========================================================================
// PLATE 01 — BFSI · transaction-network lattice
// ===========================================================================
function plate01() {
  const cx = CX;
  const cy = 1000;
  const parts = [];
  const nodes = [];

  const outer = 14;
  const rOuter = 720;
  for (let i = 0; i < outer; i++) {
    const a = (i / outer) * Math.PI * 2 - Math.PI / 2;
    nodes.push({ x: cx + rOuter * Math.cos(a), y: cy + rOuter * Math.sin(a), ring: 'o' });
  }
  const inner = 8;
  const rInner = 420;
  for (let i = 0; i < inner; i++) {
    const a = (i / inner) * Math.PI * 2 - Math.PI / 2 + Math.PI / inner;
    nodes.push({ x: cx + rInner * Math.cos(a), y: cy + rInner * Math.sin(a), ring: 'i' });
  }
  const rCore = 140;
  nodes.push({ x: cx + rCore * Math.cos(Math.PI / 4), y: cy + rCore * Math.sin(Math.PI / 4), ring: 'c' });
  nodes.push({ x: cx + rCore * Math.cos((5 * Math.PI) / 4), y: cy + rCore * Math.sin((5 * Math.PI) / 4), ring: 'c' });

  const O = (i) => i; // outer index 0..13
  const I = (i) => outer + i; // inner index
  const C = (i) => outer + inner + i; // core index

  // gray edges
  const edges = [];
  for (let i = 0; i < outer; i++) edges.push([O(i), O((i + 1) % outer)]); // outer ring
  for (let i = 0; i < inner; i++) edges.push([I(i), I((i + 1) % inner)]); // inner ring
  for (let i = 0; i < inner; i++) edges.push([I(i), O((i * 2) % outer)]); // spokes out
  for (let i = 0; i < inner; i++) edges.push([I(i), C(i % 2)]); // spokes to core
  edges.push([C(0), C(1)]);

  for (const [a, b] of edges) {
    parts.push(line(nodes[a].x, nodes[a].y, nodes[b].x, nodes[b].y, GRAY, W_THIN, 0.4));
  }
  // gray nodes
  for (const n of nodes) parts.push(dot(n.x, n.y, 9, GRAY, BG, 2));

  // anomaly path: 3 edges + 2 nodes highlighted emerald
  const path = [O(3), I(1), C(0), I(5)];
  for (let i = 0; i < path.length - 1; i++) {
    parts.push(line(nodes[path[i]].x, nodes[path[i]].y, nodes[path[i + 1]].x, nodes[path[i + 1]].y, EMERALD, W_BOLD));
  }
  for (const idx of [I(1), C(0)]) parts.push(dot(nodes[idx].x, nodes[idx].y, 15, EMERALD));

  return parts.join('\n');
}

// ===========================================================================
// PLATE 02 — Automotive & Manufacturing · isometric assembly line
// ===========================================================================
function plate02() {
  const parts = [];
  const baseY = 1180; // conveyor upper line; boxes' front-bottom vertex sits here
  // Non-cubic box: a cube is degenerate in this isometry (back-top projects onto
  // front-bottom → flat hexagon). Taller-than-footprint reads as a solid machine,
  // sharing the exact projection language of plate 04.
  const bw = 240;
  const bd = 240;
  const bh = 340;
  const count = 6;
  const emeraldIdx = 3;
  const xStart = 520;
  const xEnd = 3320;
  const step = (xEnd - xStart) / (count - 1);

  // conveyor: double baseline (full composition width) + roller ticks every 96px.
  // Drawn first; opaque box faces mask it so the belt reads as running behind them.
  parts.push(line(260, baseY, 3580, baseY, GRAY, W_MID, 0.5));
  parts.push(line(260, baseY + 24, 3580, baseY + 24, GRAY, W_THIN, 0.3));
  for (let x = Math.ceil(260 / CELL) * CELL; x <= 3580; x += CELL) {
    parts.push(line(x, baseY, x, baseY + 24, GRAY, W_THIN, 0.4));
  }

  for (let i = 0; i < count; i++) {
    const o = { x: xStart + i * step, y: baseY };
    const em = i === emeraldIdx;
    const stroke = em ? EMERALD : GRAY;
    const w = em ? W_BOLD : W_MID;
    const op = em ? 1 : 0.6;
    const dw = em ? W_MID : W_THIN; // detail weight

    const b0 = P(o, 0, 0, 0); // front-bottom (on the belt line)
    const b1 = P(o, bw, 0, 0);
    const b2 = P(o, 0, bd, 0);
    const t0 = P(o, 0, 0, bh);
    const t1 = P(o, bw, 0, bh);
    const t2 = P(o, 0, bd, bh);
    const t3 = P(o, bw, bd, bh);

    // closed box: opaque faces (mask grid + belt behind), all edges drawn
    parts.push(poly([b0, b2, t2, t0], stroke, w, op, BG)); // left side face
    parts.push(poly([b0, b1, t1, t0], stroke, w, op, BG)); // right side face (front)
    parts.push(poly([t0, t1, t3, t2], stroke, w, op, BG)); // top face

    // interior detail on the front (right) face — dial + panel line = "machine"
    const face = (u, v) => P(o, bw * u, 0, bh * v);
    const dc = face(0.5, 0.56);
    parts.push(circle(dc[0], dc[1], 40, stroke, dw, op * 0.9));
    parts.push(line(...face(0.24, 0.3), ...face(0.76, 0.3), stroke, dw, op * 0.85));
  }
  return parts.join('\n');
}

// ===========================================================================
// PLATE 03 — Logistics & Supply Chain · route map
// ===========================================================================
function plate03() {
  const parts = [];
  const D = [
    [360, 520], [760, 1200], [1180, 460], [1520, 980], [1980, 1480],
    [2180, 620], [2560, 1180], [2980, 780], [3320, 1340], [3460, 460],
  ].map(([x, y]) => ({ x, y }));

  // orthogonal + 45° router: straight along the longer axis, then a 45° dogleg
  const ortho = (a, b) => {
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const adx = Math.abs(dx);
    const ady = Math.abs(dy);
    const diag = Math.min(adx, ady);
    const sx = Math.sign(dx);
    const sy = Math.sign(dy);
    const pts = [[a.x, a.y]];
    if (adx > ady) pts.push([a.x + sx * (adx - diag), a.y]);
    else pts.push([a.x, a.y + sy * (ady - diag)]);
    pts.push([b.x, b.y]);
    return pts;
  };

  const grayConn = [
    [0, 1], [1, 3], [2, 3], [3, 5], [5, 6], [6, 7],
    [7, 8], [4, 6], [0, 2], [9, 7], [1, 4], [5, 9],
  ];
  for (const [a, b] of grayConn) parts.push(pline(ortho(D[a], D[b]), GRAY, W_THIN, 0.4));

  // depot markers
  for (const d of D) {
    parts.push(`<rect x="${r(d.x - 11)}" y="${r(d.y - 11)}" width="22" height="22" fill="${BG}" stroke="${GRAY}" stroke-width="${W_THIN}" stroke-opacity="0.6"/>`);
  }

  // ONE continuous emerald route crossing the canvas (left edge → right edge)
  const emerald = [[280, D[0].y]]
    .concat(ortho(D[0], D[3]))
    .concat(ortho(D[3], D[6]))
    .concat(ortho(D[6], D[8]))
    .concat([[3560, D[8].y]]);
  parts.push(pline(emerald, EMERALD, W_BOLD));
  for (const i of [0, 3, 6, 8]) {
    parts.push(`<rect x="${r(D[i].x - 13)}" y="${r(D[i].y - 13)}" width="26" height="26" fill="${BG}" stroke="${EMERALD}" stroke-width="${W_BOLD}"/>`);
  }

  return parts.join('\n');
}

// ===========================================================================
// PLATE 04 — EPCM & Construction · isometric building wireframe
// ===========================================================================
function plate04() {
  const parts = [];
  const o = { x: 1780, y: 1450 }; // front-bottom vertex
  const wb = 420;
  const db = 420;
  const storeyH = 130;
  const storeys = 9;
  const totalH = storeyH * storeys;
  const compliance = 6; // emerald plane level

  const floor = (h) => [P(o, 0, 0, h), P(o, wb, 0, h), P(o, wb, db, h), P(o, 0, db, h)];

  // floor plates
  for (let k = 0; k <= storeys; k++) {
    if (k === compliance) continue;
    const op = k === 0 || k === storeys ? 0.6 : 0.4;
    parts.push(poly(floor(k * storeyH), GRAY, k === 0 || k === storeys ? W_MID : W_THIN, op));
  }
  // vertical edges
  for (const [rr, ll] of [[0, 0], [wb, 0], [0, db], [wb, db]]) {
    parts.push(line(...P(o, rr, ll, 0), ...P(o, rr, ll, totalH), GRAY, W_MID, 0.55));
  }

  // dimension line + storey ticks (left of the building)
  const dimX = P(o, 0, db, 0)[0] - 130;
  const topY = P(o, 0, db, totalH)[1];
  const botY = P(o, 0, db, 0)[1];
  parts.push(line(dimX, topY, dimX, botY, GRAY, W_THIN, 0.5));
  for (let k = 0; k <= storeys; k++) {
    const y = P(o, 0, db, k * storeyH)[1];
    parts.push(line(dimX - 16, y, dimX + 16, y, GRAY, W_THIN, 0.5));
  }

  // section line (dashed horizontal cut) with end ticks
  const secH = 4 * storeyH;
  const secL = P(o, 0, db, secH);
  const secR = P(o, wb, 0, secH);
  parts.push(line(secL[0] - 220, secL[1] + 60, secR[0] + 220, secR[1] + 60, GRAY, W_THIN, 0.4, '28 22'));

  // emerald horizontal compliance plane — outline + flat hatch strokes
  const cp = floor(compliance * storeyH);
  parts.push(poly(cp, EMERALD, W_BOLD));
  for (let t = 1; t <= 4; t++) {
    const f = t / 5;
    const a = [cp[0][0] + (cp[1][0] - cp[0][0]) * f, cp[0][1] + (cp[1][1] - cp[0][1]) * f];
    const b = [cp[3][0] + (cp[2][0] - cp[3][0]) * f, cp[3][1] + (cp[2][1] - cp[3][1]) * f];
    parts.push(line(a[0], a[1], b[0], b[1], EMERALD, W_THIN, 0.8));
  }

  return parts.join('\n');
}

// ===========================================================================
// PLATE 05 — Strategic AI & Enterprise · concentric operating-model rings
// ===========================================================================
function plate05() {
  const parts = [];
  const cx = CX;
  const cy = 1060;
  const radii = [300, 470, 640, 810];
  const outer = radii[radii.length - 1];

  // rings
  radii.forEach((rad, i) => parts.push(circle(cx, cy, rad, GRAY, i === radii.length - 1 ? W_MID : W_THIN, 0.5)));

  // radial spokes (12) from inner ring to outer ring
  const spokes = 12;
  for (let i = 0; i < spokes; i++) {
    const a = (i / spokes) * Math.PI * 2;
    parts.push(line(cx + radii[0] * Math.cos(a), cy + radii[0] * Math.sin(a), cx + outer * Math.cos(a), cy + outer * Math.sin(a), GRAY, W_THIN, 0.35));
  }
  // minor tick marks around the outer ring (every 15°)
  for (let i = 0; i < 24; i++) {
    const a = (i / 24) * Math.PI * 2;
    parts.push(line(cx + outer * Math.cos(a), cy + outer * Math.sin(a), cx + (outer + 22) * Math.cos(a), cy + (outer + 22) * Math.sin(a), GRAY, W_THIN, 0.5));
  }
  // hub
  parts.push(dot(cx, cy, 10, GRAY));

  // ONE emerald arc segment (~70°) on ring r=640
  const ar = 640;
  const a0 = (-15 * Math.PI) / 180;
  const a1 = (55 * Math.PI) / 180;
  const sx = cx + ar * Math.cos(a0);
  const sy = cy + ar * Math.sin(a0);
  const ex = cx + ar * Math.cos(a1);
  const ey = cy + ar * Math.sin(a1);
  parts.push(`<path d="M${r(sx)} ${r(sy)} A ${ar} ${ar} 0 0 1 ${r(ex)} ${r(ey)}" fill="none" stroke="${EMERALD}" stroke-width="${W_BOLD}" stroke-linecap="round"/>`);

  return parts.join('\n');
}

// ---------------------------------------------------------------------------
const PLATES = [
  { file: 'plate-01-bfsi.png', label: 'PLATE 01 · BFSI', motif: plate01 },
  { file: 'plate-02-automotive.png', label: 'PLATE 02 · AUTOMOTIVE & MANUFACTURING', motif: plate02 },
  { file: 'plate-03-logistics.png', label: 'PLATE 03 · LOGISTICS & SUPPLY CHAIN', motif: plate03 },
  { file: 'plate-04-construction.png', label: 'PLATE 04 · EPCM & CONSTRUCTION', motif: plate04 },
  { file: 'plate-05-strategic.png', label: 'PLATE 05 · STRATEGIC AI & ENTERPRISE', motif: plate05 },
];

function compose(label, motif) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
<rect width="${W}" height="${H}" fill="${BG}"/>
${grid()}
${motif}
${titleBlock(label)}
</svg>`;
}

const outDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'assets', 'work');
mkdirSync(outDir, { recursive: true });

for (const { file, label, motif } of PLATES) {
  const svg = compose(label, motif());
  await sharp(Buffer.from(svg)).png({ compressionLevel: 9 }).toFile(join(outDir, file));
  console.log(`${file} written`);
}
console.log('all work-art plates written to src/assets/work/');

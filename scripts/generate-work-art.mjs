// Generative industry art plates — one deterministic SVG composition per
// industry, rendered to PNG with sharp. NO stock photos, NO AI-photo look:
// every coordinate is computed, every plate shares ONE technical-drawing style
// derived from the site's design system (blueprint grid, gray strokes, a single
// emerald accent element).
//
// Each plate is emitted in TWO themes (dark / light) and TWO formats
// (standard 16:9 · wide 3840×1080), i.e. 4 files per industry → 20 files total.
// The motif code is written ONCE and parameterized by a palette + a per-format
// layout object; the light theme is the dark system inverted. The STANDARD
// plate carries a bottom-right title block; the WIDE plate drops it and instead
// recomposes (does not squash) into a left-third industry label + right-two-
// thirds motif, the label alone identifying the plate.
//
// Run: `node scripts/generate-work-art.mjs` → writes src/assets/work/*.png
import sharp from 'sharp';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// ---------------------------------------------------------------------------
// Palettes — the ONLY thing that differs between dark and light. Same opacity
// scheme in both; the light theme is the dark technical-drawing system inverted.
// ---------------------------------------------------------------------------
const DARK = {
  bg: '#0a0a0a',
  grid: 'rgba(236,236,236,0.05)',
  gray: '#9aa1ad',
  emerald: '#2fbd8f',
  titleMuted: 'rgba(236,236,236,0.4)',
  titleBorder: 'rgba(236,236,236,0.25)',
  fgStrong: '#ececec',
};
const LIGHT = {
  bg: '#fafafa',
  grid: 'rgba(22,24,29,0.05)',
  gray: '#5f6572',
  emerald: '#0e7c5b',
  titleMuted: 'rgba(22,24,29,0.4)',
  titleBorder: 'rgba(22,24,29,0.25)',
  fgStrong: '#16181d',
};

// ---------------------------------------------------------------------------
// Formats — canvas + (standard-only) title-block metrics. `standard` reproduces
// the original 16:9 plate exactly (byte-for-byte in the dark theme); `wide`
// recomposes and carries no title block, so it needs only canvas + margin.
// ---------------------------------------------------------------------------
const FORMATS = {
  standard: { W: 3840, H: 2160, margin: 240, tbW: 1200, tbH: 120, pad: 40, y1: 58, y2: 98, fs1: 40, fs2: 26, ls1: 8, ls2: 6 },
  wide: { W: 3840, H: 1080, margin: 120 },
};

const CELL = 96; // blueprint grid cell (constant in both formats)
const CX_STD = 1920; // standard canvas centre-x

// Stroke weights (constant across formats — geometry scales, weights do not)
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

const rect = (x, y, w, h, fill, stroke, sw, op = 1) =>
  `<rect x="${r(x)}" y="${r(y)}" width="${r(w)}" height="${r(h)}" fill="${fill}"` +
  `${stroke ? ` stroke="${stroke}" stroke-width="${sw}"` : ''}${op !== 1 ? ` stroke-opacity="${op}"` : ''}/>`;

// ---- blueprint grid (single path, 1px lines) -------------------------------
function grid(pal, g) {
  let d = '';
  for (let x = 0; x <= g.W; x += CELL) d += `M${x} 0V${g.H}`;
  for (let y = 0; y <= g.H; y += CELL) d += `M0 ${y}H${g.W}`;
  return `<path d="${d}" stroke="${pal.grid}" stroke-width="1" fill="none"/>`;
}

// ---- title block (bottom-right, constant motif across plates) --------------
function titleBlock(pal, g, label) {
  const tbX = g.W - g.margin - g.tbW;
  const tbY = g.H - g.margin - g.tbH;
  return [
    // opaque field masks the grid behind for a clean technical title block
    rect(tbX, tbY, g.tbW, g.tbH, pal.bg, pal.titleBorder, 1),
    `<text x="${tbX + g.pad}" y="${tbY + g.y1}" font-family="'Courier New', Courier, monospace" font-size="${g.fs1}" letter-spacing="${g.ls1}" fill="${pal.emerald}">${esc(label)}</text>`,
    `<text x="${tbX + g.pad}" y="${tbY + g.y2}" font-family="'Courier New', Courier, monospace" font-size="${g.fs2}" letter-spacing="${g.ls2}" fill="${pal.titleMuted}">ENVER CETIN · WORK</text>`,
  ].join('\n');
}

// ---- wide-format industry label (typeset INSIDE the left third) ------------
// Large mono caps, auto-fit + word-wrapped to the left third, vertically
// centred; colour is the theme's foreground-strong.
function wideLabel(pal, g, industry) {
  const maxW = g.W / 3 - 160; // usable width inside the left third (~1120)
  const ls = 24;
  const words = industry.toUpperCase().split(/\s+/);
  const longest = Math.max(...words.map((w) => w.length));
  const adv = (f) => f * 0.62 + ls; // Courier advance ≈ 0.62em + letter-spacing
  let font = 120;
  while (font > 48 && longest * adv(font) > maxW) font -= 2;
  const lines = [];
  let cur = '';
  for (const w of words) {
    const trial = cur ? `${cur} ${w}` : w;
    if (cur && trial.length * adv(font) > maxW) { lines.push(cur); cur = w; } else cur = trial;
  }
  if (cur) lines.push(cur);
  const lineH = font * 1.2;
  const startBaseline = g.H / 2 - (lines.length * lineH) / 2 + font * 0.82;
  return lines
    .map((ln, i) =>
      `<text x="${g.margin}" y="${r(startBaseline + i * lineH)}" font-family="'Courier New', Courier, monospace" font-size="${font}" letter-spacing="${ls}" fill="${pal.fgStrong}">${esc(ln)}</text>`)
    .join('\n');
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
function plate01(pal, L) {
  const { cx, cy, rOuter, rInner, rCore, nodeR, emNodeR } = L;
  const parts = [];
  const nodes = [];

  const outer = 14;
  for (let i = 0; i < outer; i++) {
    const a = (i / outer) * Math.PI * 2 - Math.PI / 2;
    nodes.push({ x: cx + rOuter * Math.cos(a), y: cy + rOuter * Math.sin(a), ring: 'o' });
  }
  const inner = 8;
  for (let i = 0; i < inner; i++) {
    const a = (i / inner) * Math.PI * 2 - Math.PI / 2 + Math.PI / inner;
    nodes.push({ x: cx + rInner * Math.cos(a), y: cy + rInner * Math.sin(a), ring: 'i' });
  }
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
    parts.push(line(nodes[a].x, nodes[a].y, nodes[b].x, nodes[b].y, pal.gray, W_THIN, 0.4));
  }
  // gray nodes
  for (const n of nodes) parts.push(dot(n.x, n.y, nodeR, pal.gray, pal.bg, 2));

  // anomaly path: 3 edges + 2 nodes highlighted emerald
  const path = [O(3), I(1), C(0), I(5)];
  for (let i = 0; i < path.length - 1; i++) {
    parts.push(line(nodes[path[i]].x, nodes[path[i]].y, nodes[path[i + 1]].x, nodes[path[i + 1]].y, pal.emerald, W_BOLD));
  }
  for (const idx of [I(1), C(0)]) parts.push(dot(nodes[idx].x, nodes[idx].y, emNodeR, pal.emerald));

  return parts.join('\n');
}

// ===========================================================================
// PLATE 02 — Automotive & Manufacturing · isometric assembly line
// ===========================================================================
function plate02(pal, L) {
  const { baseY, bw, bd, bh, count, emeraldIdx, xStart, xEnd, beltL, beltR } = L;
  const parts = [];
  const step = (xEnd - xStart) / (count - 1);

  // conveyor: double baseline + roller ticks every CELL px. Drawn first; opaque
  // box faces mask it so the belt reads as running behind them.
  parts.push(line(beltL, baseY, beltR, baseY, pal.gray, W_MID, 0.5));
  parts.push(line(beltL, baseY + 24, beltR, baseY + 24, pal.gray, W_THIN, 0.3));
  for (let x = Math.ceil(beltL / CELL) * CELL; x <= beltR; x += CELL) {
    parts.push(line(x, baseY, x, baseY + 24, pal.gray, W_THIN, 0.4));
  }

  for (let i = 0; i < count; i++) {
    const o = { x: xStart + i * step, y: baseY };
    const em = i === emeraldIdx;
    const stroke = em ? pal.emerald : pal.gray;
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
    parts.push(poly([b0, b2, t2, t0], stroke, w, op, pal.bg)); // left side face
    parts.push(poly([b0, b1, t1, t0], stroke, w, op, pal.bg)); // right side face (front)
    parts.push(poly([t0, t1, t3, t2], stroke, w, op, pal.bg)); // top face

    // interior detail on the front (right) face — dial + panel line = "machine"
    const face = (u, v) => P(o, bw * u, 0, bh * v);
    const dc = face(0.5, 0.56);
    parts.push(circle(dc[0], dc[1], Math.round(bh * 0.118), stroke, dw, op * 0.9));
    parts.push(line(...face(0.24, 0.3), ...face(0.76, 0.3), stroke, dw, op * 0.85));
  }
  return parts.join('\n');
}

// ===========================================================================
// PLATE 03 — Logistics & Supply Chain · route map
// ===========================================================================
function plate03(pal, L) {
  const { pts, leftEdge, rightEdge, mg, me } = L;
  const parts = [];
  const D = pts;

  // orthogonal + 45° router: straight along the longer axis, then a 45° dogleg
  const ortho = (a, b) => {
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const adx = Math.abs(dx);
    const ady = Math.abs(dy);
    const diag = Math.min(adx, ady);
    const sx = Math.sign(dx);
    const sy = Math.sign(dy);
    const p = [[a.x, a.y]];
    if (adx > ady) p.push([a.x + sx * (adx - diag), a.y]);
    else p.push([a.x, a.y + sy * (ady - diag)]);
    p.push([b.x, b.y]);
    return p;
  };

  const grayConn = [
    [0, 1], [1, 3], [2, 3], [3, 5], [5, 6], [6, 7],
    [7, 8], [4, 6], [0, 2], [9, 7], [1, 4], [5, 9],
  ];
  for (const [a, b] of grayConn) parts.push(pline(ortho(D[a], D[b]), pal.gray, W_THIN, 0.4));

  // depot markers
  for (const d of D) {
    parts.push(rect(d.x - mg, d.y - mg, mg * 2, mg * 2, pal.bg, pal.gray, W_THIN, 0.6));
  }

  // ONE continuous emerald route crossing the canvas (left edge → right edge)
  const emerald = [[leftEdge, D[0].y]]
    .concat(ortho(D[0], D[3]))
    .concat(ortho(D[3], D[6]))
    .concat(ortho(D[6], D[8]))
    .concat([[rightEdge, D[8].y]]);
  parts.push(pline(emerald, pal.emerald, W_BOLD));
  for (const i of [0, 3, 6, 8]) {
    parts.push(rect(D[i].x - me, D[i].y - me, me * 2, me * 2, pal.bg, pal.emerald, W_BOLD));
  }

  return parts.join('\n');
}

// ===========================================================================
// PLATE 04 — EPCM & Construction · isometric building wireframe
// ===========================================================================
function plate04(pal, L) {
  const { o, wb, db, storeyH, storeys, compliance, dimOffset, dimTick, secExtend, secLower, dash } = L;
  const parts = [];
  const totalH = storeyH * storeys;

  const floor = (h) => [P(o, 0, 0, h), P(o, wb, 0, h), P(o, wb, db, h), P(o, 0, db, h)];

  // floor plates
  for (let k = 0; k <= storeys; k++) {
    if (k === compliance) continue;
    const op = k === 0 || k === storeys ? 0.6 : 0.4;
    parts.push(poly(floor(k * storeyH), pal.gray, k === 0 || k === storeys ? W_MID : W_THIN, op));
  }
  // vertical edges
  for (const [rr, ll] of [[0, 0], [wb, 0], [0, db], [wb, db]]) {
    parts.push(line(...P(o, rr, ll, 0), ...P(o, rr, ll, totalH), pal.gray, W_MID, 0.55));
  }

  // dimension line + storey ticks (left of the building)
  const dimX = P(o, 0, db, 0)[0] - dimOffset;
  const topY = P(o, 0, db, totalH)[1];
  const botY = P(o, 0, db, 0)[1];
  parts.push(line(dimX, topY, dimX, botY, pal.gray, W_THIN, 0.5));
  for (let k = 0; k <= storeys; k++) {
    const y = P(o, 0, db, k * storeyH)[1];
    parts.push(line(dimX - dimTick, y, dimX + dimTick, y, pal.gray, W_THIN, 0.5));
  }

  // section line (dashed horizontal cut) with end ticks
  const secH = 4 * storeyH;
  const secL = P(o, 0, db, secH);
  const secR = P(o, wb, 0, secH);
  parts.push(line(secL[0] - secExtend, secL[1] + secLower, secR[0] + secExtend, secR[1] + secLower, pal.gray, W_THIN, 0.4, dash));

  // emerald horizontal compliance plane — outline + flat hatch strokes
  const cp = floor(compliance * storeyH);
  parts.push(poly(cp, pal.emerald, W_BOLD));
  for (let t = 1; t <= 4; t++) {
    const f = t / 5;
    const a = [cp[0][0] + (cp[1][0] - cp[0][0]) * f, cp[0][1] + (cp[1][1] - cp[0][1]) * f];
    const b = [cp[3][0] + (cp[2][0] - cp[3][0]) * f, cp[3][1] + (cp[2][1] - cp[3][1]) * f];
    parts.push(line(a[0], a[1], b[0], b[1], pal.emerald, W_THIN, 0.8));
  }

  return parts.join('\n');
}

// ===========================================================================
// PLATE 05 — Strategic AI & Enterprise · concentric operating-model rings
// ===========================================================================
function plate05(pal, L) {
  const { cx, cy, radii, hubR, nodeR, emNodeR, tickLen } = L;
  const parts = [];
  const outer = radii[radii.length - 1];

  // rings
  radii.forEach((rad, i) => parts.push(circle(cx, cy, rad, pal.gray, i === radii.length - 1 ? W_MID : W_THIN, 0.5)));

  // radial spokes (12) from inner ring to outer ring
  const spokes = 12;
  for (let i = 0; i < spokes; i++) {
    const a = (i / spokes) * Math.PI * 2;
    parts.push(line(cx + radii[0] * Math.cos(a), cy + radii[0] * Math.sin(a), cx + outer * Math.cos(a), cy + outer * Math.sin(a), pal.gray, W_THIN, 0.35));
  }
  // minor tick marks around the outer ring (every 15°)
  for (let i = 0; i < 24; i++) {
    const a = (i / 24) * Math.PI * 2;
    parts.push(line(cx + outer * Math.cos(a), cy + outer * Math.sin(a), cx + (outer + tickLen) * Math.cos(a), cy + (outer + tickLen) * Math.sin(a), pal.gray, W_THIN, 0.5));
  }
  // hub
  parts.push(dot(cx, cy, hubR, pal.gray));

  // small filled nodes where each spoke crosses ring-2 and ring-3 — turns the
  // abstract lattice into a legible "operating model" of tiered nodes.
  for (let i = 0; i < spokes; i++) {
    const a = (i / spokes) * Math.PI * 2;
    for (const rr of [radii[1], radii[2]]) {
      parts.push(dot(cx + rr * Math.cos(a), cy + rr * Math.sin(a), nodeR, pal.gray));
    }
  }

  // ONE emerald arc segment (~70°) on ring-3
  const ar = radii[2];
  const a0 = (-15 * Math.PI) / 180;
  const a1 = (55 * Math.PI) / 180;
  const sx = cx + ar * Math.cos(a0);
  const sy = cy + ar * Math.sin(a0);
  const ex = cx + ar * Math.cos(a1);
  const ey = cy + ar * Math.sin(a1);
  parts.push(`<path d="M${r(sx)} ${r(sy)} A ${ar} ${ar} 0 0 1 ${r(ex)} ${r(ey)}" fill="none" stroke="${pal.emerald}" stroke-width="${W_BOLD}" stroke-linecap="round"/>`);
  // emerald filled node terminating the arc — anchors the highlighted path
  parts.push(dot(ex, ey, emNodeR, pal.emerald));

  return parts.join('\n');
}

// ---------------------------------------------------------------------------
// Per-plate layouts. `standard` reproduces the original 16:9 composition; `wide`
// recomposes the motif into the right two thirds at the shorter 1080 height.
// Wide motifs centre around x≈2560 (right-two-thirds centre) / y=540, sized to
// clear the left-third label and stay inside the canvas.
// ---------------------------------------------------------------------------
const PLATES = [
  {
    slug: 'plate-01-bfsi', label: 'PLATE 01 · BFSI', industry: 'BFSI', motif: plate01,
    layout: {
      standard: { cx: CX_STD, cy: 1000, rOuter: 720, rInner: 420, rCore: 140, nodeR: 9, emNodeR: 15 },
      wide: { cx: 2560, cy: 540, rOuter: 390, rInner: 228, rCore: 76, nodeR: 8, emNodeR: 13 },
    },
  },
  {
    slug: 'plate-02-automotive', label: 'PLATE 02 · AUTOMOTIVE & MANUFACTURING', industry: 'Automotive & Manufacturing', motif: plate02,
    layout: {
      standard: { baseY: 1180, bw: 240, bd: 240, bh: 340, count: 6, emeraldIdx: 3, xStart: 520, xEnd: 3320, beltL: 260, beltR: 3580 },
      wide: { baseY: 780, bw: 150, bd: 150, bh: 300, count: 6, emeraldIdx: 3, xStart: 1600, xEnd: 3520, beltL: 1440, beltR: 3680 },
    },
  },
  {
    slug: 'plate-03-logistics', label: 'PLATE 03 · LOGISTICS & SUPPLY CHAIN', industry: 'Logistics & Supply Chain', motif: plate03,
    layout: {
      standard: {
        pts: [
          [360, 520], [760, 1200], [1180, 460], [1520, 980], [1980, 1480],
          [2180, 620], [2560, 1180], [2980, 780], [3320, 1340], [3460, 460],
        ].map(([x, y]) => ({ x, y })),
        leftEdge: 280, rightEdge: 3560, mg: 11, me: 13,
      },
      // point cloud (orig bbox centre 1910/970) mapped uniformly (s≈0.627) around 2560/540
      wide: {
        pts: [
          [360, 520], [760, 1200], [1180, 460], [1520, 980], [1980, 1480],
          [2180, 620], [2560, 1180], [2980, 780], [3320, 1340], [3460, 460],
        ].map(([x, y]) => ({ x: 2560 + (x - 1910) * 0.627, y: 540 + (y - 970) * 0.627 })),
        leftEdge: 1400, rightEdge: 3720, mg: 7, me: 9,
      },
    },
  },
  {
    slug: 'plate-04-construction', label: 'PLATE 04 · EPCM & CONSTRUCTION', industry: 'EPCM & Construction', motif: plate04,
    layout: {
      standard: { o: { x: 1780, y: 1450 }, wb: 420, db: 420, storeyH: 130, storeys: 9, compliance: 6, dimOffset: 130, dimTick: 16, secExtend: 220, secLower: 60, dash: '28 22' },
      wide: { o: { x: 2560, y: 820 }, wb: 230, db: 230, storeyH: 72, storeys: 9, compliance: 6, dimOffset: 72, dimTick: 9, secExtend: 120, secLower: 33, dash: '16 12' },
    },
  },
  {
    slug: 'plate-05-strategic', label: 'PLATE 05 · STRATEGIC AI & ENTERPRISE', industry: 'Strategic AI & Enterprise', motif: plate05,
    layout: {
      standard: { cx: CX_STD, cy: 1060, radii: [300, 470, 640, 810], hubR: 10, nodeR: 10, emNodeR: 16, tickLen: 22 },
      wide: { cx: 2560, cy: 540, radii: [140, 220, 300, 380], hubR: 6, nodeR: 7, emNodeR: 12, tickLen: 11 },
    },
  },
];

function compose(pal, format, plate) {
  const g = FORMATS[format];
  const L = plate.layout[format];
  const body = [
    `<rect width="${g.W}" height="${g.H}" fill="${pal.bg}"/>`,
    grid(pal, g),
    format === 'wide' ? wideLabel(pal, g, plate.industry) : null,
    plate.motif(pal, L),
    // Title block on STANDARD only. WIDE is identified by its large left-third
    // label alone, so the small title box would be redundant there.
    format === 'wide' ? null : titleBlock(pal, g, plate.label),
  ].filter(Boolean).join('\n');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${g.W}" height="${g.H}" viewBox="0 0 ${g.W} ${g.H}">\n${body}\n</svg>`;
}

const outDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'assets', 'work');
mkdirSync(outDir, { recursive: true });

// theme × format → filename suffix
const VARIANTS = [
  { theme: DARK, format: 'standard', suffix: '' },
  { theme: LIGHT, format: 'standard', suffix: '-light' },
  { theme: DARK, format: 'wide', suffix: '-wide' },
  { theme: LIGHT, format: 'wide', suffix: '-wide-light' },
];

for (const plate of PLATES) {
  for (const { theme, format, suffix } of VARIANTS) {
    const file = `${plate.slug}${suffix}.png`;
    const svg = compose(theme, format, plate);
    await sharp(Buffer.from(svg)).png({ compressionLevel: 9 }).toFile(join(outDir, file));
    console.log(`${file} written`);
  }
}
console.log(`all work-art plates written to src/assets/work/ (${PLATES.length * VARIANTS.length} files)`);

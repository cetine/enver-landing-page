// Generative industry art plates — one deterministic SVG composition per
// industry, sharing ONE technical-drawing style derived from the site's design
// system (blueprint grid, gray strokes, a single emerald accent element). NO
// stock photos, NO AI-photo look: every coordinate is computed.
//
// PRIMARY output (page-facing): five theme-adaptive inline SVGs
//   → src/assets/work/plate-0X.svg (viewBox 0 0 3840 2160, a 16:9 vector).
// Every colour is a CSS variable (--plate-*) defined in global.css, so ONE file
// serves both light and dark themes and stays crisp at any size. Animatable
// elements carry stable classes (.p-accent-path, .p-station, .p-plane, …) that
// global.css keys motion off via [data-motion='a'|'b']; the files themselves are
// fully static (no <animate>, no inline styles).
//
// LEGACY output (OG-style raster, no longer referenced by pages): the dark/light
// × standard/wide PNGs. The code path is retained but only runs with EMIT_PNG=1
// so a normal run does not churn the committed binaries.
//
// Run: `node scripts/generate-work-art.mjs`            → writes the 5 SVGs
//      `EMIT_PNG=1 node scripts/generate-work-art.mjs` → also writes the 20 PNGs
import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// ---------------------------------------------------------------------------
// Palettes. DARK/LIGHT drive the (legacy) PNGs with literal colours. VAR drives
// the SVGs: every value is a CSS variable, so the theme lives in global.css and
// a single file renders correctly in both. `strong` is the brightest structural
// gray (dark #e4e7ec / light #3d434e); `gray` the regular stroke/node colour.
// ---------------------------------------------------------------------------
const DARK = {
  bg: '#0a0a0a',
  grid: 'rgba(236,236,236,0.05)',
  gray: '#9aa1ad',
  strong: '#e4e7ec',
  emerald: '#2fbd8f',
  titleMuted: 'rgba(236,236,236,0.4)',
  titleBorder: 'rgba(236,236,236,0.25)',
  fgStrong: '#ececec',
};
const LIGHT = {
  bg: '#fafafa',
  grid: 'rgba(22,24,29,0.05)',
  gray: '#5f6572',
  strong: '#3d434e',
  emerald: '#0e7c5b',
  titleMuted: 'rgba(22,24,29,0.4)',
  titleBorder: 'rgba(22,24,29,0.25)',
  fgStrong: '#16181d',
};
// One SVG, both themes: colours are variables, theme difference lives in CSS.
const VAR = {
  bg: 'var(--plate-bg)',
  grid: 'var(--plate-grid)',
  gray: 'var(--plate-stroke)',
  strong: 'var(--plate-strong)',
  emerald: 'var(--plate-accent)',
  titleMuted: 'var(--plate-muted)',
  titleBorder: 'var(--plate-line)',
  fgStrong: 'var(--plate-strong)',
};

// ---------------------------------------------------------------------------
// Formats — canvas + (standard-only) title-block metrics. `standard` is the 16:9
// plate (also the SVG geometry); `wide` recomposes and carries no title block.
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

// Attach a stable class to a single primitive string (inserts after the tag).
const cls = (svg, className) => svg.replace(/^<([a-zA-Z]+)/, `<$1 class="${className}"`);
// Wrap children in a classed group (for nth-of-type staggering + group motion).
const group = (className, inner) => `<g class="${className}">\n${inner}\n</g>`;

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
function wideLabel(pal, g, industry) {
  const maxW = g.W / 3 - 160;
  const ls = 24;
  const words = industry.toUpperCase().split(/\s+/);
  const longest = Math.max(...words.map((w) => w.length));
  const adv = (f) => f * 0.62 + ls;
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

  const O = (i) => i;
  const I = (i) => outer + i;
  const C = (i) => outer + inner + i;

  const edges = [];
  for (let i = 0; i < outer; i++) edges.push([O(i), O((i + 1) % outer)]);
  for (let i = 0; i < inner; i++) edges.push([I(i), I((i + 1) % inner)]);
  for (let i = 0; i < inner; i++) edges.push([I(i), O((i * 2) % outer)]);
  for (let i = 0; i < inner; i++) edges.push([I(i), C(i % 2)]);
  edges.push([C(0), C(1)]);

  for (const [a, b] of edges) {
    parts.push(line(nodes[a].x, nodes[a].y, nodes[b].x, nodes[b].y, pal.gray, W_THIN, 0.6));
  }
  // gray nodes — grouped so intensity B can shimmer them (staggered)
  const grayNodes = nodes.map((n) => dot(n.x, n.y, nodeR, pal.gray, pal.bg, 2));
  parts.push(group('p-nodes', grayNodes.join('\n')));

  // anomaly path: one continuous emerald polyline (traveling-pulse target)
  const path = [O(3), I(1), C(0), I(5)].map((i) => [nodes[i].x, nodes[i].y]);
  parts.push(cls(pline(path, pal.emerald, W_BOLD), 'p-accent-path'));
  for (const idx of [I(1), C(0)]) parts.push(cls(dot(nodes[idx].x, nodes[idx].y, emNodeR, pal.emerald), 'p-accent-node'));

  return parts.join('\n');
}

// ===========================================================================
// PLATE 02 — Automotive & Manufacturing · isometric assembly line
// ===========================================================================
function plate02(pal, L) {
  const { baseY, bw, bd, bh, count, xStart, xEnd, beltL, beltR } = L;
  const parts = [];
  const step = (xEnd - xStart) / (count - 1);

  // one isometric station box (faces + dial + panel line) in a given ink weight.
  const station = (o, stroke, w, op, dw) => {
    const b0 = P(o, 0, 0, 0);
    const b1 = P(o, bw, 0, 0);
    const b2 = P(o, 0, bd, 0);
    const t0 = P(o, 0, 0, bh);
    const t1 = P(o, bw, 0, bh);
    const t2 = P(o, 0, bd, bh);
    const t3 = P(o, bw, bd, bh);
    const face = (u, v) => P(o, bw * u, 0, bh * v);
    const dc = face(0.5, 0.56);
    return [
      poly([b0, b2, t2, t0], stroke, w, op, pal.bg),
      poly([b0, b1, t1, t0], stroke, w, op, pal.bg),
      poly([t0, t1, t3, t2], stroke, w, op, pal.bg),
      circle(dc[0], dc[1], Math.round(bh * 0.118), stroke, dw, op * 0.9),
      line(...face(0.24, 0.3), ...face(0.76, 0.3), stroke, dw, op * 0.85),
    ].join('\n');
  };

  // conveyor: double baseline + roller ticks. Ticks extend TWO CELLs beyond each
  // edge so the idle two-cell drift (and the faster hover boost on top) loop
  // seamlessly — no gap enters the visible belt as the group shifts.
  parts.push(line(beltL, baseY, beltR, baseY, pal.gray, W_MID, 0.65));
  parts.push(line(beltL, baseY + 24, beltR, baseY + 24, pal.gray, W_THIN, 0.55));
  const ticks = [];
  for (let x = Math.floor(beltL / CELL) * CELL - 2 * CELL; x <= beltR + 2 * CELL; x += CELL) {
    ticks.push(line(x, baseY, x, baseY + 24, pal.gray, W_THIN, 0.6));
  }
  parts.push(group('p-ticks', ticks.join('\n')));

  // Base: all six stations in gray — no permanently-emerald station.
  for (let i = 0; i < count; i++) {
    parts.push(station({ x: xStart + i * step, y: baseY }, pal.gray, W_MID, 0.72, W_THIN));
  }
  // Emerald overlay twin per station (opacity 0 at rest), same geometry in bold
  // emerald. CSS lights them one after another (station-cycle) to read as an
  // assembly-line progression sweeping left→right. Grouped so :nth-of-type keys
  // the per-station stagger cleanly.
  const overlays = [];
  for (let i = 0; i < count; i++) {
    const box = station({ x: xStart + i * step, y: baseY }, pal.emerald, W_BOLD, 1, W_MID);
    overlays.push(`<g class="p-station-hl" opacity="0">\n${box}\n</g>`);
  }
  parts.push(group('p-stations-hl', overlays.join('\n')));

  return parts.join('\n');
}

// ===========================================================================
// PLATE 03 — Logistics & Supply Chain · route map
// ===========================================================================
function plate03(pal, L) {
  const { pts, leftEdge, rightEdge, mg, me } = L;
  const parts = [];
  const D = pts;

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
  for (const [a, b] of grayConn) parts.push(pline(ortho(D[a], D[b]), pal.gray, W_THIN, 0.6));

  // gray depot markers — grouped for intensity-B shimmer
  const grayDepots = D.map((d) => rect(d.x - mg, d.y - mg, mg * 2, mg * 2, pal.bg, pal.gray, W_THIN, 0.72));
  parts.push(group('p-depots-gray', grayDepots.join('\n')));

  // ONE continuous emerald route crossing the canvas (route-flow target)
  const emerald = [[leftEdge, D[0].y]]
    .concat(ortho(D[0], D[3]))
    .concat(ortho(D[3], D[6]))
    .concat(ortho(D[6], D[8]))
    .concat([[rightEdge, D[8].y]]);
  parts.push(cls(pline(emerald, pal.emerald, W_BOLD), 'p-route'));
  const emDepots = [0, 3, 6, 8].map((i) => cls(rect(D[i].x - me, D[i].y - me, me * 2, me * 2, pal.bg, pal.emerald, W_BOLD), 'p-depot'));
  parts.push(group('p-depots', emDepots.join('\n')));

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

  // floor plates — top/bottom read as the building's strongest edges
  for (let k = 0; k <= storeys; k++) {
    if (k === compliance) continue;
    const strong = k === 0 || k === storeys;
    parts.push(poly(floor(k * storeyH), strong ? pal.strong : pal.gray, strong ? W_MID : W_THIN, strong ? 0.72 : 0.6));
  }
  // vertical edges (strong)
  for (const [rr, ll] of [[0, 0], [wb, 0], [0, db], [wb, db]]) {
    parts.push(line(...P(o, rr, ll, 0), ...P(o, rr, ll, totalH), pal.strong, W_MID, 0.7));
  }

  // dimension line + storey ticks (left of the building) — ticks grouped for B
  const dimX = P(o, 0, db, 0)[0] - dimOffset;
  const topY = P(o, 0, db, totalH)[1];
  const botY = P(o, 0, db, 0)[1];
  parts.push(line(dimX, topY, dimX, botY, pal.gray, W_THIN, 0.65));
  const dimTicks = [];
  for (let k = 0; k <= storeys; k++) {
    const y = P(o, 0, db, k * storeyH)[1];
    dimTicks.push(line(dimX - dimTick, y, dimX + dimTick, y, pal.gray, W_THIN, 0.65));
  }
  parts.push(group('p-dim-ticks', dimTicks.join('\n')));

  // section line (dashed horizontal cut) with end ticks
  const secH = 4 * storeyH;
  const secL = P(o, 0, db, secH);
  const secR = P(o, wb, 0, secH);
  parts.push(line(secL[0] - secExtend, secL[1] + secLower, secR[0] + secExtend, secR[1] + secLower, pal.gray, W_THIN, 0.6, dash));

  // emerald horizontal compliance plane — outline + flat hatch (translate target)
  const cp = floor(compliance * storeyH);
  const plane = [poly(cp, pal.emerald, W_BOLD)];
  for (let t = 1; t <= 4; t++) {
    const f = t / 5;
    const a = [cp[0][0] + (cp[1][0] - cp[0][0]) * f, cp[0][1] + (cp[1][1] - cp[0][1]) * f];
    const b = [cp[3][0] + (cp[2][0] - cp[3][0]) * f, cp[3][1] + (cp[2][1] - cp[3][1]) * f];
    plane.push(line(a[0], a[1], b[0], b[1], pal.emerald, W_THIN, 0.8));
  }
  parts.push(group('p-plane', plane.join('\n')));

  return parts.join('\n');
}

// ===========================================================================
// PLATE 05 — Strategic AI & Enterprise · concentric operating-model rings
// ===========================================================================
function plate05(pal, L) {
  const { cx, cy, radii, hubR, nodeR, emNodeR, tickLen } = L;
  const parts = [];
  const outer = radii[radii.length - 1];

  // rings — outermost is the strong bounding ring
  radii.forEach((rad, i) => {
    const isOuter = i === radii.length - 1;
    parts.push(circle(cx, cy, rad, isOuter ? pal.strong : pal.gray, isOuter ? W_MID : W_THIN, isOuter ? 0.7 : 0.65));
  });

  const spokes = 12;
  for (let i = 0; i < spokes; i++) {
    const a = (i / spokes) * Math.PI * 2;
    parts.push(line(cx + radii[0] * Math.cos(a), cy + radii[0] * Math.sin(a), cx + outer * Math.cos(a), cy + outer * Math.sin(a), pal.gray, W_THIN, 0.55));
  }
  for (let i = 0; i < 24; i++) {
    const a = (i / 24) * Math.PI * 2;
    parts.push(line(cx + outer * Math.cos(a), cy + outer * Math.sin(a), cx + (outer + tickLen) * Math.cos(a), cy + (outer + tickLen) * Math.sin(a), pal.gray, W_THIN, 0.65));
  }
  parts.push(dot(cx, cy, hubR, pal.gray));

  // ring-intersection nodes — grouped for intensity-B shimmer
  const ringNodes = [];
  for (let i = 0; i < spokes; i++) {
    const a = (i / spokes) * Math.PI * 2;
    for (const rr of [radii[1], radii[2]]) {
      ringNodes.push(dot(cx + rr * Math.cos(a), cy + rr * Math.sin(a), nodeR, pal.gray));
    }
  }
  parts.push(group('p-ring-nodes', ringNodes.join('\n')));

  // ONE emerald arc segment (~70°) on ring-3 + a terminating node — orbit target
  const ar = radii[2];
  const a0 = (-15 * Math.PI) / 180;
  const a1 = (55 * Math.PI) / 180;
  const sx = cx + ar * Math.cos(a0);
  const sy = cy + ar * Math.sin(a0);
  const ex = cx + ar * Math.cos(a1);
  const ey = cy + ar * Math.sin(a1);
  parts.push(cls(`<path d="M${r(sx)} ${r(sy)} A ${ar} ${ar} 0 0 1 ${r(ex)} ${r(ey)}" fill="none" stroke="${pal.emerald}" stroke-width="${W_BOLD}" stroke-linecap="round"/>`, 'p-arc'));
  parts.push(cls(dot(ex, ey, emNodeR, pal.emerald), 'p-orbit-node'));

  return parts.join('\n');
}

// ---------------------------------------------------------------------------
// Per-plate layouts. `standard` is the 16:9 composition (and the SVG geometry);
// `wide` recomposes into the right two thirds at the shorter 1080 height.
// ---------------------------------------------------------------------------
const PLATES = [
  {
    slug: 'plate-01-bfsi', svg: 'plate-01', label: 'PLATE 01 · BFSI', industry: 'BFSI', motif: plate01,
    layout: {
      standard: { cx: CX_STD, cy: 1000, rOuter: 720, rInner: 420, rCore: 140, nodeR: 9, emNodeR: 15 },
      wide: { cx: 2560, cy: 540, rOuter: 390, rInner: 228, rCore: 76, nodeR: 8, emNodeR: 13 },
    },
  },
  {
    slug: 'plate-02-automotive', svg: 'plate-02', label: 'PLATE 02 · AUTOMOTIVE & MANUFACTURING', industry: 'Automotive & Manufacturing', motif: plate02,
    layout: {
      standard: { baseY: 1180, bw: 240, bd: 240, bh: 340, count: 6, emeraldIdx: 3, xStart: 520, xEnd: 3320, beltL: 260, beltR: 3580 },
      wide: { baseY: 780, bw: 150, bd: 150, bh: 300, count: 6, emeraldIdx: 3, xStart: 1600, xEnd: 3520, beltL: 1440, beltR: 3680 },
    },
  },
  {
    slug: 'plate-03-logistics', svg: 'plate-03', label: 'PLATE 03 · LOGISTICS & SUPPLY CHAIN', industry: 'Logistics & Supply Chain', motif: plate03,
    layout: {
      standard: {
        pts: [
          [360, 520], [760, 1200], [1180, 460], [1520, 980], [1980, 1480],
          [2180, 620], [2560, 1180], [2980, 780], [3320, 1340], [3460, 460],
        ].map(([x, y]) => ({ x, y })),
        leftEdge: 280, rightEdge: 3560, mg: 11, me: 13,
      },
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
    slug: 'plate-04-construction', svg: 'plate-04', label: 'PLATE 04 · EPCM & CONSTRUCTION', industry: 'EPCM & Construction', motif: plate04,
    layout: {
      standard: { o: { x: 1780, y: 1450 }, wb: 420, db: 420, storeyH: 130, storeys: 9, compliance: 6, dimOffset: 130, dimTick: 16, secExtend: 220, secLower: 60, dash: '28 22' },
      wide: { o: { x: 2560, y: 820 }, wb: 230, db: 230, storeyH: 72, storeys: 9, compliance: 6, dimOffset: 72, dimTick: 9, secExtend: 120, secLower: 33, dash: '16 12' },
    },
  },
  {
    slug: 'plate-05-strategic', svg: 'plate-05', label: 'PLATE 05 · STRATEGIC AI & ENTERPRISE', industry: 'Strategic AI & Enterprise', motif: plate05,
    layout: {
      standard: { cx: CX_STD, cy: 1060, radii: [300, 470, 640, 810], hubR: 10, nodeR: 10, emNodeR: 16, tickLen: 22 },
      wide: { cx: 2560, cy: 540, radii: [140, 220, 300, 380], hubR: 6, nodeR: 7, emNodeR: 12, tickLen: 11 },
    },
  },
];

// ---- SVG composition (theme-adaptive, page-facing) -------------------------
function composeSvg(plate) {
  const g = FORMATS.standard;
  const L = plate.layout.standard;
  const body = [
    `<rect width="${g.W}" height="${g.H}" fill="${VAR.bg}"/>`,
    grid(VAR, g),
    group('p-motif', plate.motif(VAR, L)),
    titleBlock(VAR, g, plate.label),
  ].join('\n');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${g.W} ${g.H}" preserveAspectRatio="xMidYMid meet" role="presentation" aria-hidden="true">\n${body}\n</svg>\n`;
}

// ---- PNG composition (legacy raster, EMIT_PNG=1 only) ----------------------
function composePng(pal, format, plate) {
  const g = FORMATS[format];
  const L = plate.layout[format];
  const body = [
    `<rect width="${g.W}" height="${g.H}" fill="${pal.bg}"/>`,
    grid(pal, g),
    format === 'wide' ? wideLabel(pal, g, plate.industry) : null,
    plate.motif(pal, L),
    format === 'wide' ? null : titleBlock(pal, g, plate.label),
  ].filter(Boolean).join('\n');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${g.W}" height="${g.H}" viewBox="0 0 ${g.W} ${g.H}">\n${body}\n</svg>`;
}

const outDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'assets', 'work');
mkdirSync(outDir, { recursive: true });

// PRIMARY: the five theme-adaptive SVGs.
for (const plate of PLATES) {
  writeFileSync(join(outDir, `${plate.svg}.svg`), composeSvg(plate));
  console.log(`${plate.svg}.svg written`);
}

// LEGACY: the 20 PNGs, only when explicitly requested (keeps binaries stable).
if (process.env.EMIT_PNG) {
  const sharp = (await import('sharp')).default;
  const VARIANTS = [
    { theme: DARK, format: 'standard', suffix: '' },
    { theme: LIGHT, format: 'standard', suffix: '-light' },
    { theme: DARK, format: 'wide', suffix: '-wide' },
    { theme: LIGHT, format: 'wide', suffix: '-wide-light' },
  ];
  for (const plate of PLATES) {
    for (const { theme, format, suffix } of VARIANTS) {
      const file = `${plate.slug}${suffix}.png`;
      await sharp(Buffer.from(composePng(theme, format, plate))).png({ compressionLevel: 9 }).toFile(join(outDir, file));
      console.log(`${file} written`);
    }
  }
}

console.log(`work-art SVG plates written to src/assets/work/ (${PLATES.length} files)`);

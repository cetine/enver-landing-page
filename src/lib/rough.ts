// Deterministic hand-drawn ("Excalidraw-style") SVG path generation.
//
// Excalidraw gets its look from rough.js: every edge is stroked twice along a
// slightly bowed, jittered bezier, so corners overshoot and no two lines are
// quite parallel. This module reimplements that in ~80 lines because the real
// dependency ships a canvas renderer we would never use, and the site's JS
// budget is 15 KB gzip — these paths are generated at build time and shipped as
// plain SVG, costing zero client JS.
//
// The jitter comes from a seeded PRNG, never Math.random(): the same seed must
// produce the same `d` attribute on every build, otherwise each rebuild churns
// the diagram markup and pollutes diffs.

/** mulberry32 — small, fast, deterministic. Returns values in [0, 1). */
function mulberry32(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export interface RoughOptions {
  /** Seed for the jitter. Same seed + same geometry ⇒ same path. */
  seed?: number;
  /** Jitter amplitude multiplier. 1 ≈ rough.js default. */
  roughness?: number;
  /** How much each edge bows outward. 1 ≈ rough.js default. */
  bowing?: number;
}

const n = (v: number): string => (Math.round(v * 10) / 10).toString();

/**
 * One jittered bezier approximating the straight segment (x1,y1)→(x2,y2),
 * following rough.js' `_line`: endpoints are displaced, and two control points
 * sit at ~1/3 and ~2/3 of the run with a perpendicular bow.
 */
function segment(
  x1: number, y1: number, x2: number, y2: number,
  rand: () => number, roughness: number, bowing: number,
): string {
  const lengthSq = (x1 - x2) ** 2 + (y1 - y2) ** 2;
  const length = Math.sqrt(lengthSq);
  // Long lines get proportionally less jitter, or they read as wavy rather
  // than hand-drawn.
  const gain = length < 200 ? 1 : length > 500 ? 0.4 : -0.0016668 * length + 1.233334;
  let offset = 2 * roughness;
  if (offset * offset * 100 > lengthSq) offset = length / 10;

  const jitter = (): number => gain * (rand() * 2 - 1) * offset;
  const divergePoint = 0.2 + rand() * 0.2;
  const bowX = (bowing * offset * (y2 - y1)) / 200;
  const bowY = (bowing * offset * (x1 - x2)) / 200;

  const sx = x1 + jitter();
  const sy = y1 + jitter();
  const c1x = bowX + x1 + (x2 - x1) * divergePoint + jitter();
  const c1y = bowY + y1 + (y2 - y1) * divergePoint + jitter();
  const c2x = bowX + x1 + 2 * (x2 - x1) * divergePoint + jitter();
  const c2y = bowY + y1 + 2 * (y2 - y1) * divergePoint + jitter();
  const ex = x2 + jitter();
  const ey = y2 + jitter();

  return `M${n(sx)} ${n(sy)}C${n(c1x)} ${n(c1y)} ${n(c2x)} ${n(c2y)} ${n(ex)} ${n(ey)}`;
}

/** A hand-drawn line: two overlapping strokes, as rough.js draws them. */
export function roughLine(
  x1: number, y1: number, x2: number, y2: number, opts: RoughOptions = {},
): string {
  const { seed = 1, roughness = 1, bowing = 1 } = opts;
  const rand = mulberry32(seed);
  return (
    segment(x1, y1, x2, y2, rand, roughness, bowing) +
    segment(x1, y1, x2, y2, rand, roughness, bowing)
  );
}

/**
 * A hand-drawn rectangle. Corners overshoot slightly because each edge is drawn
 * independently — the same reason a pen-drawn box never closes perfectly.
 */
export function roughRect(
  x: number, y: number, w: number, h: number, opts: RoughOptions = {},
): string {
  const { seed = 1, roughness = 1, bowing = 1 } = opts;
  const rand = mulberry32(seed);
  const corners: ReadonlyArray<readonly [number, number, number, number]> = [
    [x, y, x + w, y],
    [x + w, y, x + w, y + h],
    [x + w, y + h, x, y + h],
    [x, y + h, x, y],
  ];
  return corners
    .map(([ax, ay, bx, by]) =>
      segment(ax, ay, bx, by, rand, roughness, bowing) +
      segment(ax, ay, bx, by, rand, roughness, bowing))
    .join('');
}

/**
 * A hand-drawn polyline through `points` — used for the routed return path,
 * which turns a corner rather than running straight.
 */
export function roughPolyline(
  points: ReadonlyArray<readonly [number, number]>, opts: RoughOptions = {},
): string {
  const { seed = 1, roughness = 1, bowing = 1 } = opts;
  const rand = mulberry32(seed);
  let d = '';
  for (let i = 0; i < points.length - 1; i += 1) {
    const [ax, ay] = points[i];
    const [bx, by] = points[i + 1];
    d += segment(ax, ay, bx, by, rand, roughness, bowing);
    d += segment(ax, ay, bx, by, rand, roughness, bowing);
  }
  return d;
}

/**
 * Two short strokes forming an arrowhead at (x,y), pointing along the direction
 * given by `angle` (radians). Kept separate from the shaft so the shaft can be a
 * straight line or a routed polyline without special-casing the head.
 */
export function roughArrowHead(
  x: number, y: number, angle: number, opts: RoughOptions & { size?: number } = {},
): string {
  const { seed = 1, roughness = 1, bowing = 1, size = 11 } = opts;
  const rand = mulberry32(seed);
  const spread = 0.42;
  const a = [x - size * Math.cos(angle - spread), y - size * Math.sin(angle - spread)] as const;
  const b = [x - size * Math.cos(angle + spread), y - size * Math.sin(angle + spread)] as const;
  // Both barbs are stroked twice like every other edge in this module; drawn
  // once they render visibly thinner than the shapes they point at.
  return (
    segment(a[0], a[1], x, y, rand, roughness, bowing) +
    segment(a[0], a[1], x, y, rand, roughness, bowing) +
    segment(b[0], b[1], x, y, rand, roughness, bowing) +
    segment(b[0], b[1], x, y, rand, roughness, bowing)
  );
}

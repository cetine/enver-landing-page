import { describe, it, expect } from 'vitest';
import { roughLine, roughRect, roughPolyline, roughArrowHead } from '../../src/lib/rough';

describe('rough path generation', () => {
  it('is deterministic for a given seed', () => {
    // The diagram is generated at build time and committed as rendered markup;
    // non-deterministic output would churn the HTML on every rebuild.
    expect(roughRect(0, 0, 100, 50, { seed: 7 })).toBe(roughRect(0, 0, 100, 50, { seed: 7 }));
    expect(roughLine(0, 0, 80, 0, { seed: 3 })).toBe(roughLine(0, 0, 80, 0, { seed: 3 }));
  });

  it('varies with the seed, so adjacent shapes are not identical', () => {
    expect(roughRect(0, 0, 100, 50, { seed: 1 })).not.toBe(roughRect(0, 0, 100, 50, { seed: 2 }));
  });

  it('draws every edge twice, as a hand-drawn stroke doubles back', () => {
    // 4 edges × 2 passes = 8 subpaths for a rectangle.
    expect(roughRect(0, 0, 100, 50, { seed: 5 }).match(/M/g)).toHaveLength(8);
    expect(roughLine(0, 0, 10, 10, { seed: 5 }).match(/M/g)).toHaveLength(2);
    // 2 segments × 2 passes for a three-point polyline.
    expect(roughPolyline([[0, 0], [10, 0], [10, 10]], { seed: 5 }).match(/M/g)).toHaveLength(4);
    // An arrowhead is two barbs, each drawn twice.
    expect(roughArrowHead(10, 10, 0, { seed: 5 }).match(/M/g)).toHaveLength(4);
  });

  it('stays near the requested geometry', () => {
    // Jitter must read as a wobble, not a redrawn shape: every emitted
    // coordinate of a 200×100 box should sit within a few px of the box.
    const coords = roughRect(0, 0, 200, 100, { seed: 9 })
      .split(/[MC ]/)
      .filter(Boolean)
      .map(Number);
    for (const v of coords) {
      expect(v).toBeGreaterThan(-8);
      expect(v).toBeLessThan(208);
    }
  });

  it('emits no NaN for zero-length input', () => {
    expect(roughLine(5, 5, 5, 5, { seed: 2 })).not.toMatch(/NaN/);
  });
});

import { describe, it, expect } from 'vitest';
import { filterLocale, sortByDateDesc, groupByMonth, readingTimeMinutes } from '../../src/lib/writing';

const mk = (slug: string, iso: string) => ({
  slug, locale: 'en' as const, title: slug, date: new Date(iso),
  description: '', tags: [], type: 'post' as const,
});

describe('filterLocale', () => {
  it('keeps only entries with the locale prefix', () => {
    const entries = [{ id: 'en/a' }, { id: 'de/a' }, { id: 'en/b' }];
    expect(filterLocale(entries, 'en').map((e) => e.id)).toEqual(['en/a', 'en/b']);
  });
});

describe('sortByDateDesc', () => {
  it('newest first', () => {
    const sorted = sortByDateDesc([mk('old', '2025-01-01'), mk('new', '2026-06-01')]);
    expect(sorted[0].slug).toBe('new');
  });
  it('does not mutate the input array', () => {
    const input = [mk('old', '2025-01-01'), mk('new', '2026-06-01')];
    sortByDateDesc(input);
    expect(input[0].slug).toBe('old');
  });
});

describe('groupByMonth', () => {
  it('stays flat below threshold', () => {
    const r = groupByMonth([mk('a', '2026-06-01')], 'en');
    expect(r.grouped).toBe(false);
    expect(r.groups[0].items).toHaveLength(1);
  });
  it('groups by month at threshold with locale labels', () => {
    const items = Array.from({ length: 8 }, (_, i) => mk(`p${i}`, `2026-0${(i % 3) + 1}-15`));
    const en = groupByMonth(items, 'en', 8);
    expect(en.grouped).toBe(true);
    expect(en.groups[0].label).toBe('2026 March');
    const de = groupByMonth(items, 'de', 8);
    expect(de.groups[0].label).toBe('März 2026');
  });
});

describe('readingTimeMinutes', () => {
  it('rounds up and has a floor of 1', () => {
    expect(readingTimeMinutes('word '.repeat(450))).toBe(3);
    expect(readingTimeMinutes('short text')).toBe(1);
  });
});

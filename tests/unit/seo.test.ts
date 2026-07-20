import { describe, it, expect } from 'vitest';
import { pageTitle, personJsonLd, articleJsonLd } from '../../src/lib/seo';

describe('pageTitle', () => {
  it('default and page variants', () => {
    expect(pageTitle()).toBe('Enver Cetin — Director AI');
    expect(pageTitle('Writing')).toBe('Writing — Enver Cetin');
  });
});

describe('personJsonLd', () => {
  it('has type, name and sameAs', () => {
    const p = personJsonLd() as any;
    expect(p['@type']).toBe('Person');
    expect(p.name).toBe('Enver Cetin');
    expect(p.sameAs.length).toBeGreaterThanOrEqual(2);
  });
});

describe('articleJsonLd', () => {
  it('maps fields', () => {
    const a = articleJsonLd({ title: 'T', description: 'D', date: new Date('2026-07-20'), url: 'https://envercetin.de/writing/t', lang: 'en' }) as any;
    expect(a['@type']).toBe('Article');
    expect(a.datePublished).toBe('2026-07-20');
    expect(a.author.name).toBe('Enver Cetin');
  });
});

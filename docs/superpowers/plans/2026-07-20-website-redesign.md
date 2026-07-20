# Website-Redesign envercetin.de — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the personal site as a bilingual (EN root / DE under `/de/`) static Astro site per `docs/superpowers/specs/2026-07-20-website-redesign-design.md` — Editorial-Operator concept, deployed on the existing Vercel project, canonical domain `envercetin.de`.

**Architecture:** Astro 5 static output. Content lives in Content Collections (Markdown/YAML), pages are thin locale wrappers around shared page components. One React island (SearchPalette, lazy). Everything else zero-JS except two inline scripts (theme, hash-redirect) and one vanilla form script.

**Tech Stack:** Astro 5, TypeScript, Tailwind CSS 4 (`@tailwindcss/vite`), React (island only), Pagefind, `@fontsource` IBM Plex Sans/Serif/Mono, Vitest, Playwright, web3forms, Vercel.

## Global Constraints

- Repo root: `/Users/ece/Documents/Documents - MB-928749/EnverLandingPage`. Work happens on branch `redesign/astro`. The old Vite app is **replaced**, not kept alongside.
- Hero claim verbatim, never paraphrased: `I build AI that actually works.` / `Not in labs. Not in theory.`
- Role string everywhere: `Director AI, Ciklum · Munich` (EN) / `Director AI, Ciklum · München` (DE).
- Colors: light bg `#fafafa` fg `#16181d`; dark bg `#0a0a0a` fg `#ececec`; accent `#0e7c5b` (light) / `#2fbd8f` (dark). No gradients. No other hues.
- IBM Plex Serif Light = large headings only. IBM Plex Mono = eyebrows/meta/badges/KPI only, **never body text**. IBM Plex Sans = everything else.
- No emoji as icons. No custom cursor, no intro overlay, no parallax, no scroll-progress bar, no React Flow.
- KPI values are magnitudes (`~70 %`, `>3×`), never fake precision (`-78 %`).
- JS budget: all site JS excluding Pagefind < 15 KB gzip. Lighthouse mobile targets: Perf ≥ 95, SEO 100, A11y ≥ 95.
- Locale routing: EN at root (`/writing`), DE prefixed (`/de/writing`). Every page emits canonical + hreflang (en, de, x-default=en).
- `.env` is never committed. web3forms key becomes `PUBLIC_WEB3FORMS_KEY` (copy value from the existing `.env`).
- Commit format `<type>: <description>` (no attribution footer — user has attribution disabled).
- All shell commands below run from the repo root.

---

### Task 1: Baseline safety commit + Astro scaffold on new branch

**Files:**
- Modify: `package.json`, `tsconfig.json`, `.gitignore`, `.env`
- Create: `astro.config.mjs`, `src/pages/index.astro` (throwaway), `src/env.d.ts`
- Delete: old Vite files (`vite.config.ts`, `index.html`, `eslint.config.js`, `postcss.config.js`, `tailwind.config.js`, `tsconfig.app.json`, `tsconfig.node.json`, `src/` Vite sources — **except** keep `src/components/ProjectsSection.tsx`, `src/components/VenturesSection.tsx`, `src/data/profile.ts` temporarily as content source, and `public/images/`)

**Interfaces:**
- Produces: a building Astro skeleton; npm scripts `dev`, `build`, `preview`, `check`, `test`, `e2e`; content-source files parked under `legacy/`.

- [ ] **Step 1: Safety-commit the uncommitted local changes on `main`**

```bash
git checkout main
git add -A
git commit -m "chore: snapshot local WIP before astro rebuild"
git push origin main
```

- [ ] **Step 2: Create branch and park legacy content sources**

```bash
git checkout -b redesign/astro
mkdir -p legacy
git mv src/components/ProjectsSection.tsx src/components/VenturesSection.tsx src/data/profile.ts legacy/
```

- [ ] **Step 3: Remove Vite app files**

```bash
git rm -r src vite.config.ts index.html eslint.config.js postcss.config.js tailwind.config.js tsconfig.app.json tsconfig.node.json
rm -rf dist node_modules package-lock.json
```

- [ ] **Step 4: Write new `package.json`**

```json
{
  "name": "enver-landing-page",
  "private": true,
  "version": "2.0.0",
  "type": "module",
  "scripts": {
    "dev": "astro dev",
    "build": "astro build && pagefind --site dist",
    "preview": "astro preview",
    "check": "astro check",
    "test": "vitest run",
    "e2e": "playwright test"
  },
  "dependencies": {
    "@astrojs/react": "^4.2.0",
    "@astrojs/rss": "^4.0.11",
    "@astrojs/sitemap": "^3.2.1",
    "@fontsource/ibm-plex-mono": "^5.1.0",
    "@fontsource/ibm-plex-sans": "^5.1.0",
    "@fontsource/ibm-plex-serif": "^5.1.0",
    "@tailwindcss/vite": "^4.1.0",
    "astro": "^5.7.0",
    "pagefind": "^1.3.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "tailwindcss": "^4.1.0"
  },
  "devDependencies": {
    "@astrojs/check": "^0.9.4",
    "@playwright/test": "^1.50.0",
    "typescript": "^5.7.0",
    "vitest": "^3.0.0"
  }
}
```

- [ ] **Step 5: Write `astro.config.mjs`**

```js
import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://envercetin.de',
  trailingSlash: 'never',
  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'de'],
    routing: { prefixDefaultLocale: false },
  },
  integrations: [
    react(),
    sitemap({
      i18n: { defaultLocale: 'en', locales: { en: 'en', de: 'de' } },
    }),
  ],
  vite: { plugins: [tailwindcss()] },
});
```

- [ ] **Step 6: Write `tsconfig.json`, `src/env.d.ts`, minimal `src/pages/index.astro`**

`tsconfig.json`:
```json
{
  "extends": "astro/tsconfigs/strict",
  "include": [".astro/types.d.ts", "src/**/*", "tests/**/*", "legacy/**/*"],
  "exclude": ["dist"]
}
```

`src/env.d.ts`:
```ts
/// <reference types="astro/client" />
interface ImportMetaEnv {
  readonly PUBLIC_WEB3FORMS_KEY: string;
}
```

`src/pages/index.astro` (throwaway, replaced in Task 9):
```astro
---
---
<html lang="en"><head><title>Enver Cetin</title></head><body><h1>scaffold ok</h1></body></html>
```

- [ ] **Step 7: Update `.env` key name**

Open `.env`, copy the existing web3forms access key value into a line `PUBLIC_WEB3FORMS_KEY=<value>` (keep the old line for now). Update `.env.example` to list `PUBLIC_WEB3FORMS_KEY=`.

- [ ] **Step 8: Install and verify build**

```bash
npm install
npm run build
```
Expected: build succeeds, `dist/index.html` contains `scaffold ok`. (Pagefind may warn about nothing to index — fine.)

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore: replace vite spa with astro 5 scaffold"
```

---

### Task 2: Design tokens, fonts, global CSS

**Files:**
- Create: `src/styles/global.css`

**Interfaces:**
- Produces: Tailwind utilities `bg-bg`, `text-fg`, `text-muted`, `border-line`, `text-accent`, `bg-accent-soft`, `font-sans`, `font-serif`, `font-mono`; `data-theme` attribute contract on `<html>`; class `dark:` variant bound to `[data-theme='dark']`.

- [ ] **Step 1: Write `src/styles/global.css`**

```css
@import 'tailwindcss';

@custom-variant dark (&:where([data-theme='dark'], [data-theme='dark'] *));

:root {
  --bg: #fafafa;
  --fg: #16181d;
  --muted: #5f6572;
  --line: rgba(22, 24, 29, 0.14);
  --accent: #0e7c5b;
  --accent-soft: rgba(14, 124, 91, 0.1);
}
[data-theme='dark'] {
  --bg: #0a0a0a;
  --fg: #ececec;
  --muted: #9aa1ad;
  --line: rgba(236, 236, 236, 0.16);
  --accent: #2fbd8f;
  --accent-soft: rgba(47, 189, 143, 0.12);
}

@theme inline {
  --color-bg: var(--bg);
  --color-fg: var(--fg);
  --color-muted: var(--muted);
  --color-line: var(--line);
  --color-accent: var(--accent);
  --color-accent-soft: var(--accent-soft);
  --font-sans: 'IBM Plex Sans', ui-sans-serif, system-ui, sans-serif;
  --font-serif: 'IBM Plex Serif', ui-serif, Georgia, serif;
  --font-mono: 'IBM Plex Mono', ui-monospace, 'SF Mono', monospace;
}

html {
  background: var(--bg);
  color: var(--fg);
  font-family: var(--font-sans);
  scroll-behavior: smooth;
}
@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
  *, *::before, *::after { animation: none !important; transition: none !important; }
}
::selection { background: var(--accent-soft); }

/* Prose column for posts/cases */
.prose-col { max-width: 40em; }
.prose-col h2 { font-family: var(--font-serif); font-weight: 300; font-size: 1.6rem; margin: 2.2rem 0 0.8rem; }
.prose-col h3 { font-weight: 600; font-size: 1.1rem; margin: 1.8rem 0 0.6rem; }
.prose-col p { line-height: 1.7; margin: 0 0 1.1rem; }
.prose-col a { text-decoration: underline; text-underline-offset: 3px; text-decoration-color: var(--accent); }
.prose-col ul, .prose-col ol { line-height: 1.7; margin: 0 0 1.1rem 1.2rem; }
.prose-col li { margin-bottom: 0.35rem; }
.prose-col code { font-family: var(--font-mono); font-size: 0.88em; background: var(--accent-soft); padding: 0.1em 0.35em; border-radius: 4px; }
.prose-col pre { overflow-x: auto; border: 1px solid var(--line); border-radius: 8px; padding: 1rem; margin: 0 0 1.1rem; }
.prose-col pre code { background: none; padding: 0; }
```

- [ ] **Step 2: Import fonts + css in the throwaway index and verify**

Replace `src/pages/index.astro` frontmatter with:
```astro
---
import '@fontsource/ibm-plex-sans/400.css';
import '@fontsource/ibm-plex-sans/500.css';
import '@fontsource/ibm-plex-sans/600.css';
import '@fontsource/ibm-plex-serif/300.css';
import '@fontsource/ibm-plex-serif/300-italic.css';
import '@fontsource/ibm-plex-mono/400.css';
import '@fontsource/ibm-plex-mono/500.css';
import '../styles/global.css';
---
<html lang="en"><head><title>Enver Cetin</title></head>
<body><h1 class="font-serif font-light text-4xl">I build AI that actually works.</h1></body></html>
```

```bash
npm run build
```
Expected: build succeeds; `dist/index.html` references woff2 assets and the compiled CSS contains `--accent: #0e7c5b`.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: design tokens, ibm plex fonts, global css"
```

---

### Task 3: Monogram/logo, favicon, default OG image

**Files:**
- Create: `src/components/Monogram.astro`, `public/favicon.svg`, `scripts/generate-og.mjs`, `public/og-default.png` (generated)

**Interfaces:**
- Produces: `<Monogram size={28} />` (circle mark, theme-aware via `currentColor`); `/favicon.svg`; `/og-default.png` (1200×630).

- [ ] **Step 1: Write `src/components/Monogram.astro`**

```astro
---
interface Props { size?: number }
const { size = 28 } = Astro.props;
---
<svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true">
  <circle cx="16" cy="16" r="16" fill="currentColor"></circle>
  <text x="16" y="21" text-anchor="middle"
    font-family="IBM Plex Sans, sans-serif" font-weight="600" font-size="12.5"
    letter-spacing="-0.5" fill="var(--bg)">EC</text>
</svg>
```

- [ ] **Step 2: Write `public/favicon.svg`** (self-contained, no CSS vars)

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <circle cx="16" cy="16" r="16" fill="#16181d"/>
  <text x="16" y="21" text-anchor="middle" font-family="ui-sans-serif,system-ui,sans-serif" font-weight="600" font-size="12.5" letter-spacing="-0.5" fill="#fafafa">EC</text>
</svg>
```

- [ ] **Step 3: Write `scripts/generate-og.mjs`** (uses sharp, ships with Astro)

```js
import sharp from 'sharp';

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
  <rect width="1200" height="630" fill="#0a0a0a"/>
  <circle cx="120" cy="120" r="44" fill="#ececec"/>
  <text x="120" y="135" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-weight="700" font-size="36" fill="#0a0a0a">EC</text>
  <text x="80" y="330" font-family="Georgia, serif" font-weight="300" font-size="64" fill="#ececec">I build AI that actually works.</text>
  <text x="80" y="395" font-family="Georgia, serif" font-style="italic" font-weight="300" font-size="40" fill="#9aa1ad">Not in labs. Not in theory.</text>
  <text x="80" y="540" font-family="Courier New, monospace" font-size="26" letter-spacing="4" fill="#2fbd8f">ENVER CETIN — DIRECTOR AI, CIKLUM · MUNICH</text>
</svg>`;

await sharp(Buffer.from(svg)).png().toFile('public/og-default.png');
console.log('og-default.png written');
```

- [ ] **Step 4: Generate and verify**

```bash
node scripts/generate-og.mjs && file public/og-default.png
```
Expected: `PNG image data, 1200 x 630`. Open it once to eyeball the layout.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: ec monogram, favicon, default og image"
```

---

### Task 4: i18n helpers (TDD)

**Files:**
- Create: `src/i18n/ui.ts`, `src/i18n/routes.ts`, `tests/unit/i18n.test.ts`, `vitest.config.ts`

**Interfaces:**
- Produces:
  - `type Locale = 'en' | 'de'`; `const locales: Locale[]`
  - `t(locale: Locale): (key: string) => string`
  - `getLocaleFromPath(pathname: string): Locale`
  - `localizePath(enRootPath: string, locale: Locale): string` (e.g. `('/writing','de') → '/de/writing'`)
  - `alternatePath(pathname: string): string` (same page, other locale)

- [ ] **Step 1: Write `vitest.config.ts`**

```ts
import { defineConfig } from 'vitest/config';
export default defineConfig({ test: { include: ['tests/unit/**/*.test.ts'] } });
```

- [ ] **Step 2: Write the failing tests `tests/unit/i18n.test.ts`**

```ts
import { describe, it, expect } from 'vitest';
import { getLocaleFromPath, localizePath, alternatePath, t } from '../../src/i18n/routes';

describe('getLocaleFromPath', () => {
  it('detects de prefix', () => {
    expect(getLocaleFromPath('/de')).toBe('de');
    expect(getLocaleFromPath('/de/writing')).toBe('de');
  });
  it('defaults to en', () => {
    expect(getLocaleFromPath('/')).toBe('en');
    expect(getLocaleFromPath('/writing/foo')).toBe('en');
    expect(getLocaleFromPath('/design')).toBe('en'); // no false 'de' match
  });
});

describe('localizePath', () => {
  it('prefixes de and keeps en at root', () => {
    expect(localizePath('/writing', 'de')).toBe('/de/writing');
    expect(localizePath('/', 'de')).toBe('/de');
    expect(localizePath('/writing', 'en')).toBe('/writing');
  });
});

describe('alternatePath', () => {
  it('round-trips both directions', () => {
    expect(alternatePath('/writing/foo')).toBe('/de/writing/foo');
    expect(alternatePath('/de/writing/foo')).toBe('/writing/foo');
    expect(alternatePath('/')).toBe('/de');
    expect(alternatePath('/de')).toBe('/');
  });
});

describe('t', () => {
  it('returns translated ui strings and falls back to en', () => {
    expect(t('de')('nav.work')).toBe('Projekte');
    expect(t('en')('nav.work')).toBe('Work');
  });
});
```

- [ ] **Step 3: Run tests, verify they fail**

```bash
npx vitest run
```
Expected: FAIL (module not found).

- [ ] **Step 4: Implement `src/i18n/ui.ts`**

```ts
export const ui = {
  en: {
    'nav.work': 'Work', 'nav.writing': 'Writing', 'nav.ventures': 'Ventures',
    'nav.about': 'About', 'nav.contact': 'Contact', 'nav.search': 'Search',
    'home.paths.title': 'How we can work together',
    'home.writing.title': 'Selected writing', 'home.work.title': 'Selected work',
    'home.ventures.title': 'Ventures', 'home.router.title': 'What now?',
    'writing.external': 'External', 'writing.readmore': 'Read on',
    'work.disclaimer': 'Anonymized engagement patterns from real programs I led or architected. Figures are order-of-magnitude.',
    'footer.imprint': 'Imprint', 'footer.privacy': 'Privacy',
    'contact.title': 'Get in touch', 'meta.minRead': 'min read',
    'notfound.title': 'Page not found', 'notfound.back': 'Back to start',
  },
  de: {
    'nav.work': 'Projekte', 'nav.writing': 'Artikel', 'nav.ventures': 'Ventures',
    'nav.about': 'Über mich', 'nav.contact': 'Kontakt', 'nav.search': 'Suche',
    'home.paths.title': 'Wie wir zusammenarbeiten können',
    'home.writing.title': 'Ausgewählte Artikel', 'home.work.title': 'Ausgewählte Projekte',
    'home.ventures.title': 'Ventures', 'home.router.title': 'Was nun?',
    'writing.external': 'Extern', 'writing.readmore': 'Weiterlesen auf',
    'work.disclaimer': 'Anonymisierte Engagement-Muster aus realen Programmen, die ich geleitet oder architektiert habe. Zahlen sind Größenordnungen.',
    'footer.imprint': 'Impressum', 'footer.privacy': 'Datenschutz',
    'contact.title': 'Kontakt aufnehmen', 'meta.minRead': 'Min. Lesezeit',
    'notfound.title': 'Seite nicht gefunden', 'notfound.back': 'Zur Startseite',
  },
} as const;
```

(Weitere Keys dürfen in späteren Tasks ergänzt werden — immer paarweise en+de.)

- [ ] **Step 5: Implement `src/i18n/routes.ts`**

```ts
import { ui } from './ui';

export type Locale = 'en' | 'de';
export const locales: Locale[] = ['en', 'de'];

export function getLocaleFromPath(pathname: string): Locale {
  return pathname === '/de' || pathname.startsWith('/de/') ? 'de' : 'en';
}

export function localizePath(enRootPath: string, locale: Locale): string {
  const clean = enRootPath.startsWith('/') ? enRootPath : `/${enRootPath}`;
  if (locale === 'en') return clean;
  return clean === '/' ? '/de' : `/de${clean}`;
}

export function alternatePath(pathname: string): string {
  if (getLocaleFromPath(pathname) === 'de') {
    const rest = pathname === '/de' ? '/' : pathname.slice(3);
    return rest;
  }
  return localizePath(pathname, 'de');
}

export function t(locale: Locale) {
  return (key: string): string =>
    (ui[locale] as Record<string, string>)[key] ?? (ui.en as Record<string, string>)[key] ?? key;
}
```

- [ ] **Step 6: Run tests, verify pass**

```bash
npx vitest run
```
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: i18n route helpers and ui strings with tests"
```

---

### Task 5: Content collections — schemas, cases, ventures, profile

**Files:**
- Create: `src/content.config.ts`, `src/content/work/en/*.md` (6 files), `src/content/work/de/*.md` (6 files), `src/content/ventures.yaml`, `src/data/profile.ts`
- Reference (read-only source): `legacy/ProjectsSection.tsx`, `legacy/VenturesSection.tsx`, `legacy/profile.ts`

**Interfaces:**
- Produces: collections `writing` (empty for now, schema ready) and `work`; `ventures.yaml` shape `[{ id, url, status, en: {name, tagline, story}, de: {...} }]`; `profile` export with `name, role: {en, de}, location: {en, de}, claim: [string, string], linkedin, github, email, expertise: {en: Pillar[], de: Pillar[]}` where `Pillar = { title: string, items: string[] }`.

- [ ] **Step 1: Write `src/content.config.ts`**

```ts
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const writing = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/writing' }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    description: z.string(),
    tags: z.array(z.string()).default([]),
    type: z.enum(['post', 'external']).default('post'),
    externalUrl: z.string().url().optional(),
    source: z.string().optional(),
    draft: z.boolean().default(false),
  }).refine((d) => d.type !== 'external' || !!d.externalUrl, {
    message: 'external entries need externalUrl',
  }),
});

const work = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/work' }),
  schema: z.object({
    title: z.string(),
    industry: z.string(),
    workType: z.enum(['Strategy', 'Architecture', 'Engineering']),
    kpis: z.array(z.object({ label: z.string(), value: z.string() })).max(3),
    tags: z.array(z.string()).default([]),
    order: z.number(),
  }),
});

export const collections = { writing, work };
```

- [ ] **Step 2: Create the 6 curated work cases (EN), porting text from `legacy/ProjectsSection.tsx`**

Curated selection (max 2 per industry; source text sits in the legacy file — condense each `challenge` to ≤ 3 sentences, write `## Challenge`, `## Approach`, `## Impact` sections from the legacy `challenge`/`summary` fields, and convert every KPI to an order-of-magnitude value):

| File | Legacy case | industry | workType | order |
|---|---|---|---|---|
| `en/bfsi-fraud-detection.md` | Adaptive Fraud Detection Network | BFSI | Engineering | 1 |
| `en/bfsi-kyc-due-diligence.md` | Automated KYC & Enhanced Due Diligence | BFSI | Architecture | 2 |
| `en/automotive-technician-swarm.md` | Technician Support Agentic Swarm | Automotive & Manufacturing | Engineering | 3 |
| `en/logistics-fleet-dispatch.md` | Predictive Fleet Dispatch & Delivery | Logistics & Supply Chain | Architecture | 4 |
| `en/construction-bim-compliance.md` | Generative BIM Compliance | EPCM & Construction | Engineering | 5 |
| `en/enterprise-ai-academy.md` | VP-Level AI Academy | Strategic AI & Enterprise | Strategy | 6 |

Fully worked example — `src/content/work/en/bfsi-fraud-detection.md` (the other five follow exactly this shape):

```md
---
title: Adaptive Fraud Detection Network
industry: BFSI
workType: Engineering
kpis:
  - { label: 'False positives', value: '~75 % fewer' }
  - { label: 'Novel fraud caught', value: '>3× more' }
  - { label: 'Investigation time', value: '~70 % less' }
tags: [LLM, Anomaly Detection, Streaming]
order: 1
---

## Challenge

The legacy rule-based fraud engine flagged overwhelmingly legitimate transactions — investigators spent their days triaging noise while novel fraud patterns slipped through. Losses were rising despite a growing team.

## Approach

Replaced static rules with an adaptive detection network: streaming feature pipeline, anomaly models with LLM-assisted case summarization, and a feedback loop from investigator decisions back into the models.

## Impact

Investigators now start from ranked, pre-summarized cases instead of raw alerts. False positives dropped by an order of magnitude class, materially more novel fraud is caught, and triage time per case collapsed.
```

- [ ] **Step 3: Create the 6 DE counterparts (`src/content/work/de/…`, same filenames)**

Same frontmatter (title may stay English where it is a proper product term; `kpis` labels translated), body translated into sachlichen deutschen Fachstil. Worked example `de/bfsi-fraud-detection.md`:

```md
---
title: Adaptive Fraud Detection Network
industry: BFSI
workType: Engineering
kpis:
  - { label: 'False Positives', value: '~75 % weniger' }
  - { label: 'Neue Betrugsmuster', value: '>3× mehr erkannt' }
  - { label: 'Untersuchungszeit', value: '~70 % kürzer' }
tags: [LLM, Anomaly Detection, Streaming]
order: 1
---

## Ausgangslage

Die regelbasierte Fraud-Engine markierte überwiegend legitime Transaktionen — die Ermittler verbrachten ihre Tage mit dem Triagieren von Rauschen, während neuartige Betrugsmuster durchrutschten. Die Verluste stiegen trotz wachsendem Team.

## Vorgehen

Statische Regeln wurden durch ein adaptives Erkennungsnetz ersetzt: Streaming-Feature-Pipeline, Anomalie-Modelle mit LLM-gestützter Fallzusammenfassung und eine Feedback-Schleife von Ermittler-Entscheidungen zurück in die Modelle.

## Ergebnis

Ermittler starten heute mit priorisierten, vorzusammengefassten Fällen statt roher Alerts. False Positives sanken um eine Größenordnung, deutlich mehr neuartiger Betrug wird erkannt, die Triagezeit pro Fall bricht ein.
```

- [ ] **Step 4: Write `src/content/ventures.yaml`** (text source: `legacy/VenturesSection.tsx` + Spec §3)

```yaml
- id: vertragsklar
  url: https://vertragsklar.de
  status: live
  en:
    name: Vertragsklar
    tagline: AI contract analysis for consumers — five specialized legal AI agents review German contracts in under two minutes.
    story: Built to make contract risks understandable for non-lawyers. An "AI council" of five specialized agents (contract law, T&C, tenancy, labor law, risk) cross-validates findings and produces a plain-language PDF report. GDPR-compliant, German servers, one-time pricing.
  de:
    name: Vertragsklar
    tagline: KI-Vertragsanalyse für Verbraucher — fünf spezialisierte Legal-KI-Agenten prüfen deutsche Verträge in unter zwei Minuten.
    story: Gebaut, um Vertragsrisiken für Nicht-Juristen verständlich zu machen. Ein „KI-Rat" aus fünf spezialisierten Agenten (Vertragsrecht, AGB, Mietrecht, Arbeitsrecht, Risiko) validiert Befunde gegenseitig und erzeugt einen verständlichen PDF-Report. DSGVO-konform, deutsche Server, Einmalpreis.
- id: nebenkosten-ninja
  url: https://nebenkosten-ninja.vercel.app
  status: live
  en:
    name: Nebenkosten-Ninja
    tagline: Freemium checker for German utility-cost statements — a client-side rules engine spots the most common billing errors.
    story: German tenants overpay through faulty utility statements every year. Nebenkosten-Ninja checks a statement against a curated rule set entirely in the browser — no upload, no account — and explains every finding in plain language.
  de:
    name: Nebenkosten-Ninja
    tagline: Freemium-Check für Nebenkostenabrechnungen — eine client-seitige Regel-Engine findet die häufigsten Abrechnungsfehler.
    story: Mieter zahlen jedes Jahr durch fehlerhafte Nebenkostenabrechnungen drauf. Nebenkosten-Ninja prüft eine Abrechnung vollständig im Browser gegen ein kuratiertes Regelwerk — ohne Upload, ohne Konto — und erklärt jeden Befund verständlich.
```

- [ ] **Step 5: Write `src/data/profile.ts`** (port from `legacy/profile.ts`, update role to Director, keep numbers user-verifiable)

```ts
export type Pillar = { title: string; items: string[] };

export const profile = {
  name: 'Enver Cetin',
  claim: ['I build AI that actually works.', 'Not in labs. Not in theory.'],
  role: { en: 'Director AI, Ciklum · Munich', de: 'Director AI, Ciklum · München' },
  email: 'mail@envercetin.de', // verify with Enver before launch
  linkedin: 'https://www.linkedin.com/in/enver-cetin',
  github: 'https://github.com/cetine',
  expertise: {
    en: [
      { title: 'AI Strategy & Transformation', items: ['Enterprise AI strategy & operating models', 'AI governance & roadmaps', 'Use-case frameworks & CoE structures'] },
      { title: 'Agentic AI & LLM Engineering', items: ['Multi-agent orchestration (LangGraph, CrewAI, SK)', 'RAG & enterprise data integration', 'LLM cost-performance modeling'] },
      { title: 'Enterprise Architecture & Delivery', items: ['AI-first integration architectures', 'Event-driven automation', 'API / ERP / DMS integration'] },
      { title: 'Applied Automation', items: ['Computer vision in production', 'Process automation at scale', 'From RPA to agentic systems'] },
      { title: 'Industries', items: ['Banking & financial services', 'Manufacturing & logistics', 'Energy, construction, real estate'] },
    ],
    de: [
      { title: 'AI-Strategie & Transformation', items: ['Enterprise-AI-Strategie & Operating Models', 'AI-Governance & Roadmaps', 'Use-Case-Frameworks & CoE-Strukturen'] },
      { title: 'Agentic AI & LLM Engineering', items: ['Multi-Agent-Orchestrierung (LangGraph, CrewAI, SK)', 'RAG & Enterprise-Datenintegration', 'LLM-Kosten-Leistungs-Modellierung'] },
      { title: 'Enterprise-Architektur & Delivery', items: ['AI-first Integrationsarchitekturen', 'Event-getriebene Automatisierung', 'API- / ERP- / DMS-Integration'] },
      { title: 'Angewandte Automatisierung', items: ['Computer Vision in der Produktion', 'Prozessautomatisierung im großen Maßstab', 'Von RPA zu agentischen Systemen'] },
      { title: 'Branchen', items: ['Banken & Finanzdienstleister', 'Fertigung & Logistik', 'Energie, Bau, Immobilien'] },
    ],
  },
} as const;

// Career timeline: ported 1:1 from legacy/profile.ts careerHighlights,
// with the Ciklum entry split into "Director | AI (…– Present)" and the
// prior "Senior Manager | AI" period — exact dates to be confirmed by Enver.
export { careerHighlights, volunteerRoles } from '../../legacy/profile';
```

- [ ] **Step 6: Verify schemas via build**

```bash
mkdir -p src/content/writing/en src/content/writing/de
npm run build
```
Expected: build succeeds; no zod schema errors. (Writing collection empty is fine.)

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: content collections with 6 curated cases (en/de), ventures, profile"
```

---

### Task 6: Writing lib — merge, sort, group, reading time (TDD)

**Files:**
- Create: `src/lib/writing.ts`, `tests/unit/writing.test.ts`

**Interfaces:**
- Consumes: collection entry ids shaped `en/slug` / `de/slug`.
- Produces:
  - `type WritingMeta = { slug: string; locale: Locale; title: string; date: Date; description: string; tags: string[]; type: 'post' | 'external'; externalUrl?: string; source?: string }`
  - `filterLocale<T extends {id: string}>(entries: T[], locale: Locale): T[]`
  - `sortByDateDesc(items: WritingMeta[]): WritingMeta[]`
  - `groupByMonth(items: WritingMeta[], locale: Locale, min?: number): { grouped: boolean; groups: { label: string; items: WritingMeta[] }[] }` (min default 8; label like `2026 July` / `Juli 2026`)
  - `readingTimeMinutes(text: string, wpm?: number): number` (min 1)

- [ ] **Step 1: Write failing tests `tests/unit/writing.test.ts`**

```ts
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
    expect(en.groups[0].label).toMatch(/^2026 /);
    const de = groupByMonth(items, 'de', 8);
    expect(de.groups[0].label).toMatch(/2026$/); // "März 2026" style
  });
});

describe('readingTimeMinutes', () => {
  it('rounds up and has a floor of 1', () => {
    expect(readingTimeMinutes('word '.repeat(450))).toBe(3);
    expect(readingTimeMinutes('short text')).toBe(1);
  });
});
```

- [ ] **Step 2: Run, verify FAIL** — `npx vitest run` → module not found.

- [ ] **Step 3: Implement `src/lib/writing.ts`**

```ts
import type { Locale } from '../i18n/routes';

export type WritingMeta = {
  slug: string; locale: Locale; title: string; date: Date; description: string;
  tags: string[]; type: 'post' | 'external'; externalUrl?: string; source?: string;
};

export function filterLocale<T extends { id: string }>(entries: T[], locale: Locale): T[] {
  return entries.filter((e) => e.id.startsWith(`${locale}/`));
}

export function sortByDateDesc<T extends { date: Date }>(items: T[]): T[] {
  return [...items].sort((a, b) => b.date.getTime() - a.date.getTime());
}

export function groupByMonth(items: WritingMeta[], locale: Locale, min = 8) {
  const sorted = sortByDateDesc(items);
  if (sorted.length < min) return { grouped: false, groups: [{ label: '', items: sorted }] };
  const fmt = new Intl.DateTimeFormat(locale === 'de' ? 'de-DE' : 'en-US', { month: 'long' });
  const groups: { label: string; items: WritingMeta[] }[] = [];
  for (const item of sorted) {
    const label = locale === 'de'
      ? `${fmt.format(item.date)} ${item.date.getFullYear()}`
      : `${item.date.getFullYear()} ${fmt.format(item.date)}`;
    const last = groups[groups.length - 1];
    if (last && last.label === label) last.items.push(item);
    else groups.push({ label, items: [item] });
  }
  return { grouped: true, groups };
}

export function readingTimeMinutes(text: string, wpm = 200): number {
  const words = text.trim().split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.ceil(words / wpm));
}
```

- [ ] **Step 4: Run, verify PASS** — `npx vitest run`.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: writing lib (locale filter, sort, month grouping, reading time)"`

---

### Task 7: SEO lib (TDD)

**Files:**
- Create: `src/lib/seo.ts`, `tests/unit/seo.test.ts`

**Interfaces:**
- Produces:
  - `pageTitle(title?: string): string` → `Enver Cetin — Director AI` (no arg) / `${title} — Enver Cetin`
  - `personJsonLd(): object` (Schema.org Person with sameAs)
  - `articleJsonLd(a: { title: string; description: string; date: Date; url: string; lang: string }): object`
  - `websiteJsonLd(): object`

- [ ] **Step 1: Failing tests `tests/unit/seo.test.ts`**

```ts
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
```

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Implement `src/lib/seo.ts`**

```ts
import { profile } from '../data/profile';

const SITE = 'https://envercetin.de';

export function pageTitle(title?: string): string {
  return title ? `${title} — ${profile.name}` : `${profile.name} — Director AI`;
}

export function personJsonLd() {
  return {
    '@context': 'https://schema.org',
    '@type': 'Person',
    name: profile.name,
    jobTitle: 'Director AI',
    worksFor: { '@type': 'Organization', name: 'Ciklum' },
    url: SITE,
    sameAs: [profile.linkedin, profile.github],
  };
}

export function websiteJsonLd() {
  return { '@context': 'https://schema.org', '@type': 'WebSite', name: profile.name, url: SITE };
}

export function articleJsonLd(a: { title: string; description: string; date: Date; url: string; lang: string }) {
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: a.title,
    description: a.description,
    datePublished: a.date.toISOString().slice(0, 10),
    inLanguage: a.lang,
    url: a.url,
    author: { '@type': 'Person', name: profile.name, url: SITE },
  };
}
```

- [ ] **Step 4: Run, verify PASS. Step 5: Commit** — `git commit -am "feat: seo lib (titles, json-ld builders)"`

---

### Task 8: Base layout, Nav, Footer, theme toggle

**Files:**
- Create: `src/layouts/Base.astro`, `src/components/Nav.astro`, `src/components/Footer.astro`, `src/components/Eyebrow.astro`

**Interfaces:**
- Consumes: `Monogram`, i18n helpers, seo lib, fonts/global.css.
- Produces: `<Base title description pathname locale jsonLd?>` wrapping every page; slot `default`. `<Eyebrow>01 · TEXT</Eyebrow>` (mono, accent, tracking). Nav search button `id="open-search"` + `data-pagefind-ignore` on chrome.

- [ ] **Step 1: Write `src/components/Eyebrow.astro`**

```astro
---
---
<span class="font-mono text-[11px] tracking-[0.15em] uppercase text-accent"><slot /></span>
```

- [ ] **Step 2: Write `src/components/Nav.astro`**

```astro
---
import Monogram from './Monogram.astro';
import { t, localizePath, alternatePath, type Locale } from '../i18n/routes';
interface Props { locale: Locale; pathname: string }
const { locale, pathname } = Astro.props;
const tr = t(locale);
const links = [
  { href: localizePath('/work', locale), label: tr('nav.work') },
  { href: localizePath('/writing', locale), label: tr('nav.writing') },
  { href: localizePath('/ventures', locale), label: tr('nav.ventures') },
  { href: localizePath('/about', locale), label: tr('nav.about') },
];
const isActive = (href: string) => pathname === href || pathname.startsWith(`${href}/`);
---
<header class="sticky top-0 z-40 border-b border-line bg-bg/80 backdrop-blur" data-pagefind-ignore>
  <nav class="mx-auto flex max-w-5xl items-center justify-between gap-4 px-5 py-3">
    <a href={localizePath('/', locale)} class="flex items-center gap-2.5 text-fg">
      <Monogram size={26} />
      <span class="text-[13px] font-semibold tracking-[0.22em]">ENVER&nbsp;CETIN</span>
    </a>
    <div class="hidden items-center gap-5 sm:flex">
      {links.map((l) => (
        <a href={l.href} class:list={['text-[13px] tracking-wide', isActive(l.href) ? 'text-fg' : 'text-muted hover:text-fg']}>{l.label}</a>
      ))}
      <button id="open-search" class="flex items-center gap-1.5 text-[13px] text-muted hover:text-fg" aria-label={tr('nav.search')}>
        {tr('nav.search')}
        <kbd class="rounded border border-line px-1.5 py-0.5 font-mono text-[10px]">⌘K</kbd>
      </button>
      <a href={alternatePath(pathname)} class="font-mono text-[11px] text-muted hover:text-fg" rel="alternate">{locale === 'en' ? 'DE' : 'EN'}</a>
      <button id="theme-toggle" class="text-muted hover:text-fg" aria-label="Toggle theme">◐</button>
    </div>
    <div class="flex items-center gap-4 sm:hidden">
      <button id="open-search-mobile" class="text-muted" aria-label={tr('nav.search')}>⌕</button>
      <a href={alternatePath(pathname)} class="font-mono text-[11px] text-muted" rel="alternate">{locale === 'en' ? 'DE' : 'EN'}</a>
      <button id="menu-toggle" class="text-fg" aria-expanded="false" aria-controls="mobile-menu" aria-label="Menu">☰</button>
    </div>
  </nav>
  <div id="mobile-menu" class="hidden border-t border-line px-5 py-3 sm:hidden">
    {links.map((l) => <a href={l.href} class="block py-2 text-sm text-fg">{l.label}</a>)}
    <button id="theme-toggle-mobile" class="py-2 text-sm text-muted">Light / Dark</button>
  </div>
</header>
<script>
  const toggle = () => {
    const html = document.documentElement;
    const next = html.dataset.theme === 'dark' ? 'light' : 'dark';
    html.dataset.theme = next;
    localStorage.setItem('theme', next);
  };
  document.getElementById('theme-toggle')?.addEventListener('click', toggle);
  document.getElementById('theme-toggle-mobile')?.addEventListener('click', toggle);
  const menu = document.getElementById('mobile-menu');
  const btn = document.getElementById('menu-toggle');
  btn?.addEventListener('click', () => {
    const open = menu?.classList.toggle('hidden') === false;
    btn.setAttribute('aria-expanded', String(open));
  });
</script>
```

- [ ] **Step 3: Write `src/components/Footer.astro`**

```astro
---
import { t, localizePath, type Locale } from '../i18n/routes';
import { profile } from '../data/profile';
interface Props { locale: Locale }
const { locale } = Astro.props;
const tr = t(locale);
const year = new Date().getFullYear();
---
<footer class="border-t border-line" data-pagefind-ignore>
  <div class="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-3 px-5 py-8 text-[13px] text-muted">
    <span>© {year} {profile.name}</span>
    <div class="flex flex-wrap gap-4">
      <a href={`mailto:${profile.email}`} class="hover:text-fg">Mail</a>
      <a href={profile.linkedin} class="hover:text-fg" rel="me noopener">LinkedIn</a>
      <a href={profile.github} class="hover:text-fg" rel="me noopener">GitHub</a>
      <a href={locale === 'de' ? '/de/rss.xml' : '/rss.xml'} class="hover:text-fg">RSS</a>
      <a href={localizePath('/impressum', locale)} class="hover:text-fg">{tr('footer.imprint')}</a>
      <a href={localizePath('/datenschutz', locale)} class="hover:text-fg">{tr('footer.privacy')}</a>
    </div>
  </div>
</footer>
```

- [ ] **Step 4: Write `src/layouts/Base.astro`**

```astro
---
import '@fontsource/ibm-plex-sans/400.css';
import '@fontsource/ibm-plex-sans/500.css';
import '@fontsource/ibm-plex-sans/600.css';
import '@fontsource/ibm-plex-serif/300.css';
import '@fontsource/ibm-plex-serif/300-italic.css';
import '@fontsource/ibm-plex-mono/400.css';
import '@fontsource/ibm-plex-mono/500.css';
import '../styles/global.css';
import Nav from '../components/Nav.astro';
import Footer from '../components/Footer.astro';
import SearchPalette from '../components/SearchPalette';
import { pageTitle, websiteJsonLd } from '../lib/seo';
import { alternatePath, getLocaleFromPath, type Locale } from '../i18n/routes';

interface Props { title?: string; description: string; jsonLd?: object[] }
const { title, description, jsonLd = [] } = Astro.props;
const pathname = Astro.url.pathname.replace(/\/$/, '') || '/';
const locale: Locale = getLocaleFromPath(pathname);
const site = 'https://envercetin.de';
const canonical = `${site}${pathname === '/' ? '' : pathname}`;
const alt = alternatePath(pathname);
const enHref = locale === 'en' ? canonical : `${site}${alt === '/' ? '' : alt}`;
const deHref = locale === 'de' ? canonical : `${site}${alt}`;
const fullTitle = pageTitle(title);
const allJsonLd = [websiteJsonLd(), ...jsonLd];
---
<html lang={locale} data-theme="light">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{fullTitle}</title>
    <meta name="description" content={description} />
    <link rel="canonical" href={canonical} />
    <link rel="alternate" hreflang="en" href={enHref} />
    <link rel="alternate" hreflang="de" href={deHref} />
    <link rel="alternate" hreflang="x-default" href={enHref} />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <link rel="alternate" type="application/rss+xml" href={locale === 'de' ? '/de/rss.xml' : '/rss.xml'} />
    <meta property="og:title" content={fullTitle} />
    <meta property="og:description" content={description} />
    <meta property="og:url" content={canonical} />
    <meta property="og:type" content="website" />
    <meta property="og:image" content={`${site}/og-default.png`} />
    <meta name="twitter:card" content="summary_large_image" />
    <script is:inline>
      const saved = localStorage.getItem('theme');
      const preferred = saved ?? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      document.documentElement.dataset.theme = preferred;
    </script>
    {allJsonLd.map((o) => <script type="application/ld+json" set:html={JSON.stringify(o)} />)}
  </head>
  <body class="min-h-screen bg-bg font-sans text-fg antialiased">
    <a href="#main" class="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:bg-bg focus:p-2">Skip to content</a>
    <Nav locale={locale} pathname={pathname} />
    <main id="main" class="mx-auto max-w-5xl px-5"><slot /></main>
    <Footer locale={locale} />
    <SearchPalette client:idle locale={locale} />
  </body>
</html>
```

Note: `SearchPalette` does not exist until Task 16 — for this task create a stub `src/components/SearchPalette.tsx`:

```tsx
export default function SearchPalette(_props: { locale: string }) { return null; }
```

- [ ] **Step 5: Point the throwaway index at Base and verify**

`src/pages/index.astro`:
```astro
---
import Base from '../layouts/Base.astro';
---
<Base description="Enver Cetin — Director AI, Ciklum. Enterprise AI strategy, agentic systems, applied automation.">
  <h1 class="mt-16 font-serif text-5xl font-light">I build AI that actually works.</h1>
</Base>
```

```bash
npm run build && grep -c 'hreflang' dist/index.html
```
Expected: build passes; grep prints `3`.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat: base layout with nav, footer, theme toggle, seo head"`

---

### Task 9: Home page (EN + DE)

**Files:**
- Create: `src/components/pages/HomePage.astro`, `src/components/CaseCard.astro`, `src/components/VentureCard.astro`, `src/components/WritingRow.astro`
- Modify: `src/pages/index.astro`; Create: `src/pages/de/index.astro`
- Move: `public/images/Enver_Cetin.png` → `src/assets/enver-cetin.png`

**Interfaces:**
- Consumes: collections `work`/`writing`, `ventures.yaml`, `profile`, `Eyebrow`, libs.
- Produces: `<CaseCard entry locale compact?>`, `<VentureCard venture locale />`, `<WritingRow item locale />` — reused by Tasks 10–12.

- [ ] **Step 1: Write `src/components/WritingRow.astro`**

```astro
---
import { t, localizePath, type Locale } from '../i18n/routes';
import type { WritingMeta } from '../lib/writing';
interface Props { item: WritingMeta; locale: Locale }
const { item, locale } = Astro.props;
const tr = t(locale);
const fmt = new Intl.DateTimeFormat(locale === 'de' ? 'de-DE' : 'en-US', { year: 'numeric', month: 'long', day: 'numeric' });
const href = item.type === 'external' ? item.externalUrl! : localizePath(`/writing/${item.slug}`, locale);
---
<article class="py-3">
  <a href={href} rel={item.type === 'external' ? 'noopener' : undefined} class="group block">
    <h3 class="text-[17px] font-medium group-hover:underline underline-offset-4 decoration-accent">
      {item.title}
      {item.type === 'external' && <span class="ml-2 rounded-full bg-accent-soft px-2 py-0.5 font-mono text-[10px] tracking-wide text-accent align-middle">{item.source ?? tr('writing.external')} ↗</span>}
    </h3>
    <p class="mt-1 text-[13px] text-muted">
      <time datetime={item.date.toISOString().slice(0, 10)}>{fmt.format(item.date)}</time>
      {item.tags.length > 0 && <span> — {item.tags.join(', ')}</span>}
    </p>
  </a>
</article>
```

- [ ] **Step 2: Write `src/components/CaseCard.astro`**

```astro
---
import type { CollectionEntry } from 'astro:content';
import { localizePath, type Locale } from '../i18n/routes';
interface Props { entry: CollectionEntry<'work'>; locale: Locale; compact?: boolean }
const { entry, locale, compact = false } = Astro.props;
const { title, industry, workType, kpis } = entry.data;
---
<article class="border-t border-line py-6">
  <p class="font-mono text-[11px] tracking-[0.15em] uppercase text-muted">{industry} · <span class="text-accent">{workType}</span></p>
  <h3 class="mt-2 text-lg font-medium">
    <a href={`${localizePath('/work', locale)}#${entry.id.split('/')[1]}`} class="hover:underline underline-offset-4 decoration-accent">{title}</a>
  </h3>
  {!compact && (
    <dl class="mt-3 flex flex-wrap gap-x-8 gap-y-2">
      {kpis.map((k) => (
        <div>
          <dd class="font-mono text-[15px] font-medium text-fg">{k.value}</dd>
          <dt class="text-[12px] text-muted">{k.label}</dt>
        </div>
      ))}
    </dl>
  )}
</article>
```

- [ ] **Step 3: Write `src/components/VentureCard.astro`**

```astro
---
import type { Locale } from '../i18n/routes';
type Venture = { id: string; url: string; status: string; en: { name: string; tagline: string; story: string }; de: { name: string; tagline: string; story: string } };
interface Props { venture: Venture; locale: Locale; withStory?: boolean }
const { venture, locale, withStory = false } = Astro.props;
const v = venture[locale];
---
<article class="rounded-lg border border-line p-5">
  <div class="flex items-center gap-2.5">
    <h3 class="text-lg font-medium">{v.name}</h3>
    {venture.status === 'live' && (
      <span class="inline-flex items-center gap-1.5 rounded-full bg-accent-soft px-2 py-0.5 font-mono text-[10px] tracking-wide text-accent">
        <span class="h-1.5 w-1.5 rounded-full bg-accent"></span>LIVE
      </span>
    )}
  </div>
  <p class="mt-2 text-[14px] leading-relaxed text-muted">{v.tagline}</p>
  {withStory && <p class="mt-3 text-[14px] leading-relaxed">{v.story}</p>}
  <a href={venture.url} rel="noopener" class="mt-3 inline-block text-[13px] underline underline-offset-4 decoration-accent hover:text-accent">{venture.url.replace('https://', '')} ↗</a>
</article>
```

- [ ] **Step 4: Write `src/components/pages/HomePage.astro`**

```astro
---
import { getCollection } from 'astro:content';
import { Image } from 'astro:assets';
import Base from '../../layouts/Base.astro';
import Eyebrow from '../Eyebrow.astro';
import CaseCard from '../CaseCard.astro';
import VentureCard from '../VentureCard.astro';
import WritingRow from '../WritingRow.astro';
import ventures from '../../content/ventures.yaml';
import headshot from '../../assets/enver-cetin.png';
import { profile } from '../../data/profile';
import { personJsonLd } from '../../lib/seo';
import { t, localizePath, type Locale } from '../../i18n/routes';
import { filterLocale, sortByDateDesc, type WritingMeta } from '../../lib/writing';

interface Props { locale: Locale }
const { locale } = Astro.props;
const tr = t(locale);

const work = filterLocale(await getCollection('work'), locale)
  .sort((a, b) => a.data.order - b.data.order).slice(0, 4);

const writingAll = filterLocale(await getCollection('writing', ({ data }) => !data.draft), locale);
const writing: WritingMeta[] = sortByDateDesc(
  writingAll.map((e) => ({ slug: e.id.split('/')[1], locale, ...e.data }))
).slice(0, 3);

const paths = locale === 'de' ? [
  { n: '01', title: 'Speaking & Workshops', text: 'Keynotes, Vorträge und Executive-Workshops zu Enterprise AI, agentischen Systemen und AI-Adoption — praxisnah statt Hype.', cta: 'Vortrag anfragen', intent: 'speaking' },
  { n: '02', title: 'Advisory', text: 'Sparring für Führungskräfte: AI-Strategie, Operating Models, Architektur-Reviews. Direkt, unabhängig, umsetzungsnah.', cta: 'Sparring vereinbaren', intent: 'advisory' },
  { n: '03', title: 'Enterprise AI', text: 'AI-Programme mit Team: von der Strategie bis zum produktiven Agenten-System — für Mittelstand und Konzerne.', cta: 'Projekt besprechen', intent: 'enterprise' },
] : [
  { n: '01', title: 'Speaking & Workshops', text: 'Keynotes, talks and executive workshops on enterprise AI, agentic systems and AI adoption — grounded in practice, not hype.', cta: 'Request a talk', intent: 'speaking' },
  { n: '02', title: 'Advisory', text: 'Sparring for leaders: AI strategy, operating models, architecture reviews. Direct, independent, close to execution.', cta: 'Book a sparring session', intent: 'advisory' },
  { n: '03', title: 'Enterprise AI', text: 'AI programs with a team: from strategy to production agentic systems — for Mittelstand and global enterprises.', cta: 'Discuss a project', intent: 'enterprise' },
];

const router = locale === 'de' ? [
  { q: 'Du planst ein Event und suchst einen Speaker?', a: 'Vortrag anfragen', href: '/contact?intent=speaking' },
  { q: 'Du willst AI in deinem Unternehmen ernsthaft voranbringen?', a: 'Projekt besprechen', href: '/contact?intent=enterprise' },
  { q: 'Du willst ein zweites Paar Augen auf deine AI-Strategie?', a: 'Sparring vereinbaren', href: '/contact?intent=advisory' },
  { q: 'Einfach nur mitlesen?', a: 'LinkedIn folgen', href: profile.linkedin, external: true },
] : [
  { q: 'Planning an event and looking for a speaker?', a: 'Request a talk', href: '/contact?intent=speaking' },
  { q: 'Serious about moving AI forward in your company?', a: 'Discuss a project', href: '/contact?intent=enterprise' },
  { q: 'Want a second pair of eyes on your AI strategy?', a: 'Book a sparring session', href: '/contact?intent=advisory' },
  { q: 'Just want to follow along?', a: 'Follow on LinkedIn', href: profile.linkedin, external: true },
];

const description = locale === 'de'
  ? 'Enver Cetin — Director AI bei Ciklum. Enterprise-AI-Strategie, agentische Systeme und angewandte Automatisierung. Speaking, Advisory, Enterprise-Programme.'
  : 'Enver Cetin — Director AI at Ciklum. Enterprise AI strategy, agentic systems and applied automation. Speaking, advisory, enterprise programs.';
---
<Base description={description} jsonLd={[personJsonLd()]}>
  <!-- Hero -->
  <section class="grid gap-10 py-16 sm:grid-cols-[1fr_auto] sm:items-center sm:py-24">
    <div>
      <h1 class="font-serif text-4xl font-light leading-tight sm:text-5xl">{profile.claim[0]}</h1>
      <p class="mt-2 font-serif text-2xl font-light italic text-muted sm:text-3xl">{profile.claim[1]}</p>
      <p class="mt-6 font-mono text-[12px] tracking-[0.15em] uppercase text-muted">{profile.role[locale]}</p>
    </div>
    <Image src={headshot} alt="Enver Cetin" width={280} densities={[1, 2]}
      class="h-40 w-40 rounded-full object-cover sm:h-52 sm:w-52" loading="eager" />
  </section>

  <!-- Engagement paths -->
  <section class="border-t border-line py-14">
    <h2 class="sr-only">{tr('home.paths.title')}</h2>
    <div class="grid gap-8 sm:grid-cols-3">
      {paths.map((p) => (
        <div>
          <Eyebrow>{p.n} · {p.title}</Eyebrow>
          <p class="mt-3 text-[14px] leading-relaxed">{p.text}</p>
          <a href={localizePath(`/contact?intent=${p.intent}`, locale)} class="mt-3 inline-block text-[13px] underline underline-offset-4 decoration-accent hover:text-accent">{p.cta} →</a>
        </div>
      ))}
    </div>
  </section>

  <!-- Selected writing (hidden when empty) -->
  {writing.length > 0 && (
    <section class="border-t border-line py-14">
      <div class="flex items-baseline justify-between">
        <h2 class="font-serif text-2xl font-light">{tr('home.writing.title')}</h2>
        <a href={localizePath('/writing', locale)} class="text-[13px] text-muted hover:text-fg">{locale === 'de' ? 'Alle Artikel' : 'All writing'} →</a>
      </div>
      <div class="mt-4 divide-y divide-line">{writing.map((w) => <WritingRow item={w} locale={locale} />)}</div>
    </section>
  )}

  <!-- Selected work -->
  <section class="border-t border-line py-14">
    <div class="flex items-baseline justify-between">
      <h2 class="font-serif text-2xl font-light">{tr('home.work.title')}</h2>
      <a href={localizePath('/work', locale)} class="text-[13px] text-muted hover:text-fg">{locale === 'de' ? 'Alle Projekte' : 'All work'} →</a>
    </div>
    <div class="mt-2">{work.map((e) => <CaseCard entry={e} locale={locale} compact />)}</div>
  </section>

  <!-- Ventures -->
  <section class="border-t border-line py-14">
    <div class="flex items-baseline justify-between">
      <h2 class="font-serif text-2xl font-light">{tr('home.ventures.title')}</h2>
      <a href={localizePath('/ventures', locale)} class="text-[13px] text-muted hover:text-fg">{locale === 'de' ? 'Mehr' : 'More'} →</a>
    </div>
    <div class="mt-5 grid gap-5 sm:grid-cols-2">{ventures.map((v: any) => <VentureCard venture={v} locale={locale} />)}</div>
  </section>

  <!-- What now? router -->
  <section class="border-t border-line py-14">
    <h2 class="font-serif text-2xl font-light">{tr('home.router.title')}</h2>
    <ul class="mt-5 space-y-3">
      {router.map((r) => (
        <li class="flex flex-wrap items-baseline gap-x-3 gap-y-1 text-[14px]">
          <span>{r.q}</span>
          <a href={r.external ? r.href : localizePath(r.href, locale)} rel={r.external ? 'noopener' : undefined}
            class="underline underline-offset-4 decoration-accent hover:text-accent">{r.a} →</a>
        </li>
      ))}
    </ul>
  </section>
</Base>

<script is:inline>
  // Legacy hash routes from the old SPA
  const map = { '#ventures': '/ventures', '#labs': '/', '#projects': '/work', '#contact': '/contact', '#tech-map': '/about' };
  const target = map[location.hash];
  if (target && location.pathname === '/') location.replace(target);
</script>
```

- [ ] **Step 5: Wire pages**

`src/pages/index.astro`:
```astro
---
import HomePage from '../components/pages/HomePage.astro';
---
<HomePage locale="en" />
```

`src/pages/de/index.astro`:
```astro
---
import HomePage from '../../components/pages/HomePage.astro';
---
<HomePage locale="de" />
```

Also: `git mv public/images/Enver_Cetin.png src/assets/enver-cetin.png` and add YAML support — create `src/types/yaml.d.ts`:
```ts
declare module '*.yaml' { const value: any; export default value; }
```
and add to `astro.config.mjs` vite plugins if needed: Astro ≥5 supports YAML imports natively via `@rollup/plugin-yaml` — add dev dependency and plugin:
```bash
npm install -D @rollup/plugin-yaml
```
```js
// astro.config.mjs vite section becomes:
import yaml from '@rollup/plugin-yaml';
// ...
vite: { plugins: [tailwindcss(), yaml()] },
```

- [ ] **Step 6: Verify**

```bash
npm run build
grep -c 'I build AI that actually works.' dist/index.html dist/de/index.html
```
Expected: both files contain the claim once each; images emitted as optimized variants under `dist/_astro/`.

- [ ] **Step 7: Commit** — `git add -A && git commit -m "feat: home page en/de with engagement paths, selections, router"`

---

### Task 10: Work page (EN + DE)

**Files:**
- Create: `src/components/pages/WorkPage.astro`, `src/pages/work.astro`, `src/pages/de/work.astro`

**Interfaces:**
- Consumes: `work` collection, `CaseCard` pattern (full rendering here is custom — body included), `Eyebrow`, i18n.

- [ ] **Step 1: Write `src/components/pages/WorkPage.astro`**

```astro
---
import { getCollection, render } from 'astro:content';
import Base from '../../layouts/Base.astro';
import Eyebrow from '../Eyebrow.astro';
import { t, type Locale } from '../../i18n/routes';
import { filterLocale } from '../../lib/writing';

interface Props { locale: Locale }
const { locale } = Astro.props;
const tr = t(locale);
const entries = filterLocale(await getCollection('work'), locale).sort((a, b) => a.data.order - b.data.order);
const rendered = await Promise.all(entries.map(async (e) => ({ e, C: (await render(e)).Content })));
const byIndustry: { industry: string; items: typeof rendered }[] = [];
for (const r of rendered) {
  const last = byIndustry[byIndustry.length - 1];
  if (last && last.industry === r.e.data.industry) last.items.push(r);
  else byIndustry.push({ industry: r.e.data.industry, items: [r] });
}
const title = locale === 'de' ? 'Projekte' : 'Work';
const description = locale === 'de'
  ? 'Anonymisierte Engagement-Muster aus realen AI-Programmen: BFSI, Fertigung, Logistik, Bau, Enterprise-Strategie.'
  : 'Anonymized engagement patterns from real AI programs: BFSI, manufacturing, logistics, construction, enterprise strategy.';
---
<Base title={title} description={description}>
  <header class="py-14">
    <h1 class="font-serif text-4xl font-light">{title}</h1>
    <p class="mt-3 max-w-[46em] text-[14px] text-muted">{tr('work.disclaimer')}</p>
  </header>
  {byIndustry.map((group) => (
    <section class="border-t border-line py-10">
      <h2 class="font-mono text-[12px] tracking-[0.18em] uppercase text-muted">{group.industry}</h2>
      {group.items.map(({ e, C }) => (
        <article id={e.id.split('/')[1]} class="mt-8 scroll-mt-24">
          <Eyebrow>{e.data.workType}</Eyebrow>
          <h3 class="mt-2 font-serif text-2xl font-light">{e.data.title}</h3>
          <dl class="mt-4 flex flex-wrap gap-x-10 gap-y-2">
            {e.data.kpis.map((k) => (
              <div>
                <dd class="font-mono text-lg font-medium">{k.value}</dd>
                <dt class="text-[12px] text-muted">{k.label}</dt>
              </div>
            ))}
          </dl>
          <div class="prose-col mt-4"><C /></div>
          {e.data.tags.length > 0 && <p class="mt-2 font-mono text-[11px] tracking-wide text-muted">{e.data.tags.join(' · ')}</p>}
        </article>
      ))}
    </section>
  ))}
</Base>
```

- [ ] **Step 2: Wire `src/pages/work.astro` + `src/pages/de/work.astro`** (same thin-wrapper pattern as Task 9 Step 5, `locale="en"` / `"de"`).

- [ ] **Step 3: Verify** — `npm run build && grep -c 'Adaptive Fraud Detection' dist/work/index.html dist/de/work/index.html` → both ≥ 1.

- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat: work page with industry-grouped engagement patterns"`

---

### Task 11: Writing index + post pages (EN + DE)

**Files:**
- Create: `src/components/pages/WritingIndexPage.astro`, `src/components/pages/WritingPostLayout.astro`, `src/pages/writing/index.astro`, `src/pages/writing/[slug].astro`, `src/pages/de/writing/index.astro`, `src/pages/de/writing/[slug].astro`
- Create sample own post (draft): `src/content/writing/en/hello-world.md`, `src/content/writing/de/hello-world.md`

**Interfaces:**
- Consumes: `writing` collection, `WritingRow`, `groupByMonth`, `readingTimeMinutes`, `articleJsonLd`.

- [ ] **Step 1: Create the draft sample post (stays `draft: true` until Enver writes real content)**

`src/content/writing/en/hello-world.md`:
```md
---
title: Why this site exists
date: 2026-07-20
description: What I plan to write about — enterprise AI that survives contact with reality.
tags: [Meta]
type: post
draft: true
---

Placeholder starter post. Enver replaces this before launch or leaves it drafted.
```
(DE counterpart mirrors this with translated fields, also `draft: true`.)

- [ ] **Step 2: Write `src/components/pages/WritingIndexPage.astro`**

```astro
---
import { getCollection } from 'astro:content';
import Base from '../../layouts/Base.astro';
import WritingRow from '../WritingRow.astro';
import { t, type Locale } from '../../i18n/routes';
import { filterLocale, groupByMonth, type WritingMeta } from '../../lib/writing';

interface Props { locale: Locale }
const { locale } = Astro.props;
const tr = t(locale);
const entries = filterLocale(await getCollection('writing', ({ data }) => !data.draft), locale);
const items: WritingMeta[] = entries.map((e) => ({ slug: e.id.split('/')[1], locale, ...e.data }));
const { grouped, groups } = groupByMonth(items, locale);
const title = locale === 'de' ? 'Artikel' : 'Writing';
const description = locale === 'de'
  ? 'Artikel und Publikationen von Enver Cetin zu Enterprise AI, agentischen Systemen und AI-Adoption.'
  : 'Articles and publications by Enver Cetin on enterprise AI, agentic systems and AI adoption.';
---
<Base title={title} description={description}>
  <header class="py-14"><h1 class="font-serif text-4xl font-light">{title}</h1></header>
  {items.length === 0 && <p class="pb-16 text-muted">{locale === 'de' ? 'Bald.' : 'Soon.'}</p>}
  {groups.map((g) => (
    <section class="border-t border-line py-8 sm:grid sm:grid-cols-[160px_1fr] sm:gap-6">
      <h2 class="font-mono text-[12px] uppercase tracking-[0.18em] text-muted">{grouped ? g.label : ''}</h2>
      <div class="divide-y divide-line">{g.items.map((w) => <WritingRow item={w} locale={locale} />)}</div>
    </section>
  ))}
</Base>
```

- [ ] **Step 3: Write `src/components/pages/WritingPostLayout.astro`**

```astro
---
import { render, type CollectionEntry } from 'astro:content';
import Base from '../../layouts/Base.astro';
import { t, localizePath, type Locale } from '../../i18n/routes';
import { readingTimeMinutes } from '../../lib/writing';
import { articleJsonLd } from '../../lib/seo';
import { profile } from '../../data/profile';

interface Props { entry: CollectionEntry<'writing'>; locale: Locale }
const { entry, locale } = Astro.props;
const tr = t(locale);
const { Content, headings } = await render(entry);
const minutes = readingTimeMinutes(entry.body ?? '');
const fmt = new Intl.DateTimeFormat(locale === 'de' ? 'de-DE' : 'en-US', { year: 'numeric', month: 'long', day: 'numeric' });
const slug = entry.id.split('/')[1];
const url = `https://envercetin.de${localizePath(`/writing/${slug}`, locale)}`;
const toc = headings.filter((h) => h.depth === 2);
---
<Base title={entry.data.title} description={entry.data.description}
  jsonLd={[articleJsonLd({ title: entry.data.title, description: entry.data.description, date: entry.data.date, url, lang: locale })]}>
  <article class="py-14 lg:grid lg:grid-cols-[150px_minmax(0,40em)_1fr] lg:gap-10">
    <aside class="mb-6 font-mono text-[12px] text-muted lg:mb-0">
      <time datetime={entry.data.date.toISOString().slice(0, 10)}>{fmt.format(entry.data.date)}</time>
      <p class="mt-1">{minutes} {tr('meta.minRead')}</p>
    </aside>
    <div>
      <h1 class="font-serif text-3xl font-light leading-tight sm:text-4xl">{entry.data.title}</h1>
      <div class="prose-col mt-8"><Content /></div>
      <p class="mt-12 border-t border-line pt-6 text-[14px] text-muted">
        {locale === 'de' ? 'Fragen oder Gedanken dazu? ' : 'Questions or thoughts? '}
        <a href={profile.linkedin} rel="noopener" class="underline underline-offset-4 decoration-accent hover:text-accent">LinkedIn</a>
        {' · '}
        <a href={`mailto:${profile.email}`} class="underline underline-offset-4 decoration-accent hover:text-accent">Mail</a>
      </p>
    </div>
    {toc.length >= 3 && (
      <nav class="hidden lg:block" aria-label="Table of contents" data-pagefind-ignore>
        <div class="sticky top-24 text-[13px]">
          <p class="font-mono text-[11px] uppercase tracking-[0.15em] text-muted">Contents</p>
          <ul class="mt-3 space-y-2">
            {toc.map((h) => <li><a href={`#${h.slug}`} class="text-muted hover:text-fg">{h.text}</a></li>)}
          </ul>
        </div>
      </nav>
    )}
  </article>
</Base>
```

- [ ] **Step 4: Wire the four page files**

`src/pages/writing/index.astro` / `src/pages/de/writing/index.astro`: thin wrappers (locale en/de) around `WritingIndexPage`.

`src/pages/writing/[slug].astro`:
```astro
---
import { getCollection } from 'astro:content';
import WritingPostLayout from '../../components/pages/WritingPostLayout.astro';

export async function getStaticPaths() {
  const entries = await getCollection('writing', ({ id, data }) => id.startsWith('en/') && data.type === 'post' && !data.draft);
  return entries.map((entry) => ({ params: { slug: entry.id.split('/')[1] }, props: { entry } }));
}
const { entry } = Astro.props;
---
<WritingPostLayout entry={entry} locale="en" />
```

`src/pages/de/writing/[slug].astro`: identical with `de/` prefix filter and `locale="de"`.

- [ ] **Step 5: Verify** — `npm run build` passes; with all entries drafted, `dist/writing/index.html` shows the "Soon." state and no post pages are emitted.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat: writing index and post pages with toc, reading time, soft cta"`

---

### Task 12: Ventures + About pages (EN + DE)

**Files:**
- Create: `src/components/pages/VenturesPage.astro`, `src/components/pages/AboutPage.astro`, `src/pages/ventures.astro`, `src/pages/de/ventures.astro`, `src/pages/about.astro`, `src/pages/de/about.astro`

- [ ] **Step 1: `VenturesPage.astro`** — same Base pattern: h1 (`Ventures`), intro line (EN: `Products I build and run on the side — proof that I don't just advise on AI, I ship it.` / DE: `Produkte, die ich nebenbei baue und betreibe — Beleg, dass ich AI nicht nur berate, sondern shippe.`), then `ventures.map((v) => <VentureCard venture={v} locale={locale} withStory />)` in a `sm:grid-cols-2` grid.

- [ ] **Step 2: `AboutPage.astro`** — sections in order, all data from `profile.ts`/legacy exports:

```astro
---
import Base from '../../layouts/Base.astro';
import Eyebrow from '../Eyebrow.astro';
import { profile, careerHighlights, volunteerRoles } from '../../data/profile';
import { personJsonLd } from '../../lib/seo';
import type { Locale } from '../../i18n/routes';
interface Props { locale: Locale }
const { locale } = Astro.props;
const title = locale === 'de' ? 'Über mich' : 'About';
const description = locale === 'de'
  ? 'Enver Cetin — Director AI bei Ciklum. Werdegang: Wacker Chemie, Andreas Schmid Group, Ciklum. CSU-Digitalbeauftragter, Atlantik-Brücke-Alumnus, Lecturer bei Bots & People.'
  : 'Enver Cetin — Director AI at Ciklum. Career: Wacker Chemie, Andreas Schmid Group, Ciklum. CSU digital lead, Atlantik-Brücke alumnus, lecturer at Bots & People.';
---
<Base title={title} description={description} jsonLd={[personJsonLd()]}>
  <header class="py-14">
    <h1 class="font-serif text-4xl font-light">{title}</h1>
    <p class="mt-2 font-mono text-[12px] tracking-[0.15em] uppercase text-muted">{profile.role[locale]}</p>
  </header>
  <section class="prose-col border-t border-line py-10">
    <!-- Bio narrative: port the 5 paragraphs from legacy profile.about (EN),
         translate for DE; update title mentions to Director. -->
  </section>
  <section class="border-t border-line py-10">
    <h2 class="font-serif text-2xl font-light">{locale === 'de' ? 'Expertise' : 'Expertise'}</h2>
    <div class="mt-6 grid gap-8 sm:grid-cols-2 lg:grid-cols-3">
      {profile.expertise[locale].map((p, i) => (
        <div>
          <Eyebrow>{String(i + 1).padStart(2, '0')} · {p.title}</Eyebrow>
          <ul class="mt-3 space-y-1.5 text-[14px]">{p.items.map((it) => <li>{it}</li>)}</ul>
        </div>
      ))}
    </div>
  </section>
  <section class="border-t border-line py-10">
    <h2 class="font-serif text-2xl font-light">{locale === 'de' ? 'Werdegang' : 'Career'}</h2>
    <ol class="mt-6 space-y-8">
      {careerHighlights.map((c) => (
        <li class="grid gap-1 sm:grid-cols-[180px_1fr] sm:gap-6">
          <span class="font-mono text-[12px] text-muted">{c.period}</span>
          <div>
            <h3 class="font-medium">{c.role} · {c.company}</h3>
            <p class="mt-1 text-[14px] leading-relaxed text-muted">{c.summary}</p>
          </div>
        </li>
      ))}
    </ol>
  </section>
  <section class="border-t border-line py-10">
    <h2 class="font-serif text-2xl font-light">{locale === 'de' ? 'Ehrenamt & Netzwerk' : 'Volunteering & network'}</h2>
    <ul class="mt-4 space-y-2 text-[14px]">
      {volunteerRoles.map((v) => <li><span class="font-medium">{v.role}</span> · {v.organization} <span class="font-mono text-[12px] text-muted">({v.period})</span></li>)}
    </ul>
  </section>
</Base>
```

The bio-narrative comment block must be replaced with the actual ported paragraphs in this task (EN from `legacy/profile.ts` `about`, DE translated) — the career summaries stay EN in both locales for v1 (marked for Enver's review, Spec §15).

- [ ] **Step 3: Wire the four thin-wrapper page files. Step 4: Verify** — `npm run build && grep -c 'Expertise' dist/about/index.html dist/de/about/index.html`.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: ventures and about pages"`

---

### Task 13: Contact page + form (EN + DE)

**Files:**
- Create: `src/components/pages/ContactPage.astro`, `src/pages/contact.astro`, `src/pages/de/contact.astro`, `src/lib/validate.ts`, `tests/unit/validate.test.ts`

**Interfaces:**
- Produces: `validateContact(data: { name: string; email: string; message: string }): { ok: boolean; errors: Partial<Record<'name'|'email'|'message', string>> }` (locale-independent keys; UI maps to strings).

- [ ] **Step 1: Failing test `tests/unit/validate.test.ts`**

```ts
import { describe, it, expect } from 'vitest';
import { validateContact } from '../../src/lib/validate';

describe('validateContact', () => {
  it('accepts a valid submission', () => {
    expect(validateContact({ name: 'A', email: 'a@b.de', message: 'Hello there' }).ok).toBe(true);
  });
  it('rejects bad email and empty fields', () => {
    const r = validateContact({ name: '', email: 'nope', message: '' });
    expect(r.ok).toBe(false);
    expect(Object.keys(r.errors)).toEqual(['name', 'email', 'message']);
  });
});
```

- [ ] **Step 2: Run → FAIL. Step 3: Implement `src/lib/validate.ts`**

```ts
export function validateContact(data: { name: string; email: string; message: string }) {
  const errors: Partial<Record<'name' | 'email' | 'message', string>> = {};
  if (!data.name.trim()) errors.name = 'required';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email)) errors.email = 'invalid';
  if (data.message.trim().length < 5) errors.message = 'required';
  return { ok: Object.keys(errors).length === 0, errors };
}
```

- [ ] **Step 4: Run → PASS.**

- [ ] **Step 5: Write `ContactPage.astro`** — intent chips + form; the `intent` query param preselects a hidden subject field:

```astro
---
import Base from '../../layouts/Base.astro';
import { t, type Locale } from '../../i18n/routes';
import { profile } from '../../data/profile';
interface Props { locale: Locale }
const { locale } = Astro.props;
const tr = t(locale);
const key = import.meta.env.PUBLIC_WEB3FORMS_KEY;
const intents = locale === 'de'
  ? [{ id: 'speaking', label: 'Speaking / Workshop' }, { id: 'advisory', label: 'Advisory / Sparring' }, { id: 'enterprise', label: 'Enterprise-Projekt' }, { id: 'other', label: 'Sonstiges' }]
  : [{ id: 'speaking', label: 'Speaking / workshop' }, { id: 'advisory', label: 'Advisory / sparring' }, { id: 'enterprise', label: 'Enterprise project' }, { id: 'other', label: 'Other' }];
const title = tr('contact.title');
const description = locale === 'de'
  ? 'Kontakt zu Enver Cetin — Speaking-Anfragen, Advisory, Enterprise-AI-Projekte.'
  : 'Contact Enver Cetin — speaking inquiries, advisory, enterprise AI projects.';
---
<Base title={title} description={description}>
  <header class="py-14">
    <h1 class="font-serif text-4xl font-light">{title}</h1>
    <p class="mt-3 max-w-[42em] text-[14px] text-muted">
      {locale === 'de'
        ? 'Kein Formular-Zwang: eine Mail an '
        : 'No form required: an email to '}
      <a href={`mailto:${profile.email}`} class="underline underline-offset-4 decoration-accent">{profile.email}</a>
      {locale === 'de' ? ' oder eine Nachricht auf ' : ' or a message on '}
      <a href={profile.linkedin} rel="noopener" class="underline underline-offset-4 decoration-accent">LinkedIn</a>
      {locale === 'de' ? ' funktioniert genauso.' : ' works just as well.'}
    </p>
  </header>
  <form id="contact-form" class="max-w-[42em] border-t border-line py-10" novalidate>
    <input type="hidden" name="access_key" value={key} />
    <fieldset class="flex flex-wrap gap-2">
      <legend class="mb-2 font-mono text-[11px] uppercase tracking-[0.15em] text-muted">{locale === 'de' ? 'Worum geht es?' : 'What is it about?'}</legend>
      {intents.map((i, idx) => (
        <label class="cursor-pointer rounded-full border border-line px-3 py-1 text-[13px] has-checked:border-accent has-checked:text-accent">
          <input type="radio" name="intent" value={i.id} checked={idx === 3} class="sr-only" />{i.label}
        </label>
      ))}
    </fieldset>
    <div class="mt-6 grid gap-4 sm:grid-cols-2">
      <label class="block text-[13px]">Name
        <input name="name" type="text" required class="mt-1 w-full rounded border border-line bg-transparent px-3 py-2 text-[14px] focus:border-accent focus:outline-none" />
      </label>
      <label class="block text-[13px]">Email
        <input name="email" type="email" required class="mt-1 w-full rounded border border-line bg-transparent px-3 py-2 text-[14px] focus:border-accent focus:outline-none" />
      </label>
    </div>
    <label class="mt-4 block text-[13px]">{locale === 'de' ? 'Nachricht' : 'Message'}
      <textarea name="message" rows="5" required class="mt-1 w-full rounded border border-line bg-transparent px-3 py-2 text-[14px] focus:border-accent focus:outline-none"></textarea>
    </label>
    <button type="submit" class="mt-5 rounded border border-fg px-5 py-2 text-[14px] hover:bg-fg hover:text-bg">
      {locale === 'de' ? 'Senden' : 'Send'}
    </button>
    <p id="form-status" role="status" class="mt-3 hidden text-[13px]"></p>
  </form>
</Base>
<script>
  import { validateContact } from '../../lib/validate';
  const form = document.getElementById('contact-form') as HTMLFormElement | null;
  const status = document.getElementById('form-status')!;
  const de = document.documentElement.lang === 'de';
  // Preselect intent from ?intent=
  const intent = new URLSearchParams(location.search).get('intent');
  if (intent) form?.querySelector<HTMLInputElement>(`input[name="intent"][value="${intent}"]`)?.click();
  form?.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const fd = new FormData(form);
    const check = validateContact({ name: String(fd.get('name') ?? ''), email: String(fd.get('email') ?? ''), message: String(fd.get('message') ?? '') });
    status.classList.remove('hidden');
    if (!check.ok) {
      status.textContent = de ? 'Bitte Name, gültige E-Mail und Nachricht angeben.' : 'Please provide name, a valid email, and a message.';
      status.className = 'mt-3 text-[13px] text-accent';
      return;
    }
    fd.set('subject', `envercetin.de contact — ${fd.get('intent')}`);
    status.textContent = de ? 'Senden…' : 'Sending…';
    try {
      const res = await fetch('https://api.web3forms.com/submit', { method: 'POST', body: fd });
      if (!res.ok) throw new Error(String(res.status));
      form.reset();
      status.textContent = de ? 'Danke — ich melde mich.' : 'Thanks — I will get back to you.';
    } catch {
      status.textContent = de
        ? 'Senden fehlgeschlagen — bitte direkt per Mail schreiben.'
        : 'Sending failed — please email me directly.';
    }
  });
</script>
```

- [ ] **Step 6: Wire thin wrappers, verify build, commit** — `git commit -am "feat: contact page with intent routing and validated web3forms submit"`

---

### Task 14: Legal pages + 404

**Files:**
- Create: `src/pages/impressum.astro`, `src/pages/datenschutz.astro`, `src/pages/de/impressum.astro`, `src/pages/de/datenschutz.astro`, `src/pages/404.astro`

- [ ] **Step 1: Impressum** (single-language German content is legally fine; EN route renders the same German legal text with an English intro note). Content per §5 TMG template: full name, address placeholder `[Anschrift — Enver ergänzt vor Livegang]`, email. **This placeholder is intentional and gated: Task 20's checklist blocks launch until Enver fills it.** Mark the page `data-pagefind-ignore` and `<meta name="robots" content="noindex">`.

- [ ] **Step 2: Datenschutz** — standard DSGVO text covering: hosting on Vercel (server logs), web3forms form processing, Vercel Web Analytics (cookieless), no other tracking, rights of data subjects, responsible party = site owner. German text, both routes, noindex.

- [ ] **Step 3: `404.astro`** — Base layout, `<h1 class="font-serif text-4xl font-light">404</h1>`, `tr('notfound.title')`, link `tr('notfound.back')` to `/`. (Single 404 for both locales, EN strings + DE line beneath.)

- [ ] **Step 4: Verify + commit** — `npm run build`; `git commit -am "feat: legal pages and 404"`

---

### Task 15: Search — Pagefind + ⌘K palette island

**Files:**
- Modify: `src/components/SearchPalette.tsx` (replace stub)

**Interfaces:**
- Consumes: buttons `#open-search` / `#open-search-mobile` from Nav; Pagefind bundle at `/pagefind/pagefind.js` (exists only after `npm run build`).
- Produces: modal palette; opens on button click or ⌘K/Ctrl-K; closes on Esc/backdrop.

- [ ] **Step 1: Implement `src/components/SearchPalette.tsx`**

```tsx
import { useCallback, useEffect, useRef, useState } from 'react';

type Result = { url: string; title: string; excerpt: string };
declare global { interface Window { __pagefind?: any } }

export default function SearchPalette({ locale }: { locale: string }) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Result[]>([]);
  const [error, setError] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const de = locale === 'de';

  const ensurePagefind = useCallback(async () => {
    if (window.__pagefind) return window.__pagefind;
    try {
      window.__pagefind = await import(/* @vite-ignore */ '/pagefind/pagefind.js');
      await window.__pagefind.options({ excerptLength: 20 });
      return window.__pagefind;
    } catch {
      setError(true);
      return null;
    }
  }, []);

  useEffect(() => {
    const openFn = () => { setOpen(true); setTimeout(() => inputRef.current?.focus(), 30); };
    const key = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); openFn(); }
      if (e.key === 'Escape') setOpen(false);
    };
    document.getElementById('open-search')?.addEventListener('click', openFn);
    document.getElementById('open-search-mobile')?.addEventListener('click', openFn);
    window.addEventListener('keydown', key);
    return () => window.removeEventListener('keydown', key);
  }, []);

  useEffect(() => {
    if (!open || !query.trim()) { setResults([]); return; }
    let cancelled = false;
    (async () => {
      const pf = await ensurePagefind();
      if (!pf) return;
      const search = await pf.search(query);
      const top = await Promise.all(search.results.slice(0, 8).map((r: any) => r.data()));
      if (!cancelled) {
        setResults(top
          .filter((d: any) => (de ? d.url.startsWith('/de/') || d.url === '/de' : !d.url.startsWith('/de')))
          .map((d: any) => ({ url: d.url, title: d.meta?.title ?? d.url, excerpt: d.excerpt })));
      }
    })();
    return () => { cancelled = true; };
  }, [query, open, de, ensurePagefind]);

  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 bg-black/40 p-4 pt-[12vh]" onClick={() => setOpen(false)}>
      <div className="mx-auto max-w-xl rounded-lg border border-line bg-bg shadow-xl" onClick={(e) => e.stopPropagation()}>
        <input
          ref={inputRef}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={de ? 'Suchen…' : 'Search…'}
          className="w-full border-b border-line bg-transparent px-4 py-3 text-[15px] text-fg outline-none"
          aria-label={de ? 'Suche' : 'Search'}
        />
        <div className="max-h-[50vh] overflow-y-auto p-2">
          {error && <p className="p-3 text-[13px] text-muted">{de ? 'Suche ist im Dev-Modus nicht verfügbar (erst nach Build).' : 'Search unavailable in dev mode (available after build).'}</p>}
          {!error && query && results.length === 0 && <p className="p-3 text-[13px] text-muted">{de ? 'Keine Treffer.' : 'No results.'}</p>}
          {results.map((r) => (
            <a key={r.url} href={r.url} className="block rounded p-3 hover:bg-accent-soft">
              <p className="text-[14px] font-medium text-fg">{r.title}</p>
              <p className="mt-0.5 text-[12px] text-muted" dangerouslySetInnerHTML={{ __html: r.excerpt }} />
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Verify against the built site**

```bash
npm run build && npm run preview &
sleep 2 && curl -s http://localhost:4321/pagefind/pagefind.js | head -c 60; kill %1
```
Expected: JS content (not 404). Manual check in browser: ⌘K opens, searching `fraud` returns the BFSI case.

- [ ] **Step 3: Commit** — `git commit -am "feat: pagefind search with cmd-k palette island"`

---

### Task 16: RSS, robots.txt, llms.txt

**Files:**
- Create: `src/pages/rss.xml.ts`, `src/pages/de/rss.xml.ts`, `public/robots.txt`, `public/llms.txt`

- [ ] **Step 1: `src/pages/rss.xml.ts`**

```ts
import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';
import type { APIContext } from 'astro';

export async function GET(context: APIContext) {
  const entries = await getCollection('writing', ({ id, data }) => id.startsWith('en/') && !data.draft);
  return rss({
    title: 'Enver Cetin — Writing',
    description: 'Enterprise AI, agentic systems, applied automation.',
    site: context.site!,
    items: entries.map((e) => ({
      title: e.data.title,
      description: e.data.description,
      pubDate: e.data.date,
      link: e.data.type === 'external' ? e.data.externalUrl! : `/writing/${e.id.split('/')[1]}`,
    })),
  });
}
```

`de/rss.xml.ts`: same with `de/` filter, German title `Enver Cetin — Artikel`, links prefixed `/de`.

- [ ] **Step 2: `public/robots.txt`**

```
User-agent: *
Allow: /
Sitemap: https://envercetin.de/sitemap-index.xml
```

- [ ] **Step 3: `public/llms.txt`**

```
# Enver Cetin — envercetin.de

Director AI at Ciklum (Munich). Enterprise AI strategy, agentic systems, applied automation.

## Pages
- /about: bio, expertise, career
- /work: anonymized engagement patterns from real AI programs
- /writing: articles and publications
- /ventures: shipped products (Vertragsklar, Nebenkosten-Ninja)
- /contact: speaking, advisory and enterprise inquiries
German versions under /de/.
```

- [ ] **Step 4: Verify + commit** — `npm run build && ls dist/rss.xml dist/de/rss.xml dist/sitemap-index.xml`; `git commit -am "feat: rss feeds, robots, llms.txt"`

---### Task 17: Playwright verification suite

**Files:**
- Create: `playwright.config.ts`, `tests/e2e/site.spec.ts`

- [ ] **Step 1: `playwright.config.ts`**

```ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: 'tests/e2e',
  webServer: {
    command: 'npm run preview',
    port: 4321,
    reuseExistingServer: true,
  },
  projects: [
    { name: 'mobile', use: { viewport: { width: 390, height: 844 } } },
    { name: 'desktop', use: { viewport: { width: 1920, height: 1080 } } },
  ],
});
```

- [ ] **Step 2: `tests/e2e/site.spec.ts`**

```ts
import { test, expect } from '@playwright/test';

const pages = ['/', '/work', '/writing', '/ventures', '/about', '/contact', '/de', '/de/work', '/de/writing', '/de/ventures', '/de/about', '/de/contact'];

for (const path of pages) {
  test(`no horizontal scroll + meta on ${path}`, async ({ page }) => {
    await page.goto(path);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    expect(overflow).toBeLessThanOrEqual(1);
    expect(await page.locator('meta[name="description"]').getAttribute('content')).toBeTruthy();
    expect(await page.locator('link[rel="canonical"]').count()).toBe(1);
    expect(await page.locator('link[rel="alternate"][hreflang]').count()).toBe(3);
    const lang = await page.locator('html').getAttribute('lang');
    expect(lang).toBe(path.startsWith('/de') ? 'de' : 'en');
  });
}

test('hero claim is verbatim', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('h1')).toHaveText('I build AI that actually works.');
});

test('theme toggle switches data-theme', async ({ page, viewport }) => {
  test.skip(viewport!.width < 640, 'desktop toggle');
  await page.goto('/');
  await page.click('#theme-toggle');
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
});

test('search opens and finds a case', async ({ page, viewport }) => {
  test.skip(viewport!.width < 640, 'desktop palette');
  await page.goto('/');
  await page.keyboard.press(process.platform === 'darwin' ? 'Meta+k' : 'Control+k');
  await page.getByPlaceholder('Search…').fill('fraud');
  await expect(page.locator('a[href*="/work"]').first()).toBeVisible({ timeout: 5000 });
});

test('language toggle keeps the page', async ({ page, viewport }) => {
  test.skip(viewport!.width < 640, 'desktop nav');
  await page.goto('/work');
  await page.click('a[rel="alternate"]');
  await expect(page).toHaveURL(/\/de\/work$/);
});

test('contact form validates before send', async ({ page }) => {
  await page.goto('/contact');
  await page.click('button[type="submit"]');
  await expect(page.locator('#form-status')).toContainText(/name|Name/);
});
```

- [ ] **Step 3: Run**

```bash
npx playwright install chromium
npm run build && npm run e2e
```
Expected: all tests pass in both projects (mobile + desktop).

- [ ] **Step 4: Commit** — `git add -A && git commit -m "test: playwright e2e suite (viewports, i18n, search, meta)"`

---

### Task 18: Performance budget + JS size check

**Files:**
- Create: `scripts/check-budget.mjs`

- [ ] **Step 1: Write `scripts/check-budget.mjs`**

```js
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
```

- [ ] **Step 2: Run and fix violations**

```bash
npm run build && node scripts/check-budget.mjs
```
Expected: `budget ok`. If the React island exceeds budget: confirm `client:idle` is the only island and no page imports React statically. If the headshot exceeds 120 KB: lower `Image` width/densities in `HomePage.astro`.

- [ ] **Step 3: Commit** — `git add -A && git commit -m "chore: js and image budget check script"`

---

### Task 19: Preview deploy on Vercel  — USER GATE

**Files:** none (infra)

- [ ] **Step 1: Push branch**

```bash
git push -u origin redesign/astro
```

- [ ] **Step 2: Verify Vercel picks up the branch** — a preview deployment appears on the existing `enver-landing-page` project. If the framework preset is stale (Vite), set it to **Astro** in Vercel project settings (or via `vercel.json`: `{ "framework": "astro" }` committed to the branch). Build command must be `npm run build` (includes Pagefind), output `dist`.

- [ ] **Step 3: Add `PUBLIC_WEB3FORMS_KEY` to Vercel env vars** (all environments) with the value from local `.env`.

- [ ] **Step 4: Smoke-check the preview URL** — home EN/DE, work, writing, ventures, about, contact, search (⌘K), theme toggle, mobile device check by Enver.

- [ ] **STOP: Enver reviews the preview (desktop + phone) and explicitly approves go-live.** Content review checklist for Enver: 6 case texts + KPI magnitudes, bio/Director dates, email address in `profile.ts`, Impressum address filled, external article links provided (added as `type: external` entries).

---

### Task 20: Go-live — merge, domain, redirects, analytics  — USER GATE

**Files:**
- Modify: `src/layouts/Base.astro` (analytics snippet)

- [ ] **Step 1: Enable Vercel Web Analytics** — in Vercel project settings enable Web Analytics; add to `Base.astro` before `</body>`:

```html
<script defer src="/_vercel/insights/script.js"></script>
```
Commit: `git commit -am "feat: vercel web analytics"`

- [ ] **Step 2: Merge after approval**

```bash
git checkout main
git merge --no-ff redesign/astro -m "feat: relaunch as bilingual astro site (editorial operator)"
git push origin main
```

- [ ] **Step 3: Connect domain** — Vercel project → Domains → add `envercetin.de` (+ `www.envercetin.de` redirecting to apex). Follow the DNS instructions at the registrar. `enver-landing-page.vercel.app` then auto-redirects (308) to the primary domain.

- [ ] **Step 4: Post-launch verification**

```bash
curl -sI https://envercetin.de | head -3
curl -sI https://enver-landing-page.vercel.app | grep -i location
```
Expected: 200 on the domain; redirect header on the vercel.app URL. Then: share the URL in a LinkedIn draft post to confirm the OG preview shows the branded card; run Lighthouse (mobile) on `/` and `/writing` — targets per Global Constraints; delete the stale `vercel/vercel-web-analytics-integrati-ionqgj` remote branch.

- [ ] **Step 5: Cleanup**

```bash
git rm -r legacy && git commit -m "chore: remove legacy vite content sources" && git push
```
(Only after confirming all content was ported.)

---

## Self-Review Notes

- Spec §3 pages ↔ Tasks 9–14 ✓; §4 tokens ↔ Task 2/3 ✓; §5 content model ↔ Task 5 ✓; §6 i18n ↔ Task 4 + thin wrappers ✓; §7 search ↔ Task 15 ✓; §8 SEO ↔ Tasks 8/16 ✓; §9 conversion ↔ Tasks 9/13 ✓; §11 budget ↔ Task 18 ✓; §12 error handling ↔ Tasks 13 (form), 15 (dev-mode search hint), 14 (404), 9 (hash script) ✓; §13 migration ↔ Tasks 1/19/20 ✓; §14 verification ↔ Task 17 ✓.
- Known intentional gaps (Spec §15/§16): Impressum address, email address, external article links, bio dates — all gated in Task 19's STOP checklist. DE translations of career summaries deferred to v1.1 (marked).
- Type consistency: `WritingMeta`, `Locale`, `validateContact`, `Pillar` used consistently across tasks; `SearchPalette` stubbed in Task 8 and replaced in Task 15 with identical default export signature.

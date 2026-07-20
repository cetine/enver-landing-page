# Website-Redesign envercetin.de — Design-Spec

**Datum:** 2026-07-20 · **Status:** Zur Review · **Repo:** `cetine/enver-landing-page` · **Deploy:** Vercel (bestehendes Projekt)

## 1. Ziel & Kontext

Die persönliche Website von Enver Cetin (aktuell Vite-SPA auf `enver-landing-page.vercel.app`) wird neu gebaut. Kernziel: **gefunden, kontaktiert, beauftragt werden** — über vier Kanäle (Speaking & Workshops, Advisory, Enterprise-Leads, Sichtbarkeit/Netzwerk), ohne verkäuferisch zu wirken. Substanz vor Sales.

Hauptdefekt der Ist-Seite: rein client-seitiges Rendering — Crawler und Social-Scraper sehen eine leere Hülle mit Titel „enver-landing-page". Dazu AI-Slop-Marker (Gradienten, Emoji-Icons, Custom Cursor, Intro-Splash, Parallax, React Flow).

**Konzept (gewählt): „Editorial Operator"** — philschmid-Typografie-Minimalismus + Monospace-Annotationsebene (amar.im) + dezentes Intent-Routing (katjanettesheim.de).

## 2. Getroffene Entscheidungen

| Entscheidung | Wahl |
|---|---|
| Conversion-Ziel | Alle 4 Kanäle, substanz-getrieben, nicht sales-lastig |
| Sprachen | DE + EN, Toggle; **EN auf Root** (`/writing/...`), **DE unter `/de/...`** |
| Blog-Inhalt | Kuratierte externe Artikel **und** eigene Posts in einem Stream |
| Ventures | Vertragsklar + Nebenkosten-Ninja |
| Cases | Bestehende 10 Cases aus `ProjectsSection.tsx` als Basis, kuratiert auf **6**, gerahmt als „anonymisierte Engagement-Muster aus realen Programmen" |
| Stack | **Astro** (statisches HTML, Content Collections, i18n, RSS/Sitemap built-in) |
| Design-Richtung | Kreis-Monogramm + IBM Plex Trio + Akzent Smaragd (via Visual Companion bestätigt) |
| Domain | **envercetin.de** (bereits im Besitz) wird kanonische Domain |
| Titel-Update | „Director AI, Ciklum" (statt Senior Manager) |

## 3. Seitenstruktur (IA)

Jede Seite existiert als EN (Root) und DE (`/de/…`), statisch gerendert.

| Route | Inhalt |
|---|---|
| `/` | Hero: Claim „I build AI that actually works. / Not in labs. Not in theory." + „Director AI, Ciklum · Munich" + optimiertes Foto. Drei nummerierte Engagement-Pfade (`01 · Speaking & Workshops`, `02 · Advisory`, `03 · Enterprise AI`) — je 2 Sätze + eigenes CTA-Verb. Danach: 3 ausgewählte Artikel, 4 ausgewählte Cases, 2 Ventures-Karten, „Was nun?"-Intent-Router, Footer |
| `/work` | 6 Cases, gruppiert nach Branche (max. 2 je Branche), Schema: Challenge → Approach → Impact, max. 3 KPIs, Work-Type-Label (Strategy / Architecture / Engineering). Ehrliche Rahmung als Engagement-Muster |
| `/writing` | Ein Stream: eigene Posts (voll gerendert, eigene URL) + externe Artikel (Karte mit Quellen-Badge → Originalquelle). philschmid-Stil: Titel + gedämpfte Metazeile (Datum — Tags), keine Thumbnails. Flache Liste; Monatsgruppierung automatisch ab ≥ 8 Einträgen pro Sprache |
| `/writing/[slug]` | Post-Seite: schmale Prosa-Spalte (~40em), Datum/Lesezeit-Rail, TOC ab 3+ Headings, Soft-CTA am Ende („Fragen? → LinkedIn / Mail") |
| `/ventures` | Vertragsklar + Nebenkosten-Ninja: je Live-Badge, Kurzgeschichte (Warum → Was → Link). Kein „Coming Soon" |
| `/about` | Narrative Bio mit harten Zahlen (Wacker → Andreas Schmid → Ciklum Director), 5-Säulen-Expertise als statisches Grid (Inhalt aus alter Tech-Map), Ehrenämter (CSU Digitalbeauftragter, Atlantik-Brücke, Young Königswinter), Lecturer-Rolle (Bots & People) |
| `/contact` | Intent-Routing (Speaking / Advisory / Enterprise / Sonstiges), bestehendes web3forms-Formular, Mail + LinkedIn |
| `/impressum`, `/datenschutz` | Neu, Pflicht (fehlen aktuell komplett) |
| `/404` | Gestaltete 404 mit Navigation zurück |

**Global:** Sticky Nav (Monogramm + ENVER CETIN, Links: Work · Writing · Ventures · About, ⌘K-Suche, DE/EN-Toggle, Theme-Toggle) · Footer (Kontaktwege, RSS, Impressum/Datenschutz) · „Was nun?"-Router nur auf Home.

**Entfällt ersatzlos:** React Flow, Custom Cursor, Intro-Overlay, Parallax-Orbs, Scroll-Progress-Bar, Emoji-Icons, Gradient-Text, Labs-Seite (bis es echten Inhalt gibt).

## 4. Design-System

- **Logo:** Gefüllter Kreis (near-black bzw. invertiert im Dark Mode) mit „EC" + Wortmarke ENVER CETIN in Versalien, Letterspacing ~3px. Als SVG; daraus Favicon + OG-Template-Brand.
- **Typografie (IBM Plex Superfamilie, selbst gehostet, subsettet):**
  - IBM Plex Serif Light — nur große Titel/H1/H2
  - IBM Plex Sans — Body, UI, Navigation
  - IBM Plex Mono — Annotationsebene: Eyebrows (`01 · ADVISORY`), Metazeilen, Badges, KPI-Zahlen, Code. **Nie Fließtext.**
- **Farben:** Streng monochrom. Light: bg `#fafafa`, fg near-black. Dark: bg `#0a0a0a`, fg `#ececec`. Akzent Smaragd: `#0e7c5b` (light) / `#2fbd8f` (dark) — **nur** für Live-Badges, aktive Zustände, Link-Unterstreichung/Hover, sparsame Mono-Eyebrows. Keine Gradienten, keine Schatten-Orgien, keine Glassmorphism.
- **Layout-Primitiv:** Eine Content-Spalte `max-w` ~72rem, Prosa ~40em; Hairline-Trenner (`opacity-20`); nummerierte Listen als wiederkehrendes Muster.
- **Motion:** Fast keine. Erlaubt: Hover-Unterstreichung, Theme-Fade, dezente Einblendung der ⌘K-Palette. Kein whileInView-Zoo, kein Parallax. `prefers-reduced-motion` respektiert das Wenige zusätzlich.
- **Bilder:** Nur echte Fotos (Headshot, ggf. später Speaking-Fotos). Keine Stock-Grafiken, keine 3D-Blobs.

## 5. Content-Modell (Astro Content Collections)

```
content/
  writing/
    en/agentic-ai-mittelstand.md      # eigener Post
    de/agentic-ai-mittelstand.md
    en/hbr-article-xyz.md             # externer Artikel (Stub)
  work/
    en/bfsi-fraud-detection.md ...    # 6 Cases × 2 Sprachen
  ventures.yaml                       # 2 Einträge
src/data/profile.ts                   # Bio, Rollen, Expertise-Grid, Social-Links
```

- **writing-Frontmatter:** `title, date, lang, tags[], description, type: "post" | "external", externalUrl?, source?` — `external` rendert als Karte im Stream (Badge mit `source`, Link öffnet Originalquelle), bekommt keine eigene Detailseite.
- **work-Frontmatter:** `title, industry, workType, kpis[{label, value}] (max 3), tags[]`; Body-Sektionen Challenge / Approach / Impact.
- **DE/EN-Paare:** gleicher Slug in beiden Ordnern. Fehlt DE, wird EN-Inhalt mit Hinweis ausgeliefert (kein 404).
- KPI-Regel gegen Fabrikations-Eindruck: Werte werden als Größenordnungen formuliert („~70 % weniger Triage-Zeit") statt Pseudo-Präzision, und der Seitenkopf von `/work` erklärt die Anonymisierung in einem Satz.

## 6. i18n

Astro-i18n-Routing: `defaultLocale: "en"` (Root), `locales: ["en", "de"]`. Toggle wechselt zur selben Seite in der anderen Sprache (Slug-Mapping über Collection-IDs). `hreflang`-Alternates auf jeder Seite. UI-Strings in `src/i18n/{en,de}.ts`.

## 7. Suche

Pagefind läuft post-build über das statische HTML beider Sprachen. UI: ⌘K-Command-Palette als React-Insel (Desktop: „Search ⌘K" in der Nav; Mobile: Such-Icon → Vollbild-Overlay). Ergebnisse nach aktueller Sprache gefiltert, andere Sprache als Sekundärgruppe.

## 8. SEO / AEO

- Kanonische Domain `https://envercetin.de`, `*.vercel.app` → 308-Redirect.
- Pro Seite: `<title>`, Meta-Description, Canonical, hreflang, OG/Twitter-Tags mit gebrandetem OG-Bild (statisches Template mit Monogramm + Seitentitel).
- JSON-LD: `Person` (Home/About, mit `sameAs`: LinkedIn, GitHub) + `Article` (Posts) + `WebSite`.
- `sitemap.xml`, `robots.txt`, `rss.xml` (EN + DE), `llms.txt`.
- Semantisches HTML (ein `<main>`, Heading-Hierarchie, `<article>`/`<time>`).

## 9. Conversion-Flow (nicht sales-lastig)

1. Nav enthält keinen schreienden CTA — „Contact" ist normaler Link.
2. Die drei Engagement-Pfade auf Home haben je ein eigenes CTA-Verb (z. B. „Vortrag anfragen →", „Sparring vereinbaren →", „Projekt besprechen →") und führen zu `/contact` mit vorgewähltem Intent.
3. Jeder Post endet mit einem Soft-CTA (eine Zeile, LinkedIn/Mail).
4. Home endet mit „Was nun?"-Router: 4–5 Wenn-dann-Zeilen inkl. unverbindlichem Fallback („Einfach mitlesen → LinkedIn / RSS").
5. Kontaktformular: web3forms (bestehender Key), Client-Validierung, Erfolgs-/Fehlerzustand mit Mail-Fallback sichtbar.

## 10. Architektur & Stack

- **Astro 5** + TypeScript, Tailwind CSS 4 (Design-Tokens als CSS-Variablen), React nur für **eine** Insel: SearchPalette (lazy, lädt erst bei Öffnen). Kontaktformular = reines HTML-Formular + kleines Vanilla-JS für Validierung/Zustände. Theme-Toggle als Inline-Script.
- Komponenten klein und fokussiert (Ziel < 200 Zeilen/Datei), Struktur: `layouts/`, `components/`, `pages/`, `content/`, `i18n/`.
- Bestehender Vite-Code wird ersetzt; Wiederverwendet werden **Inhalte** (profile.ts, Cases, Ventures-Texte, web3forms-Key aus `.env`).
- Fonts via `@fontsource` (Plex Sans/Serif/Mono, latin subset, nur benötigte Gewichte).

## 11. Performance-Budget

- Headshot: 3,2 MB PNG → AVIF/WebP ≤ 60 KB via `astro:assets`.
- JS gesamt (ohne Suche): < 15 KB gzip; Pagefind lädt lazy erst bei Suche.
- Lighthouse-Ziele (Mobile): Performance ≥ 95, SEO = 100, A11y ≥ 95, CLS ≈ 0 (Font-Fallback-Metriken).

## 12. Fehlerbehandlung

- Formular: Netz-/API-Fehler → sichtbare Meldung + Mailto-Fallback; Pflichtfelder client- und serverunabhängig validiert (web3forms).
- Suche: Pagefind-Ladefehler → Palette zeigt Hinweis statt leer zu bleiben.
- i18n: fehlende Übersetzung → EN-Fallback mit dezentem Hinweis, nie 404.
- 404-Seite mit Navigation. Alte Hash-URLs (`/#ventures`, `/#labs`) erreichen den Server nie — ein 3-Zeilen-Inline-Script auf der Home mappt bekannte Hashes client-seitig auf die neuen Routen.

## 13. Migration & Deployment

1. Lokale uncommittete Änderungen als Sicherungs-Commit auf `main`.
2. Neubau auf Branch `redesign/astro`; lokale Review unter `npm run dev` (Port 4321).
3. Push → Vercel-Preview-URL → mobile + Desktop-Review durch Enver.
4. Nach Freigabe: Merge auf `main` (Framework-Preset im Vercel-Projekt: Astro), Produktion.
5. Domain `envercetin.de` im Vercel-Projekt verbinden (+ `www` → Apex-Redirect), `enver-landing-page.vercel.app` → 308 auf envercetin.de.
6. Vercel Web Analytics aktivieren (bestehenden angefangenen Branch verwerfen, sauber in Astro einbauen).

## 14. Verifikation (vor jedem „fertig")

- `astro check` + Build ohne Warnungen.
- Playwright auf echten Auflösungen: 390×844 (Mobile) und 1920×1080 (Desktop) — beide Sprachen, beide Themes; Assertions auf: Nav funktioniert, Suche liefert Treffer, Formular validiert, kein horizontales Scrollen mobil.
- Meta-Validierung: OG-Tags + Title pro Seite per Skript geprüft; LinkedIn-Preview via Vercel-Preview-URL manuell gegengecheckt.
- Interne Links + hreflang-Paare per Link-Checker.

## 15. Startinhalte (zu befüllen während der Implementierung)

- 6 Cases: aus bestehenden 10 kuratiert und gestrafft (Enver reviewt Auswahl + Zahlen vor Livegang).
- Writing: 3–6 externe Artikel (Enver liefert Links/Quellen) + optional 1 eigener Startpost.
- About: Bio-Update auf Director, Zahlen verifiziert Enver.
- Impressum/Datenschutz: Standardtexte, Enver prüft Adresse/Angaben.

## 16. Nicht in diesem Projekt (bewusst später)

- Newsletter/E-Mail-Capture · Speaking-Videos/Bühnenfotos · automatische OG-Bild-Generierung pro Post (satori) · Labs-Seite · Kalender-Booking-Link (kann jederzeit in `/contact` ergänzt werden, sobald vorhanden).

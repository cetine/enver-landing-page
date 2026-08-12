# House style for writing posts

Derived from `src/content/writing/en/gdpr-presidio-llm-privacy.mdx`, which is the
reference article. When in doubt, open it and match it.

This file is read by the weekly article automation (`scripts/weekly-article/`).
Changing it changes what gets written.

## The thesis rule

Every article makes **one argument that a competent reader could disagree with**,
and it is usually a correction of a widely held belief. The Presidio piece does
not explain what Presidio is; it argues that redaction buys you less than teams
think. If a draft could be summarised as "here is how X works", it is not ready.

State the thesis in the first three paragraphs, before any explanation.

## Non-negotiables

1. **Every number is verified against a primary source.** Statute text from
   EUR-Lex, judgments from curia, papers from arXiv/ACL, software behaviour from
   the actual repository. Secondary blogs are never sufficient for a number, a
   date, a case reference, or a version string. If a figure cannot be traced to a
   primary source, it does not appear.
2. **Claims about software are executed, not read.** The reference article's
   value is that Presidio was installed and run: `Goethestr` → `PERSON` at 0.85 is
   an observed output, not a plausible one. Where an article makes a behavioural
   claim, run it and quote the real output verbatim.
3. **Report the inconvenient result.** The reference article reports that the
   tool it recommends reaches 0.460 recall. An article with no finding against
   its own recommendation has not been researched hard enough.
4. **Date and version everything perishable.** "as of August 2026",
   `presidio-analyzer 2.2.364`. Close with the verification footer.
5. **Never state law as settled when it is not.** Draft guidelines are labelled
   drafts. Judgments carry the chamber, the regulation actually interpreted, and
   whether anything was finally determined.

## Shape

- **Length: 1,200–1,600 words of prose** (excluding code blocks and markup),
  which renders as 6–8 minutes. Check with the counting rule in
  `src/lib/writing.ts`.
- **TL;DR first.** An `<aside class="tldr">` with a `<p class="tldr-label">TL;DR</p>`
  and 3–4 `<li>` bullets, one per argument. Written so someone who reads only the
  bullets still gets the correction.
- **6–9 `##` sections**, so the table of contents appears and is useful. Roughly:
  the problem or the law → what the thing actually is → the architecture (figure)
  → what it looks like in practice → where it breaks → the harder limit → what I
  would build → bottom line → sources.
- **One figure**, an Astro component using `src/lib/rough.ts` for the hand-drawn
  look, imported into the `.mdx`. It carries exactly one idea. The `figcaption`
  states the qualification the picture cannot.
- **Sources: 6–9 bullets**, only entries that a claim in the body actually rests
  on. If a source is not load-bearing, cut it.

## Voice

- First person, present tense, short declaratives. "The reflex is right. The
  reasoning behind it usually is not."
- Concrete over abstract: a named entity, a real score, an exact article number.
- No vendor language, no superlatives, no call to action. The strongest
  permitted endorsement is the shape of "Use it — I do."
- British-leaning spelling ("anonymisation", "minimisation"), matching the
  reference article.
- Bold is for the load-bearing clause of a paragraph, not for emphasis generally.
- Close on a line that lands. "The compliance argument was never going to be won
  in the regex."

## Mechanics

- English only. There is no German version of writing posts.
- File: `src/content/writing/en/<slug>.mdx`, frontmatter `title`, `date`,
  `description`, `tags`, `type: post`.
- Add the new route to `tests/e2e/site.spec.ts` with `hreflang: 2` — posts are
  English-only and must not advertise a German counterpart.
- `npm run verify` must pass before the article is considered done.

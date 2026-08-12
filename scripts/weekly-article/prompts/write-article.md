ultracode

Write one new article for envercetin.de on this topic:

TOPIC: {{TOPIC}}

You are running unattended. Nobody can answer a question, so make the reasonable
call and keep going. Do not ask for confirmation.

## Before you write

1. Read `docs/ARTICLE-STYLE.md`. It is binding, not advisory.
2. Read `src/content/writing/en/gdpr-presidio-llm-privacy.mdx` end to end. That
   is the reference article — match its structure, its voice, and above all its
   evidentiary standard.
3. Read `src/components/PiiFlowDiagram.astro` and `src/lib/rough.ts` to see how
   figures are built.

## Research

Use a Workflow to fan out research across the dimensions the topic needs, then
adversarially fact-check every number, date, case reference and version string
against a PRIMARY source before it reaches the draft. Secondary blogs do not
confirm a statistic — this has already burned us once, on a widely repeated "81%
of CIOs" figure that turned out not to be in the source it was attributed to.

If the topic makes a behavioural claim about software, install it and run it.
Quote real output verbatim. Local models are available via Ollama if useful.
Report what you actually observed, including the results that do not flatter the
argument.

### Hard boundary on what you may touch

You are running unattended on Enver's personal machine, alongside his open
applications and unrelated projects.

- **Never drive a running GUI application.** No `osascript`/AppleScript, no
  `open`, no automating Word, Pages, Excel, Preview, a browser or anything else
  the user may have open. On 2026-08-12 a run did exactly this to test watermark
  survival, hit the wrong document, and removed files from an unrelated project
  under a deadline.
- **Stay inside this repository and your own temp directory.** Do not read,
  write or delete anything under `~/Projects`, `~/Documents` outside this repo,
  `~/Desktop` or `~/Downloads`.
- **Never delete a file you did not create in this run.**
- **Never push, deploy, or publish.** `run.sh` owns those steps, after Enver has
  approved.

If an experiment cannot be done within those limits, do not do it — describe the
limitation in the article instead. An honest "I could not test this without
touching the user's machine" is a better sentence than a result obtained by
reaching outside the sandbox. A repository-level deny list in `.claude/settings.json`
enforces the worst of these, but the responsibility is yours regardless.

Anything you cannot verify does not go in the article.

## Write

- `src/content/writing/en/<slug>.mdx`, following the house style exactly:
  TL;DR aside, 6–9 sections, one figure, 1,200–1,600 words of prose, 6–9 sources.
- Build the figure as a new Astro component using `src/lib/rough.ts`. One idea
  only. Give it a real `<title>`/`<desc>` for screen readers, keep it inside the
  40em prose column, and make it work in light and dark.
- Add the new route to `tests/e2e/site.spec.ts` with `hreflang: 2`.

## Verify before you finish

- `npm run verify` must pass. Fix what it reports; do not weaken a test to make
  it pass.
- Confirm the rendered reading time is between 6 and 8 minutes.
- Re-read your own draft against the house style's non-negotiables and fix any
  claim that is not traceable to a primary source or an executed run.

## Output

Finish by printing, as the last line of your response, exactly:

SLUG: <the slug you used>

Nothing else on that line.

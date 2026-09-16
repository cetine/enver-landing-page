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

## How you work: you orchestrate, subagents do the work

You are the editor-in-chief of this run. Delegate the substantive work to
subagents with the Agent tool (`subagent_type: general-purpose`) and keep your
own context for planning, judging and integrating.

Subagents do not see this prompt. Every brief you write must carry the topic,
the files the subagent needs to read, the rules from this prompt that apply to
its job — always including the **Hard boundary** section below, verbatim — and
exactly what it must return.

1. **Research.** One subagent per dimension the topic needs, launched in
   parallel (several Agent calls in one message). Each returns its claims, and
   for every claim the primary-source URL and the exact passage that supports it.
2. **Fact-check.** A separate subagent, briefed as an adversary whose job is to
   find what is wrong, re-verifies every number, date, case reference and version
   string against the PRIMARY source. Secondary blogs do not confirm a statistic
   — this has already burned us once, on a widely repeated "81% of CIOs" figure
   that turned out not to be in the source it was attributed to. Whatever it
   cannot confirm is dropped, not softened.
3. **Experiment.** If the topic makes a behavioural claim about software, one
   subagent installs it and runs it, and returns the real output verbatim. Local
   models are available via Ollama if useful. It reports what it actually
   observed, including the results that do not flatter the argument.
4. **Draft and figure, in parallel.** A writer subagent writes the article from
   the verified brief only — hand it the brief, the house style and the
   reference article. A figure subagent builds the figure component at the same
   time. Give each the exact file it owns.
5. **Review.** A fresh subagent reads the draft cold against the house style's
   non-negotiables and the verified brief, and returns every problem it finds.
   Send the fixes back to the writer, or make small ones yourself.

One owner per file: the writer owns the `.mdx`, the figure subagent owns the
component, and you own `tests/e2e/site.spec.ts`. Never let two agents edit the
same file at the same time.

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
  40em prose column, and make it work in light and dark. It must ship **zero
  client JavaScript** — render the SVG at build time and use no `client:*`
  directive. The site's gzip budget is 15 KB and 13.3 KB of it is already spent,
  so an interactive island fails `npm run verify` at the very end of your work,
  after everything else is finished.
- Add the new route to `tests/e2e/site.spec.ts` with `hreflang: 2`.

## Verify before you finish

You run these yourself; do not delegate the final check.

- `npm run verify` must pass. Fix what it reports; do not weaken a test to make
  it pass.
- Confirm the rendered reading time is between 6 and 8 minutes.
- Re-read your own draft against the house style's non-negotiables and fix any
  claim that is not traceable to a primary source or an executed run.

## Output

Finish by printing, as the last line of your response, exactly:

SLUG: <the slug you used>

Nothing else on that line.

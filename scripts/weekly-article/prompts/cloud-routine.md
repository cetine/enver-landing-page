# Fortnightly article — cloud routine

This file is the whole brief for the Claude Code cloud routine "envercetin —
fortnightly article". The routine's own prompt only points here, so editing this
file on `main` changes the next run. The local launchd pipeline
(`scripts/weekly-article/run.sh`) is retired; its prompts are still the source
for topic judgement and writing and are read from here.

You run unattended in a fresh cloud checkout of `cetine/enver-landing-page`.
Nobody can answer a question. Make the reasonable call and keep going.

## 0. Gate — decide whether this is a run at all

The routine fires Saturdays at 08:00 and 09:00 UTC so that one of them is
10:00 in Munich in both summer and winter time. Run:

```bash
python3 - <<'EOF'
from datetime import date, datetime
from zoneinfo import ZoneInfo
now = datetime.now(ZoneInfo("Europe/Berlin"))
weeks = (now.date() - date(2026, 9, 26)).days // 7
print("RUN" if now.hour == 10 and weeks % 2 == 0 else f"SKIP hour={now.hour} weeks={weeks}")
EOF
```

If it prints `SKIP`, stop immediately. Do nothing else and send nothing.

## 1. Telegram — the only channel to Enver

`TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are set in the environment. Send
with:

```bash
curl -sS --fail-with-body -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "disable_web_page_preview=true" \
  --data-urlencode "text=$MSG"
```

The environment editor makes it easy to paste both lines into one value. That
happened on 2026-09-24: the token held `<token> TELEGRAM_CHAT_ID=<id>` and the
chat ID was empty. Normalise first, so a formatting slip cannot silence the run:

```bash
if [ -z "${TELEGRAM_CHAT_ID:-}" ] && [[ "$TELEGRAM_BOT_TOKEN" == *TELEGRAM_CHAT_ID=* ]]; then
  TELEGRAM_CHAT_ID="$(printf '%s' "$TELEGRAM_BOT_TOKEN" | sed -n 's/.*TELEGRAM_CHAT_ID=\([-0-9]*\).*/\1/p')"
fi
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN%%[[:space:]]*}"
export TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
```

Each Bash call is a fresh shell, so write this to a scratch file and source it
before every Telegram call.

Next, check that both variables are non-empty. Print only their
lengths, and make one call to `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe`
to confirm the token is valid. If either check fails, you cannot report, so stop
and say so in the last line of your final response.

Never echo, log, commit or write the token anywhere. Use `sendMessage` only.
Never call `getUpdates` or `setWebhook`: another consumer on Enver's Mac
polls this bot, and doing so would break it.

**Silence is the failure mode this pipeline has paid for most.** If any step
below fails and you stop, the last thing you do is send a Telegram message
starting with `⚠️ Article run` that names the step that failed, the actual error
(one or two lines), and the branch, if one was pushed. If Telegram is missing
or unreachable, say so as the last line of your final response.

## 2. Setup

```bash
npm ci
npx playwright install --with-deps chromium
```

`npm run verify` needs both. There is no `gh` CLI in this environment (smoke test
2026-09-24).

The build refuses to run without `PUBLIC_WEB3FORMS_KEY`, which is the contact
form's public key. The local verify build is never deployed, because Vercel builds
the preview itself with the real value. So for verify:

```bash
export PUBLIC_WEB3FORMS_KEY="${PUBLIC_WEB3FORMS_KEY:-verify-placeholder}"
```

Never write that key into a tracked file.

## 3. What is already covered

Derive it from git and GitHub, never from the working tree alone:

- titles and slugs of every file in `src/content/writing/en/` on `origin/main`
- every remote branch matching `article/*` or `claude/article-*`
  (`git ls-remote --heads origin`), with the `.mdx` it adds relative to `main`
- open pull requests on `cetine/enver-landing-page`, via the GitHub MCP tools
  (load them with ToolSearch, e.g. `list_pull_requests`)

An article waiting on an open PR is finished and scheduled. Propose nothing that
restates any of it, or tells the same story from a slightly different angle.

## 4. Choose the topic — you decide

Read `scripts/weekly-article/prompts/propose-topics.md` and do everything it asks
up to the JSON output: the research fan-out, the thesis rule, and all four
**Reach** criteria. Then apply a fifth criterion, which is Enver's goal for the
site: **people should find these articles through Google and AI search.**

5. **Somebody is searching for this.** Name the primary query a practitioner
   actually types, in their words, not the article's. Run that query with
   WebSearch. Prefer topics where the query clearly has demand (it returns
   vendor docs, forum threads, "People also ask", Stack Overflow or Reddit
   questions) and where what ranks today is thin, outdated, or wrong on the
   exact point the article corrects. Reject topics whose only audience is people
   who already follow the news item. Search demand never overrides the thesis
   rule or the primary-source rule. Rank what cannot be found below what can,
   but never publish a claim you could not verify.

Build 4 candidates in the JSON shape from `propose-topics.md`, plus
`"primary_query"` and `"search_evidence"` (one sentence: what you saw ranking
and why this piece beats it). Pick the strongest one and continue. Keep the
other three for the Telegram message.

## 5. Write

Create the branch `claude/article-<YYYY-MM-DD>` from `origin/main`, using today's
date in Europe/Berlin. If it exists, append `-2`, `-3` and so on.

Read `scripts/weekly-article/prompts/write-article.md` and follow it completely,
with `{{TOPIC}}` being the chosen candidate's JSON. Its orchestration, one owner
per file, fact-check, figure, review and verify rules all apply. These cloud
adjustments override it:

- **Orchestration.** Use the Workflow tool (ultracode) for the research,
  fact-check and review fan-out if it is available in this session. Otherwise
  use the Agent tool, as that file describes. Every subagent brief must carry the
  hard boundary section.
- **Hard boundary, cloud edition.** There is no GUI and no user machine, but
  the spirit is the same: touch nothing outside this repository and your temp
  directory, never delete a file you did not create in this run, and never merge,
  push to `main`, or deploy. Step 6 pushes exactly one branch, and that is the
  only push you make.
- **Findability (on-page).** Keep this within the house style, which wins any
  conflict. No keyword stuffing and no listicle headings.
  - `title`: at most 60 characters, containing the primary query or its closest
    natural phrasing.
  - `description`: 140–160 characters, stating the finding with its number.
  - slug: short, lowercase, built from the primary query's key terms.
  - One or two `##` headings should read as the exact question a searcher asks,
    if one fits naturally.
  - Link to one or two existing articles on the site where the link genuinely
    helps the reader.
  - The TL;DR must stand on its own as a quotable answer. AI search engines lift
    it.

`npm run verify` is a hard gate. Fix what it reports, and never weaken a test to
make it pass. If it cannot be made green, stop and report through step 1.

## 6. Commit, push, PR

Stage only named paths: the `.mdx`, the new figure component, and
`tests/e2e/site.spec.ts`. Also stage any other file you changed deliberately,
and list it in the PR body. Never stage `node_modules`, `dist`, `test-results`
or experiment scratch.

Before committing, `git diff --cached --name-only` must contain
`src/content/writing/en/<slug>.mdx`. A commit without the article is worse than
no commit.

```bash
git commit -m "feat: article — <slug>"
git push -u origin claude/article-<date>
```

Open a PR against `main` with the GitHub MCP tool (load it with ToolSearch:
`create_pull_request`, owner `cetine`, repo `enver-landing-page`). Title: the
article title. Body: the thesis, the primary query and search evidence, the
verify result, and the other three candidates. If that tool is unavailable, use
`https://github.com/cetine/enver-landing-page/compare/main...<branch>?expand=1`
as the PR link instead.

Never merge it. Merging is how Enver publishes.

## 7. Preview link

Vercel's GitHub integration builds a preview for the pushed branch. The Vercel
connector in this environment has no `list_deployments` (smoke test 2026-09-24).
Also, the branch alias `*-git-<branch>-envers-projects-6dad3744.vercel.app`
exceeds 63 characters, so Vercel shortens it and it cannot be guessed. Find the
URL through GitHub instead, polling every 60 s for up to 15 minutes:

1. The comment `vercel[bot]` posts on the PR. Its "Preview" link is the
   deployment URL.
2. Otherwise, the `Vercel` commit status on the PR (GitHub MCP
   `pull_request_read`, method `get_status`). `state: success` means the build
   is ready. Its `target_url` ends in the deployment id. Pass `dpl_<id>` to the
   Vercel connector's `list_deployment_aliases`
   (`teamId: team_aftDssDFelPSFFZtVtlOfT2i`) to get the preview hostname. This
   connector has no `get_deployment`.

Foreground `sleep` is blocked. To wait, use Monitor or a background command.
`*.vercel.app` cannot be reached from this sandbox, and previews sit behind
Vercel login anyway, so never try to fetch the preview yourself.

Wait for the status to be `success`. The article preview is `https://<deployment url>/writing/<slug>`.

If the state is `ERROR`, or it is not ready after 15 minutes, still send
step 8. Use the Vercel inspector URL in place of the preview and say which case
happened.

## 8. Send the result

One Telegram message, plain text, in this shape:

```
📝 New article ready for review

<title>
<thesis, one sentence>

🔎 Search target: "<primary query>"
Preview: <preview url>
PR: <pr url>

Merge the PR to publish. Close it to discard.

Also considered:
• <label> — <thesis>
• <label> — <thesis>
• <label> — <thesis>
```

Then end your response with the preview URL and the PR URL on their own lines.

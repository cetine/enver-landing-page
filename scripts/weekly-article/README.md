# Weekly article automation

Saturdays at 14:00, Claude proposes topics over Telegram, writes the chosen
article, and publishes it only after you approve a preview.

## The flow

| Step | What happens | Can it touch the live site? |
|---|---|---|
| 1 | Claude web-researches and proposes 4 topics | no |
| 2 | Telegram asks you: tap a proposal, or type your own | no |
| 3 | Claude researches and writes the article on a local branch, in ultracode | no |
| 4 | `npm run verify` runs as a hard gate | no |
| 5 | `vercel deploy` publishes a **preview** from the local working tree | no — preview URL only, nothing pushed to GitHub |
| 6 | Telegram sends you the preview link and asks | no |
| 7 | Only on **Publish**: merge to main, push, deploy to production | yes |

Nothing reaches GitHub or envercetin.de before step 7. If you answer anything
other than "Publish", the work stays on a local branch and the preview URL
remains readable.

## Activation

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.enver.envercetin.weekly-article.plist
launchctl enable gui/$(id -u)/com.enver.envercetin.weekly-article
```

Check it is registered:

```sh
launchctl list | grep weekly-article
```

Deactivate:

```sh
launchctl bootout gui/$(id -u)/com.enver.envercetin.weekly-article
```

## Running it by hand

```sh
scripts/weekly-article/run.sh
```

Same pipeline, same Telegram prompts. Use this to test end to end without
waiting for Saturday.

## What it writes

`docs/ARTICLE-STYLE.md` is the binding house style, derived from the Presidio
article. Editing that file changes what gets written — it is the main knob.

The prompts are in `prompts/`; `lib/topics.py` turns the proposal JSON into the
Telegram message.

## Logs

`~/Library/Logs/envercetin-weekly-article/YYYY-MM-DD.log`, plus
`-topics.json` and `-verify.log` alongside it for the same date.

## Safety properties

- **Refuses to run on a dirty tree.** If the repo has uncommitted changes it
  sends a note and exits without touching anything.
- **Every failure notifies.** An `ERR` trap sends the failing line number and
  the log path to Telegram.
- **`npm run verify` is a hard gate.** A failing build never reaches a preview,
  let alone production.
- **No reply, no article.** If you do not answer the topic question within 4
  hours, the run exits and nothing is written.

## Known constraints

- The Mac must be awake at Saturday 14:00. If it is asleep, launchd runs the job
  at the next wake rather than skipping the week.
- Step 7 pushes to `main` and then runs `vercel deploy --prod`. If the Vercel
  GitHub integration is connected, the push already triggers a production build
  and that explicit deploy is a harmless duplicate — drop the line if you want.
- `--permission-mode acceptEdits` is what lets Claude work unattended. It is
  scoped by `--allowed-tools` in `run.sh`; widen that list rather than reaching
  for `--dangerously-skip-permissions`.

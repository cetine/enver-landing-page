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
| 7 | On **Publish**: a one-shot launchd job is scheduled — the following Friday 19:00–21:00 or Saturday 10:00–13:00, picked at random | not yet |
| 8 | At that moment: merge to main, verify again, push → production | yes |

Nothing reaches GitHub or envercetin.de before step 8. Approving in step 7 only sets the date; you get a Telegram message naming the exact time and the command to cancel it. If you answer anything
other than "Publish", the work stays on a local branch and the preview URL
remains readable.

## Activation

```sh
scripts/weekly-article/install.sh
```

Idempotent. It installs the guard to `~/.local/bin/envercetin-guard`, writes the
plist with the repo's current path, and loads the job. Run it after moving the
repo or editing `guard.sh`.

Check without changing anything:

```sh
scripts/weekly-article/install.sh --check
```

Deactivate:

```sh
launchctl bootout gui/$(id -u)/com.enver.envercetin.weekly-article
```

### Where the repo may live

`install.sh` refuses to install if the repo sits under `~/Documents`, `~/Desktop`,
`~/Downloads` or `~/Library/CloudStorage`. A LaunchAgent gets no access to those
folders under macOS TCC, so launchd cannot start a script there at all. That is
not theoretical: it is how the run of **2026-08-15** was lost, silently, after
the repo had been sitting in `~/Documents` all along.

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
- **A job that cannot start notifies too.** launchd starts `guard.sh` — which
  lives outside the repo — and never the pipeline directly. The guard checks the
  target script is readable before running it, and reports any non-zero exit,
  including crashes and kills that the script itself could not report. Telegram
  is the channel; a macOS notification is the fallback if Telegram is what broke.
- **One run at a time.** The guard takes a PID lock, so a run that is still going
  is never joined by a second one. A lock left by a killed run is taken over, not
  honoured forever.
- **The ask lock is always released.** If a run dies holding personal-os's
  `data/ask-active.lock`, the guard removes it — but only if that run created it
  — so `kb_daemon` does not stay paused indefinitely.
- **`npm run verify` is a hard gate.** A failing build never reaches a preview,
  let alone production.
- **No reply, no article — but it asks three times first.** The topic question
  is repeated up to three times, 150 minutes apart, with the last one flagged as
  a last call. Only then does the run exit, having written nothing.

## Logs from the guard

`~/Library/Logs/envercetin-weekly-article/guard-<job>-YYYY-MM-DD-HHMM.log`. Start
here when a run seems not to have happened — if the guard never logged, launchd
never started it.

## Known constraints

- The Mac does not have to be awake at Saturday 14:00. If it is asleep, shut down
  or logged out, launchd runs the job once at the next wake or login rather than
  skipping the week. Several missed weeks still collapse into a single run.
- Step 8 publishes by pushing `main` and nothing else. The Vercel GitHub
  integration builds production from that push (verified 2026-08-12: a build
  started 12 s after one). No `vercel --prod` call, which also keeps production
  deploy rights out of the model's hands.
- `--permission-mode acceptEdits` is what lets Claude work unattended. It is
  scoped by `--allowed-tools` in `run.sh`; widen that list rather than reaching
  for `--dangerously-skip-permissions`.

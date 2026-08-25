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

Nothing reaches GitHub or envercetin.de before step 8. Approving in step 7 only
sets the date; you get a Telegram message naming the exact time and the command
to cancel it. If you decline, the work stays on a local branch and the preview
URL remains readable — and if the question never reaches you, or you never
answer, that is reported as undecided rather than filed as a No.

### Calling off a scheduled publish

```sh
scripts/weekly-article/cancel-publish.sh <branch>     # keeps the work as draft/<name>
scripts/weekly-article/cancel-publish.sh --list       # what is scheduled
```

Do **not** cancel with `launchctl bootout` alone: that unloads the job and leaves
the plist in `~/Library/LaunchAgents`, so at the next login launchd loads it
again and the article you withdrew goes live. `cancel-publish.sh` deletes the
file first, then unloads, and renames `article/<name>` to `draft/<name>` so the
watchdog stops reporting a branch with no schedule as stuck. Add
`--delete-branch` to throw the article away, or `--keep-branch` to leave it where
it is because you mean to reschedule. Undo a rename with
`git branch -m draft/<name> article/<name>`.

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

## The watchdog

`watchdog.sh` runs Saturdays and Tuesdays at 10:00, from its own launchd job. It
watches the pipeline from outside and reports **only problems**, so silence means
healthy. Saturday is the pre-flight — today is a writing day, is last week's
article actually out? Tuesday is the post-mortem — Saturday has been and gone,
did anything come of it?

It checks six things, nearly all from local state:

1. the weekly job is still loaded in launchd;
2. `~/.local/bin/envercetin-guard` and `-notify` match the repo (editing
   `guard.sh` changes nothing until `install.sh` copies it, so a fix can look
   done and not be);
3. every `article/*` branch either has a publish job still in the future, or is
   reported as stuck — including the case where the job exists but its date has
   already passed, which is precisely what 2026-08-22 left behind;
4. whether local `main` holds article commits the remote has never seen — a
   failed push used to leave exactly that, and every other check here reads
   local `main` and would have called it healthy;
5. whether a run is still holding a lock past the 36-hour cap, which blocks
   every other job behind it;
6. how long since anything actually reached the site (default: complain after
   10 days).

Run it by hand without sending anything:

```sh
scripts/weekly-article/watchdog.sh --check
```

## Tests

```sh
scripts/weekly-article/tests/run-all.sh      # everything
scripts/weekly-article/tests/guard.test.sh   # or one suite at a time
```

`install.sh` runs `run-all.sh` and refuses to install if anything fails, because
installing is the moment a regression goes live and every failure mode here is a
silent one.

| Suite | What it pins down |
|---|---|
| `guard.test.sh` | the launchd-only behaviour: a retry that must not boot itself out, the offline give-up path |
| `repo-lock.test.sh` | one job at a time per working tree; a hung run swept and killed rather than blocking every later week |
| `timeout.test.sh` | `with_timeout`: 124 on a hang, children die with the parent, and it works inside a pipeline |
| `approval.test.sh` | what an answer to "Publish it?" means — including a broken Telegram, which is not a No |
| `approval-flow.test.sh` | what `run.sh` actually *does* with each of those answers, end to end with fake `claude`/`vercel`/`tg.py` |
| `deploy.test.sh` | a rejected push leaves the repo exactly as it was, and success is confirmed against the remote before it is claimed |
| `cancel-publish.test.sh` | the plist is deleted rather than merely unloaded, and the watchdog stops nagging |
| `watchdog.test.sh` | each broken state is reported, and a healthy one is silent |

The guard tests drive the real guard through real launchd jobs, because the bugs
worth catching there only exist under launchd — a self-`bootout` cannot be
reproduced any other way. Every probe job is labelled
`com.enver.envercetin.retry-guardtest-*` and is booted out in a trap. Everything
else runs against temp repos with a real bare remote, and reaches neither GitHub,
Vercel, nor Telegram.

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
- **One run at a time, and one job at a time per repo.** The guard takes a lock
  for the job *and* a lock for the working tree. The second one matters because
  a publish job that launchd deferred to the next wake and the Saturday writing
  run are different jobs with equal right to run — and both begin with
  `git checkout` in the same directory. A job that finds the repo busy arms a
  retry and says so once, rather than joining in or being lost.
- **A hung run cannot cost more than one cycle.** Every long step has a ceiling
  (writing 2 h, verify 45 min, deploy 15 min, anything on the network 10 min) and
  is killed with its whole process group when it passes it. If a run hangs
  anyway, its lock carries the time it was taken: the next job to arrive kills
  the holder and reports it. There is deliberately no sweeper daemon — alarms do
  not fire while the Mac sleeps and a background sweeper would sleep with it, so
  the check belongs in whatever wakes up next.
- **A failed push rolls back.** `deploy-scheduled.sh` either leaves the article
  on GitHub or leaves the repo exactly as it found it. It confirms the push
  landed by asking the remote before it reports success — "✅ Published" used to
  be sent on the strength of `git push` returning 0, and a rejected push left the
  article merged into local `main` only, with the branch deleted and every alarm
  green.
- **A question that fails is not an answer.** A Telegram error, a dropped poll or
  a reply that is neither option is reported as undecided — with both ways out —
  and never as "kept as a draft, as you asked". Collapsing those into a No turned
  a finished article into a permanent draft whose topic could never be proposed
  again.
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

- **A closed lid on battery still sleeps through Saturday.** This is the real
  limit and it is not fixable from here. `caffeinate` — which the guard now holds
  for the duration of a run — prevents *idle* sleep; it cannot prevent *clamshell*
  sleep on battery. On 2026-08-22 the Mac went to clamshell sleep at 10:28 and
  only dark-woke for a few seconds every quarter hour for the rest of the day, so
  neither the publish nor the write ever got a usable connection. The job does
  catch up at the next real wake, and the watchdog says so on Tuesday — but if
  weekends away become normal, the schedule belongs on a machine that does not
  sleep.
- The Mac does not have to be awake at Saturday 14:00. If it is asleep, shut down
  or logged out, launchd runs the job once at the next wake or login rather than
  skipping the week. Several missed weeks still collapse into a single run.
- **The network budget is awake time, not wall-clock.** A run that starts offline
  waits up to 90 minutes *of actual running*, crediting each poll with the time
  that poll really took, capped. A wall-clock deadline is spent almost entirely
  while a sleeping machine is not running: on 2026-08-22 ninety minutes of
  deadline bought about two minutes of runtime before the run gave up.
- **Giving up is never silent.** When the wait is exhausted the run arms a retry
  *and says so*, through the spool. The give-up branch used to exit 0 without a
  word, which is why a lost Saturday looked exactly like a normal one.
- **A retry never boots out its own label.** `launchctl bootout` terminates the
  process executing it. The guard used to clear "a pending retry for this job"
  without noticing that it *was* that retry, so every retry it armed killed itself
  three lines before the network check — silently, without running, reporting, or
  releasing its lock. `deploy-scheduled.sh` had the same shape at the end.
- **Queued alerts drain on their own.** `com.enver.envercetin.notify-flush` runs
  every 30 minutes. The backlog used to be flushed only by the weekly run, which
  is the very thing that fails when there is no network to deliver on.
- Step 8 publishes by pushing `main` and nothing else. The Vercel GitHub
  integration builds production from that push (verified 2026-08-12: a build
  started 12 s after one). No `vercel --prod` call, which also keeps production
  deploy rights out of the model's hands.
- `--permission-mode acceptEdits` is what lets Claude work unattended. It is
  scoped by `--allowed-tools` in `run.sh`; widen that list rather than reaching
  for `--dangerously-skip-permissions`.

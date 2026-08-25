# Pipeline-Härtung — die 4 schweren Defekte + der Abbruch-Befehl

Aus dem Audit vom 24.08.2026. Alles mit Test, weil jeder dieser Defekte genau
dann zuschlägt, wenn niemand hinschaut.

## 1. Repo-Sperre
Der Guard sperrt pro **Job**, nicht pro **Repo**. Ein aufgeschobener Publish-Job
und der Samstagslauf können gleichzeitig im selben Arbeitsbaum stehen —
`git checkout` gegen `git rebase`, `git reset --hard` gegen den frisch
geschriebenen Artikel.
- [x] Guard: zusätzliche Repo-Sperre, gehalten für den ganzen Lauf
- [x] Belegtes Repo → Retry armen + melden statt still abbrechen (nichts geht verloren)
- [x] Sperren über EXIT-Trap freigeben (schließt auch die Leckpfade)
- [x] Test: zweiter Lauf startet sein Ziel nicht, armt einen Retry, meldet sich

## 2. Timeouts + Sweeper
Ein hängender Schritt hält Job- und Repo-Sperre für immer. SIGALRM feuert im
Schlaf nicht und ein Hintergrund-Sweeper schläft mit — also **kein** Daemon:
die Sperre trägt ihr Alter, und der nächste Lauf räumt auf.
- [x] `lib/with_timeout.sh` — kein `timeout` auf diesem Mac; killt die Prozessgruppe, rc 124
- [x] run.sh + deploy-scheduled.sh: Schreiben, Verify, Deploy, Push begrenzt
- [x] Guard: Sperre älter als die Obergrenze → Halter killen, übernehmen, melden
- [x] Wächter: hängender Lauf ist ein Befund
- [x] Test: hängender Befehl wird begrenzt, schneller nicht; Kind stirbt mit

## 3. Push-Rollback
`git push` schlägt fehl → main ist lokal schon gemergt, der Branch gelöscht,
"✅ Veröffentlicht" behauptet. Der Wächter liest lokales main und sieht nichts.
- [x] Push scheitert → `git reset --hard` auf den Stand davor, Branch bleibt
- [x] Erfolg erst behaupten, wenn `main == origin/main` wirklich gilt
- [x] Wächter: lokales main vor origin/main mit Artikeln = eigener Alarm
- [x] Test: gegen ein echtes Bare-Remote, Push abgelehnt → Zustand exakt wie vorher

## 4. Abfrage-Fehler ≠ Ablehnung
`rc != 0` wird wie "Keep as draft" behandelt. Ein verlorener Poll macht aus einem
fertigen Artikel einen dauerhaften Entwurf.
- [x] `lib/approval.sh` — publish | draft | undecided | error
- [x] Timeout → erneut fragen, dann ehrlich "nichts entschieden"
- [x] Fehler → ⚠️ + exit 1, niemals "wie gewünscht als Entwurf behalten"
- [x] Test: Wahrheitstabelle, inkl. Freitext-Antwort

## 5. cancel-publish.sh (mein eigener Defekt)
`launchctl bootout` löscht die Plist nicht — beim nächsten Login ist der
zurückgezogene Artikel wieder scharf. Und ein abgebrochener Branch lässt den
Wächter bis in alle Ewigkeit nörgeln.
- [x] `cancel-publish.sh <branch|label>` — Plist löschen, Job entladen
- [x] Branch nach `draft/*` umbenennen (Wächter schweigt, Arbeit bleibt, umkehrbar)
- [x] Laufender Publish → verweigern statt mitten hinein
- [x] run.sh + Wächter zeigen auf dieses Skript
- [x] Test: Plist ist weg, Branch umbenannt, laufender Job wird verweigert

---

## Ergebnis (25.08.2026)

125 Prüfungen in 8 Suites, alle grün; `install.sh` führt jetzt `tests/run-all.sh`
aus und verweigert die Installation, wenn irgendetwas davon fehlschlägt.

Was dabei zusätzlich auffiel und mit erledigt ist:

- **Die Antwort-Zeile wurde mit `grep` gelesen.** Ohne Treffer liefert grep 1,
  und mit `set -e` plus `pipefail` stirbt der Lauf an der Zuweisung — genau auf
  dem Timeout-Pfad, der ohne Verlust überstehbar sein muss. Jetzt `sed -n`.
- **Ein Wächter-Test war verrottet.** Er nahm an, `main~1` zeige noch auf einen
  alten Artikel; seit dem Token-Tax-Artikel stimmte das nicht mehr und der Test
  meldete grün. Läuft jetzt gegen ein Fixture mit rückdatiertem Commit.
- **`claude` und `vercel` werden namentlich aufgerufen.** run.sh stellt
  `~/.local/bin` vor den PATH, also überstimmte es jede Test-Attrappe und fuhr
  das echte Modell gegen ein Wegwerf-Repo.
- **Offline-Meldungen wiederholen sich nicht mehr.** Ein Retry, der sich alle 30
  Minuten neu armt, hat stundenlang identische Nachrichten gespoolt und sie beim
  Netzstart alle auf einmal zugestellt. Gesagt wird es beim ersten Mal.

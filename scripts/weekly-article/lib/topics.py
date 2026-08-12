#!/usr/bin/env python3
"""Turn the proposal JSON into the strings run.sh needs.

Kept out of run.sh as a real file rather than a heredoc: macOS ships bash 3.2,
whose parser scans heredoc bodies for quote characters when they sit inside
`$( )`. A single apostrophe in a comment is enough to break the script.

Usage:
  topics.py question <topics.json>       the Telegram message body
  topics.py options  <topics.json>       comma-separated button labels
  topics.py brief    <topics.json> PICK  full brief for the chosen label,
                                         or PICK itself if Enver typed his own
"""
import json
import sys

# Telegram rejects messages over 4096 characters; leave headroom for the buttons.
MAX_MESSAGE = 3900
HEADER = "What should this week's article be about?"
FOOTER = "Tap one, or just type a topic of your own."


def label_of(topic: dict) -> str:
    # `--options` is comma-separated, so a comma in a label would silently
    # become two buttons.
    return topic["label"].replace(",", " ").strip()


def question(topics: list) -> str:
    def render(verbose: bool) -> str:
        lines = [HEADER, ""]
        for i, t in enumerate(topics, 1):
            lines.append(f"{i}. {label_of(t)} — {t['thesis']}")
            if verbose:
                lines.append(f"   why now: {t['why_now']}")
        lines += ["", FOOTER]
        return "\n".join(lines)

    text = render(verbose=True)
    if len(text) > MAX_MESSAGE:
        text = render(verbose=False)
    return text[:MAX_MESSAGE]


def brief(topics: list, pick: str) -> str:
    pick = pick.strip()
    for t in topics:
        if label_of(t) == pick:
            return (f"{t['label']} — {t['thesis']} "
                    f"(why now: {t['why_now']}; measurable angle: {t['can_measure']})")
    return pick


def main(argv: list) -> int:
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 1
    command, path = argv[1], argv[2]
    topics = json.load(open(path, encoding="utf-8"))
    if not isinstance(topics, list) or not topics:
        print("topics file is not a non-empty JSON array", file=sys.stderr)
        return 1

    if command == "question":
        print(question(topics))
    elif command == "options":
        print(",".join(label_of(t) for t in topics))
    elif command == "brief":
        if len(argv) < 4:
            print("brief needs the chosen label", file=sys.stderr)
            return 1
        print(brief(topics, argv[3]))
    else:
        print(f"unknown command: {command}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

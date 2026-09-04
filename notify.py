#!/usr/bin/env python3
"""Record a Scout ticket and fire a native macOS notification.

Usage: notify.py "<title>" ["<summary>"]
"""
import json
import subprocess
import sys
import time
import uuid
from pathlib import Path

EVENTS_PATH = Path.home() / ".scout-pet" / "events.json"
MAX_EVENTS = 20


def main():
    if len(sys.argv) < 2:
        print("usage: notify.py <title> [summary]", file=sys.stderr)
        sys.exit(1)
    title = sys.argv[1]
    summary = sys.argv[2] if len(sys.argv) > 2 else ""

    try:
        events = json.loads(EVENTS_PATH.read_text())
        if not isinstance(events, list):
            events = []
    except (FileNotFoundError, json.JSONDecodeError):
        events = []

    events.append({
        "id": "evt-" + uuid.uuid4().hex[:12],
        "title": title,
        "summary": summary,
        "finishedAt": int(time.time() * 1000),
    })
    events = events[-MAX_EVENTS:]
    EVENTS_PATH.write_text(json.dumps(events))

    osa_title = title.replace('"', "'")
    osa_summary = (summary or "Background task finished").replace('"', "'")
    subprocess.run([
        "osascript", "-e",
        'display notification "{}" with title "Scout" subtitle "{}"'.format(osa_summary, osa_title)
    ], check=False)


if __name__ == "__main__":
    main()

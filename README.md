# Scout

A tiny coral terminal-bot that lives in a floating, always-on-top widget on your Mac. It sits at a laptop and types whenever Claude Code is actively working — in this conversation or any other session on your machine — and stands back up the moment everything goes idle.

Inspired by the "Codex pet" style of desktop companion.

## What it does

- **Floats above every window and Space**, borderless and transparent, in the corner of your screen.
- **Sits down and types** while any Claude Code session is actively running.
- **Reacts to task completions**: prints a ticket into a small on-screen log and fires a native macOS notification when a background task finishes.
- **Pettable**: click it for a heart reaction, just because.

## How it works

- `pet.html` — the character itself: SVG art, CSS animations (idle bob, wander, blink cursor, sit/stand, celebration), and the JS state machine. Pure client-side, no network calls.
- `ScoutPetApp.swift` — a small AppKit app that hosts `pet.html` in a borderless, floating `NSPanel` via `WKWebView`, and pushes live state into the page (`window.scoutSetStatus`, `window.scoutSetEvents`) once a second.
- `notify.py` — call this from anywhere (`notify.py "<title>" "<summary>"`) to record a completed-task ticket and pop a native notification.

### Why "push" instead of the page polling files itself

`WKWebView` blocks JavaScript's `fetch`/`XMLHttpRequest` from reading local `file://` resources even with read access granted. So instead of the page polling JSON files, the native Swift side reads them and calls into the page directly via `evaluateJavaScript`.

### How it knows *any* session is working, not just one

Two signals, combined:

1. **Fast local signal**: any `~/.claude/projects/**/*.jsonl` transcript written to in the last few seconds. Good for instant feedback, but misses long silent gaps inside a single long-running tool call.
2. **Authoritative signal**: `sessions.json`, refreshed periodically by a Claude Code loop/cron job that calls the session-management tool for the real `isRunning` flag per session. Ignored if stale (loop stopped), so it degrades gracefully to local-only detection.

## Build & run

```bash
swiftc ScoutPetApp.swift -o ScoutPet -O -framework Cocoa -framework WebKit
./ScoutPet &
```

A 🐾 menu bar icon lets you reload or quit it.

## Notifying Scout of a finished task

```bash
python3 notify.py "Build finished" "3 tests failed"
```

This appends to `events.json` (capped at the last 20) and fires a native notification.

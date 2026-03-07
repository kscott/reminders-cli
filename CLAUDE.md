# reminders-cli

Swift CLI tool for Apple Reminders via EventKit.

## Build & run

```bash
reminders setup   # build release binary and install to ~/bin
reminders test    # build and run test suite
```

Or directly via SPM:
```bash
swift build -c release   # build
swift build              # build debug (needed before running tests)
```

## Project structure

- `Sources/RemindersLib/DateParsing.swift` — pure date parsing logic, no framework deps
- `Sources/RemindersCLI/main.swift` — CLI entry point, all EventKit/AppKit code
- `Tests/RemindersLibTests/main.swift` — custom test runner (no Xcode/XCTest required)
- `reminders` — bash wrapper script, symlinked into `~/bin`

## Key decisions

- **EventKit over AppleScript** — AppleScript blocks the Reminders UI and is ~20x slower
- **RemindersLib separated from RemindersCLI** — allows unit testing without entitlements
- **Custom test runner instead of XCTest** — works with CLT only, no full Xcode needed
- **`reminders open` uses NSWorkspace** — non-blocking, doesn't require Reminders to be running

## Known limitations

- Sections within a list are not exposed by EventKit — all reminders appear flat
- Sub-tasks have no parent-child relationship in the public EventKit API
- Sharing state (who a list is shared with) is not accessible via EventKit
- `complete` and `delete` only search incomplete reminders, matched by title (first match wins)

## Deployment

Binary lives at `~/bin/reminders-bin`. The `reminders` wrapper in this repo is symlinked there.
On a new machine, run `~/dev/reminders-cli/reminders setup` after cloning.
Requires macOS 14+.

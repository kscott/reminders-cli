# reminders-cli

Swift CLI tool for Apple Reminders via EventKit.

## Build & run

```bash
reminders setup   # build release binary and install to ~/bin
reminders test    # build and run test suite
```

Or directly via SPM:
```bash
swift build -c release   # build release
swift build              # build debug (needed before running tests)
```

## Project structure

- `Sources/RemindersLib/DateParsing.swift` — pure date parsing logic, no framework deps
- `Sources/RemindersLib/RecurrenceParsing.swift` — pure recurrence parsing logic, no framework deps
- `Sources/RemindersCLI/main.swift` — CLI entry point, all EventKit/AppKit code
- `Tests/RemindersLibTests/main.swift` — custom test runner (no Xcode/XCTest required)
- `reminders` — bash wrapper script, symlinked into `~/bin`

See [DEVELOPMENT.md](DEVELOPMENT.md) for coding conventions, interface design rules, and patterns to follow when adding features.

## Key decisions

- **EventKit over AppleScript** — AppleScript blocks the Reminders UI and is ~20x slower
- **RemindersLib separated from RemindersCLI** — allows unit testing without entitlements or permissions
- **Custom test runner instead of XCTest** — works with CLT only, no full Xcode needed
- **`reminders open` uses NSWorkspace** — non-blocking, doesn't require Reminders to be running
- **RecurrenceSpec in RemindersLib** — parsing and description are pure functions, converted to EKRecurrenceRule in main.swift

## Commands

```
reminders open
reminders lists
reminders list [list-name]
reminders create <title> [list] [date]
reminders edit <title> [list] [date] [--title "New Title"]
reminders complete <title> [list]
reminders delete <title> [list]
```

`edit` updates only fields that are specified. `--title` is the one flag in the tool — necessary to distinguish the new name from the existing title used to find the reminder.

## Repeat

The word `repeat` in the date portion acts as a delimiter — left side is parsed as a date, right side as a recurrence:

```
reminders create "Pay rent" "march 1 repeat monthly"
reminders create "Book club" "repeat last tuesday"
```

Formats: `daily`, `weekly`, `monthly`, `yearly`, `every 2 weeks`, `first monday`, `last tuesday`, etc.

## Known limitations

- Sections within a list are not exposed by EventKit — all reminders appear flat
- Sub-tasks have no parent-child relationship in the public EventKit API
- Sharing state (who a list is shared with) is not accessible via EventKit
- `complete` and `delete` only search incomplete reminders, matched by title (first match wins)

## Deployment

Binary lives at `~/bin/reminders-bin`. The `reminders` wrapper in this repo is symlinked there.
On a new machine, run `~/dev/reminders-cli/reminders setup` after cloning.
Requires macOS 14+.

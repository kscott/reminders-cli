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
reminders list [name]
reminders find <query>
reminders add <name> [list] [date]
reminders change <name> [list] [date]
reminders rename <name> <new-name> [list]
reminders done <name> [list]
reminders remove <name> [list]
```

`change` updates only fields that are specified — everything else is left as-is.
`rename` changes the title (identity) of a reminder; `change` modifies its attributes.

## Optional fields

After title and optional list/date, keywords `repeat`, `priority`, `url`, and `note` can appear in any order. `note` must be last — it captures everything after it to end of string.

```
reminders add "Pay rent" march 1 repeat monthly priority high note pay via bank
reminders change "Call dentist" friday priority medium url https://dentist.com note ask about X-rays
```

- `repeat`: `daily`, `weekly`, `monthly`, `yearly`, `every 2 weeks`, `last tuesday`, `2nd friday`, `the 15th`, `on the 1st of the month`, etc. Unknown values error rather than silently doing nothing.
- `priority`: `high`, `medium`, `low`, `none`
- `url`: any URL string
- `note`: free text to end of string (must be last)

## Known limitations

- Sections within a list are not exposed by EventKit — all reminders appear flat
- Sub-tasks have no parent-child relationship in the public EventKit API
- Sharing state (who a list is shared with) is not accessible via EventKit
- `done` and `remove` only match incomplete reminders (first match wins)

## Deployment

Binary lives at `~/bin/reminders-bin`. The `reminders` wrapper in this repo is symlinked there.
On a new machine, run `~/dev/reminders-cli/reminders setup` after cloning.
Requires macOS 14+.

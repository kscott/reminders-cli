# Development conventions

Patterns and decisions established for this project. Follow these when adding or changing anything.

## Architecture: what goes where

The project has three layers — keep them strictly separated.

**`RemindersLib`** — pure Swift, no framework dependencies
- Parsing logic: recurrence strings, options strings
- Business logic: `parseReminderChanges`, `parsePriority`
- Formatting: `metaLine(for:)`, `ReminderMeta`
- Types: `FieldChange<T>`, `ReminderChanges`, `RecurrenceSpec`
- If it doesn't need EventKit, it goes here

**`RemindersCLI/`** — EventKit boundary helpers (not main.swift)
- `RecurrenceConversion.swift` — `toEKRule`: RecurrenceSpec → EKRecurrenceRule
- `Sorting.swift` — `byDue`, `byPriority`, `byTitle`, `byCreated` over EKReminder

**`RemindersCLI/main.swift`** — dispatch and EventKit calls only
- Argument parsing and command dispatch
- EventKit calls (fetch, save, delete)
- `NSWorkspace` for launching apps
- Constructs framework objects from Lib results; applies changes to EKReminder

The rule: if you find yourself wanting to test something that lives in `main.swift`, that's a sign it should be moved to `RemindersLib`.

## Interface design: no flags

The tool uses positional arguments and natural language keywords — not flags.

**Correct:**
```
reminders add "Pay rent" march 1 repeat monthly
reminders change "Buy groceries" "Daily Life" friday repeat weekly
reminders rename "Buy groceries" "Weekly shopping"
```

**Avoid:**
```
reminders add "Pay rent" --date "march 1" --repeat monthly   # don't do this
```

There are no flags in this tool. `rename` is a dedicated command — it changes the
identity of a reminder (its title). `change` modifies attributes. They are distinct
operations, not variants of the same thing.

## Argument parsing conventions

- **Title** is always `args[1]` — required, user should quote it
- **List detection** — check if the first remaining arg matches a known list name via `store.calendars(for: .reminder)`; if so, it's the list and the rest is date/repeat
- **Options parsing** — join remaining args into a single string, pass to `parseOptions()`; returns `ParsedOptions` with `date`, `recurrence`, `priority`, `note`, `url` fields. `note` is extracted first (captures to end of string); remaining keywords (`repeat`, `priority`, `url`) can appear in any order
- **Unquoted args** — the shell splits on spaces; we rejoin with spaces, so quoting is the user's choice and both forms should work identically

## Natural language over syntax

Prefer recognising natural words over inventing syntax.

- `repeat`/`repeats`/`repeating`/`repeated` — all work as delimiters; accept conjugations people naturally type
- `first monday`, `last tuesday` — ordinal weekday phrases, not `monday#1` or `monday:-1`
- `every 2 weeks` — plain English intervals, not `2w` or `biweekly`
- `note` captures to end of string — no escaping needed; free text just works

When adding new features, ask: what would someone naturally type? Accept that.

## Testing

- All test-worthy logic lives in `RemindersLib` so it can be tested without Reminders permissions
- Framework: Quick + Nimble; run with `swift test`
- One spec file per source file: `RecurrenceParsingSpec`, `OptionsParsingSpec`, `ReminderFormatterSpec`, `ChangeCommandSpec`
- Structure: `describe` → `context` → `it`; one assertion per `it`
- New behaviour → new spec covering: typical inputs, edge cases, invalid/nil inputs

## Output conventions

Commands confirm what they did. Format:

| Command | Output |
|---------|--------|
| `add` | `Added: <title> (in <list>)[ due <date>][ repeat <freq>]` |
| `change` | `Updated "<title>": <change>, <change>` |
| `rename` | `Renamed: "<old>" → "<new>"` |
| `done` | `Done: <title>` |
| `remove` | `Removed: <title>` |

Errors go to stderr via `fail()`, which exits non-zero. No silent failures.

## Adding a new command

1. Add the case to the `switch cmd` block in `main.swift`
2. Add it to `usage()`
3. Add it to the command table in `README.md` and `CLAUDE.md`
4. If the command introduces new parsing logic, add it to `RemindersLib` with tests

# Development conventions

Patterns and decisions established for this project. Follow these when adding or changing anything.

## Architecture: what goes where

The project has two targets — keep them strictly separated.

**`RemindersLib`** — pure Swift, no framework dependencies
- All parsing logic: dates, recurrence strings, splitting
- All description/formatting of domain types
- Anything that can be expressed as `String → SomeType`
- If it doesn't need EventKit, it goes here

**`RemindersCLI/main.swift`** — EventKit and AppKit only
- Argument parsing and command dispatch
- EventKit calls (fetch, save, delete)
- Thin conversion wrappers (e.g. `toEKRule(_ spec: RecurrenceSpec)`)
- `NSWorkspace` for launching apps

The rule: if you find yourself wanting to test something that lives in `main.swift`, that's a sign it should be moved to `RemindersLib`.

## Interface design: no flags

The tool uses positional arguments and natural language keywords — not flags.

**Correct:**
```
reminders create "Pay rent" march 1 repeat monthly
reminders edit "Buy groceries" "Daily Life" friday repeat weekly
```

**Avoid:**
```
reminders create "Pay rent" --date "march 1" --repeat monthly   # don't do this
```

The one exception is `--title` in the `edit` command. It's necessary because there's no unambiguous way to distinguish the existing title (used to find the reminder) from a new title (what to rename it to) positionally.

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
- Tests live in `Tests/RemindersLibTests/main.swift` — a custom runner, no XCTest or Xcode required
- Run with `reminders test`
- New parsing behaviour → new test suite. Cover: typical inputs, edge cases, invalid/nil inputs
- Test descriptions should read as plain English sentences (they appear verbatim in output)

## Output conventions

Commands confirm what they did. Format:

| Command | Output |
|---------|--------|
| `create` | `Created: <title> (in <list>)[ due <date>][ repeat <freq>]` |
| `edit` | `Updated "<title>": <change>, <change>` |
| `complete` | `Completed: <title>` |
| `delete` | `Deleted: <title>` |

Errors go to stderr via `fail()`, which exits non-zero. No silent failures.

## Adding a new command

1. Add the case to the `switch cmd` block in `main.swift`
2. Add it to `usage()`
3. Add it to the command table in `README.md` and `CLAUDE.md`
4. If the command introduces new parsing logic, add it to `RemindersLib` with tests

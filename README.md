# reminders-cli

A fast command-line interface for Apple Reminders, built with Swift and EventKit.

Unlike AppleScript-based approaches, this tool talks to Reminders via the native EventKit framework — keeping the app responsive and commands fast (~0.05–0.35s).

## Commands

```
reminders open                                    # Open the Reminders app
reminders lists                                   # Show all reminder lists
reminders list [list-name]                        # List incomplete reminders
reminders create <title> [list] [date]            # Create a reminder
reminders edit <title> [list] [date] [--title T]  # Edit due date, repeat, or title
reminders complete <title> [list]                 # Mark a reminder complete
reminders delete <title> [list]                   # Delete a reminder
```

## Due dates and repeats

The title must always be quoted (it's the first argument). Everything after that — list name, date, and repeat — can be typed naturally with or without quotes.

```
reminders create "Call dentist" tomorrow
reminders create "Submit report" Reminders friday
reminders create "Team meeting" Work "tuesday at 2pm"
reminders create "Pay rent" "march 1"
reminders create "Follow up" "2026-04-10"
```

If no time is given, defaults to 9:00 AM. If a date has already passed this year, it rolls to next year.

### Repeating reminders

Include the word `repeat` (also `repeats`, `repeating`, or `repeated`) anywhere in the date — it acts as a separator between the date and the recurrence. Both of these are equivalent:

```
reminders create "Take vitamins" repeat daily
reminders create "Take vitamins" "repeat daily"
```

The repeat word can come before or after the date:

```
reminders create "Team standup" Work monday 9am repeat weekly
reminders create "Pay rent" march 1 repeats monthly
reminders create "Book club" repeating last tuesday
reminders create "Gym" repeat every 2 days
reminders create "Monthly review" repeat first friday
```

Repeat formats:

| Format | Example |
|--------|---------|
| Simple | `daily`, `weekly`, `monthly`, `yearly`, `annually` |
| Natural | `every day`, `every week`, `every month`, `every year` |
| Interval | `every 2 weeks`, `every 3 months`, `every 6 days` |
| Ordinal weekday | `first monday`, `last tuesday`, `second friday`, `third wednesday`, `fourth sunday` |

Ordinal rules repeat on that weekday each month (e.g. "last tuesday" = last Tuesday of every month).

## Setup

Requires macOS 14+ with Swift installed (comes with Xcode command line tools).

```bash
git clone git@github.com:kscott/reminders-cli.git ~/dev/reminders-cli
~/dev/reminders-cli/reminders setup
```

`setup` builds the Swift package, installs the binary to `~/bin/reminders-bin`, and symlinks `~/bin/reminders` to the wrapper script. Make sure `~/bin` is in your `$PATH`.

On first run, macOS will prompt you to grant Reminders access.

## Project structure

```
reminders-cli/
├── Package.swift                        # Swift Package Manager manifest
├── reminders                            # Wrapper script (symlinked into ~/bin)
├── Sources/
│   ├── RemindersLib/
│   │   ├── DateParsing.swift            # Date parsing logic (no Apple framework deps)
│   │   └── RecurrenceParsing.swift      # Recurrence parsing logic (no Apple framework deps)
│   └── RemindersCLI/
│       └── main.swift                   # CLI entry point (EventKit + AppKit)
└── Tests/
    └── RemindersLibTests/
        └── main.swift                   # Test runner (no Xcode required)
```

`RemindersLib` is kept separate from the EventKit code so it can be unit tested without permissions or framework dependencies.

## Tests

```bash
reminders test
```

Builds and runs the test suite against the date and recurrence parsing logic. No Xcode required.

## Editing reminders

`edit` finds a reminder by title and updates only the fields you specify — everything else is left as-is.

**Find the exact title first:**
```bash
reminders list "Daily Life"
```

**Add or change a due date:**
```bash
reminders edit "Buy groceries" "Daily Life" friday
reminders edit "Buy groceries" "Daily Life" "friday at 5pm"
```

**Add or change a repeat:**
```bash
reminders edit "Buy groceries" "Daily Life" repeat weekly
reminders edit "Pay rent" "Daily Life" repeat monthly
reminders edit "Book club" "Daily Life" repeat "last tuesday"
```

**Set both at once:**
```bash
reminders edit "Buy groceries" "Daily Life" friday repeat weekly
reminders edit "Pay rent" "Daily Life" "march 1 repeat monthly"
```

**Rename a reminder:**
```bash
reminders edit "Buy groceries" "Daily Life" --title "Buy groceries and wine"
```

**Rename and update in one go:**
```bash
reminders edit "Buy groceries" "Daily Life" friday --title "Weekly shopping"
```

The list name is optional — if you leave it out, it searches all lists. Include it to be precise or if the same title appears in multiple lists.

## Known limitations

- **Sections** within a list are not exposed by the EventKit API — reminders appear flat
- **Sub-tasks** similarly have no parent-child relationship in the public API
- `complete` and `delete` match by title against incomplete reminders (first match wins)

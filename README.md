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

The title must always be quoted (it's the first argument). Everything after that — list name, date, and options — can be typed naturally with or without quotes.

```
reminders create "Call dentist" tomorrow
reminders create "Submit report" Reminders friday
reminders create "Team meeting" Work "tuesday at 2pm"
reminders create "Pay rent" "march 1"
reminders create "Follow up" "2026-04-10"
```

If no time is given, defaults to 9:00 AM. If a date has already passed this year, it rolls to next year.

## Optional fields

After the title (and optional list name and date), you can add any of these keywords in any order:

| Keyword | Values | Example |
|---------|--------|---------|
| `repeat` | see below | `repeat weekly` |
| `priority` | `high`, `medium`, `low`, `none` | `priority high` |
| `url` | any URL | `url https://example.com` |
| `note` | free text to end of line | `note call before 5pm` |

**`note` must always come last** — everything after it is treated as note text, including words that would otherwise be recognised as keywords. This means you can write freely without worrying about escaping.

```
reminders create "Pay rent" march 1 priority high note pay via bank transfer
reminders create "Call dentist" friday priority medium url https://dentist.com note ask about cleaning cost
reminders create "Take vitamins" repeat daily priority low note take with breakfast
reminders create "Review contract" tomorrow url https://docs.example.com priority high note sign by EOD, check clause 4
```

Fields without a date:
```
reminders create "Buy milk" priority low
reminders create "Read article" url https://example.com note save for weekend
```

### Repeating reminders

Use the word `repeat` (also `repeats`, `repeating`, or `repeated`) — it can appear before or after the date:

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
| Ordinal weekday | `first monday`, `last tuesday`, `2nd friday`, `3rd wednesday`, `4th thursday` |
| Day of month | `the 1st`, `on the 15th`, `2nd of the month`, `on the 22nd` |

Ordinal weekday rules repeat on that weekday each month. Leading words like "the" and "on the" are ignored, so `the last wednesday` and `on the first friday` both work naturally.

Day-of-month rules repeat on a fixed date each month — useful for things like bills or payroll.

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

**Add priority, note, or URL:**
```bash
reminders edit "Pay rent" "Daily Life" priority high
reminders edit "Call dentist" url https://dentist.com note ask about X-rays
reminders edit "Buy groceries" friday repeat weekly priority medium note check the fridge first
```

**Set multiple fields at once:**
```bash
reminders edit "Pay rent" "Daily Life" march 1 repeat monthly priority high note pay via bank
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

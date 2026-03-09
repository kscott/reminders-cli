# reminders-cli

A fast command-line interface for Apple Reminders, built with Swift and EventKit.

Unlike AppleScript-based approaches, this tool talks to Reminders via the native EventKit framework — keeping the app responsive and commands fast (~0.05–0.35s).

## Commands

```
reminders open                                                     # Open the Reminders app
reminders lists                                                    # Show all reminder lists
reminders list [list-name] [by due|priority|title|created]         # List incomplete reminders
reminders show <title> [list]                                      # Show full detail of a reminder
reminders create <title> [list] [date]                             # Create a reminder
reminders edit <title> [list] [date] [--title T]                   # Edit fields
reminders complete <title> [list]                                  # Mark complete (case-insensitive)
reminders delete <title> [list]                                    # Delete (case-insensitive)
```

## Due dates and repeats

The title must always be quoted (it's the first argument). Everything after that — list name, date, and options — can be typed naturally with or without quotes.

```
reminders create "Call dentist" tomorrow
reminders create "Submit report" Reminders friday
reminders create "Team meeting" Work "tuesday at 2pm"
reminders create "Pay rent" "march 1"
reminders create "Follow up" "2026-04-10"
reminders create "Weekly review" "next friday"
```

`next` and `this` are ignored before weekday names — `next friday` and `friday` mean the same thing. If no time is given, the reminder is date-only (no alarm time). If a date has already passed this year, it rolls to next year.

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

## Listing reminders

`list` shows incomplete reminders with metadata — due date, repeat status, priority, and note/url indicators:

```
--- Daily Life ---
  Pay rent          Mar 1, 2026  ·  repeating  ·  high
  Buy groceries     Fri, Mar 6, 2026
  Take vitamins     repeating  ·  low  ·  + note
```

Sort order (default is by due date, soonest first):
```
reminders list                           # all lists, by due date
reminders list "Daily Life" by priority  # single list, high priority first
reminders list by title                  # all lists, alphabetical
reminders list Work by created           # oldest added first
```

Title matching in `complete`, `delete`, and `edit` is case-insensitive — "buy groceries" finds "Buy Groceries".

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

**Clear a field with `none`:**
```bash
reminders edit "Pay rent" due none       # remove due date
reminders edit "Pay rent" repeat none    # remove recurrence
reminders edit "Pay rent" note none      # clear note
reminders edit "Pay rent" url none       # clear URL
reminders edit "Pay rent" priority none  # clear priority
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

## Using with Claude

Claude can manage your reminders conversationally — just describe what you want and it will translate that into the right command.

### Creating reminders

Tell Claude naturally:

> "Remind me to call the dentist on Friday"
> "Add a reminder to pay rent on the 1st of every month, high priority"
> "I need to follow up with Sarah next Tuesday at 2pm — put it in Work"
> "Remind me to take vitamins every morning"
> "Set a reminder for the team meeting every Monday at 9am in Work, repeat weekly"

Claude will pick the right list, parse the date, and set repeat and priority as needed.

### Editing reminders

> "Move the dentist reminder to next week"
> "Change the team meeting to Thursdays"
> "Add a note to the rent reminder — pay via bank transfer"
> "Make the grocery reminder high priority"
> "Rename 'Buy milk' to 'Weekly groceries'"
> "Remove the due date from the book club reminder"

Claude will run `reminders list` first if it needs to find the exact title.

### Completing and deleting

> "Mark the dentist reminder done"
> "I paid rent, check that off"
> "Delete the 'Follow up with Sarah' reminder"

### Listing and reviewing

> "What reminders do I have this week?"
> "Show me everything in my Work list by priority"
> "What's due today?"
> "Show me the details of the rent reminder"

### Tips for best results

- **List names** — mention the list if you have reminders with similar titles in multiple lists ("put it in Work", "add it to Daily Life")
- **Repeat reminders** — just say "every week", "monthly", "every other Tuesday" — Claude knows the formats
- **Time vs. date-only** — if you want an alarm, include a time ("Friday at 3pm"); if you just want a date with no notification, leave the time out
- **Clearing fields** — say "remove the due date" or "clear the note" and Claude will use the `none` keyword

## Known limitations

- **Sections** within a list are not exposed by the EventKit API — reminders appear flat
- **Sub-tasks** similarly have no parent-child relationship in the public API
- `complete` and `delete` match by title against incomplete reminders (first match wins)

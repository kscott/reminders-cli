# reminders-cli

A command-line tool that lets Claude create, manage, and query your Apple Reminders — just by asking.

Instead of switching to the Reminders app, you tell Claude what you need and it handles it. The tool connects directly to Apple's native Reminders framework, so your existing lists, reminders, and sync all work exactly as before.

## Using with Claude

This is the main use case. Tell Claude what you want in plain language:

> "Remind me to call the dentist on Friday"
> "Add a reminder to pay rent on the 1st of every month, high priority"
> "I need to follow up with Sarah next Tuesday at 2pm — put it in Work"
> "Move the dentist reminder to next week"
> "What reminders do I have this week?"
> "Mark the dentist reminder done"

Claude translates your words into the right commands, picks the correct list, parses dates and times, and sets priority or recurrence as needed.

### Tips for best results

- **Mention the list** if you have similar reminders in multiple places ("put it in Work", "add it to Daily Life")
- **Include a time** if you want an alarm ("Friday at 3pm") — date-only reminders have no notification
- **Repeat reminders** — just say "every week", "monthly", "every other Tuesday" and Claude knows what to do
- **Clearing fields** — "remove the due date" or "clear the note" works naturally

## Setup

### Requirements

- **macOS 14 (Sonoma) or later**
- **Xcode Command Line Tools** — provides Swift and the build toolchain. Install by running this in Terminal:

  ```bash
  xcode-select --install
  ```

  Or download directly from [developer.apple.com/download/all](https://developer.apple.com/download/all/) (search "Command Line Tools").

- **`~/bin` in your `$PATH`** — the installer puts the binary there. If `reminders` isn't found after install, add this line to your `~/.zshrc`:

  ```bash
  export PATH="$HOME/bin:$PATH"
  ```

  Then open a new Terminal window.

### Install

```bash
git clone https://github.com/kscott/reminders-cli.git ~/dev/reminders-cli
~/dev/reminders-cli/reminders setup
```

`setup` builds the tool and installs it to `~/bin/reminders`. The `~/dev/reminders-cli` location is just a suggestion — clone it wherever you like.

On first run, macOS will prompt you to grant Reminders access.

## Command reference

For direct use or scripting — Claude handles all of this automatically when you ask conversationally.

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

### Date formats

The title must always be quoted. Everything after — list name, date, options — can be typed naturally:

```
reminders create "Call dentist" tomorrow
reminders create "Team meeting" Work "tuesday at 2pm"
reminders create "Pay rent" "march 1"
reminders create "Weekly review" "next friday"
```

If no time is given, the reminder is date-only (no alarm). Dates that have passed this year roll to next year.

### Optional fields

| Keyword | Values | Example |
|---------|--------|---------|
| `repeat` | see below | `repeat weekly` |
| `priority` | `high`, `medium`, `low`, `none` | `priority high` |
| `url` | any URL | `url https://example.com` |
| `note` | free text to end of line | `note call before 5pm` |

**`note` must always come last** — everything after it is treated as note text.

```
reminders create "Pay rent" march 1 priority high note pay via bank transfer
reminders create "Take vitamins" repeat daily priority low note take with breakfast
```

### Repeating reminders

Use the word `repeat` (or `repeats`, `repeating`, `repeated`) before or after the date:

| Format | Example |
|--------|---------|
| Simple | `daily`, `weekly`, `monthly`, `yearly` |
| Natural | `every day`, `every week`, `every month` |
| Interval | `every 2 weeks`, `every 3 months` |
| Ordinal weekday | `first monday`, `last tuesday`, `2nd friday` |
| Day of month | `the 1st`, `on the 15th`, `the 22nd` |

### Listing reminders

```
reminders list                           # all lists, by due date
reminders list "Daily Life" by priority  # single list, high priority first
reminders list Work by created           # oldest added first
```

### Editing reminders

`edit` updates only the fields you specify — everything else is left as-is:

```bash
reminders edit "Buy groceries" friday repeat weekly priority medium
reminders edit "Pay rent" "Daily Life" march 1 repeat monthly priority high
reminders edit "Pay rent" due none        # remove due date
reminders edit "Pay rent" repeat none     # remove recurrence
reminders edit "Buy groceries" --title "Weekly shopping"
```

## Known limitations

- **Sections** within a list are not exposed by Apple's API — reminders appear flat
- **Sub-tasks** have no parent-child relationship in the public API
- `complete` and `delete` match by title against incomplete reminders (first match wins)

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

## Tests

```bash
reminders test
```

Builds and runs the test suite against the date and recurrence parsing logic. No Xcode required.

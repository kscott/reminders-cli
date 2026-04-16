> **This repository has been archived.** This tool has been merged into [kscott/get-clear](https://github.com/kscott/get-clear). Issues, history, and active development have moved there.

---

# reminders-cli

A command-line tool that lets Claude create, manage, and query your Apple Reminders — just by asking.

Instead of switching to the Reminders app, you tell Claude what you need and it handles it. The tool connects directly to Apple's native Reminders framework, so your existing lists, reminders, and sync all work exactly as before.

Part of the [Get Clear](https://github.com/kscott/get-clear) suite.

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
- **Repeat reminders** — just say "every week", "monthly", "last tuesday" and Claude knows what to do
- **Clearing fields** — "remove the due date" or "clear the note" works naturally

## Setup

### Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon Mac (arm64) for the pre-built binary; Intel Macs must build from source

### Install

Install the full Get Clear suite via the PKG installer — download from the [latest release](https://github.com/kscott/get-clear/releases/latest) and run it.

This installs all five tools to `/usr/local/bin`. Make sure that's in your `$PATH`:

```bash
export PATH="/usr/local/bin:$PATH"   # add to ~/.zshrc
```

On first run, macOS will prompt you to grant Reminders access.

### Build from source

```bash
xcode-select --install   # if not already installed
git clone https://github.com/kscott/reminders-cli.git ~/dev/reminders-cli
cd ~/dev/reminders-cli
swift build -c release
cp .build/release/reminders-bin /usr/local/bin/reminders
```

## Command reference

```
reminders                                                          # Show help
reminders --version                                                # Show version
reminders open                                                     # Open the Reminders app
reminders lists                                                    # Show all reminder lists
reminders list [name] [by due|priority|title|created]              # List incomplete reminders
reminders find <query>                                             # Find reminders by title or note
reminders show <title>                                             # Show full detail of a reminder
reminders add <title> [list] [options]                             # Add a reminder
reminders change <title> [list] [options]                          # Change fields on a reminder
reminders rename <title> <new-title>                               # Rename a reminder
reminders done <title>                                             # Mark complete
reminders remove <title>                                           # Remove a reminder
```

### Date formats

```
reminders add "Call dentist" tomorrow
reminders add "Team meeting" Work "tuesday at 2pm"
reminders add "Pay rent" "march 1"
reminders add "Weekly review" "next friday"
reminders add "Submit report" "2026-04-15 at 9am"
```

If no time is given, the reminder is date-only (no alarm). Dates that have passed this year roll to next year.

### Optional fields

| Keyword | Values | Example |
|---------|--------|---------|
| `repeat` | see below | `repeat weekly` |
| `priority` | `high`, `medium`, `low`, `none` | `priority high` |
| `url` | any URL | `url https://example.com` |
| `note` | free text to end of line | `note call before 5pm` |
| `list` | list name | `list Work` |

**`note` must always come last** — everything after it is treated as note text.

```
reminders add "Pay rent" march 1 priority high note pay via bank transfer
reminders add "Take vitamins" repeat daily priority low note take with breakfast
```

### Repeating reminders

Use `repeat` (or `repeats`, `repeating`, `repeated`) before or after the date:

| Format | Example |
|--------|---------|
| Simple | `daily`, `weekly`, `monthly`, `yearly` |
| Natural | `every day`, `every week`, `every month` |
| Interval | `every 2 weeks`, `every 3 months` |
| Ordinal weekday | `first monday`, `last tuesday`, `2nd friday` |
| Day of month | `the 1st`, `on the 15th`, `the 22nd` |

### Listing and sorting

```
reminders list                           # all lists, sorted by due date
reminders list "Daily Life" by priority  # single list, high priority first
reminders list Work by created           # oldest added first
```

### Changing reminders

`change` updates only the fields you specify — everything else is left as-is:

```bash
reminders change "Buy groceries" friday repeat weekly priority medium
reminders change "Pay rent" march 1 repeat monthly priority high
reminders change "Pay rent" due none        # remove due date
reminders change "Pay rent" repeat none     # remove recurrence
reminders rename "Buy groceries" "Weekly shopping"
```

## Known limitations

- **Sections** within a list are not exposed by Apple's API — reminders appear flat
- **Sub-tasks** have no parent-child relationship in the public API
- Moving a reminder between lists is not yet supported — workaround: `remove` then `add`
- `done` and `remove` require an exact (case-insensitive) title match

## Project structure

```
reminders-cli/
├── Package.swift
├── Sources/
│   ├── RemindersLib/                    # Pure Swift — no framework deps, fully testable
│   │   ├── RecurrenceParsing.swift      # Parses recurrence strings into RecurrenceSpec
│   │   └── OptionsParsing.swift         # Parses combined options strings into fields
│   └── RemindersCLI/
│       └── main.swift                   # CLI entry point (EventKit + AppKit)
└── Tests/
    └── RemindersLibTests/               # Quick + Nimble test suite
        ├── DateParserSpec.swift
        ├── RecurrenceParsingSpec.swift
        └── OptionsParsingSpec.swift
```

## Tests

```bash
swift test
```

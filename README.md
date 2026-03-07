# reminders-cli

A fast command-line interface for Apple Reminders, built with Swift and EventKit.

Unlike AppleScript-based approaches, this tool talks to Reminders via the native EventKit framework — keeping the app responsive and commands fast (~0.05–0.35s).

## Commands

```
reminders open                               # Open the Reminders app
reminders lists                              # Show all reminder lists
reminders list [list-name]                   # List incomplete reminders
reminders create <title> [list] [due date]   # Create a reminder (default: iCloud default list)
reminders complete <title> [list]            # Mark a reminder complete
reminders delete <title> [list]              # Delete a reminder
```

## Due date formats

```
reminders create "Call dentist" tomorrow
reminders create "Submit report" "Reminders" friday
reminders create "Team meeting" Work "tuesday at 2pm"
reminders create "Pay rent" "march 1"
reminders create "Follow up" "2026-04-10"
```

If no time is given, defaults to 9:00 AM. If a date has already passed this year, it rolls to next year.

## Setup

Requires macOS 14+ with Swift installed (comes with Xcode command line tools).

```bash
# Clone and set up
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
│   │   └── DateParsing.swift            # Date parsing logic (no Apple framework deps)
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

Builds and runs the test suite against the date parsing logic. No Xcode required.

## Known limitations

- **Sections** within a list are not exposed by the EventKit API — reminders appear flat
- **Sub-tasks** similarly have no parent-child relationship in the public API
- `complete` and `delete` match by title against incomplete reminders (first match wins)

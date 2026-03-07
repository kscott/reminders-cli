// reminders-bin.swift
//
// A fast CLI for Apple Reminders using EventKit directly, avoiding AppleScript
// which is slow and blocks the Reminders app UI during execution.
//
// USAGE:
//   reminders lists                              # Show all reminder lists
//   reminders list [list-name]                   # List incomplete reminders
//   reminders create <title> [list] [due date]   # Create a reminder (default list: Reminders)
//   reminders complete <title> [list]            # Mark a reminder complete
//   reminders delete <title> [list]              # Delete a reminder
//
// DUE DATE FORMATS (for `create`):
//   Natural day:  "today", "tomorrow", "friday", "march 15"
//   Numeric date: "2026-03-10", "3/10", "3-10"
//   Time only:    "3pm", "14:30"  (defaults to today)
//   Combined:     "tomorrow 3pm", "friday at 5pm", "march 15 9am"
//   If no time is given, defaults to 9:00 AM.
//   If a month/date has already passed this year, it rolls to next year.
//
// KNOWN LIMITATIONS:
//   - Sections within a list are not exposed by EventKit; all reminders appear flat.
//   - Sub-tasks (child reminders) have no parent-child relationship in the public
//     EventKit API, so they also appear flat alongside top-level reminders.
//   - `complete` and `delete` only match incomplete reminders by title (first match wins).
//
// COMPILING:
//   swiftc ~/dev/reminders-bin.swift -o ~/bin/reminders-bin
//
// The compiled binary is invoked via ~/bin/reminders, which is a thin shell wrapper:
//   #!/bin/bash
//   exec reminders-bin "$@"
//
// On a new machine: grant Reminders access when prompted on first run, then it's fast
// (~0.05-0.35s per command) because EventKit caches data locally from iCloud.

import Foundation
import AppKit
import EventKit

let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
let args = Array(CommandLine.arguments.dropFirst())

func fail(_ msg: String) -> Never {
    fputs("Error: \(msg)\n", stderr)
    exit(1)
}

func usage() -> Never {
    print("""
    Usage:
      reminders open                               # Open the Reminders app
      reminders lists                              # Show all reminder lists
      reminders list [list-name]                   # List incomplete reminders
      reminders create <title> [list] [due date]   # Create a reminder (default list: Reminders)
      reminders complete <title> [list]            # Mark a reminder complete
      reminders delete <title> [list]              # Delete a reminder

    Due date examples:
      "tomorrow", "friday", "march 15", "2026-03-10", "3pm", "tomorrow 3pm", "friday at 5pm"
    """)
    exit(0)
}

// MARK: - Date parsing
//
// Splits the input into a day part and a time part, parses each independently,
// then merges into a single DateComponents. Defaults: today, 9:00 AM.

func parseDate(_ input: String) -> Date? {
    let s = input.lowercased().trimmingCharacters(in: .whitespaces)
    let cal = Calendar.current
    let now = Date()
    var components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
    components.hour = 9
    components.minute = 0

    // Patterns that match a time expression at the end of the string
    let timePatterns = [
        #"(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#,
        #"(?:at\s+)?(\d{1,2}):(\d{2})$"#
    ]

    var dayPart = s
    var timePart: String? = nil

    for pattern in timePatterns {
        if let range = s.range(of: pattern, options: .regularExpression) {
            timePart = String(s[range])
            dayPart = s.replacingCharacters(in: range, with: "").trimmingCharacters(in: .init(charactersIn: " ,at"))
            break
        }
    }

    // Parse time component
    if let timePart {
        let tp = timePart.replacingOccurrences(of: "at ", with: "")
        if let hourRange = tp.range(of: #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#, options: .regularExpression) {
            let hourStr = String(tp[hourRange])
            let numRegex = try! NSRegularExpression(pattern: #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#)
            if let match = numRegex.firstMatch(in: hourStr, range: NSRange(hourStr.startIndex..., in: hourStr)) {
                let hour = Int((hourStr as NSString).substring(with: match.range(at: 1))) ?? 9
                let minute = match.range(at: 2).location != NSNotFound
                    ? Int((hourStr as NSString).substring(with: match.range(at: 2))) ?? 0 : 0
                let ampm = match.range(at: 3).location != NSNotFound
                    ? (hourStr as NSString).substring(with: match.range(at: 3)) : ""
                components.hour = ampm == "pm" && hour < 12 ? hour + 12 :
                                  ampm == "am" && hour == 12 ? 0 : hour
                components.minute = minute
            }
        }
    }

    // Parse day component
    let weekdays = ["sunday":1,"monday":2,"tuesday":3,"wednesday":4,"thursday":5,"friday":6,"saturday":7]
    let months = ["january":1,"february":2,"march":3,"april":4,"may":5,"june":6,
                  "july":7,"august":8,"september":9,"october":10,"november":11,"december":12]

    let dayTrimmed = dayPart.trimmingCharacters(in: .whitespaces)

    if dayTrimmed.isEmpty || dayTrimmed == "today" {
        // keep today's date components
    } else if dayTrimmed == "tomorrow" {
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        let tc = cal.dateComponents([.year, .month, .day], from: tomorrow)
        components.year = tc.year; components.month = tc.month; components.day = tc.day
    } else if let weekdayNum = weekdays[dayTrimmed] {
        // Next future occurrence of the named weekday
        var dc = DateComponents(); dc.weekday = weekdayNum
        if let next = cal.nextDate(after: now, matching: dc, matchingPolicy: .nextTime) {
            let nc = cal.dateComponents([.year, .month, .day], from: next)
            components.year = nc.year; components.month = nc.month; components.day = nc.day
        }
    } else {
        let parts = dayTrimmed.split(separator: " ").map(String.init)
        if parts.count == 2, let monthNum = months[parts[0]], let day = Int(parts[1]) {
            // "march 15" — rolls to next year if already past
            components.month = monthNum; components.day = day
            if let d = cal.date(from: components), d < now {
                components.year = (components.year ?? 0) + 1
            }
        } else if parts.count == 1 {
            // Numeric formats: "2026-03-15", "3/15", "3-15"
            let numParts = parts[0].components(separatedBy: CharacterSet(charactersIn: "/-"))
            if numParts.count == 3, let y = Int(numParts[0]), let m = Int(numParts[1]), let d = Int(numParts[2]) {
                components.year = y; components.month = m; components.day = d
            } else if numParts.count == 2, let m = Int(numParts[0]), let d = Int(numParts[1]) {
                components.month = m; components.day = d
                if let date = cal.date(from: components), date < now {
                    components.year = (components.year ?? 0) + 1
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    return cal.date(from: components)
}

func formatDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f.string(from: date)
}

// MARK: - Main

guard let cmd = args.first else { usage() }

store.requestFullAccessToReminders { granted, _ in
    guard granted else { fail("Reminders access denied") }

    switch cmd {

    case "open":
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
        semaphore.signal()

    case "lists":
        let names = store.calendars(for: .reminder).map { $0.title }.sorted()
        print(names.joined(separator: "\n"))
        semaphore.signal()

    case "list":
        let filterList = args.count > 1 ? args[1] : nil
        let calendars: [EKCalendar]
        if let filterList {
            guard let cal = store.calendars(for: .reminder).first(where: { $0.title == filterList }) else {
                fail("List not found: \(filterList)")
            }
            calendars = [cal]
        } else {
            calendars = store.calendars(for: .reminder)
        }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)
        store.fetchReminders(matching: predicate) { reminders in
            let sorted = (reminders ?? []).sorted { $0.calendar.title < $1.calendar.title }
            if filterList != nil {
                for r in sorted { print(r.title ?? "") }
            } else {
                var currentList = ""
                for r in sorted {
                    if r.calendar.title != currentList {
                        currentList = r.calendar.title
                        print("--- \(currentList) ---")
                    }
                    print("  \(r.title ?? "")")
                }
            }
            semaphore.signal()
        }

    case "create":
        // Args: create <title> [list] [due date]
        // List detection: if the first extra arg matches a known list name, treat it as the list.
        // Everything after (or all extra args if no list match) is parsed as a due date string.
        guard args.count > 1 else { fail("provide a reminder title") }
        let title = args[1]
        var listName = "Reminders"
        var dueDate: Date? = nil

        if args.count > 2 {
            let remaining = Array(args.dropFirst(2))
            let knownLists = store.calendars(for: .reminder).map { $0.title }
            if knownLists.contains(remaining[0]) {
                listName = remaining[0]
                if remaining.count > 1 {
                    dueDate = parseDate(remaining.dropFirst().joined(separator: " "))
                }
            } else {
                dueDate = parseDate(remaining.joined(separator: " "))
            }
        }

        let defaultCal = store.defaultCalendarForNewReminders()
        guard let cal = store.calendars(for: .reminder).first(where: { $0.title == listName })
                     ?? defaultCal else {
            fail("List not found: \(listName)")
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = cal
        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: dueDate)
        }
        do {
            try store.save(reminder, commit: true)
            let dateStr = dueDate.map { " due \(formatDate($0))" } ?? ""
            print("Created: \(title) (in \(cal.title))\(dateStr)")
        } catch {
            fail("Could not save reminder: \(error.localizedDescription)")
        }
        semaphore.signal()

    case "complete", "delete":
        guard args.count > 1 else { fail("provide a reminder title") }
        let title = args[1]
        let listName = args.count > 2 ? args[2] : nil
        let calendars: [EKCalendar]
        if let listName {
            guard let cal = store.calendars(for: .reminder).first(where: { $0.title == listName }) else {
                fail("List not found: \(listName)")
            }
            calendars = [cal]
        } else {
            calendars = store.calendars(for: .reminder)
        }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)
        store.fetchReminders(matching: predicate) { reminders in
            guard let reminder = (reminders ?? []).first(where: { $0.title == title }) else {
                fail("Not found: \(title)\(listName.map { " in \($0)" } ?? "")")
            }
            do {
                if cmd == "complete" {
                    reminder.isCompleted = true
                    try store.save(reminder, commit: true)
                    print("Completed: \(title)")
                } else {
                    try store.remove(reminder, commit: true)
                    print("Deleted: \(title)")
                }
            } catch {
                fail("Operation failed: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

    default:
        usage()
    }
}

semaphore.wait()

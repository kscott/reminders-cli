// main.swift
//
// Entry point for the reminders-bin executable.
// Handles argument parsing and all EventKit/AppKit interactions.
// Date parsing is delegated to RemindersLib so it can be unit tested independently.

import Foundation
import AppKit
import EventKit
import RemindersLib

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
      reminders create <title> [list] [due date]   # Create a reminder (default: iCloud default list)
      reminders complete <title> [list]            # Mark a reminder complete
      reminders delete <title> [list]              # Delete a reminder

    Due date examples:
      "tomorrow", "friday", "march 15", "2026-03-10", "3pm", "tomorrow 3pm", "friday at 5pm"
    """)
    exit(0)
}

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
        var listName: String? = nil
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
        guard let cal = listName.flatMap({ name in store.calendars(for: .reminder).first(where: { $0.title == name }) })
                     ?? defaultCal else {
            fail("List not found: \(listName ?? "default")")
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

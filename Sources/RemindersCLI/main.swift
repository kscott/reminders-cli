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
      reminders open                                    # Open the Reminders app
      reminders lists                                   # Show all reminder lists
      reminders list [list-name]                        # List incomplete reminders
      reminders create <title> [list] [date]            # Create a reminder
      reminders edit <title> [list] [date] [--title T]  # Edit due date, repeat, or title
      reminders complete <title> [list]                 # Mark a reminder complete
      reminders delete <title> [list]                   # Delete a reminder

    Date examples:
      tomorrow, friday, "march 15", "2026-03-10", 3pm, "tomorrow 3pm", "friday at 5pm"

    Repeat — use the word "repeat" in the date portion:
      reminders create "Take vitamins" repeat daily
      reminders create "Team standup" Work monday 9am repeat weekly
      reminders edit "Pay rent" "Daily Life" repeat monthly
    """)
    exit(0)
}

func toEKRule(_ spec: RecurrenceSpec) -> EKRecurrenceRule {
    let ekFreqs: [RecurrenceFrequency: EKRecurrenceFrequency] =
        [.daily:.daily, .weekly:.weekly, .monthly:.monthly, .yearly:.yearly]
    if let ow = spec.ordinalWeekday {
        let dow = EKRecurrenceDayOfWeek(dayOfTheWeek: EKWeekday(rawValue: ow.weekday)!,
                                        weekNumber: ow.weekNumber)
        return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1,
                                daysOfTheWeek: [dow], daysOfTheMonth: nil,
                                monthsOfTheYear: nil, weeksOfTheYear: nil,
                                daysOfTheYear: nil, setPositions: nil, end: nil)
    }
    return EKRecurrenceRule(recurrenceWith: ekFreqs[spec.frequency]!, interval: spec.interval, end: nil)
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
        // Args: create <title> [list] [date [repeat freq]]
        // List detection: first extra arg matching a known list name is the list.
        // The remaining string is split on the word "repeat": left = due date, right = recurrence.
        guard args.count > 1 else { fail("provide a reminder title") }

        let title = args[1]
        var listName: String? = nil
        var dueDate: Date? = nil
        var recurrenceSpec: RecurrenceSpec? = nil

        if args.count > 2 {
            let remaining = Array(args.dropFirst(2))
            let knownLists = store.calendars(for: .reminder).map { $0.title }
            let rawString: String
            if knownLists.contains(remaining[0]) {
                listName = remaining[0]
                rawString = remaining.dropFirst().joined(separator: " ")
            } else {
                rawString = remaining.joined(separator: " ")
            }
            let (datePart, repeatPart) = splitOnRepeat(rawString)
            if !datePart.isEmpty  { dueDate        = parseDate(datePart) }
            if !repeatPart.isEmpty { recurrenceSpec = parseRecurrence(repeatPart) }
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
        if let spec = recurrenceSpec {
            reminder.addRecurrenceRule(toEKRule(spec))
        }
        do {
            try store.save(reminder, commit: true)
            let dateStr   = dueDate.map { " due \(formatDate($0))" } ?? ""
            let repeatStr = recurrenceSpec.map { " " + describeRecurrence($0) } ?? ""
            print("Created: \(title) (in \(cal.title))\(dateStr)\(repeatStr)")
        } catch {
            fail("Could not save reminder: \(error.localizedDescription)")
        }
        semaphore.signal()

    case "edit":
        // Args: edit <title> [list] [date] [--title "New Title"]
        // Only fields that are specified are updated; others are left as-is.
        guard args.count > 1 else { fail("provide a reminder title") }

        var editArgs = Array(args)
        var newTitle: String? = nil
        if let idx = editArgs.firstIndex(of: "--title"), idx + 1 < editArgs.count {
            newTitle = editArgs[idx + 1]
            editArgs.remove(at: idx + 1)
            editArgs.remove(at: idx)
        }

        let title = editArgs[1]
        var listName: String? = nil
        var newDateRepeat: String? = nil

        if editArgs.count > 2 {
            let remaining = Array(editArgs.dropFirst(2))
            let knownLists = store.calendars(for: .reminder).map { $0.title }
            if knownLists.contains(remaining[0]) {
                listName = remaining[0]
                if remaining.count > 1 { newDateRepeat = remaining.dropFirst().joined(separator: " ") }
            } else {
                newDateRepeat = remaining.joined(separator: " ")
            }
        }

        let editCalendars: [EKCalendar]
        if let listName {
            guard let cal = store.calendars(for: .reminder).first(where: { $0.title == listName }) else {
                fail("List not found: \(listName)")
            }
            editCalendars = [cal]
        } else {
            editCalendars = store.calendars(for: .reminder)
        }

        store.fetchReminders(matching: store.predicateForIncompleteReminders(
                withDueDateStarting: nil, ending: nil, calendars: editCalendars)) { reminders in
            guard let reminder = (reminders ?? []).first(where: { $0.title == title }) else {
                fail("Not found: \(title)\(listName.map { " in \($0)" } ?? "")")
            }

            var changes: [String] = []

            if let newTitle {
                reminder.title = newTitle
                changes.append("title → \"\(newTitle)\"")
            }

            if let str = newDateRepeat {
                let (datePart, repeatPart) = splitOnRepeat(str)
                if !datePart.isEmpty, let date = parseDate(datePart) {
                    reminder.dueDateComponents = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: date)
                    changes.append("due → \(formatDate(date))")
                }
                if !repeatPart.isEmpty, let spec = parseRecurrence(repeatPart) {
                    reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
                    reminder.addRecurrenceRule(toEKRule(spec))
                    changes.append(describeRecurrence(spec))
                }
            }

            guard !changes.isEmpty else { fail("nothing to change — specify a date, repeat, or --title") }

            do {
                try store.save(reminder, commit: true)
                print("Updated \"\(title)\": \(changes.joined(separator: ", "))")
            } catch {
                fail("Could not save: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

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

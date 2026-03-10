// main.swift
//
// Entry point for the reminders-bin executable.
// Handles argument parsing and all EventKit/AppKit interactions.
// Date parsing is delegated to RemindersLib so it can be unit tested independently.

import Foundation
import AppKit
import EventKit
import RemindersLib

let version = "1.0.0"

let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
let args = Array(CommandLine.arguments.dropFirst())

func fail(_ msg: String) -> Never {
    fputs("Error: \(msg)\n", stderr)
    exit(1)
}

func calendarDot(_ calendar: EKCalendar) -> String {
    guard ProcessInfo.processInfo.environment["NO_COLOR"] == nil else { return "  " }
    guard let cg = calendar.cgColor else { return "  " }
    let colorSpace = cg.colorSpace?.model
    let components = cg.components ?? []
    let r, g, b: Int
    if colorSpace == .rgb, components.count >= 3 {
        r = Int(components[0] * 255)
        g = Int(components[1] * 255)
        b = Int(components[2] * 255)
    } else if colorSpace == .monochrome, components.count >= 1 {
        let w = Int(components[0] * 255)
        r = w; g = w; b = w
    } else {
        return "  "
    }
    return "\u{001B}[38;2;\(r);\(g);\(b)m●\u{001B}[0m "
}

func usage() -> Never {
    print("""
    reminders \(version) — CLI for Apple Reminders

    Usage:
      reminders open                                 # Open the Reminders app
      reminders lists                                # Show all reminder lists
      reminders list [name] [by due|priority|title|created]
      reminders add <name> [list] [date]              # Add a reminder
      reminders change <name> [list] [field value]   # Change fields; use "none" to clear
      reminders rename <name> <new-name> [list]      # Rename a reminder
      reminders show <name> [list]                   # Show full detail of a reminder
      reminders done <name> [list]                   # Mark a reminder done
      reminders remove <name> [list]                 # Remove a reminder

    Date examples:
      tomorrow, friday, "next friday", "march 15", "2026-03-10", 3pm, "friday at 5pm"

    Optional fields (any order, note must be last):
      repeat daily / repeat weekly / repeat "last tuesday" / repeat "every 2 weeks"
      priority high / priority medium / priority low / priority none
      url https://example.com
      note your free text goes here to end of line

    Clear a field with change:
      due none / repeat none / note none / url none / priority none
    """)
    exit(0)
}

func parsePriority(_ s: String) -> Int? {
    switch s.lowercased().trimmingCharacters(in: .whitespaces) {
    case "high":          return 1
    case "medium", "med": return 5
    case "low":           return 9
    case "none":          return 0
    default:              return nil
    }
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
    if let day = spec.dayOfMonth {
        return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1,
                                daysOfTheWeek: nil, daysOfTheMonth: [NSNumber(value: day)],
                                monthsOfTheYear: nil, weeksOfTheYear: nil,
                                daysOfTheYear: nil, setPositions: nil, end: nil)
    }
    return EKRecurrenceRule(recurrenceWith: ekFreqs[spec.frequency]!, interval: spec.interval, end: nil)
}

guard let cmd = args.first else { usage() }
if cmd == "--version" || cmd == "-v" || cmd == "version" { print(version); exit(0) }
if cmd == "--help"    || cmd == "-h" || cmd == "help"    { usage() }

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
        // Parse: list [list-name] [by <field>]
        var listArgs = Array(args.dropFirst())
        var sortBy = "due"
        if let byIdx = listArgs.firstIndex(of: "by"), byIdx + 1 < listArgs.count {
            sortBy = listArgs[byIdx + 1].lowercased()
            listArgs.removeSubrange(byIdx...(byIdx + 1))
        }
        let filterList = listArgs.first

        let listCalendars: [EKCalendar]
        if let filterList {
            guard let cal = store.calendars(for: .reminder).first(where: { $0.title == filterList }) else {
                fail("List not found: \(filterList)")
            }
            listCalendars = [cal]
        } else {
            listCalendars = store.calendars(for: .reminder)
        }

        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: listCalendars)
        store.fetchReminders(matching: predicate) { reminders in
            let cal = Calendar.current

            func dueDate(of r: EKReminder) -> Date? {
                r.dueDateComponents.flatMap { cal.date(from: $0) }
            }
            func byDue(_ a: EKReminder, _ b: EKReminder) -> Bool {
                switch (dueDate(of: a), dueDate(of: b)) {
                case (nil, nil):         return (a.title ?? "") < (b.title ?? "")
                case (nil, _):           return false
                case (_, nil):           return true
                case (let da?, let db?): return da < db
                }
            }
            let sortFn: (EKReminder, EKReminder) -> Bool
            switch sortBy {
            case "priority":
                sortFn = { a, b in
                    let pa = a.priority == 0 ? 10 : a.priority
                    let pb = b.priority == 0 ? 10 : b.priority
                    return pa != pb ? pa < pb : byDue(a, b)
                }
            case "title":
                sortFn = { a, b in
                    (a.title ?? "").localizedCaseInsensitiveCompare(b.title ?? "") == .orderedAscending
                }
            case "created":
                sortFn = { a, b in
                    (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
                }
            default: // "due", "date"
                sortFn = byDue
            }

            func metaFor(_ r: EKReminder) -> String {
                var parts: [String] = []
                if let comps = r.dueDateComponents, let date = cal.date(from: comps) {
                    parts.append(formatDate(date, showTime: comps.hour != nil))
                }
                if r.hasRecurrenceRules { parts.append("repeating") }
                switch r.priority {
                case 1...4: parts.append("high")
                case 5:     parts.append("medium")
                case 6...9: parts.append("low")
                default:    break
                }
                if r.notes != nil { parts.append("+ note") }
                if r.url   != nil { parts.append("+ url") }
                return parts.isEmpty ? "" : "  ·  " + parts.joined(separator: " · ")
            }

            if filterList != nil {
                let sorted = (reminders ?? []).sorted(by: sortFn)
                for r in sorted { print("\(calendarDot(r.calendar))\(r.title ?? "")\(metaFor(r))") }
            } else {
                // Group by list, sort within each group
                let grouped = Dictionary(grouping: reminders ?? [], by: { $0.calendar.title })
                let listNames = grouped.keys.sorted()
                for listName in listNames {
                    let listCal = store.calendars(for: .reminder).first { $0.title == listName }
                    let dot = listCal.map { calendarDot($0) } ?? "  "
                    print("\(dot)--- \(listName) ---")
                    for r in (grouped[listName] ?? []).sorted(by: sortFn) {
                        print("\(calendarDot(r.calendar))\(r.title ?? "")\(metaFor(r))")
                    }
                }
            }
            semaphore.signal()
        }

    case "add":
        // Args: add <title> [list] [date [repeat freq]]
        // List detection: first extra arg matching a known list name is the list.
        // The remaining string is split on the word "repeat": left = due date, right = recurrence.
        guard args.count > 1 else { fail("provide a reminder title") }

        let title = args[1]
        var listName: String? = nil
        var parsedDate: ParsedDate? = nil
        var recurrenceSpec: RecurrenceSpec? = nil

        var opts = ParsedOptions()
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
            opts = parseOptions(rawString)
        }
        if !opts.date.isEmpty { parsedDate = parseDate(opts.date) }
        if !opts.recurrence.isEmpty {
            guard let spec = parseRecurrence(opts.recurrence) else {
                fail("Unrecognised repeat: \"\(opts.recurrence)\"")
            }
            recurrenceSpec = spec
        }

        let defaultCal = store.defaultCalendarForNewReminders()
        guard let cal = listName.flatMap({ name in store.calendars(for: .reminder).first(where: { $0.title == name }) })
                     ?? defaultCal else {
            fail("List not found: \(listName ?? "default")")
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = cal
        if let pd = parsedDate {
            let comps: Set<Calendar.Component> = pd.hasTime
                ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
            reminder.dueDateComponents = Calendar.current.dateComponents(comps, from: pd.date)
        }
        if let spec = recurrenceSpec            { reminder.addRecurrenceRule(toEKRule(spec)) }
        if let p = parsePriority(opts.priority) { reminder.priority = p }
        if !opts.note.isEmpty                   { reminder.notes = opts.note }
        if !opts.url.isEmpty, let u = URL(string: opts.url) { reminder.url = u }
        do {
            try store.save(reminder, commit: true)
            var parts = ["Added: \(title) (in \(cal.title))"]
            if let pd = parsedDate          { parts.append("due \(formatDate(pd.date, showTime: pd.hasTime))") }
            if let s = recurrenceSpec       { parts.append(describeRecurrence(s)) }
            if !opts.priority.isEmpty       { parts.append("priority \(opts.priority)") }
            if !opts.note.isEmpty           { parts.append("+ note") }
            if !opts.url.isEmpty            { parts.append("url \(opts.url)") }
            print(parts.joined(separator: " · "))
        } catch {
            fail("Could not save reminder: \(error.localizedDescription)")
        }
        semaphore.signal()

    case "change":
        // Args: change <title> [list] [date]
        // Only fields that are specified are updated; others are left as-is.
        guard args.count > 1 else { fail("provide a reminder title") }

        let editArgs = Array(args)
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
            guard let reminder = (reminders ?? []).first(where: {
                ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame
            }) else {
                fail("Not found: \(title)\(listName.map { " in \($0)" } ?? "")")
            }

            var changes: [String] = []

            if let str = newDateRepeat {
                let opts = parseOptions(str)
                if !opts.date.isEmpty {
                    if opts.date.lowercased() == "none" {
                        reminder.dueDateComponents = nil
                        changes.append("due cleared")
                    } else if let pd = parseDate(opts.date) {
                        if pd.hasTime && !pd.hasDate, let existing = reminder.dueDateComponents {
                            // Time-only input (e.g. "3pm") — preserve existing date, update time only
                            var comps = existing
                            let t = Calendar.current.dateComponents([.hour, .minute], from: pd.date)
                            comps.hour = t.hour; comps.minute = t.minute
                            reminder.dueDateComponents = comps
                            let display = Calendar.current.date(from: comps) ?? pd.date
                            changes.append("due → \(formatDate(display, showTime: true))")
                        } else {
                            let comps: Set<Calendar.Component> = pd.hasTime
                                ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
                            reminder.dueDateComponents = Calendar.current.dateComponents(comps, from: pd.date)
                            changes.append("due → \(formatDate(pd.date, showTime: pd.hasTime))")
                        }
                    }
                }
                if !opts.recurrence.isEmpty {
                    if opts.recurrence.lowercased() == "none" {
                        reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
                        changes.append("repeat cleared")
                    } else {
                        guard let spec = parseRecurrence(opts.recurrence) else {
                            fail("Unrecognised repeat: \"\(opts.recurrence)\"")
                        }
                        reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
                        reminder.addRecurrenceRule(toEKRule(spec))
                        changes.append(describeRecurrence(spec))
                    }
                }
                if !opts.priority.isEmpty, let p = parsePriority(opts.priority) {
                    reminder.priority = p
                    changes.append(p == 0 ? "priority cleared" : "priority → \(opts.priority)")
                }
                if !opts.note.isEmpty {
                    if opts.note.lowercased() == "none" {
                        reminder.notes = nil
                        changes.append("note cleared")
                    } else {
                        reminder.notes = opts.note
                        changes.append("+ note")
                    }
                }
                if !opts.url.isEmpty {
                    if opts.url.lowercased() == "none" {
                        reminder.url = nil
                        changes.append("url cleared")
                    } else if let u = URL(string: opts.url) {
                        reminder.url = u
                        changes.append("url → \(opts.url)")
                    }
                }
            }

            guard !changes.isEmpty else { fail("nothing to change — specify a date, repeat, priority, note, or url") }

            do {
                try store.save(reminder, commit: true)
                print("Updated \"\(title)\": \(changes.joined(separator: ", "))")
            } catch {
                fail("Could not save: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

    case "show":
        guard args.count > 1 else { fail("provide a reminder title") }
        let title = args[1]
        let listName = args.count > 2 ? args[2] : nil
        let showCalendars: [EKCalendar]
        if let listName {
            guard let cal = store.calendars(for: .reminder).first(where: { $0.title == listName }) else {
                fail("List not found: \(listName)")
            }
            showCalendars = [cal]
        } else {
            showCalendars = store.calendars(for: .reminder)
        }
        store.fetchReminders(matching: store.predicateForIncompleteReminders(
                withDueDateStarting: nil, ending: nil, calendars: showCalendars)) { reminders in
            guard let reminder = (reminders ?? []).first(where: {
                ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame
            }) else {
                fail("Not found: \(title)\(listName.map { " in \($0)" } ?? "")")
            }
            let cal = Calendar.current
            print("Title:    \(reminder.title ?? "")")
            print("List:     \(reminder.calendar.title)")
            if let comps = reminder.dueDateComponents, let date = cal.date(from: comps) {
                print("Due:      \(formatDate(date, showTime: comps.hour != nil))")
            }
            if reminder.hasRecurrenceRules, let rule = reminder.recurrenceRules?.first {
                let freq: String
                switch rule.frequency {
                case .daily:   freq = "daily"
                case .weekly:  freq = rule.interval > 1 ? "every \(rule.interval) weeks" : "weekly"
                case .monthly: freq = rule.interval > 1 ? "every \(rule.interval) months" : "monthly"
                case .yearly:  freq = "yearly"
                @unknown default: freq = "repeating"
                }
                print("Repeat:   \(freq)")
            }
            switch reminder.priority {
            case 1...4: print("Priority: high")
            case 5:     print("Priority: medium")
            case 6...9: print("Priority: low")
            default:    break
            }
            if let notes = reminder.notes, !notes.isEmpty { print("Note:     \(notes)") }
            if let url = reminder.url                      { print("URL:      \(url)") }
            semaphore.signal()
        }

    case "rename":
        guard args.count > 2 else { fail("provide existing title and new title") }
        let oldTitle = args[1]
        let newTitle = args[2]
        let listName = args.count > 3 ? args[3] : nil
        let renameCalendars: [EKCalendar]
        if let listName {
            guard let cal = store.calendars(for: .reminder).first(where: { $0.title == listName }) else {
                fail("List not found: \(listName)")
            }
            renameCalendars = [cal]
        } else {
            renameCalendars = store.calendars(for: .reminder)
        }
        store.fetchReminders(matching: store.predicateForIncompleteReminders(
                withDueDateStarting: nil, ending: nil, calendars: renameCalendars)) { reminders in
            guard let reminder = (reminders ?? []).first(where: {
                ($0.title ?? "").caseInsensitiveCompare(oldTitle) == .orderedSame
            }) else {
                fail("Not found: \(oldTitle)\(listName.map { " in \($0)" } ?? "")")
            }
            reminder.title = newTitle
            do {
                try store.save(reminder, commit: true)
                print("Renamed: \"\(oldTitle)\" → \"\(newTitle)\"")
            } catch {
                fail("Could not rename: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

    case "done", "remove":
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
            guard let reminder = (reminders ?? []).first(where: {
                ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame
            }) else {
                fail("Not found: \(title)\(listName.map { " in \($0)" } ?? "")")
            }
            do {
                if cmd == "done" {
                    reminder.isCompleted = true
                    try store.save(reminder, commit: true)
                    print("Done: \(title)")
                } else {
                    try store.remove(reminder, commit: true)
                    print("Removed: \(title)")
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

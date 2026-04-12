// main.swift
//
// Entry point for reminders-bin. Argument dispatch and EventKit lifecycle only.
// Business logic lives in RemindersLib. EventKit helpers live in RemindersCLI/*.swift.

import Foundation
import AppKit
import EventKit
import RemindersLib
import GetClearKit

let versionString = "\(builtVersion) (Get Clear \(suiteVersion))"

let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
let args = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    print("""
    reminders \(versionString) — CLI for Apple Reminders

    Usage:
      reminders open                                   # Open the Reminders app
      reminders lists                                  # Show all reminder lists
      reminders list [name] [by due|priority|title|created]
      reminders add <name> [list] [date]               # Add a reminder
      reminders change <name> [list] [field value]     # Change fields; use "none" to clear
      reminders rename <name> <new-name> [list]        # Rename a reminder
      reminders find <query>                           # Search titles and notes
      reminders show <name> [list]                     # Show full detail of a reminder
      reminders done <name> [list]                     # Mark a reminder done
      reminders remove <name> [list]                   # Remove a reminder

    Date examples:
      tomorrow, friday, "next friday", "march 15", "2026-03-10", 3pm, "friday at 5pm"

    Optional fields (any order, note must be last):
      repeat daily / repeat weekly / repeat "last tuesday" / repeat "every 2 weeks"
      priority high / priority medium / priority low / priority none
      url https://example.com
      note your free text goes here to end of line

    Clear a field with change:
      due none / repeat none / note none / url none / priority none

    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}

let dispatch = parseArgs(args)
if case .version = dispatch { print(versionString); exit(0) }
guard case .command(let cmd, let args) = dispatch else { usage() }

store.requestFullAccessToReminders { granted, _ in
    guard granted else { fail("Reminders access denied") }

    switch cmd {

    case "what":
        let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
        guard let range = parseRange(rangeStr) else { fail("Unrecognised range: \(rangeStr)") }
        let isToday = rangeStr == "today"
        var dateUsed = Date()
        let entries: [ActivityLogEntry]
        if isToday {
            let result = ActivityLogReader.entriesForDisplay(in: range.start...range.end)
            entries = result.entries; dateUsed = result.dateUsed
        } else {
            entries = ActivityLogReader.entries(in: range.start...range.end, tool: "reminders")
        }
        print(ActivityLogFormatter.perToolWhat(entries: entries, range: range, rangeStr: rangeStr,
                                               tool: "reminders", dateUsed: dateUsed))
        semaphore.signal()

    case "open":
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
        semaphore.signal()

    case "lists":
        let names = store.calendars(for: .reminder).map { $0.title }.sorted()
        print(names.joined(separator: "\n"))
        semaphore.signal()

    case "list":
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

            let sortFn: (EKReminder, EKReminder) -> Bool
            switch sortBy {
            case "priority": sortFn = byPriority
            case "title":    sortFn = byTitle
            case "created":  sortFn = byCreated
            default:         sortFn = byDue
            }

            func metaFor(_ r: EKReminder) -> String {
                let formattedDue = r.dueDateComponents.flatMap { comps in
                    cal.date(from: comps).map { formatDate($0, showTime: comps.hour != nil) }
                }
                return metaLine(for: ReminderMeta(
                    formattedDue: formattedDue,
                    isRepeating: r.hasRecurrenceRules,
                    priority: r.priority,
                    hasNote: r.notes != nil,
                    hasURL: r.url != nil
                ))
            }

            if let filterList {
                for r in (reminders ?? []).sorted(by: sortFn) {
                    print("\(calendarDot(r.calendar))\(ANSI.bold(r.title ?? ""))\(ANSI.dim(metaFor(r)))")
                }
            } else {
                let grouped = Dictionary(grouping: reminders ?? [], by: { $0.calendar.title })
                for listName in grouped.keys.sorted() {
                    let dot = store.calendars(for: .reminder).first { $0.title == listName }.map { calendarDot($0) } ?? "  "
                    print("\(dot)\(ANSI.bold(listName))")
                    for r in (grouped[listName] ?? []).sorted(by: sortFn) {
                        print("\(calendarDot(r.calendar))\(ANSI.bold(r.title ?? ""))\(ANSI.dim(metaFor(r)))")
                    }
                }
            }
            semaphore.signal()
        }

    case "add":
        guard args.count > 1 else { fail("provide a reminder title") }
        let title = args[1]
        var listName: String? = nil
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
        let parsedDate = opts.date.isEmpty ? nil : parseDate(opts.date)
        let recurrenceSpec: RecurrenceSpec?
        if opts.recurrence.isEmpty {
            recurrenceSpec = nil
        } else {
            guard let spec = parseRecurrence(opts.recurrence) else {
                fail("Unrecognised repeat: \"\(opts.recurrence)\"")
            }
            recurrenceSpec = spec
        }

        guard let cal = listName.flatMap({ name in store.calendars(for: .reminder).first { $0.title == name } })
                        ?? store.defaultCalendarForNewReminders() else {
            fail("List not found: \(listName ?? "default")")
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = cal
        if let pd = parsedDate {
            let fields: Set<Calendar.Component> = pd.hasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
            reminder.dueDateComponents = Calendar.current.dateComponents(fields, from: pd.date)
        }
        if let spec = recurrenceSpec            { reminder.addRecurrenceRule(toEKRule(spec)) }
        if let p = parsePriority(opts.priority) { reminder.priority = p }
        if !opts.note.isEmpty                   { reminder.notes = opts.note }
        if !opts.url.isEmpty, let u = URL(string: opts.url) { reminder.url = u }
        do {
            try store.save(reminder, commit: true)
            try? ActivityLog.write(tool: "reminders", cmd: "add", desc: title, container: cal.title)
            var parts = ["Added: \(title) (in \(cal.title))"]
            if let pd = parsedDate        { parts.append("due \(formatDate(pd.date, showTime: pd.hasTime))") }
            if let s = recurrenceSpec     { parts.append(describeRecurrence(s)) }
            if !opts.priority.isEmpty     { parts.append("priority \(opts.priority)") }
            if !opts.note.isEmpty         { parts.append("+ note") }
            if !opts.url.isEmpty          { parts.append("url \(opts.url)") }
            print(parts.joined(separator: " · "))
        } catch {
            fail("Could not save reminder: \(error.localizedDescription)")
        }
        semaphore.signal()

    case "change":
        guard args.count > 1 else { fail("provide a reminder title") }
        let title = args[1]
        var listName: String? = nil
        var newDateRepeat: String? = nil
        if args.count > 2 {
            let remaining = Array(args.dropFirst(2))
            let knownLists = store.calendars(for: .reminder).map { $0.title }
            if knownLists.contains(remaining[0]) {
                listName = remaining[0]
                if remaining.count > 1 { newDateRepeat = remaining.dropFirst().joined(separator: " ") }
            } else {
                newDateRepeat = remaining.joined(separator: " ")
            }
        }
        resolveReminder(title: title, list: listName, cmd: "change", store: store) { reminder in
            let opts = newDateRepeat.map { parseOptions($0) } ?? ParsedOptions()
            let reminderChanges: ReminderChanges
            do {
                reminderChanges = try parseReminderChanges(opts, existingDue: reminder.dueDateComponents)
            } catch ReminderChangeError.nothingToChange {
                fail("nothing to change — specify a date, repeat, priority, note, url, or list")
            } catch ReminderChangeError.unrecognizedRecurrence(let s) {
                fail("Unrecognised repeat: \"\(s)\"")
            } catch {
                fail("Change failed: \(error.localizedDescription)")
            }
            let descriptions = applyChanges(reminderChanges, to: reminder, store: store)
            do {
                try store.save(reminder, commit: true)
                try? ActivityLog.write(tool: "reminders", cmd: "change", desc: title, container: reminder.calendar.title)
                print("Updated \"\(title)\": \(descriptions.joined(separator: ", "))")
            } catch {
                fail("Could not save: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

    case "show":
        guard args.count > 1 else { fail("provide a reminder title") }
        let listName = args.count > 2 ? args[2] : nil
        resolveReminder(title: args[1], list: listName, cmd: "show", store: store) { reminder in
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
        resolveReminder(title: oldTitle, list: listName, cmd: "rename", store: store) { reminder in
            reminder.title = newTitle
            do {
                try store.save(reminder, commit: true)
                try? ActivityLog.write(tool: "reminders", cmd: "rename", desc: "\(oldTitle) → \(newTitle)", container: reminder.calendar.title)
                print("Renamed: \"\(oldTitle)\" → \"\(newTitle)\"")
            } catch {
                fail("Could not rename: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

    case "find":
        guard args.count > 1 else { fail("provide a search query") }
        let query = args.dropFirst().joined(separator: " ")
        let lower = query.lowercased()
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: store.calendars(for: .reminder))
        store.fetchReminders(matching: predicate) { reminders in
            let cal = Calendar.current
            let matches = (reminders ?? []).filter {
                ($0.title ?? "").lowercased().contains(lower) ||
                ($0.notes ?? "").lowercased().contains(lower)
            }.sorted(by: byDue)
            if matches.isEmpty {
                print("No reminders matching '\(query)'")
            } else {
                for r in matches {
                    var meta = "  [\(r.calendar.title)]"
                    if let comps = r.dueDateComponents, let date = cal.date(from: comps) {
                        meta = "  ·  due \(formatDate(date, showTime: comps.hour != nil))" + meta
                    }
                    print("\(calendarDot(r.calendar))\(ANSI.bold(r.title ?? ""))\(ANSI.dim(meta))")
                }
            }
            semaphore.signal()
        }

    case "done", "remove":
        guard args.count > 1 else { fail("provide a reminder title") }
        let title = args[1]
        let listName = args.count > 2 ? args[2] : nil
        resolveReminder(title: title, list: listName, cmd: cmd, store: store) { reminder in
            do {
                if cmd == "done" {
                    reminder.isCompleted = true
                    try store.save(reminder, commit: true)
                    try? ActivityLog.write(tool: "reminders", cmd: "done", desc: title, container: reminder.calendar.title)
                    print("Done: \(title)")
                } else {
                    let container = reminder.calendar.title
                    try store.remove(reminder, commit: true)
                    try? ActivityLog.write(tool: "reminders", cmd: "remove", desc: title, container: container)
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

UpdateChecker.spawnBackgroundCheckIfNeeded()
if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }

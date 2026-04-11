// main.swift
//
// Entry point for the reminders-bin executable.
// Handles argument parsing and all EventKit/AppKit interactions.
// Date parsing is delegated to RemindersLib so it can be unit tested independently.

import Foundation
import AppKit
import EventKit
import RemindersLib
import GetClearKit

let version = builtVersion
let versionString = "\(builtVersion) (Get Clear \(suiteVersion))"

let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
let args = Array(CommandLine.arguments.dropFirst())

func calendarDot(_ calendar: EKCalendar) -> String {
    guard ANSI.enabled else { return "  " }
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
    reminders \(versionString) — CLI for Apple Reminders

    Usage:
      reminders open                                 # Open the Reminders app
      reminders lists                                # Show all reminder lists
      reminders list [name] [by due|priority|title|created]
      reminders add <name> [list] [date]              # Add a reminder
      reminders change <name> [list] [field value]   # Change fields; use "none" to clear
      reminders rename <name> <new-name> [list]      # Rename a reminder
      reminders find <query>                          # Search titles and notes
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
        let entries: [ActivityLogEntry]
        var dateUsed = Date()
        if isToday {
            let result = ActivityLogReader.entriesForDisplay(in: range.start...range.end)
            entries  = result.entries
            dateUsed = result.dateUsed
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

            if filterList != nil {
                let sorted = (reminders ?? []).sorted(by: sortFn)
                for r in sorted {
                    print("\(calendarDot(r.calendar))\(ANSI.bold(r.title ?? ""))\(ANSI.dim(metaFor(r)))")
                }
            } else {
                // Group by list, sort within each group
                let grouped = Dictionary(grouping: reminders ?? [], by: { $0.calendar.title })
                let listNames = grouped.keys.sorted()
                for listName in listNames {
                    let listCal = store.calendars(for: .reminder).first { $0.title == listName }
                    let dot = listCal.map { calendarDot($0) } ?? "  "
                    print("\(dot)\(ANSI.bold(listName))")
                    for r in (grouped[listName] ?? []).sorted(by: sortFn) {
                        print("\(calendarDot(r.calendar))\(ANSI.bold(r.title ?? ""))\(ANSI.dim(metaFor(r)))")
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
            try? ActivityLog.write(tool: "reminders", cmd: "add", desc: title, container: cal.title)
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
            let matches = (reminders ?? []).filter {
                ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame
            }
            guard !matches.isEmpty else { fail("Not found: \(title)\(listName.map { " in \($0)" } ?? "")") }
            if matches.count > 1 {
                print("Multiple reminders named '\(title)':")
                for r in matches { print("  [\(r.calendar.title)]") }
                print("Add the list name to narrow: reminders change \"\(title)\" \(matches[0].calendar.title) ...")
                exit(1)
            }
            let reminder = matches[0]

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

            if case .cleared = reminderChanges.due { reminder.dueDateComponents = nil }
            if case .set(let comps) = reminderChanges.due { reminder.dueDateComponents = comps }

            if case .cleared = reminderChanges.recurrence {
                reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
            }
            if case .set(let spec) = reminderChanges.recurrence {
                reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
                reminder.addRecurrenceRule(toEKRule(spec))
            }

            if case .set(let p) = reminderChanges.priority { reminder.priority = p }

            if case .cleared = reminderChanges.note { reminder.notes = nil }
            if case .set(let n) = reminderChanges.note { reminder.notes = n }

            if case .cleared = reminderChanges.url { reminder.url = nil }
            if case .set(let u) = reminderChanges.url, let url = URL(string: u) { reminder.url = url }

            var descriptions = reminderChanges.descriptions
            if case .set(let targetName) = reminderChanges.list {
                guard let targetCal = store.calendars(for: .reminder).first(where: {
                    $0.title.caseInsensitiveCompare(targetName) == .orderedSame
                }) else { fail("List not found: \(targetName)") }
                let from = reminder.calendar.title
                reminder.calendar = targetCal
                descriptions.append("list → \(from) → \(targetCal.title)")
            }
            let changes = descriptions

            do {
                try store.save(reminder, commit: true)
                try? ActivityLog.write(tool: "reminders", cmd: "change", desc: title, container: reminder.calendar.title)
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
            let matches = (reminders ?? []).filter {
                ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame
            }
            guard !matches.isEmpty else { fail("Not found: \(title)\(listName.map { " in \($0)" } ?? "")") }
            if matches.count > 1 {
                print("Multiple reminders named '\(title)':")
                for r in matches { print("  [\(r.calendar.title)]") }
                print("Add the list name to narrow: reminders show \"\(title)\" \(matches[0].calendar.title)")
                exit(1)
            }
            let reminder = matches[0]
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
            let matches = (reminders ?? []).filter {
                ($0.title ?? "").caseInsensitiveCompare(oldTitle) == .orderedSame
            }
            guard !matches.isEmpty else { fail("Not found: \(oldTitle)\(listName.map { " in \($0)" } ?? "")") }
            if matches.count > 1 {
                print("Multiple reminders named '\(oldTitle)':")
                for r in matches { print("  [\(r.calendar.title)]") }
                print("Add the list name to narrow: reminders rename \"\(oldTitle)\" \"\(newTitle)\" \(matches[0].calendar.title)")
                exit(1)
            }
            let reminder = matches[0]
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
        let query      = args.dropFirst().joined(separator: " ")
        let lower      = query.lowercased()
        let allCals    = store.calendars(for: .reminder)
        let predicate  = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: allCals)
        store.fetchReminders(matching: predicate) { reminders in
            let cal = Calendar.current
            let matches = (reminders ?? []).filter {
                ($0.title ?? "").lowercased().contains(lower) ||
                ($0.notes ?? "").lowercased().contains(lower)
            }.sorted { a, b in
                let da = a.dueDateComponents.flatMap { cal.date(from: $0) }
                let db = b.dueDateComponents.flatMap { cal.date(from: $0) }
                switch (da, db) {
                case (nil, nil):     return (a.title ?? "") < (b.title ?? "")
                case (nil, _):       return false
                case (_, nil):       return true
                case (let x?, let y?): return x < y
                }
            }
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
            let matches = (reminders ?? []).filter {
                ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame
            }
            guard !matches.isEmpty else { fail("Not found: \(title)\(listName.map { " in \($0)" } ?? "")") }
            if matches.count > 1 {
                print("Multiple reminders named '\(title)':")
                for r in matches { print("  [\(r.calendar.title)]") }
                print("Add the list name to narrow: reminders \(cmd) \"\(title)\" \(matches[0].calendar.title)")
                exit(1)
            }
            let reminder = matches[0]
            do {
                if cmd == "done" {
                    reminder.isCompleted = true
                    try store.save(reminder, commit: true)
                    try? ActivityLog.write(tool: "reminders", cmd: "done", desc: title, container: reminder.calendar.title)
                    print("Done: \(title)")
                } else {
                    let listName = reminder.calendar.title
                    try store.remove(reminder, commit: true)
                    try? ActivityLog.write(tool: "reminders", cmd: "remove", desc: title, container: listName)
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

// FindCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleFind(args: [String], store: EKEventStore, semaphore: DispatchSemaphore) {
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
}

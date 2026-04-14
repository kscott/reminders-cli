// ListCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleList(args: [String], store: EKEventStore, semaphore: DispatchSemaphore) {
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
            for r in (reminders ?? []).sorted(by: sortFn) {
                print("\(calendarDot(r.calendar))\(ANSI.bold(r.title ?? ""))\(ANSI.dim(metaFor(r)))")
            }
        } else {
            let grouped = Dictionary(grouping: reminders ?? [], by: { $0.calendar.title })
            for listName in grouped.keys.sorted() {
                let dot = listCalendars.first { $0.title == listName }.map { calendarDot($0) } ?? "  "
                print("\(dot)\(ANSI.bold(listName))")
                for r in (grouped[listName] ?? []).sorted(by: sortFn) {
                    print("\(calendarDot(r.calendar))\(ANSI.bold(r.title ?? ""))\(ANSI.dim(metaFor(r)))")
                }
            }
        }
        semaphore.signal()
    }
}

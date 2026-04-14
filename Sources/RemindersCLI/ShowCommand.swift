// ShowCommand.swift

import EventKit
import GetClearKit

func handleShow(args: [String], store: EKEventStore, semaphore: DispatchSemaphore) {
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
            print("Repeat:   \(describeEKRule(rule))")
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
}

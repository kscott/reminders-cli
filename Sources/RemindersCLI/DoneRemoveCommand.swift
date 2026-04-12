// DoneRemoveCommand.swift
//
// Handler for the `done` and `remove` commands — marks a reminder complete or deletes it.

import EventKit
import GetClearKit

func handleDoneOrRemove(cmd: String, args: [String], store: EKEventStore, semaphore: DispatchSemaphore) {
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
}

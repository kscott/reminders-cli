// ChangeHandler.swift
//
// Handler for the `change` command — parses args, resolves the reminder, and applies field changes.

import EventKit
import GetClearKit
import RemindersLib

func handleChange(args: [String], store: EKEventStore, semaphore: DispatchSemaphore) {
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
}

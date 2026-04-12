// ChangeApplier.swift
//
// Applies a resolved ReminderChanges value to an EKReminder in place.

import EventKit
import GetClearKit
import RemindersLib

/// Applies `changes` to `reminder`. Returns the final descriptions array,
/// including the list-move description if the reminder was moved between lists.
@discardableResult
func applyChanges(_ changes: ReminderChanges, to reminder: EKReminder, store: EKEventStore) -> [String] {
    if case .cleared = changes.due { reminder.dueDateComponents = nil }
    if case .set(let comps) = changes.due { reminder.dueDateComponents = comps }

    if case .cleared = changes.recurrence {
        reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
    }
    if case .set(let spec) = changes.recurrence {
        reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
        reminder.addRecurrenceRule(toEKRule(spec))
    }

    if case .set(let p) = changes.priority { reminder.priority = p }

    if case .cleared = changes.note { reminder.notes = nil }
    if case .set(let n) = changes.note { reminder.notes = n }

    if case .cleared = changes.url { reminder.url = nil }
    if case .set(let u) = changes.url, let url = URL(string: u) { reminder.url = url }

    var descriptions = changes.descriptions
    if case .set(let targetName) = changes.list {
        guard let targetCal = store.calendars(for: .reminder).first(where: {
            $0.title.caseInsensitiveCompare(targetName) == .orderedSame
        }) else { fail("List not found: \(targetName)") }
        let from = reminder.calendar.title
        reminder.calendar = targetCal
        descriptions.append("list → \(from) → \(targetCal.title)")
    }
    return descriptions
}

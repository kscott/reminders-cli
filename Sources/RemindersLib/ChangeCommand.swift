// ChangeCommand.swift
//
// Parses a combined options string into a value describing what fields should change.
// No EventKit dependency — lives in RemindersLib so it can be unit tested.

import Foundation
import GetClearKit

/// Describes whether a field should be left alone, cleared, or updated.
public enum FieldChange<T> {
    case unchanged
    case cleared
    case set(T)
}

extension FieldChange: Equatable where T: Equatable {}

/// The resolved set of changes to apply to a reminder.
public struct ReminderChanges {
    /// Due date as DateComponents ready to assign to EKReminder.dueDateComponents, or cleared/unchanged.
    public let due: FieldChange<DateComponents>
    public let recurrence: FieldChange<RecurrenceSpec>
    /// Priority integer (0 = none, 1 = high, 5 = medium, 9 = low), or unchanged.
    public let priority: FieldChange<Int>
    public let note: FieldChange<String>
    public let url: FieldChange<String>
    /// Target list name. Caller is responsible for resolving to EKCalendar and generating the description.
    public let list: FieldChange<String>
    /// Human-readable summary of changes made (excludes list — caller appends that).
    public var descriptions: [String]
}

/// Errors thrown by parseReminderChanges.
public enum ReminderChangeError: Error {
    case nothingToChange
    case unrecognizedRecurrence(String)
}

/// Converts a priority string to an EventKit priority integer.
/// Returns nil for unrecognized input.
public func parsePriority(_ s: String) -> Int? {
    switch s.lowercased().trimmingCharacters(in: .whitespaces) {
    case "high":          return 1
    case "medium", "med": return 5
    case "low":           return 9
    case "none":          return 0
    default:              return nil
    }
}

/// Parses opts into a ReminderChanges value describing what to apply.
///
/// - Parameter opts: Parsed options from the user's input string.
/// - Parameter existingDue: The reminder's current due date components, used to merge
///   time-only input (e.g. "3pm") with an existing date.
/// - Throws: `ReminderChangeError.nothingToChange` if no recognized fields were specified.
/// - Throws: `ReminderChangeError.unrecognizedRecurrence` if a repeat value was given but not parseable.
public func parseReminderChanges(
    _ opts: ParsedOptions,
    existingDue: DateComponents?
) throws -> ReminderChanges {
    var due: FieldChange<DateComponents>       = .unchanged
    var recurrence: FieldChange<RecurrenceSpec> = .unchanged
    var priority: FieldChange<Int>             = .unchanged
    var note: FieldChange<String>              = .unchanged
    var url: FieldChange<String>               = .unchanged
    var list: FieldChange<String>              = .unchanged
    var descriptions: [String]                 = []

    if !opts.date.isEmpty {
        if opts.date.lowercased() == "none" {
            due = .cleared
            descriptions.append("due cleared")
        } else if let pd = parseDate(opts.date) {
            let cal = Calendar.current
            if pd.hasTime && !pd.hasDate, let existing = existingDue {
                // Time-only input — preserve existing date, update time only
                var comps = existing
                let t = cal.dateComponents([.hour, .minute], from: pd.date)
                comps.hour   = t.hour
                comps.minute = t.minute
                let display  = cal.date(from: comps) ?? pd.date
                due = .set(comps)
                descriptions.append("due → \(formatDate(display, showTime: true))")
            } else {
                let fields: Set<Calendar.Component> = pd.hasTime
                    ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
                due = .set(cal.dateComponents(fields, from: pd.date))
                descriptions.append("due → \(formatDate(pd.date, showTime: pd.hasTime))")
            }
        }
    }

    if !opts.recurrence.isEmpty {
        if opts.recurrence.lowercased() == "none" {
            recurrence = .cleared
            descriptions.append("repeat cleared")
        } else if let spec = parseRecurrence(opts.recurrence) {
            recurrence = .set(spec)
            descriptions.append(describeRecurrence(spec))
        } else {
            throw ReminderChangeError.unrecognizedRecurrence(opts.recurrence)
        }
    }

    if !opts.priority.isEmpty, let p = parsePriority(opts.priority) {
        priority = .set(p)
        descriptions.append(p == 0 ? "priority cleared" : "priority → \(opts.priority)")
    }

    if !opts.note.isEmpty {
        if opts.note.lowercased() == "none" {
            note = .cleared
            descriptions.append("note cleared")
        } else {
            note = .set(opts.note)
            descriptions.append("+ note")
        }
    }

    if !opts.url.isEmpty {
        if opts.url.lowercased() == "none" {
            url = .cleared
            descriptions.append("url cleared")
        } else {
            url = .set(opts.url)
            descriptions.append("url → \(opts.url)")
        }
    }

    if !opts.list.isEmpty {
        list = .set(opts.list)
        // Description requires the "from" list name — caller appends it after resolving EKCalendar.
    }

    if descriptions.isEmpty && opts.list.isEmpty {
        throw ReminderChangeError.nothingToChange
    }

    return ReminderChanges(
        due: due, recurrence: recurrence, priority: priority,
        note: note, url: url, list: list, descriptions: descriptions
    )
}

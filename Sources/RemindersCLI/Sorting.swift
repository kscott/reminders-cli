// Sorting.swift
//
// Named sort functions for EKReminder arrays.
// Lives in RemindersCLI — not RemindersLib — because the input type is an EventKit object.

import EventKit

private func dueDate(of r: EKReminder) -> Date? {
    r.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
}

func byDue(_ a: EKReminder, _ b: EKReminder) -> Bool {
    switch (dueDate(of: a), dueDate(of: b)) {
    case (nil, nil):         return (a.title ?? "") < (b.title ?? "")
    case (nil, _):           return false
    case (_, nil):           return true
    case (let da?, let db?): return da < db
    }
}

func byPriority(_ a: EKReminder, _ b: EKReminder) -> Bool {
    let pa = a.priority == 0 ? 10 : a.priority
    let pb = b.priority == 0 ? 10 : b.priority
    return pa != pb ? pa < pb : byDue(a, b)
}

func byTitle(_ a: EKReminder, _ b: EKReminder) -> Bool {
    (a.title ?? "").localizedCaseInsensitiveCompare(b.title ?? "") == .orderedAscending
}

func byCreated(_ a: EKReminder, _ b: EKReminder) -> Bool {
    (a.creationDate ?? .distantPast) < (b.creationDate ?? .distantPast)
}

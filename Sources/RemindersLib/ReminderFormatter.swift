// ReminderFormatter.swift
//
// Formats reminder metadata into the dim suffix line shown in list output.
// Takes plain data — no EventKit dependency.

import Foundation

/// Metadata needed to format the display suffix for a single reminder.
public struct ReminderMeta {
    /// Due date already formatted by the caller (e.g. "Fri Apr 11 · 3:00pm"), or nil if no due date.
    public let formattedDue: String?
    public let isRepeating: Bool
    /// Raw EventKit priority integer: 0 = none, 1–4 = high, 5 = medium, 6–9 = low.
    public let priority: Int
    public let hasNote: Bool
    public let hasURL: Bool

    public init(
        formattedDue: String? = nil,
        isRepeating: Bool = false,
        priority: Int = 0,
        hasNote: Bool = false,
        hasURL: Bool = false
    ) {
        self.formattedDue = formattedDue
        self.isRepeating  = isRepeating
        self.priority     = priority
        self.hasNote      = hasNote
        self.hasURL       = hasURL
    }
}

/// Returns the dim metadata suffix for a reminder, e.g. "  ·  due Fri Apr 11 · repeating · high".
/// Returns "" when no metadata fields are present.
public func metaLine(for meta: ReminderMeta) -> String {
    var parts: [String] = []
    if let due = meta.formattedDue { parts.append(due) }
    if meta.isRepeating { parts.append("repeating") }
    switch meta.priority {
    case 1...4: parts.append("high")
    case 5:     parts.append("medium")
    case 6...9: parts.append("low")
    default:    break
    }
    if meta.hasNote { parts.append("+ note") }
    if meta.hasURL  { parts.append("+ url") }
    return parts.isEmpty ? "" : "  ·  " + parts.joined(separator: " · ")
}

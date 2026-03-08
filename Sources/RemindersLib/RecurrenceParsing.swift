// RecurrenceParsing.swift
//
// Parses natural-language recurrence strings into RecurrenceSpec values.
// No EventKit dependency — kept in RemindersLib so it can be unit tested.
//
// Supported formats:
//   Simple:    "daily", "weekly", "monthly", "yearly"
//   Natural:   "every day", "every week", "every month", "every year", "annually"
//   Interval:  "every 2 weeks", "every 3 months", "every 4 days", etc.
//   Ordinal:   "first monday", "last tuesday", "second friday", "third wednesday", etc.
//              (ordinal weekday-of-month → monthly recurrence)

import Foundation

public enum RecurrenceFrequency {
    case daily, weekly, monthly, yearly
}

public struct RecurrenceSpec {
    public let frequency: RecurrenceFrequency
    public let interval: Int
    /// Non-nil for ordinal weekday-of-month rules (e.g. "last tuesday").
    public let ordinalWeekday: OrdinalWeekday?

    public init(frequency: RecurrenceFrequency, interval: Int, ordinalWeekday: OrdinalWeekday?) {
        self.frequency = frequency
        self.interval = interval
        self.ordinalWeekday = ordinalWeekday
    }

    public struct OrdinalWeekday {
        /// 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat  (matches EKWeekday raw values)
        public let weekday: Int
        /// 1=first, 2=second, 3=third, 4=fourth, -1=last
        public let weekNumber: Int

        public init(weekday: Int, weekNumber: Int) {
            self.weekday = weekday
            self.weekNumber = weekNumber
        }
    }
}

public func parseRecurrence(_ s: String) -> RecurrenceSpec? {
    let lower = s.lowercased().trimmingCharacters(in: .whitespaces)

    // Ordinal weekday-of-month: "last tuesday", "first friday", "second monday", etc.
    let ordinals: [String: Int] = ["first":1,"second":2,"third":3,"fourth":4,"last":-1]
    let weekdayNums: [String: Int] = [
        "sunday":1,"monday":2,"tuesday":3,"wednesday":4,
        "thursday":5,"friday":6,"saturday":7
    ]
    let ordinalRegex = try! NSRegularExpression(
        pattern: #"(first|second|third|fourth|last)\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday)"#)
    if let m = ordinalRegex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
        let ordinalStr = (lower as NSString).substring(with: m.range(at: 1))
        let weekdayStr = (lower as NSString).substring(with: m.range(at: 2))
        return RecurrenceSpec(
            frequency: .monthly,
            interval: 1,
            ordinalWeekday: .init(weekday: weekdayNums[weekdayStr]!, weekNumber: ordinals[ordinalStr]!)
        )
    }

    // Interval: "every 2 weeks", "every 3 months", etc.
    let everyRegex = try! NSRegularExpression(pattern: #"every\s+(\d+)\s+(day|week|month|year)s?"#)
    if let m = everyRegex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
        let interval = Int((lower as NSString).substring(with: m.range(at: 1))) ?? 1
        let freq: RecurrenceFrequency
        switch (lower as NSString).substring(with: m.range(at: 2)) {
        case "day":   freq = .daily
        case "week":  freq = .weekly
        case "month": freq = .monthly
        case "year":  freq = .yearly
        default: return nil
        }
        return RecurrenceSpec(frequency: freq, interval: interval, ordinalWeekday: nil)
    }

    // Simple keywords
    let freq: RecurrenceFrequency
    switch lower {
    case "daily",   "every day":              freq = .daily
    case "weekly",  "every week":             freq = .weekly
    case "monthly", "every month":            freq = .monthly
    case "yearly",  "every year", "annually": freq = .yearly
    default: return nil
    }
    return RecurrenceSpec(frequency: freq, interval: 1, ordinalWeekday: nil)
}

/// Splits a combined date+recurrence string on the repeat keyword.
/// "march 1 repeating monthly" → ("march 1", "monthly")
/// "repeat daily"              → ("", "daily")
/// "tuesday at 3pm"            → ("tuesday at 3pm", "")
public func splitOnRepeat(_ s: String) -> (date: String, recurrence: String) {
    if let r = s.range(of: #"\brepeat(?:s|ing|ed)?\b"#, options: .regularExpression) {
        return (String(s[..<r.lowerBound]).trimmingCharacters(in: .whitespaces),
                String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces))
    }
    return (s, "")
}

public func describeRecurrence(_ spec: RecurrenceSpec) -> String {
    if let ow = spec.ordinalWeekday {
        let ordinalName = [1:"first",2:"second",3:"third",4:"fourth",-1:"last"][ow.weekNumber] ?? "\(ow.weekNumber)th"
        let dayName = ["","sunday","monday","tuesday","wednesday","thursday","friday","saturday"][ow.weekday]
        return "repeat \(ordinalName) \(dayName) of the month"
    }
    let freqNames: [RecurrenceFrequency: String] = [.daily:"daily",.weekly:"weekly",.monthly:"monthly",.yearly:"yearly"]
    let unitNames: [RecurrenceFrequency: String] = [.daily:"day",.weekly:"week",.monthly:"month",.yearly:"year"]
    let freqName = freqNames[spec.frequency]!
    let unitName = unitNames[spec.frequency]!
    return spec.interval > 1 ? "repeat every \(spec.interval) \(unitName)s" : "repeat \(freqName)"
}

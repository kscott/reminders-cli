// RecurrenceParsing.swift
//
// Parses natural-language recurrence strings into RecurrenceSpec values.
// No EventKit dependency — kept in RemindersLib so it can be unit tested.
//
// Supported formats:
//   Simple:          "daily", "weekly", "monthly", "yearly", "annually"
//   Natural:         "every day", "every week", "every month", "every year"
//   Interval:        "every 2 weeks", "every 3 months", "every 4 days", etc.
//   Ordinal weekday: "first monday", "last tuesday", "2nd friday", "3rd wednesday", etc.
//                    (word or numeric ordinal + weekday name → monthly recurrence)
//   Day of month:    "the 15th", "on the 1st", "2nd of the month", "on the 22nd", etc.
//                    (specific day number → monthly recurrence)

import Foundation

public enum RecurrenceFrequency {
    case daily, weekly, monthly, yearly
}

public struct RecurrenceSpec {
    public let frequency: RecurrenceFrequency
    public let interval: Int
    /// Non-nil for ordinal weekday-of-month rules (e.g. "last tuesday", "2nd friday").
    public let ordinalWeekday: OrdinalWeekday?
    /// Non-nil for specific day-of-month rules (e.g. "the 15th", "on the 1st").
    public let dayOfMonth: Int?

    public init(frequency: RecurrenceFrequency, interval: Int,
                ordinalWeekday: OrdinalWeekday? = nil, dayOfMonth: Int? = nil) {
        self.frequency      = frequency
        self.interval       = interval
        self.ordinalWeekday = ordinalWeekday
        self.dayOfMonth     = dayOfMonth
    }

    public struct OrdinalWeekday {
        /// 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat  (matches EKWeekday raw values)
        public let weekday: Int
        /// 1=first, 2=second, 3=third, 4=fourth, -1=last
        public let weekNumber: Int

        public init(weekday: Int, weekNumber: Int) {
            self.weekday    = weekday
            self.weekNumber = weekNumber
        }
    }
}

private let weekdayNums: [String: Int] = [
    "sunday":1,"monday":2,"tuesday":3,"wednesday":4,
    "thursday":5,"friday":6,"saturday":7
]
private let weekdayPattern =
    #"sunday|monday|tuesday|wednesday|thursday|friday|saturday"#

public func parseRecurrence(_ s: String) -> RecurrenceSpec? {
    let lower = s.lowercased().trimmingCharacters(in: .whitespaces)

    // 1. Word ordinal weekday: "last tuesday", "first friday", "second monday", etc.
    //    Also handles leading articles: "the last wednesday", "on the first friday"
    let wordOrdinals: [String: Int] = ["first":1,"second":2,"third":3,"fourth":4,"last":-1]
    let wordOrdinalRegex = try! NSRegularExpression(
        pattern: #"(first|second|third|fourth|last)\s+(\#(weekdayPattern))"#)
    if let m = wordOrdinalRegex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
        let ord = (lower as NSString).substring(with: m.range(at: 1))
        let day = (lower as NSString).substring(with: m.range(at: 2))
        return RecurrenceSpec(frequency: .monthly, interval: 1,
                              ordinalWeekday: .init(weekday: weekdayNums[day]!, weekNumber: wordOrdinals[ord]!))
    }

    // 2. Numeric ordinal weekday: "2nd wednesday", "3rd friday", "1st monday", "4th thursday"
    let numOrdinals: [String: Int] = ["1st":1,"2nd":2,"3rd":3,"4th":4]
    let numOrdinalWeekdayRegex = try! NSRegularExpression(
        pattern: #"(1st|2nd|3rd|4th)\s+(\#(weekdayPattern))"#)
    if let m = numOrdinalWeekdayRegex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
        let ord = (lower as NSString).substring(with: m.range(at: 1))
        let day = (lower as NSString).substring(with: m.range(at: 2))
        return RecurrenceSpec(frequency: .monthly, interval: 1,
                              ordinalWeekday: .init(weekday: weekdayNums[day]!, weekNumber: numOrdinals[ord]!))
    }

    // 3. Day of month: "the 15th", "on the 1st", "2nd of the month", "on the 22nd", etc.
    //    Matched after ordinal weekday checks so "2nd wednesday" is never treated as day 2.
    let dayOfMonthRegex = try! NSRegularExpression(
        pattern: #"(?:on\s+)?(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)(?:\s+of\s+(?:the\s+)?month)?"#)
    if let m = dayOfMonthRegex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
        if let day = Int((lower as NSString).substring(with: m.range(at: 1))), (1...31).contains(day) {
            return RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: day)
        }
    }

    // 4. Interval: "every 2 weeks", "every 3 months", etc.
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
        return RecurrenceSpec(frequency: freq, interval: interval)
    }

    // 5. Simple keywords
    let freq: RecurrenceFrequency
    switch lower {
    case "daily",   "every day":              freq = .daily
    case "weekly",  "every week":             freq = .weekly
    case "monthly", "every month":            freq = .monthly
    case "yearly",  "every year", "annually": freq = .yearly
    default: return nil
    }
    return RecurrenceSpec(frequency: freq, interval: 1)
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

private func ordinalSuffix(_ n: Int) -> String {
    switch n {
    case 1, 21, 31: return "\(n)st"
    case 2, 22:     return "\(n)nd"
    case 3, 23:     return "\(n)rd"
    default:        return "\(n)th"
    }
}

public func describeRecurrence(_ spec: RecurrenceSpec) -> String {
    if let ow = spec.ordinalWeekday {
        let ordName = [1:"first",2:"second",3:"third",4:"fourth",-1:"last"][ow.weekNumber] ?? "\(ow.weekNumber)th"
        let dayName = ["","sunday","monday","tuesday","wednesday","thursday","friday","saturday"][ow.weekday]
        return "repeat \(ordName) \(dayName) of the month"
    }
    if let day = spec.dayOfMonth {
        return "repeat on the \(ordinalSuffix(day)) of the month"
    }
    let freqNames: [RecurrenceFrequency: String] = [.daily:"daily",.weekly:"weekly",.monthly:"monthly",.yearly:"yearly"]
    let unitNames: [RecurrenceFrequency: String]  = [.daily:"day",.weekly:"week",.monthly:"month",.yearly:"year"]
    let freqName = freqNames[spec.frequency]!
    let unitName = unitNames[spec.frequency]!
    return spec.interval > 1 ? "repeat every \(spec.interval) \(unitName)s" : "repeat \(freqName)"
}

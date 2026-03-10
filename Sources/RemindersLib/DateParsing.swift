// DateParsing.swift
//
// Parses natural-language date strings into ParsedDate values.
// Kept separate from EventKit code so it can be unit tested without
// any Apple framework dependencies or permissions.
//
// Supported formats:
//   Relative days:  "today", "tomorrow"
//   Weekday names:  "monday" … "sunday"  (next future occurrence)
//   Month + day:    "march 15"           (rolls to next year if past)
//   ISO date:       "2026-03-15"
//   Short date:     "3/15" or "3-15"     (rolls to next year if past)
//   Time only:      "3pm", "14:30"       (defaults to today)
//   Combined:       "tomorrow 3pm", "friday at 5pm", "march 15 9am"
//
// When no time is specified, hasTime is false and callers should set
// date-only components — no alarm time is implied.

import Foundation

public struct ParsedDate {
    public let date: Date
    /// True when the input explicitly included a time ("3pm", "at 14:30", etc.)
    public let hasTime: Bool
    /// True when the input included an explicit date (day, weekday, month+day, ISO).
    /// False when the input was time-only ("3pm"), in which case date defaults to today.
    public let hasDate: Bool

    public init(date: Date, hasTime: Bool, hasDate: Bool) {
        self.date    = date
        self.hasTime = hasTime
        self.hasDate = hasDate
    }
}

public func parseDate(_ input: String) -> ParsedDate? {
    let s = input.lowercased().trimmingCharacters(in: .whitespaces)
    let cal = Calendar.current
    let now = Date()
    var components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
    components.hour   = 9
    components.minute = 0

    let timePatterns = [
        #"(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#,
        #"(?:at\s+)?(\d{1,2}):(\d{2})$"#
    ]

    var dayPart = s
    var timePart: String? = nil

    for pattern in timePatterns {
        if let range = s.range(of: pattern, options: .regularExpression) {
            timePart = String(s[range])
            dayPart = s.replacingCharacters(in: range, with: "")
                       .trimmingCharacters(in: .whitespaces)
                       .replacingOccurrences(of: #"\bat\b,?"#, with: "", options: .regularExpression)
                       .trimmingCharacters(in: .whitespaces)
            break
        }
    }

    if let timePart {
        let tp = timePart.replacingOccurrences(of: "at ", with: "")
        if let hourRange = tp.range(of: #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#, options: .regularExpression) {
            let hourStr = String(tp[hourRange])
            let numRegex = try! NSRegularExpression(pattern: #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#)
            if let match = numRegex.firstMatch(in: hourStr, range: NSRange(hourStr.startIndex..., in: hourStr)) {
                let hour   = Int((hourStr as NSString).substring(with: match.range(at: 1))) ?? 9
                let minute = match.range(at: 2).location != NSNotFound
                    ? Int((hourStr as NSString).substring(with: match.range(at: 2))) ?? 0 : 0
                let ampm   = match.range(at: 3).location != NSNotFound
                    ? (hourStr as NSString).substring(with: match.range(at: 3)) : ""
                components.hour   = ampm == "pm" && hour < 12 ? hour + 12 :
                                    ampm == "am" && hour == 12 ? 0 : hour
                components.minute = minute
            }
        }
    }

    let weekdays = ["sunday":1,"monday":2,"tuesday":3,"wednesday":4,
                    "thursday":5,"friday":6,"saturday":7]
    let months   = ["january":1,"february":2,"march":3,"april":4,"may":5,"june":6,
                    "july":7,"august":8,"september":9,"october":10,"november":11,"december":12]

    let dayTrimmed = dayPart.trimmingCharacters(in: .whitespaces)

    if dayTrimmed.isEmpty || dayTrimmed == "today" {
        // keep today's date components
    } else if dayTrimmed == "tomorrow" {
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        let tc = cal.dateComponents([.year, .month, .day], from: tomorrow)
        components.year = tc.year; components.month = tc.month; components.day = tc.day
    } else if let weekdayNum = weekdays[dayTrimmed.replacingOccurrences(
                  of: #"^(?:next|this)\s+"#, with: "", options: .regularExpression)] {
        // "next friday", "this monday" etc. — strip the prefix, same behaviour as bare weekday
        var dc = DateComponents(); dc.weekday = weekdayNum
        if let next = cal.nextDate(after: now, matching: dc, matchingPolicy: .nextTime) {
            let nc = cal.dateComponents([.year, .month, .day], from: next)
            components.year = nc.year; components.month = nc.month; components.day = nc.day
        }
    } else {
        let parts = dayTrimmed.split(separator: " ").map(String.init)
        if parts.count == 2, let monthNum = months[parts[0]], let day = Int(parts[1]) {
            // "march 15" — roll to next year if past
            components.month = monthNum; components.day = day
            if let d = cal.date(from: components), d < now {
                components.year = (components.year ?? 0) + 1
            }
        } else if parts.count == 3 {
            // "march 10 2027", "march 10, 2027", "10 march 2027"
            let p0 = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: ","))
            let p1 = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: ","))
            if let monthNum = months[p0], let day = Int(p1), let year = Int(parts[2]) {
                components.month = monthNum; components.day = day
                components.year = year < 100 ? 2000 + year : year
            } else if let day = Int(p0), let monthNum = months[p1], let year = Int(parts[2]) {
                components.month = monthNum; components.day = day
                components.year = year < 100 ? 2000 + year : year
            } else {
                return nil
            }
        } else if parts.count == 1 {
            let numParts = parts[0].components(separatedBy: CharacterSet(charactersIn: "/-"))
            if numParts.count == 3,
               let p0 = Int(numParts[0]), let p1 = Int(numParts[1]), let p2 = Int(numParts[2]) {
                // Heuristic: first part > 31 → Y/M/D (ISO); otherwise → M/D/Y (US)
                let y, m, d: Int
                if p0 > 31 { (y, m, d) = (p0, p1, p2) }
                else { let yr = p2 < 100 ? 2000 + p2 : p2; (y, m, d) = (yr, p0, p1) }
                components.year = y; components.month = m; components.day = d
            } else if numParts.count == 2,
                      let m = Int(numParts[0]), let d = Int(numParts[1]) {
                components.month = m; components.day = d
                if let date = cal.date(from: components), date < now {
                    components.year = (components.year ?? 0) + 1
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    guard let date = cal.date(from: components) else { return nil }
    return ParsedDate(date: date, hasTime: timePart != nil, hasDate: !dayTrimmed.isEmpty)
}

public func formatDate(_ date: Date, showTime: Bool) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = showTime ? .short : .none
    return f.string(from: date)
}

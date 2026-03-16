// OptionsParsing.swift
//
// Parses the combined options string (everything after <title> [list]) into individual fields.
// No EventKit dependency — lives in RemindersLib so it can be unit tested.
//
// Recognised keywords (case-insensitive, word boundaries):
//   repeat / repeats / repeating / repeated  → recurrence frequency
//   priority                                  → high / medium / low / none
//   url                                       → a URL string
//   note / notes                              → free text; must come last — captures to end of string
//
// Keyword order: repeat, priority, and url can appear in any order relative to each other
// and to the date. note must be last — everything after it is treated as note text,
// including any words that would otherwise be recognised as keywords.

import Foundation

public struct ParsedOptions {
    public var date: String       = ""
    public var recurrence: String = ""
    public var priority: String   = ""
    public var note: String       = ""
    public var url: String        = ""

    public init() {}
}

public func parseOptions(_ s: String) -> ParsedOptions {
    var result = ParsedOptions()
    var work = s.trimmingCharacters(in: .whitespaces)

    // Extract note first — it captures everything from the keyword to end of string,
    // so keywords inside note text are not misread.
    if let r = work.range(of: #"\bnotes?\b"#, options: .regularExpression) {
        result.note = String(work[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        work = String(work[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
    }

    // Find remaining keywords in whatever order they appear.
    struct KwMatch {
        let field: String
        let range: Range<String.Index>
    }
    let patterns: [(String, String)] = [
        ("repeat",   #"\brepeat(?:s|ing|ed)?\b"#),
        ("priority", #"\bpriority\b"#),
        ("url",      #"\burl\b"#),
    ]
    var matches: [KwMatch] = []
    for (field, pattern) in patterns {
        if let r = work.range(of: pattern, options: .regularExpression) {
            matches.append(KwMatch(field: field, range: r))
        }
    }
    matches.sort { $0.range.lowerBound < $1.range.lowerBound }

    // Everything before the first keyword is the date.
    // Strip a leading "due" if present — natural to say "due friday" but it's not part of the date.
    result.date = (matches.first.map { String(work[..<$0.range.lowerBound]) } ?? work)
        .trimmingCharacters(in: .whitespaces)
        .replacingOccurrences(of: #"(?i)^due\s+"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)

    // Each keyword's value runs from its end to the start of the next keyword (or end of string).
    for (i, match) in matches.enumerated() {
        let start = match.range.upperBound
        let end   = i + 1 < matches.count ? matches[i + 1].range.lowerBound : work.endIndex
        let value = String(work[start..<end]).trimmingCharacters(in: .whitespaces)
        switch match.field {
        case "repeat":   result.recurrence = value
        case "priority": result.priority   = value
        case "url":      result.url        = value
        default: break
        }
    }

    return result
}

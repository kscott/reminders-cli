// WhatCommand.swift
//
// Handler for the `what` command — displays activity log entries via GetClearKit.

import Foundation
import GetClearKit

func handleWhat(args: [String], semaphore: DispatchSemaphore) {
    let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
    guard let range = parseRange(rangeStr) else { fail("Unrecognised range: \(rangeStr)") }
    let isToday = rangeStr == "today"
    var dateUsed = Date()
    let entries: [ActivityLogEntry]
    if isToday {
        let result = ActivityLogReader.entriesForDisplay(in: range.start...range.end)
        entries = result.entries; dateUsed = result.dateUsed
    } else {
        entries = ActivityLogReader.entries(in: range.start...range.end, tool: "reminders")
    }
    print(ActivityLogFormatter.perToolWhat(entries: entries, range: range, rangeStr: rangeStr,
                                           tool: "reminders", dateUsed: dateUsed))
    semaphore.signal()
}

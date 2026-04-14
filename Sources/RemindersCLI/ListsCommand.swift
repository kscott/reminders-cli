// ListsCommand.swift
//
// Handler for the `lists` command — prints all reminder list names sorted alphabetically.

import EventKit
import Foundation

func handleLists(store: EKEventStore, semaphore: DispatchSemaphore) {
    print(store.calendars(for: .reminder).map { $0.title }.sorted().joined(separator: "\n"))
    semaphore.signal()
}

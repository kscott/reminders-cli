// OpenCommand.swift
//
// Opens the Reminders app via NSWorkspace.

import AppKit
import Foundation

func handleOpen(semaphore: DispatchSemaphore) {
    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
    semaphore.signal()
}

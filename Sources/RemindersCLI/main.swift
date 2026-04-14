// main.swift
//
// Entry point for reminders-bin. Argument dispatch and EventKit lifecycle only.
// Business logic lives in RemindersLib. EventKit helpers live in RemindersCLI/*.swift.

import Foundation
import EventKit
import RemindersLib
import GetClearKit

let versionString = "\(builtVersion) (Get Clear \(suiteVersion))"

let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
let args = Array(CommandLine.arguments.dropFirst())

let dispatch = parseArgs(args)
if case .version = dispatch { print(versionString); exit(0) }
guard case .command(let cmd, let args) = dispatch else { usage() }

store.requestFullAccessToReminders { granted, _ in
    guard granted else { fail("Reminders access denied") }

    switch cmd {
    case "what":           handleWhat(args: args, semaphore: semaphore)
    case "open":           handleOpen(semaphore: semaphore)
    case "lists":          handleLists(store: store, semaphore: semaphore)
    case "list":           handleList(args: args, store: store, semaphore: semaphore)
    case "add":            handleAdd(args: args, store: store, semaphore: semaphore)
    case "change":         handleChange(args: args, store: store, semaphore: semaphore)
    case "show":           handleShow(args: args, store: store, semaphore: semaphore)
    case "rename":         handleRename(args: args, store: store, semaphore: semaphore)
    case "find":           handleFind(args: args, store: store, semaphore: semaphore)
    case "done", "remove": handleDoneOrRemove(cmd: cmd, args: args, store: store, semaphore: semaphore)
    default:               usage()
    }
}

semaphore.wait()

UpdateChecker.spawnBackgroundCheckIfNeeded()
if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }

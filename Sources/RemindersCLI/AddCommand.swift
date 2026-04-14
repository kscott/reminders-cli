// AddCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleAdd(args: [String], store: EKEventStore, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide a reminder title") }
    let title = args[1]
    var listName: String? = nil
    var opts = ParsedOptions()
    let allCalendars = store.calendars(for: .reminder)
    if args.count > 2 {
        let remaining = Array(args.dropFirst(2))
        let rawString: String
        if allCalendars.map({ $0.title }).contains(remaining[0]) {
            listName = remaining[0]
            rawString = remaining.dropFirst().joined(separator: " ")
        } else {
            rawString = remaining.joined(separator: " ")
        }
        opts = parseOptions(rawString)
    }
    let parsedDate = opts.date.isEmpty ? nil : parseDate(opts.date)
    let recurrenceSpec: RecurrenceSpec?
    if opts.recurrence.isEmpty {
        recurrenceSpec = nil
    } else {
        guard let spec = parseRecurrence(opts.recurrence) else {
            fail("Unrecognised repeat: \"\(opts.recurrence)\"")
        }
        recurrenceSpec = spec
    }
    guard let cal = listName.flatMap({ name in allCalendars.first { $0.title == name } })
                    ?? store.defaultCalendarForNewReminders() else {
        fail("List not found: \(listName ?? "default")")
    }
    let reminder = EKReminder(eventStore: store)
    reminder.title = title
    reminder.calendar = cal
    if let pd = parsedDate {
        let fields: Set<Calendar.Component> = pd.hasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        reminder.dueDateComponents = Calendar.current.dateComponents(fields, from: pd.date)
    }
    if let spec = recurrenceSpec            { reminder.addRecurrenceRule(toEKRule(spec)) }
    if let p = parsePriority(opts.priority) { reminder.priority = p }
    if !opts.note.isEmpty                   { reminder.notes = opts.note }
    if !opts.url.isEmpty, let u = URL(string: opts.url) { reminder.url = u }
    do {
        try store.save(reminder, commit: true)
        try? ActivityLog.write(tool: "reminders", cmd: "add", desc: title, container: cal.title)
        var parts = ["Added: \(title) (in \(cal.title))"]
        if let pd = parsedDate    { parts.append("due \(formatDate(pd.date, showTime: pd.hasTime))") }
        if let s = recurrenceSpec { parts.append(describeRecurrence(s)) }
        if !opts.priority.isEmpty { parts.append("priority \(opts.priority)") }
        if !opts.note.isEmpty     { parts.append("+ note") }
        if !opts.url.isEmpty      { parts.append("url \(opts.url)") }
        print(parts.joined(separator: " · "))
    } catch {
        fail("Could not save reminder: \(error.localizedDescription)")
    }
    semaphore.signal()
}

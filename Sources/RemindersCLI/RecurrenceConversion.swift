// RecurrenceConversion.swift
//
// Converts a RecurrenceSpec to an EKRecurrenceRule for saving to EventKit.
// Lives in RemindersCLI — not RemindersLib — because the return type is an EventKit object.

import EventKit
import RemindersLib

func toEKRule(_ spec: RecurrenceSpec) -> EKRecurrenceRule {
    let ekFreqs: [RecurrenceFrequency: EKRecurrenceFrequency] =
        [.daily: .daily, .weekly: .weekly, .monthly: .monthly, .yearly: .yearly]
    if let ow = spec.ordinalWeekday {
        let dow = EKRecurrenceDayOfWeek(
            dayOfTheWeek: EKWeekday(rawValue: ow.weekday)!,
            weekNumber: ow.weekNumber)
        return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1,
                                daysOfTheWeek: [dow], daysOfTheMonth: nil,
                                monthsOfTheYear: nil, weeksOfTheYear: nil,
                                daysOfTheYear: nil, setPositions: nil, end: nil)
    }
    if let day = spec.dayOfMonth {
        return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1,
                                daysOfTheWeek: nil, daysOfTheMonth: [NSNumber(value: day)],
                                monthsOfTheYear: nil, weeksOfTheYear: nil,
                                daysOfTheYear: nil, setPositions: nil, end: nil)
    }
    return EKRecurrenceRule(recurrenceWith: ekFreqs[spec.frequency]!, interval: spec.interval, end: nil)
}

func describeEKRule(_ rule: EKRecurrenceRule) -> String {
    switch rule.frequency {
    case .daily:   return "daily"
    case .weekly:  return rule.interval > 1 ? "every \(rule.interval) weeks" : "weekly"
    case .monthly: return rule.interval > 1 ? "every \(rule.interval) months" : "monthly"
    case .yearly:  return "yearly"
    @unknown default: return "repeating"
    }
}

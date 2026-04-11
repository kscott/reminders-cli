// RecurrenceParsingTests.swift
//
// Tests for RecurrenceParsing — natural-language recurrence string parsing.

import Foundation
import RemindersLib

func runRecurrenceParsingTests(_ t: TestRunner) {
    t.suite("Recurrence — simple keywords") {
        t.expect("daily",    parseRecurrence("daily")?.frequency   == .daily)
        t.expect("weekly",   parseRecurrence("weekly")?.frequency  == .weekly)
        t.expect("monthly",  parseRecurrence("monthly")?.frequency == .monthly)
        t.expect("yearly",   parseRecurrence("yearly")?.frequency  == .yearly)
        t.expect("annually", parseRecurrence("annually")?.frequency == .yearly)
        t.expect("every day",   parseRecurrence("every day")?.frequency   == .daily)
        t.expect("every week",  parseRecurrence("every week")?.frequency  == .weekly)
        t.expect("every month", parseRecurrence("every month")?.frequency == .monthly)
        t.expect("every year",  parseRecurrence("every year")?.frequency  == .yearly)
        t.expect("simple has interval 1", parseRecurrence("weekly")?.interval == 1)
        t.expect("simple has no ordinal", parseRecurrence("weekly")?.ordinalWeekday == nil)
        t.expect("unknown returns nil",   parseRecurrence("banana") == nil)
    }

    t.suite("Recurrence — intervals") {
        let e2w = parseRecurrence("every 2 weeks")
        t.expect("every 2 weeks — frequency", e2w?.frequency == .weekly)
        t.expect("every 2 weeks — interval",  e2w?.interval  == 2)

        let e3m = parseRecurrence("every 3 months")
        t.expect("every 3 months — frequency", e3m?.frequency == .monthly)
        t.expect("every 3 months — interval",  e3m?.interval  == 3)

        let e6d = parseRecurrence("every 6 days")
        t.expect("every 6 days — frequency", e6d?.frequency == .daily)
        t.expect("every 6 days — interval",  e6d?.interval  == 6)

        let e2y = parseRecurrence("every 2 years")
        t.expect("every 2 years — frequency", e2y?.frequency == .yearly)
        t.expect("every 2 years — interval",  e2y?.interval  == 2)
    }

    t.suite("Recurrence — ordinal weekday (word)") {
        let lastTue = parseRecurrence("last tuesday")
        t.expect("last tuesday — monthly",    lastTue?.frequency                  == .monthly)
        t.expect("last tuesday — weekNumber", lastTue?.ordinalWeekday?.weekNumber == -1)
        t.expect("last tuesday — weekday",    lastTue?.ordinalWeekday?.weekday    == 3)

        let firstFri = parseRecurrence("first friday")
        t.expect("first friday — weekNumber", firstFri?.ordinalWeekday?.weekNumber == 1)
        t.expect("first friday — weekday",    firstFri?.ordinalWeekday?.weekday    == 6)

        let secondMon = parseRecurrence("second monday")
        t.expect("second monday — weekNumber", secondMon?.ordinalWeekday?.weekNumber == 2)
        t.expect("second monday — weekday",    secondMon?.ordinalWeekday?.weekday    == 2)

        let thirdWed = parseRecurrence("third wednesday")
        t.expect("third wednesday — weekNumber", thirdWed?.ordinalWeekday?.weekNumber == 3)
        t.expect("third wednesday — weekday",    thirdWed?.ordinalWeekday?.weekday    == 4)

        let fourthSun = parseRecurrence("fourth sunday")
        t.expect("fourth sunday — weekNumber", fourthSun?.ordinalWeekday?.weekNumber == 4)
        t.expect("fourth sunday — weekday",    fourthSun?.ordinalWeekday?.weekday    == 1)

        let withThe = parseRecurrence("the last wednesday")
        t.expect("the last wednesday — weekNumber", withThe?.ordinalWeekday?.weekNumber == -1)
        t.expect("the last wednesday — weekday",    withThe?.ordinalWeekday?.weekday    == 4)

        let withOn = parseRecurrence("on the first friday")
        t.expect("on the first friday — weekNumber", withOn?.ordinalWeekday?.weekNumber == 1)
        t.expect("on the first friday — weekday",    withOn?.ordinalWeekday?.weekday    == 6)
    }

    t.suite("Recurrence — ordinal weekday (numeric)") {
        let s1 = parseRecurrence("1st monday")
        t.expect("1st monday — weekNumber", s1?.ordinalWeekday?.weekNumber == 1)
        t.expect("1st monday — weekday",    s1?.ordinalWeekday?.weekday    == 2)

        let s2 = parseRecurrence("2nd wednesday")
        t.expect("2nd wednesday — weekNumber", s2?.ordinalWeekday?.weekNumber == 2)
        t.expect("2nd wednesday — weekday",    s2?.ordinalWeekday?.weekday    == 4)

        let s3 = parseRecurrence("3rd friday")
        t.expect("3rd friday — weekNumber", s3?.ordinalWeekday?.weekNumber == 3)
        t.expect("3rd friday — weekday",    s3?.ordinalWeekday?.weekday    == 6)

        let s4 = parseRecurrence("4th thursday")
        t.expect("4th thursday — weekNumber", s4?.ordinalWeekday?.weekNumber == 4)
        t.expect("4th thursday — weekday",    s4?.ordinalWeekday?.weekday    == 5)
    }

    t.suite("Recurrence — day of month") {
        let d1 = parseRecurrence("the 1st")
        t.expect("the 1st — monthly",    d1?.frequency  == .monthly)
        t.expect("the 1st — dayOfMonth", d1?.dayOfMonth == 1)

        let d15 = parseRecurrence("the 15th")
        t.expect("the 15th — dayOfMonth", d15?.dayOfMonth == 15)

        let d22 = parseRecurrence("on the 22nd")
        t.expect("on the 22nd — dayOfMonth", d22?.dayOfMonth == 22)

        let dom = parseRecurrence("2nd of the month")
        t.expect("2nd of the month — dayOfMonth", dom?.dayOfMonth == 2)

        let dom2 = parseRecurrence("on the 1st of the month")
        t.expect("on the 1st of the month — dayOfMonth", dom2?.dayOfMonth == 1)

        let notDay = parseRecurrence("2nd wednesday")
        t.expect("2nd wednesday is not day-of-month", notDay?.dayOfMonth == nil)
        t.expect("2nd wednesday is ordinal weekday",   notDay?.ordinalWeekday != nil)
    }

    t.suite("Recurrence — splitOnRepeat") {
        let kw = ["repeat", "repeats", "repeating", "repeated"]
        for word in kw {
            let (d, r) = splitOnRepeat("march 1 \(word) monthly")
            t.expect("\(word): date part",       d == "march 1")
            t.expect("\(word): recurrence part", r == "monthly")
        }

        let (d1, r1) = splitOnRepeat("repeat daily")
        t.expect("repeat before date: date empty",      d1 == "")
        t.expect("repeat before date: recurrence part", r1 == "daily")

        let (d2, r2) = splitOnRepeat("tuesday at 3pm repeating weekly")
        t.expect("after date+time: date part",       d2 == "tuesday at 3pm")
        t.expect("after date+time: recurrence part", r2 == "weekly")

        let (d3, r3) = splitOnRepeat("tuesday at 3pm")
        t.expect("no keyword: full string as date", d3 == "tuesday at 3pm")
        t.expect("no keyword: recurrence empty",    r3 == "")

        let (d4, r4) = splitOnRepeat("repeating last tuesday")
        t.expect("ordinal: date empty",      d4 == "")
        t.expect("ordinal: recurrence part", r4 == "last tuesday")
    }

    t.suite("Recurrence — descriptions") {
        let daily = RecurrenceSpec(frequency: .daily, interval: 1)
        t.expect("describe daily",   describeRecurrence(daily)   == "repeat daily")

        let e2w = RecurrenceSpec(frequency: .weekly, interval: 2)
        t.expect("describe every 2 weeks", describeRecurrence(e2w) == "repeat every 2 weeks")

        let lastTue = RecurrenceSpec(frequency: .monthly, interval: 1,
                                     ordinalWeekday: .init(weekday: 3, weekNumber: -1))
        t.expect("describe last tuesday", describeRecurrence(lastTue) == "repeat last tuesday of the month")

        let firstFri = RecurrenceSpec(frequency: .monthly, interval: 1,
                                      ordinalWeekday: .init(weekday: 6, weekNumber: 1))
        t.expect("describe first friday", describeRecurrence(firstFri) == "repeat first friday of the month")

        let dom1  = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 1)
        t.expect("describe 1st of month",  describeRecurrence(dom1)  == "repeat on the 1st of the month")

        let dom15 = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 15)
        t.expect("describe 15th of month", describeRecurrence(dom15) == "repeat on the 15th of the month")

        let dom22 = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 22)
        t.expect("describe 22nd of month", describeRecurrence(dom22) == "repeat on the 22nd of the month")

        let dom3  = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 3)
        t.expect("describe 3rd of month",  describeRecurrence(dom3)  == "repeat on the 3rd of the month")
    }
}

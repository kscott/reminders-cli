// main.swift — test runner for RemindersLib
//
// Does not require Xcode or XCTest — runs with just the Swift CLI toolchain.
// Run via:  reminders test

import Foundation
import RemindersLib

// MARK: - Minimal test harness

final class TestRunner: @unchecked Sendable {
    private var passed = 0
    private var failed = 0

    func expect(_ description: String, _ condition: Bool, file: String = #file, line: Int = #line) {
        if condition {
            print("  ✓ \(description)")
            passed += 1
        } else {
            print("  ✗ \(description)  [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]")
            failed += 1
        }
    }

    func suite(_ name: String, _ body: () -> Void) {
        print("\n\(name)")
        body()
    }

    func run() {
        let cal = Calendar.current

        func ymd(_ date: Date) -> DateComponents {
            cal.dateComponents([.year, .month, .day], from: date)
        }
        func hm(_ date: Date) -> DateComponents {
            cal.dateComponents([.hour, .minute], from: date)
        }

        suite("Default time") {
            let date = parseDate("tomorrow")!
            expect("defaults to 9:00 AM", hm(date).hour == 9 && hm(date).minute == 0)
        }

        suite("Relative days") {
            expect("today matches current date", ymd(parseDate("today")!) == ymd(Date()))
            let tomorrow = ymd(cal.date(byAdding: .day, value: 1, to: Date())!)
            expect("tomorrow is tomorrow", ymd(parseDate("tomorrow")!) == tomorrow)
        }

        suite("Weekdays") {
            let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            let oneWeekFromNow = cal.date(byAdding: .day, value: 7, to: Date())!
            for day in weekdays {
                let date = parseDate(day)!
                expect("\(day) is in the future", date > Date())
                expect("\(day) is within 7 days", date <= oneWeekFromNow)
            }
        }

        suite("Month + day") {
            let date = parseDate("march 15")!
            expect("march 15 — correct month", ymd(date).month == 3)
            expect("march 15 — correct day",   ymd(date).day   == 15)
            let jan1 = parseDate("january 1")!
            expect("january 1 rolls to future if past", jan1 >= Date())
        }

        suite("Numeric dates") {
            let iso = parseDate("2026-03-15")!
            expect("ISO year",  ymd(iso).year  == 2026)
            expect("ISO month", ymd(iso).month == 3)
            expect("ISO day",   ymd(iso).day   == 15)

            let slash = parseDate("3/15")!
            expect("3/15 month", ymd(slash).month == 3)
            expect("3/15 day",   ymd(slash).day   == 15)

            let dash = parseDate("3-15")!
            expect("3-15 month", ymd(dash).month == 3)
            expect("3-15 day",   ymd(dash).day   == 15)

            expect("1/1 rolls to future if past", parseDate("1/1")! >= Date())
        }

        suite("Time parsing") {
            expect("3pm is hour 15",   hm(parseDate("3pm")!).hour  == 15)
            expect("10am is hour 10",  hm(parseDate("10am")!).hour == 10)
            expect("12pm is noon",     hm(parseDate("12pm")!).hour == 12)
            expect("12am is midnight", hm(parseDate("12am")!).hour == 0)
            expect("14:30 hour",       hm(parseDate("14:30")!).hour   == 14)
            expect("14:30 minute",     hm(parseDate("14:30")!).minute == 30)
            expect("2:45pm hour",      hm(parseDate("2:45pm")!).hour   == 14)
            expect("2:45pm minute",    hm(parseDate("2:45pm")!).minute == 45)
        }

        suite("Combined day + time") {
            let t1 = parseDate("tomorrow 3pm")!
            let tomorrow = ymd(cal.date(byAdding: .day, value: 1, to: Date())!)
            expect("tomorrow 3pm — correct day",  ymd(t1) == tomorrow)
            expect("tomorrow 3pm — correct time", hm(t1).hour == 15)

            let t2 = parseDate("friday at 5pm")!
            expect("friday at 5pm — in the future", t2 > Date())
            expect("friday at 5pm — correct time",  hm(t2).hour == 17)

            let t3 = parseDate("march 15 9am")!
            expect("march 15 9am — month", ymd(t3).month == 3)
            expect("march 15 9am — day",   ymd(t3).day   == 15)
            expect("march 15 9am — hour",  hm(t3).hour   == 9)
        }

        suite("Invalid input") {
            expect("garbage returns nil",  parseDate("not a date") == nil)
            expect("nonsense returns nil", parseDate("banana")     == nil)
        }

        suite("Recurrence — simple keywords") {
            expect("daily",    parseRecurrence("daily")?.frequency   == .daily)
            expect("weekly",   parseRecurrence("weekly")?.frequency  == .weekly)
            expect("monthly",  parseRecurrence("monthly")?.frequency == .monthly)
            expect("yearly",   parseRecurrence("yearly")?.frequency  == .yearly)
            expect("annually", parseRecurrence("annually")?.frequency == .yearly)
            expect("every day",   parseRecurrence("every day")?.frequency   == .daily)
            expect("every week",  parseRecurrence("every week")?.frequency  == .weekly)
            expect("every month", parseRecurrence("every month")?.frequency == .monthly)
            expect("every year",  parseRecurrence("every year")?.frequency  == .yearly)
            expect("simple has interval 1", parseRecurrence("weekly")?.interval == 1)
            expect("simple has no ordinal", parseRecurrence("weekly")?.ordinalWeekday == nil)
            expect("unknown returns nil",   parseRecurrence("banana") == nil)
        }

        suite("Recurrence — intervals") {
            let e2w = parseRecurrence("every 2 weeks")
            expect("every 2 weeks — frequency", e2w?.frequency == .weekly)
            expect("every 2 weeks — interval",  e2w?.interval  == 2)

            let e3m = parseRecurrence("every 3 months")
            expect("every 3 months — frequency", e3m?.frequency == .monthly)
            expect("every 3 months — interval",  e3m?.interval  == 3)

            let e6d = parseRecurrence("every 6 days")
            expect("every 6 days — frequency", e6d?.frequency == .daily)
            expect("every 6 days — interval",  e6d?.interval  == 6)

            let e2y = parseRecurrence("every 2 years")
            expect("every 2 years — frequency", e2y?.frequency == .yearly)
            expect("every 2 years — interval",  e2y?.interval  == 2)
        }

        suite("Recurrence — ordinal weekday (word)") {
            let lastTue = parseRecurrence("last tuesday")
            expect("last tuesday — monthly",    lastTue?.frequency                  == .monthly)
            expect("last tuesday — weekNumber", lastTue?.ordinalWeekday?.weekNumber == -1)
            expect("last tuesday — weekday",    lastTue?.ordinalWeekday?.weekday    == 3)

            let firstFri = parseRecurrence("first friday")
            expect("first friday — weekNumber", firstFri?.ordinalWeekday?.weekNumber == 1)
            expect("first friday — weekday",    firstFri?.ordinalWeekday?.weekday    == 6)

            let secondMon = parseRecurrence("second monday")
            expect("second monday — weekNumber", secondMon?.ordinalWeekday?.weekNumber == 2)
            expect("second monday — weekday",    secondMon?.ordinalWeekday?.weekday    == 2)

            let thirdWed = parseRecurrence("third wednesday")
            expect("third wednesday — weekNumber", thirdWed?.ordinalWeekday?.weekNumber == 3)
            expect("third wednesday — weekday",    thirdWed?.ordinalWeekday?.weekday    == 4)

            let fourthSun = parseRecurrence("fourth sunday")
            expect("fourth sunday — weekNumber", fourthSun?.ordinalWeekday?.weekNumber == 4)
            expect("fourth sunday — weekday",    fourthSun?.ordinalWeekday?.weekday    == 1)

            // leading articles are ignored
            let withThe = parseRecurrence("the last wednesday")
            expect("the last wednesday — weekNumber", withThe?.ordinalWeekday?.weekNumber == -1)
            expect("the last wednesday — weekday",    withThe?.ordinalWeekday?.weekday    == 4)

            let withOn = parseRecurrence("on the first friday")
            expect("on the first friday — weekNumber", withOn?.ordinalWeekday?.weekNumber == 1)
            expect("on the first friday — weekday",    withOn?.ordinalWeekday?.weekday    == 6)
        }

        suite("Recurrence — ordinal weekday (numeric)") {
            let s1 = parseRecurrence("1st monday")
            expect("1st monday — weekNumber", s1?.ordinalWeekday?.weekNumber == 1)
            expect("1st monday — weekday",    s1?.ordinalWeekday?.weekday    == 2)

            let s2 = parseRecurrence("2nd wednesday")
            expect("2nd wednesday — weekNumber", s2?.ordinalWeekday?.weekNumber == 2)
            expect("2nd wednesday — weekday",    s2?.ordinalWeekday?.weekday    == 4)

            let s3 = parseRecurrence("3rd friday")
            expect("3rd friday — weekNumber", s3?.ordinalWeekday?.weekNumber == 3)
            expect("3rd friday — weekday",    s3?.ordinalWeekday?.weekday    == 6)

            let s4 = parseRecurrence("4th thursday")
            expect("4th thursday — weekNumber", s4?.ordinalWeekday?.weekNumber == 4)
            expect("4th thursday — weekday",    s4?.ordinalWeekday?.weekday    == 5)
        }

        suite("Recurrence — day of month") {
            let d1 = parseRecurrence("the 1st")
            expect("the 1st — monthly",    d1?.frequency  == .monthly)
            expect("the 1st — dayOfMonth", d1?.dayOfMonth == 1)

            let d15 = parseRecurrence("the 15th")
            expect("the 15th — dayOfMonth", d15?.dayOfMonth == 15)

            let d22 = parseRecurrence("on the 22nd")
            expect("on the 22nd — dayOfMonth", d22?.dayOfMonth == 22)

            let dom = parseRecurrence("2nd of the month")
            expect("2nd of the month — dayOfMonth", dom?.dayOfMonth == 2)

            let dom2 = parseRecurrence("on the 1st of the month")
            expect("on the 1st of the month — dayOfMonth", dom2?.dayOfMonth == 1)

            // numeric ordinal weekday must NOT be confused with day-of-month
            let notDay = parseRecurrence("2nd wednesday")
            expect("2nd wednesday is not day-of-month", notDay?.dayOfMonth == nil)
            expect("2nd wednesday is ordinal weekday",   notDay?.ordinalWeekday != nil)
        }

        suite("parseOptions — date only") {
            let o = parseOptions("friday at 3pm")
            expect("date captured",      o.date       == "friday at 3pm")
            expect("recurrence empty",   o.recurrence == "")
            expect("priority empty",     o.priority   == "")
            expect("note empty",         o.note       == "")
            expect("url empty",          o.url        == "")
        }

        suite("parseOptions — repeat") {
            let o = parseOptions("march 1 repeat monthly")
            expect("date part",      o.date       == "march 1")
            expect("recurrence",     o.recurrence == "monthly")
        }

        suite("parseOptions — priority") {
            expect("high",   parseOptions("priority high").priority   == "high")
            expect("medium", parseOptions("priority medium").priority == "medium")
            expect("low",    parseOptions("priority low").priority    == "low")
            expect("none",   parseOptions("priority none").priority   == "none")
        }

        suite("parseOptions — url") {
            let o = parseOptions("url https://example.com")
            expect("url captured", o.url == "https://example.com")
            expect("date empty",   o.date == "")
        }

        suite("parseOptions — note captures to end of string") {
            let o = parseOptions("tomorrow note pick up dry cleaning priority urgent")
            expect("date part",                  o.date == "tomorrow")
            expect("note captures everything",   o.note == "pick up dry cleaning priority urgent")
            expect("priority not parsed",        o.priority == "")
        }

        suite("parseOptions — multiple fields") {
            let o = parseOptions("friday repeat weekly priority high url https://example.com note check the dashboard")
            expect("date",       o.date       == "friday")
            expect("recurrence", o.recurrence == "weekly")
            expect("priority",   o.priority   == "high")
            expect("url",        o.url        == "https://example.com")
            expect("note",       o.note       == "check the dashboard")
        }

        suite("parseOptions — fields without date") {
            let o = parseOptions("repeat daily priority low note take with food")
            expect("date empty",   o.date       == "")
            expect("recurrence",   o.recurrence == "daily")
            expect("priority",     o.priority   == "low")
            expect("note",         o.note       == "take with food")
        }

        suite("parseOptions — any keyword order") {
            let o1 = parseOptions("priority high repeat weekly")
            expect("priority before repeat — priority", o1.priority   == "high")
            expect("priority before repeat — repeat",   o1.recurrence == "weekly")

            let o2 = parseOptions("url https://example.com priority medium")
            expect("url before priority — url",      o2.url      == "https://example.com")
            expect("url before priority — priority", o2.priority == "medium")
        }

        suite("Recurrence — splitOnRepeat") {
            // keyword variants
            let kw = ["repeat", "repeats", "repeating", "repeated"]
            for word in kw {
                let (d, r) = splitOnRepeat("march 1 \(word) monthly")
                expect("\(word): date part",      d == "march 1")
                expect("\(word): recurrence part", r == "monthly")
            }

            // repeat before date
            let (d1, r1) = splitOnRepeat("repeat daily")
            expect("repeat before date: date empty",      d1 == "")
            expect("repeat before date: recurrence part", r1 == "daily")

            // repeat after date+time
            let (d2, r2) = splitOnRepeat("tuesday at 3pm repeating weekly")
            expect("after date+time: date part",      d2 == "tuesday at 3pm")
            expect("after date+time: recurrence part", r2 == "weekly")

            // no repeat keyword
            let (d3, r3) = splitOnRepeat("tuesday at 3pm")
            expect("no keyword: full string as date", d3 == "tuesday at 3pm")
            expect("no keyword: recurrence empty",    r3 == "")

            // ordinal after keyword
            let (d4, r4) = splitOnRepeat("repeating last tuesday")
            expect("ordinal: date empty",      d4 == "")
            expect("ordinal: recurrence part", r4 == "last tuesday")
        }

        suite("Recurrence — descriptions") {
            let daily = RecurrenceSpec(frequency: .daily, interval: 1)
            expect("describe daily",   describeRecurrence(daily)   == "repeat daily")

            let e2w = RecurrenceSpec(frequency: .weekly, interval: 2)
            expect("describe every 2 weeks", describeRecurrence(e2w) == "repeat every 2 weeks")

            let lastTue = RecurrenceSpec(frequency: .monthly, interval: 1,
                                         ordinalWeekday: .init(weekday: 3, weekNumber: -1))
            expect("describe last tuesday", describeRecurrence(lastTue) == "repeat last tuesday of the month")

            let firstFri = RecurrenceSpec(frequency: .monthly, interval: 1,
                                          ordinalWeekday: .init(weekday: 6, weekNumber: 1))
            expect("describe first friday", describeRecurrence(firstFri) == "repeat first friday of the month")

            let dom1  = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 1)
            expect("describe 1st of month",  describeRecurrence(dom1)  == "repeat on the 1st of the month")

            let dom15 = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 15)
            expect("describe 15th of month", describeRecurrence(dom15) == "repeat on the 15th of the month")

            let dom22 = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 22)
            expect("describe 22nd of month", describeRecurrence(dom22) == "repeat on the 22nd of the month")

            let dom3  = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 3)
            expect("describe 3rd of month",  describeRecurrence(dom3)  == "repeat on the 3rd of the month")
        }

        print("\n\(passed + failed) tests: \(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}

TestRunner().run()

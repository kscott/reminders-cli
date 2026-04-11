// DateParserTests.swift
//
// Tests for GetClearKit DateParser — date and time string parsing.

import Foundation
import RemindersLib
import GetClearKit

func runDateParserTests(_ t: TestRunner) {
    let cal = Calendar.current

    func ymd(_ date: Date) -> DateComponents {
        cal.dateComponents([.year, .month, .day], from: date)
    }
    func hm(_ date: Date) -> DateComponents {
        cal.dateComponents([.hour, .minute], from: date)
    }

    t.suite("hasTime flag") {
        t.expect("date only — hasTime false",  parseDate("tomorrow")?.hasTime   == false)
        t.expect("date only — hasTime false",  parseDate("friday")?.hasTime     == false)
        t.expect("date only — hasTime false",  parseDate("march 15")?.hasTime   == false)
        t.expect("time included — hasTime true", parseDate("3pm")?.hasTime      == true)
        t.expect("time included — hasTime true", parseDate("tomorrow 3pm")?.hasTime == true)
        t.expect("time included — hasTime true", parseDate("friday at 5pm")?.hasTime == true)
    }

    t.suite("hasDate flag") {
        t.expect("time only — hasDate false",       parseDate("3pm")?.hasDate          == false)
        t.expect("time only — hasDate false",       parseDate("8:30pm")?.hasDate       == false)
        t.expect("time only — hasDate false",       parseDate("14:30")?.hasDate        == false)
        t.expect("tomorrow — hasDate true",         parseDate("tomorrow")?.hasDate     == true)
        t.expect("weekday — hasDate true",          parseDate("friday")?.hasDate       == true)
        t.expect("month+day — hasDate true",        parseDate("march 15")?.hasDate     == true)
        t.expect("ISO date — hasDate true",         parseDate("2026-03-15")?.hasDate   == true)
        t.expect("date+time — hasDate true",        parseDate("friday at 5pm")?.hasDate == true)
        t.expect("tomorrow+time — hasDate true",    parseDate("tomorrow 3pm")?.hasDate == true)
    }

    t.suite("Relative days") {
        t.expect("today matches current date", ymd(parseDate("today")!.date) == ymd(Date()))
        let tomorrow = ymd(cal.date(byAdding: .day, value: 1, to: Date())!)
        t.expect("tomorrow is tomorrow", ymd(parseDate("tomorrow")!.date) == tomorrow)
    }

    t.suite("Weekdays") {
        let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        for day in weekdays {
            let pd = parseDate(day)!
            t.expect("\(day) is in the future", pd.date > Date())
            let dayDiff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                                        to: cal.startOfDay(for: pd.date)).day!
            t.expect("\(day) is within 7 days", dayDiff <= 7)
        }
    }

    t.suite("next/this prefix") {
        let friday     = parseDate("friday")!.date
        let nextFriday = parseDate("next friday")!.date
        let thisFriday = parseDate("this friday")!.date
        t.expect("next friday == friday", nextFriday == friday)
        t.expect("this friday == friday", thisFriday == friday)

        let monday     = parseDate("monday")!.date
        let nextMonday = parseDate("next monday")!.date
        t.expect("next monday == monday", nextMonday == monday)
    }

    t.suite("Month + day") {
        let pd = parseDate("march 15")!
        t.expect("march 15 — correct month", ymd(pd.date).month == 3)
        t.expect("march 15 — correct day",   ymd(pd.date).day   == 15)
        let jan1 = parseDate("january 1")!
        t.expect("january 1 rolls to future if past", jan1.date >= Date())
    }

    t.suite("Month + day + year") {
        let a = parseDate("march 10 2027")!
        t.expect("march 10 2027 — year",  ymd(a.date).year  == 2027)
        t.expect("march 10 2027 — month", ymd(a.date).month == 3)
        t.expect("march 10 2027 — day",   ymd(a.date).day   == 10)

        let b = parseDate("march 10, 2027")!
        t.expect("march 10, 2027 — year",  ymd(b.date).year  == 2027)
        t.expect("march 10, 2027 — month", ymd(b.date).month == 3)
        t.expect("march 10, 2027 — day",   ymd(b.date).day   == 10)

        let c = parseDate("10 march 2027")!
        t.expect("10 march 2027 — year",  ymd(c.date).year  == 2027)
        t.expect("10 march 2027 — month", ymd(c.date).month == 3)
        t.expect("10 march 2027 — day",   ymd(c.date).day   == 10)

        let d = parseDate("january 1 28")!
        t.expect("january 1 28 — 2-digit year expands to 2028", ymd(d.date).year == 2028)
    }

    t.suite("Numeric dates") {
        let iso = parseDate("2026-03-15")!
        t.expect("ISO year",  ymd(iso.date).year  == 2026)
        t.expect("ISO month", ymd(iso.date).month == 3)
        t.expect("ISO day",   ymd(iso.date).day   == 15)

        let slash = parseDate("3/15")!
        t.expect("3/15 month", ymd(slash.date).month == 3)
        t.expect("3/15 day",   ymd(slash.date).day   == 15)

        let dash = parseDate("3-15")!
        t.expect("3-15 month", ymd(dash.date).month == 3)
        t.expect("3-15 day",   ymd(dash.date).day   == 15)

        t.expect("1/1 rolls to future if past", parseDate("1/1")!.date >= Date())

        let usLong = parseDate("3/10/2027")!
        t.expect("3/10/2027 — US M/D/Y — year",  ymd(usLong.date).year  == 2027)
        t.expect("3/10/2027 — US M/D/Y — month", ymd(usLong.date).month == 3)
        t.expect("3/10/2027 — US M/D/Y — day",   ymd(usLong.date).day   == 10)

        let usShort = parseDate("3/10/27")!
        t.expect("3/10/27 — 2-digit year — year",  ymd(usShort.date).year  == 2027)
        t.expect("3/10/27 — 2-digit year — month", ymd(usShort.date).month == 3)
        t.expect("3/10/27 — 2-digit year — day",   ymd(usShort.date).day   == 10)
    }

    t.suite("Time parsing") {
        t.expect("3pm is hour 15",   hm(parseDate("3pm")!.date).hour  == 15)
        t.expect("10am is hour 10",  hm(parseDate("10am")!.date).hour == 10)
        t.expect("12pm is noon",     hm(parseDate("12pm")!.date).hour == 12)
        t.expect("12am is midnight", hm(parseDate("12am")!.date).hour == 0)
        t.expect("14:30 hour",       hm(parseDate("14:30")!.date).hour   == 14)
        t.expect("14:30 minute",     hm(parseDate("14:30")!.date).minute == 30)
        t.expect("2:45pm hour",      hm(parseDate("2:45pm")!.date).hour   == 14)
        t.expect("2:45pm minute",    hm(parseDate("2:45pm")!.date).minute == 45)
    }

    t.suite("Combined day + time") {
        let t1 = parseDate("tomorrow 3pm")!
        let tomorrow = ymd(cal.date(byAdding: .day, value: 1, to: Date())!)
        t.expect("tomorrow 3pm — correct day",  ymd(t1.date) == tomorrow)
        t.expect("tomorrow 3pm — correct time", hm(t1.date).hour == 15)

        let t2 = parseDate("friday at 5pm")!
        t.expect("friday at 5pm — in the future", t2.date > Date())
        t.expect("friday at 5pm — correct time",  hm(t2.date).hour == 17)

        let t3 = parseDate("march 15 9am")!
        t.expect("march 15 9am — month", ymd(t3.date).month == 3)
        t.expect("march 15 9am — day",   ymd(t3.date).day   == 15)
        t.expect("march 15 9am — hour",  hm(t3.date).hour   == 9)
    }

    t.suite("Invalid input") {
        t.expect("garbage returns nil",  parseDate("not a date") == nil)
        t.expect("nonsense returns nil", parseDate("banana")     == nil)
    }
}

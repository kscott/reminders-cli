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

        print("\n\(passed + failed) tests: \(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}

TestRunner().run()

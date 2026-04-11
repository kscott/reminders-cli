// DateParserSpec.swift
//
// Tests for GetClearKit DateParser — date and time string parsing.

import Quick
import Nimble
import Foundation
import GetClearKit

final class DateParserSpec: QuickSpec {
    override class func spec() {
        let cal = Calendar.current

        func ymd(_ date: Date) -> DateComponents {
            cal.dateComponents([.year, .month, .day], from: date)
        }
        func hm(_ date: Date) -> DateComponents {
            cal.dateComponents([.hour, .minute], from: date)
        }

        describe("parseDate") {
            context("hasTime flag") {
                it("date-only string has hasTime false") {
                    expect(parseDate("tomorrow")?.hasTime) == false
                }
                it("weekday string has hasTime false") {
                    expect(parseDate("friday")?.hasTime) == false
                }
                it("month+day string has hasTime false") {
                    expect(parseDate("march 15")?.hasTime) == false
                }
                it("time-only string has hasTime true") {
                    expect(parseDate("3pm")?.hasTime) == true
                }
                it("date+time string has hasTime true") {
                    expect(parseDate("tomorrow 3pm")?.hasTime) == true
                }
                it("weekday+time string has hasTime true") {
                    expect(parseDate("friday at 5pm")?.hasTime) == true
                }
            }

            context("hasDate flag") {
                it("time-only string has hasDate false") {
                    expect(parseDate("3pm")?.hasDate) == false
                }
                it("12-hour time string has hasDate false") {
                    expect(parseDate("8:30pm")?.hasDate) == false
                }
                it("24-hour time string has hasDate false") {
                    expect(parseDate("14:30")?.hasDate) == false
                }
                it("'tomorrow' has hasDate true") {
                    expect(parseDate("tomorrow")?.hasDate) == true
                }
                it("weekday string has hasDate true") {
                    expect(parseDate("friday")?.hasDate) == true
                }
                it("month+day string has hasDate true") {
                    expect(parseDate("march 15")?.hasDate) == true
                }
                it("ISO date string has hasDate true") {
                    expect(parseDate("2026-03-15")?.hasDate) == true
                }
                it("weekday+time string has hasDate true") {
                    expect(parseDate("friday at 5pm")?.hasDate) == true
                }
                it("date+time string has hasDate true") {
                    expect(parseDate("tomorrow 3pm")?.hasDate) == true
                }
            }

            context("relative days") {
                it("'today' resolves to the current date") {
                    expect(ymd(parseDate("today")!.date)) == ymd(Date())
                }
                it("'tomorrow' resolves to the next calendar day") {
                    let expected = ymd(cal.date(byAdding: .day, value: 1, to: Date())!)
                    expect(ymd(parseDate("tomorrow")!.date)) == expected
                }
            }

            context("weekdays") {
                it("'monday' resolves to a future date") { expect(parseDate("monday")!.date) > Date() }
                it("'tuesday' resolves to a future date") { expect(parseDate("tuesday")!.date) > Date() }
                it("'wednesday' resolves to a future date") { expect(parseDate("wednesday")!.date) > Date() }
                it("'thursday' resolves to a future date") { expect(parseDate("thursday")!.date) > Date() }
                it("'friday' resolves to a future date") { expect(parseDate("friday")!.date) > Date() }
                it("'saturday' resolves to a future date") { expect(parseDate("saturday")!.date) > Date() }
                it("'sunday' resolves to a future date") { expect(parseDate("sunday")!.date) > Date() }
                it("weekday resolves within the next 7 days") {
                    let diff = cal.dateComponents([.day],
                        from: cal.startOfDay(for: Date()),
                        to: cal.startOfDay(for: parseDate("friday")!.date)).day!
                    expect(diff) <= 7
                }
            }

            context("next/this prefix") {
                it("'next friday' resolves to the same date as 'friday'") {
                    expect(parseDate("next friday")!.date) == parseDate("friday")!.date
                }
                it("'this friday' resolves to the same date as 'friday'") {
                    expect(parseDate("this friday")!.date) == parseDate("friday")!.date
                }
                it("'next monday' resolves to the same date as 'monday'") {
                    expect(parseDate("next monday")!.date) == parseDate("monday")!.date
                }
            }

            context("month and day") {
                it("'march 15' resolves to month 3") {
                    expect(ymd(parseDate("march 15")!.date).month) == 3
                }
                it("'march 15' resolves to day 15") {
                    expect(ymd(parseDate("march 15")!.date).day) == 15
                }
                it("past month+day rolls forward to the future") {
                    expect(parseDate("january 1")!.date) >= Date()
                }
            }

            context("month, day, and year") {
                it("'march 10 2027' resolves to year 2027") {
                    expect(ymd(parseDate("march 10 2027")!.date).year) == 2027
                }
                it("'march 10 2027' resolves to month 3") {
                    expect(ymd(parseDate("march 10 2027")!.date).month) == 3
                }
                it("'march 10 2027' resolves to day 10") {
                    expect(ymd(parseDate("march 10 2027")!.date).day) == 10
                }
                it("comma-separated year 'march 10, 2027' is accepted") {
                    expect(ymd(parseDate("march 10, 2027")!.date).year) == 2027
                }
                it("day-first format '10 march 2027' is accepted") {
                    expect(ymd(parseDate("10 march 2027")!.date).year) == 2027
                }
                it("2-digit year 'january 1 28' expands to 2028") {
                    expect(ymd(parseDate("january 1 28")!.date).year) == 2028
                }
            }

            context("numeric formats") {
                it("ISO '2026-03-15' resolves to year 2026") {
                    expect(ymd(parseDate("2026-03-15")!.date).year) == 2026
                }
                it("ISO '2026-03-15' resolves to month 3") {
                    expect(ymd(parseDate("2026-03-15")!.date).month) == 3
                }
                it("ISO '2026-03-15' resolves to day 15") {
                    expect(ymd(parseDate("2026-03-15")!.date).day) == 15
                }
                it("slash format '3/15' resolves to month 3") {
                    expect(ymd(parseDate("3/15")!.date).month) == 3
                }
                it("slash format '3/15' resolves to day 15") {
                    expect(ymd(parseDate("3/15")!.date).day) == 15
                }
                it("dash format '3-15' resolves to month 3") {
                    expect(ymd(parseDate("3-15")!.date).month) == 3
                }
                it("dash format '3-15' resolves to day 15") {
                    expect(ymd(parseDate("3-15")!.date).day) == 15
                }
                it("past numeric date rolls forward to the future") {
                    expect(parseDate("1/1")!.date) >= Date()
                }
                it("US M/D/Y '3/10/2027' resolves to year 2027") {
                    expect(ymd(parseDate("3/10/2027")!.date).year) == 2027
                }
                it("US M/D/Y '3/10/2027' resolves to month 3") {
                    expect(ymd(parseDate("3/10/2027")!.date).month) == 3
                }
                it("US M/D/Y '3/10/2027' resolves to day 10") {
                    expect(ymd(parseDate("3/10/2027")!.date).day) == 10
                }
                it("2-digit US year '3/10/27' expands to 2027") {
                    expect(ymd(parseDate("3/10/27")!.date).year) == 2027
                }
            }

            context("time parsing") {
                it("'3pm' resolves to hour 15") {
                    expect(hm(parseDate("3pm")!.date).hour) == 15
                }
                it("'10am' resolves to hour 10") {
                    expect(hm(parseDate("10am")!.date).hour) == 10
                }
                it("'12pm' resolves to noon (hour 12)") {
                    expect(hm(parseDate("12pm")!.date).hour) == 12
                }
                it("'12am' resolves to midnight (hour 0)") {
                    expect(hm(parseDate("12am")!.date).hour) == 0
                }
                it("'14:30' resolves to hour 14") {
                    expect(hm(parseDate("14:30")!.date).hour) == 14
                }
                it("'14:30' resolves to minute 30") {
                    expect(hm(parseDate("14:30")!.date).minute) == 30
                }
                it("'2:45pm' resolves to hour 14") {
                    expect(hm(parseDate("2:45pm")!.date).hour) == 14
                }
                it("'2:45pm' resolves to minute 45") {
                    expect(hm(parseDate("2:45pm")!.date).minute) == 45
                }
            }

            context("date and time combined") {
                it("'tomorrow 3pm' resolves to tomorrow's date") {
                    let expected = ymd(cal.date(byAdding: .day, value: 1, to: Date())!)
                    expect(ymd(parseDate("tomorrow 3pm")!.date)) == expected
                }
                it("'tomorrow 3pm' resolves to hour 15") {
                    expect(hm(parseDate("tomorrow 3pm")!.date).hour) == 15
                }
                it("'friday at 5pm' resolves to a future date") {
                    expect(parseDate("friday at 5pm")!.date) > Date()
                }
                it("'friday at 5pm' resolves to hour 17") {
                    expect(hm(parseDate("friday at 5pm")!.date).hour) == 17
                }
                it("'march 15 9am' resolves to month 3") {
                    expect(ymd(parseDate("march 15 9am")!.date).month) == 3
                }
                it("'march 15 9am' resolves to day 15") {
                    expect(ymd(parseDate("march 15 9am")!.date).day) == 15
                }
                it("'march 15 9am' resolves to hour 9") {
                    expect(hm(parseDate("march 15 9am")!.date).hour) == 9
                }
            }

            context("invalid input") {
                it("unrecognised string returns nil") {
                    expect(parseDate("not a date")).to(beNil())
                }
                it("nonsense word returns nil") {
                    expect(parseDate("banana")).to(beNil())
                }
            }
        }
    }
}

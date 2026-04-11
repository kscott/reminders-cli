// RecurrenceParsingSpec.swift
//
// Tests for RecurrenceParsing — natural-language recurrence string parsing.

import Quick
import Nimble
import Foundation
import RemindersLib

final class RecurrenceParsingSpec: QuickSpec {
    override class func spec() {
        describe("parseRecurrence") {
            context("simple keywords") {
                it("parses 'daily'") { expect(parseRecurrence("daily")?.frequency) == .daily }
                it("parses 'weekly'") { expect(parseRecurrence("weekly")?.frequency) == .weekly }
                it("parses 'monthly'") { expect(parseRecurrence("monthly")?.frequency) == .monthly }
                it("parses 'yearly'") { expect(parseRecurrence("yearly")?.frequency) == .yearly }
                it("parses 'annually' as yearly") { expect(parseRecurrence("annually")?.frequency) == .yearly }
                it("parses 'every day' as daily") { expect(parseRecurrence("every day")?.frequency) == .daily }
                it("parses 'every week' as weekly") { expect(parseRecurrence("every week")?.frequency) == .weekly }
                it("parses 'every month' as monthly") { expect(parseRecurrence("every month")?.frequency) == .monthly }
                it("parses 'every year' as yearly") { expect(parseRecurrence("every year")?.frequency) == .yearly }
                it("simple keywords produce interval of 1") { expect(parseRecurrence("weekly")?.interval) == 1 }
                it("simple keywords produce no ordinal weekday") {
                    expect(parseRecurrence("weekly")?.ordinalWeekday).to(beNil())
                }
                it("returns nil for unrecognized input") { expect(parseRecurrence("banana")).to(beNil()) }
            }

            context("intervals") {
                it("'every 2 weeks' has weekly frequency") {
                    expect(parseRecurrence("every 2 weeks")?.frequency) == .weekly
                }
                it("'every 2 weeks' has interval 2") {
                    expect(parseRecurrence("every 2 weeks")?.interval) == 2
                }
                it("'every 3 months' has monthly frequency") {
                    expect(parseRecurrence("every 3 months")?.frequency) == .monthly
                }
                it("'every 3 months' has interval 3") {
                    expect(parseRecurrence("every 3 months")?.interval) == 3
                }
                it("'every 6 days' has daily frequency") {
                    expect(parseRecurrence("every 6 days")?.frequency) == .daily
                }
                it("'every 6 days' has interval 6") {
                    expect(parseRecurrence("every 6 days")?.interval) == 6
                }
                it("'every 2 years' has yearly frequency") {
                    expect(parseRecurrence("every 2 years")?.frequency) == .yearly
                }
                it("'every 2 years' has interval 2") {
                    expect(parseRecurrence("every 2 years")?.interval) == 2
                }
            }

            context("ordinal weekday — word") {
                it("'last tuesday' is monthly") {
                    expect(parseRecurrence("last tuesday")?.frequency) == .monthly
                }
                it("'last tuesday' has weekNumber -1") {
                    expect(parseRecurrence("last tuesday")?.ordinalWeekday?.weekNumber) == -1
                }
                it("'last tuesday' has weekday 3") {
                    expect(parseRecurrence("last tuesday")?.ordinalWeekday?.weekday) == 3
                }
                it("'first friday' has weekNumber 1") {
                    expect(parseRecurrence("first friday")?.ordinalWeekday?.weekNumber) == 1
                }
                it("'first friday' has weekday 6") {
                    expect(parseRecurrence("first friday")?.ordinalWeekday?.weekday) == 6
                }
                it("'second monday' has weekNumber 2") {
                    expect(parseRecurrence("second monday")?.ordinalWeekday?.weekNumber) == 2
                }
                it("'second monday' has weekday 2") {
                    expect(parseRecurrence("second monday")?.ordinalWeekday?.weekday) == 2
                }
                it("'third wednesday' has weekNumber 3") {
                    expect(parseRecurrence("third wednesday")?.ordinalWeekday?.weekNumber) == 3
                }
                it("'third wednesday' has weekday 4") {
                    expect(parseRecurrence("third wednesday")?.ordinalWeekday?.weekday) == 4
                }
                it("'fourth sunday' has weekNumber 4") {
                    expect(parseRecurrence("fourth sunday")?.ordinalWeekday?.weekNumber) == 4
                }
                it("'fourth sunday' has weekday 1") {
                    expect(parseRecurrence("fourth sunday")?.ordinalWeekday?.weekday) == 1
                }
                it("leading article 'the' is ignored") {
                    expect(parseRecurrence("the last wednesday")?.ordinalWeekday?.weekNumber) == -1
                }
                it("leading phrase 'on the' is ignored") {
                    expect(parseRecurrence("on the first friday")?.ordinalWeekday?.weekNumber) == 1
                }
            }

            context("ordinal weekday — numeric") {
                it("'1st monday' has weekNumber 1") {
                    expect(parseRecurrence("1st monday")?.ordinalWeekday?.weekNumber) == 1
                }
                it("'1st monday' has weekday 2") {
                    expect(parseRecurrence("1st monday")?.ordinalWeekday?.weekday) == 2
                }
                it("'2nd wednesday' has weekNumber 2") {
                    expect(parseRecurrence("2nd wednesday")?.ordinalWeekday?.weekNumber) == 2
                }
                it("'2nd wednesday' has weekday 4") {
                    expect(parseRecurrence("2nd wednesday")?.ordinalWeekday?.weekday) == 4
                }
                it("'3rd friday' has weekNumber 3") {
                    expect(parseRecurrence("3rd friday")?.ordinalWeekday?.weekNumber) == 3
                }
                it("'3rd friday' has weekday 6") {
                    expect(parseRecurrence("3rd friday")?.ordinalWeekday?.weekday) == 6
                }
                it("'4th thursday' has weekNumber 4") {
                    expect(parseRecurrence("4th thursday")?.ordinalWeekday?.weekNumber) == 4
                }
                it("'4th thursday' has weekday 5") {
                    expect(parseRecurrence("4th thursday")?.ordinalWeekday?.weekday) == 5
                }
            }

            context("day of month") {
                it("'the 1st' is monthly") {
                    expect(parseRecurrence("the 1st")?.frequency) == .monthly
                }
                it("'the 1st' has dayOfMonth 1") {
                    expect(parseRecurrence("the 1st")?.dayOfMonth) == 1
                }
                it("'the 15th' has dayOfMonth 15") {
                    expect(parseRecurrence("the 15th")?.dayOfMonth) == 15
                }
                it("'on the 22nd' has dayOfMonth 22") {
                    expect(parseRecurrence("on the 22nd")?.dayOfMonth) == 22
                }
                it("'2nd of the month' has dayOfMonth 2") {
                    expect(parseRecurrence("2nd of the month")?.dayOfMonth) == 2
                }
                it("'on the 1st of the month' has dayOfMonth 1") {
                    expect(parseRecurrence("on the 1st of the month")?.dayOfMonth) == 1
                }
                it("'the 29th' has dayOfMonth 29") {
                    expect(parseRecurrence("the 29th")?.dayOfMonth) == 29
                }
                it("'the 30th' has dayOfMonth 30") {
                    expect(parseRecurrence("the 30th")?.dayOfMonth) == 30
                }
                it("'the 31st' has dayOfMonth 31") {
                    expect(parseRecurrence("the 31st")?.dayOfMonth) == 31
                }
                it("day 32 is rejected") {
                    expect(parseRecurrence("the 32nd")).to(beNil())
                }
                it("day 0 is rejected") {
                    expect(parseRecurrence("the 0th")).to(beNil())
                }
                it("'last day of the month' returns nil — not yet supported") {
                    expect(parseRecurrence("last day of the month")).to(beNil())
                }
                it("'end of month' returns nil — not yet supported") {
                    expect(parseRecurrence("end of month")).to(beNil())
                }
                it("'2nd wednesday' is not treated as day-of-month") {
                    expect(parseRecurrence("2nd wednesday")?.dayOfMonth).to(beNil())
                }
                it("'2nd wednesday' is treated as ordinal weekday") {
                    expect(parseRecurrence("2nd wednesday")?.ordinalWeekday).toNot(beNil())
                }
            }
        }

        describe("splitOnRepeat") {
            context("keyword variants") {
                it("'repeat' splits date from recurrence") {
                    let r = splitOnRepeat("march 1 repeat monthly")
                    expect(r.date) == "march 1"
                    expect(r.recurrence) == "monthly"
                }
                it("'repeats' variant splits correctly") {
                    let r = splitOnRepeat("march 1 repeats monthly")
                    expect(r.date) == "march 1"
                    expect(r.recurrence) == "monthly"
                }
                it("'repeating' variant splits correctly") {
                    let r = splitOnRepeat("march 1 repeating monthly")
                    expect(r.date) == "march 1"
                    expect(r.recurrence) == "monthly"
                }
                it("'repeated' variant splits correctly") {
                    let r = splitOnRepeat("march 1 repeated monthly")
                    expect(r.date) == "march 1"
                    expect(r.recurrence) == "monthly"
                }
            }

            context("keyword position") {
                it("keyword before any date leaves date empty") {
                    expect(splitOnRepeat("repeat daily").date) == ""
                }
                it("keyword before any date captures recurrence") {
                    expect(splitOnRepeat("repeat daily").recurrence) == "daily"
                }
                it("keyword after date+time splits correctly") {
                    let r = splitOnRepeat("tuesday at 3pm repeating weekly")
                    expect(r.date) == "tuesday at 3pm"
                    expect(r.recurrence) == "weekly"
                }
                it("no keyword returns full string as date") {
                    expect(splitOnRepeat("tuesday at 3pm").date) == "tuesday at 3pm"
                }
                it("no keyword returns empty recurrence") {
                    expect(splitOnRepeat("tuesday at 3pm").recurrence) == ""
                }
                it("ordinal recurrence after keyword is captured") {
                    expect(splitOnRepeat("repeating last tuesday").recurrence) == "last tuesday"
                }
            }
        }

        describe("describeRecurrence") {
            context("simple frequencies") {
                it("describes daily") {
                    expect(describeRecurrence(RecurrenceSpec(frequency: .daily, interval: 1))) == "repeat daily"
                }
                it("describes weekly") {
                    expect(describeRecurrence(RecurrenceSpec(frequency: .weekly, interval: 1))) == "repeat weekly"
                }
                it("describes monthly") {
                    expect(describeRecurrence(RecurrenceSpec(frequency: .monthly, interval: 1))) == "repeat monthly"
                }
                it("describes yearly") {
                    expect(describeRecurrence(RecurrenceSpec(frequency: .yearly, interval: 1))) == "repeat yearly"
                }
            }

            context("intervals") {
                it("describes interval > 1") {
                    expect(describeRecurrence(RecurrenceSpec(frequency: .weekly, interval: 2))) == "repeat every 2 weeks"
                }
            }

            context("ordinal weekday") {
                it("describes last tuesday of the month") {
                    let spec = RecurrenceSpec(frequency: .monthly, interval: 1,
                        ordinalWeekday: .init(weekday: 3, weekNumber: -1))
                    expect(describeRecurrence(spec)) == "repeat last tuesday of the month"
                }
                it("describes first friday of the month") {
                    let spec = RecurrenceSpec(frequency: .monthly, interval: 1,
                        ordinalWeekday: .init(weekday: 6, weekNumber: 1))
                    expect(describeRecurrence(spec)) == "repeat first friday of the month"
                }
            }

            context("day of month") {
                it("describes 1st of the month") {
                    let spec = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 1)
                    expect(describeRecurrence(spec)) == "repeat on the 1st of the month"
                }
                it("describes 15th of the month") {
                    let spec = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 15)
                    expect(describeRecurrence(spec)) == "repeat on the 15th of the month"
                }
                it("describes 22nd of the month") {
                    let spec = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 22)
                    expect(describeRecurrence(spec)) == "repeat on the 22nd of the month"
                }
                it("describes 3rd of the month") {
                    let spec = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 3)
                    expect(describeRecurrence(spec)) == "repeat on the 3rd of the month"
                }
            }
        }
    }
}

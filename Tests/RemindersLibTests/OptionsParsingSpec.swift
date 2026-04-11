// OptionsParsingSpec.swift
//
// Tests for OptionsParsing — combined options string parsing into individual fields.

import Quick
import Nimble
import Foundation
import RemindersLib

final class OptionsParsingSpec: QuickSpec {
    override class func spec() {
        describe("parseOptions") {
            context("date only") {
                it("captures date when no other keywords present") {
                    expect(parseOptions("friday at 3pm").date) == "friday at 3pm"
                }
                it("leaves recurrence empty when no repeat keyword") {
                    expect(parseOptions("friday at 3pm").recurrence) == ""
                }
                it("leaves priority empty when no priority keyword") {
                    expect(parseOptions("friday at 3pm").priority) == ""
                }
                it("leaves note empty when no note keyword") {
                    expect(parseOptions("friday at 3pm").note) == ""
                }
                it("leaves url empty when no url keyword") {
                    expect(parseOptions("friday at 3pm").url) == ""
                }
            }

            context("repeat keyword") {
                it("captures recurrence after repeat keyword") {
                    expect(parseOptions("march 1 repeat monthly").recurrence) == "monthly"
                }
                it("captures date before repeat keyword") {
                    expect(parseOptions("march 1 repeat monthly").date) == "march 1"
                }
            }

            context("priority keyword") {
                it("captures 'high'") { expect(parseOptions("priority high").priority) == "high" }
                it("captures 'medium'") { expect(parseOptions("priority medium").priority) == "medium" }
                it("captures 'low'") { expect(parseOptions("priority low").priority) == "low" }
                it("captures 'none'") { expect(parseOptions("priority none").priority) == "none" }
            }

            context("url keyword") {
                it("captures url value") {
                    expect(parseOptions("url https://example.com").url) == "https://example.com"
                }
                it("leaves date empty when only url present") {
                    expect(parseOptions("url https://example.com").date) == ""
                }
            }

            context("note keyword") {
                it("captures note text to end of string") {
                    expect(parseOptions("tomorrow note pick up dry cleaning priority urgent").note)
                        == "pick up dry cleaning priority urgent"
                }
                it("captures date before note keyword") {
                    expect(parseOptions("tomorrow note pick up dry cleaning priority urgent").date) == "tomorrow"
                }
                it("does not parse keywords found inside note text") {
                    expect(parseOptions("tomorrow note pick up dry cleaning priority urgent").priority) == ""
                }
            }

            context("multiple fields") {
                let input = "friday repeat weekly priority high url https://example.com note check the dashboard"

                it("captures date") {
                    expect(parseOptions(input).date) == "friday"
                }
                it("captures recurrence") {
                    expect(parseOptions(input).recurrence) == "weekly"
                }
                it("captures priority") {
                    expect(parseOptions(input).priority) == "high"
                }
                it("captures url") {
                    expect(parseOptions(input).url) == "https://example.com"
                }
                it("captures note") {
                    expect(parseOptions(input).note) == "check the dashboard"
                }
            }

            context("fields without date") {
                let input = "repeat daily priority low note take with food"

                it("leaves date empty when string starts with keyword") {
                    expect(parseOptions(input).date) == ""
                }
                it("captures recurrence when no date present") {
                    expect(parseOptions(input).recurrence) == "daily"
                }
                it("captures priority when no date present") {
                    expect(parseOptions(input).priority) == "low"
                }
                it("captures note when no date present") {
                    expect(parseOptions(input).note) == "take with food"
                }
            }

            context("due keyword prefix stripped") {
                it("strips 'due' prefix from weekday+time") {
                    expect(parseOptions("due friday at 9am repeat weekly").date) == "friday at 9am"
                }
                it("preserves recurrence after stripping 'due' prefix") {
                    expect(parseOptions("due friday at 9am repeat weekly").recurrence) == "weekly"
                }
                it("strips 'due' prefix from ISO date") {
                    expect(parseOptions("due 2026-03-20 at 9am").date) == "2026-03-20 at 9am"
                }
                it("strips 'due' prefix from bare weekday") {
                    expect(parseOptions("due friday").date) == "friday"
                }
                it("preserves 'due none' as the string 'none'") {
                    expect(parseOptions("due none").date) == "none"
                }
                it("leaves date unchanged when no 'due' prefix present") {
                    expect(parseOptions("friday at 9am repeat weekly").date) == "friday at 9am"
                }
                it("strips 'date' prefix from weekday") {
                    expect(parseOptions("date wednesday").date) == "wednesday"
                }
                it("strips 'date' prefix from ISO date") {
                    expect(parseOptions("date 2026-03-18").date) == "2026-03-18"
                }
            }

            context("list keyword") {
                it("captures list name") {
                    expect(parseOptions("list Ibotta").list) == "Ibotta"
                }
                it("leaves date empty when only list present") {
                    expect(parseOptions("list Ibotta").date) == ""
                }
                it("captures date before list keyword") {
                    expect(parseOptions("friday list Ibotta").date) == "friday"
                }
                it("captures list name after date") {
                    expect(parseOptions("friday list Ibotta").list) == "Ibotta"
                }
                it("captures multi-word list name") {
                    expect(parseOptions("list My Work Tasks repeat weekly").list) == "My Work Tasks"
                }
                it("captures repeat keyword after multi-word list name") {
                    expect(parseOptions("list My Work Tasks repeat weekly").recurrence) == "weekly"
                }
                it("captures all fields when list is among them") {
                    let o = parseOptions("friday repeat weekly list Ibotta priority high")
                    expect(o.date) == "friday"
                    expect(o.recurrence) == "weekly"
                    expect(o.list) == "Ibotta"
                    expect(o.priority) == "high"
                }
            }

            context("keyword order independence") {
                it("captures priority when it appears before repeat") {
                    expect(parseOptions("priority high repeat weekly").priority) == "high"
                }
                it("captures recurrence when priority appears before it") {
                    expect(parseOptions("priority high repeat weekly").recurrence) == "weekly"
                }
                it("captures url when it appears before priority") {
                    expect(parseOptions("url https://example.com priority medium").url) == "https://example.com"
                }
                it("captures priority when url appears before it") {
                    expect(parseOptions("url https://example.com priority medium").priority) == "medium"
                }
            }
        }
    }
}

// ChangeCommandSpec.swift
//
// Tests for ChangeCommand — parsePriority and parseReminderChanges.

import Quick
import Nimble
import Foundation
import RemindersLib

final class ChangeCommandSpec: QuickSpec {
    override class func spec() {

        // MARK: parsePriority

        describe("parsePriority") {
            context("recognized values") {
                it("maps 'high' to 1") { expect(parsePriority("high")) == 1 }
                it("maps 'medium' to 5") { expect(parsePriority("medium")) == 5 }
                it("maps 'med' to 5") { expect(parsePriority("med")) == 5 }
                it("maps 'low' to 9") { expect(parsePriority("low")) == 9 }
                it("maps 'none' to 0") { expect(parsePriority("none")) == 0 }
            }
            context("case insensitivity") {
                it("accepts 'HIGH'") { expect(parsePriority("HIGH")) == 1 }
                it("accepts 'Medium'") { expect(parsePriority("Medium")) == 5 }
                it("accepts 'LOW'") { expect(parsePriority("LOW")) == 9 }
            }
            context("unrecognized values") {
                it("returns nil for empty string") { expect(parsePriority("")) == nil }
                it("returns nil for unrecognized string") { expect(parsePriority("urgent")) == nil }
                it("returns nil for partial match") { expect(parsePriority("hig")) == nil }
            }
        }

        // MARK: parseReminderChanges

        describe("parseReminderChanges") {

            context("empty options") {
                it("throws nothingToChange when all fields are empty") {
                    var opts = ParsedOptions()
                    expect { try parseReminderChanges(opts, existingDue: nil) }
                        .to(throwError(ReminderChangeError.nothingToChange))
                }
            }

            context("due date") {
                it("clears due when date is 'none'") {
                    var opts = ParsedOptions(); opts.date = "none"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.due) == .cleared
                }
                it("adds 'due cleared' to descriptions") {
                    var opts = ParsedOptions(); opts.date = "none"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.descriptions).to(contain("due cleared"))
                }
                it("sets due date components when date is recognized") {
                    var opts = ParsedOptions(); opts.date = "2026-04-15"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    if case .set(let comps) = changes.due {
                        expect(comps.year) == 2026
                        expect(comps.month) == 4
                        expect(comps.day) == 15
                    } else {
                        fail("expected .set")
                    }
                }
                it("adds 'due →' to descriptions for a recognized date") {
                    var opts = ParsedOptions(); opts.date = "2026-04-15"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.descriptions.first).to(beginWith("due →"))
                }
                it("leaves due unchanged when date is empty") {
                    var opts = ParsedOptions(); opts.priority = "high"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.due) == .unchanged
                }
                it("merges time-only input with existing due date") {
                    var opts = ParsedOptions(); opts.date = "3pm"
                    var existing = DateComponents()
                    existing.year = 2026; existing.month = 4; existing.day = 20
                    let changes = try! parseReminderChanges(opts, existingDue: existing)
                    if case .set(let comps) = changes.due {
                        expect(comps.year) == 2026
                        expect(comps.month) == 4
                        expect(comps.day) == 20
                        expect(comps.hour) == 15
                    } else {
                        fail("expected .set with merged components")
                    }
                }
                it("description includes time when merged") {
                    var opts = ParsedOptions(); opts.date = "3pm"
                    var existing = DateComponents()
                    existing.year = 2026; existing.month = 4; existing.day = 20
                    let changes = try! parseReminderChanges(opts, existingDue: existing)
                    expect(changes.descriptions.first).to(beginWith("due →"))
                }
            }

            context("recurrence") {
                it("clears recurrence when value is 'none'") {
                    var opts = ParsedOptions(); opts.recurrence = "none"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    if case .cleared = changes.recurrence { } else { fail("expected .cleared") }
                }
                it("adds 'repeat cleared' to descriptions") {
                    var opts = ParsedOptions(); opts.recurrence = "none"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.descriptions).to(contain("repeat cleared"))
                }
                it("sets recurrence for 'weekly'") {
                    var opts = ParsedOptions(); opts.recurrence = "weekly"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    if case .set(let spec) = changes.recurrence {
                        expect(spec.frequency) == .weekly
                    } else {
                        fail("expected .set")
                    }
                }
                it("throws unrecognizedRecurrence for invalid input") {
                    var opts = ParsedOptions(); opts.recurrence = "garbage"
                    expect { try parseReminderChanges(opts, existingDue: nil) }
                        .to(throwError(ReminderChangeError.unrecognizedRecurrence("garbage")))
                }
                it("leaves recurrence unchanged when empty") {
                    var opts = ParsedOptions(); opts.priority = "high"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    if case .unchanged = changes.recurrence { } else { fail("expected .unchanged") }
                }
            }

            context("priority") {
                it("sets priority to 1 for 'high'") {
                    var opts = ParsedOptions(); opts.priority = "high"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.priority) == .set(1)
                }
                it("sets priority to 0 for 'none'") {
                    var opts = ParsedOptions(); opts.priority = "none"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.priority) == .set(0)
                }
                it("adds 'priority → high' to descriptions") {
                    var opts = ParsedOptions(); opts.priority = "high"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.descriptions).to(contain("priority → high"))
                }
                it("adds 'priority cleared' when priority is none") {
                    var opts = ParsedOptions(); opts.priority = "none"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.descriptions).to(contain("priority cleared"))
                }
                it("leaves priority unchanged when empty") {
                    var opts = ParsedOptions(); opts.note = "buy milk"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.priority) == .unchanged
                }
            }

            context("note") {
                it("clears note when value is 'none'") {
                    var opts = ParsedOptions(); opts.note = "none"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.note) == .cleared
                }
                it("sets note for non-empty value") {
                    var opts = ParsedOptions(); opts.note = "buy milk"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.note) == .set("buy milk")
                }
                it("adds 'note cleared' to descriptions") {
                    var opts = ParsedOptions(); opts.note = "none"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.descriptions).to(contain("note cleared"))
                }
                it("adds '+ note' to descriptions for non-empty value") {
                    var opts = ParsedOptions(); opts.note = "buy milk"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.descriptions).to(contain("+ note"))
                }
            }

            context("url") {
                it("clears url when value is 'none'") {
                    var opts = ParsedOptions(); opts.url = "none"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.url) == .cleared
                }
                it("sets url for non-empty value") {
                    var opts = ParsedOptions(); opts.url = "https://example.com"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.url) == .set("https://example.com")
                }
                it("adds 'url cleared' to descriptions") {
                    var opts = ParsedOptions(); opts.url = "none"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.descriptions).to(contain("url cleared"))
                }
                it("adds 'url → ...' to descriptions for non-empty value") {
                    var opts = ParsedOptions(); opts.url = "https://example.com"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.descriptions).to(contain("url → https://example.com"))
                }
            }

            context("list") {
                it("sets list field when provided") {
                    var opts = ParsedOptions(); opts.list = "Work"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.list) == .set("Work")
                }
                it("does not throw nothingToChange when only list is specified") {
                    var opts = ParsedOptions(); opts.list = "Work"
                    expect { try parseReminderChanges(opts, existingDue: nil) }.notTo(throwError())
                }
                it("does not add list to descriptions (caller handles it)") {
                    var opts = ParsedOptions(); opts.list = "Work"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.descriptions).to(beEmpty())
                }
            }

            context("multiple fields") {
                it("collects descriptions for all changed fields") {
                    var opts = ParsedOptions()
                    opts.priority = "high"
                    opts.note = "buy milk"
                    let changes = try! parseReminderChanges(opts, existingDue: nil)
                    expect(changes.descriptions.count) == 2
                }
            }
        }
    }
}

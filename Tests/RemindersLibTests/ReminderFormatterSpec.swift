// ReminderFormatterSpec.swift
//
// Tests for ReminderFormatter — metaLine formatting for list output.

import Quick
import Nimble
import Foundation
import RemindersLib

final class ReminderFormatterSpec: QuickSpec {
    override class func spec() {
        describe("metaLine") {

            context("no metadata") {
                it("returns empty string for empty meta") {
                    expect(metaLine(for: ReminderMeta())) == ""
                }
                it("returns empty string when all flags are false and priority is 0") {
                    expect(metaLine(for: ReminderMeta(formattedDue: nil, isRepeating: false, priority: 0, hasNote: false, hasURL: false))) == ""
                }
            }

            context("due date") {
                it("includes formattedDue string when present") {
                    let meta = ReminderMeta(formattedDue: "Fri Apr 11 · 3:00pm")
                    expect(metaLine(for: meta)).to(contain("Fri Apr 11 · 3:00pm"))
                }
                it("returns empty string when formattedDue is nil") {
                    expect(metaLine(for: ReminderMeta(formattedDue: nil))) == ""
                }
            }

            context("repeating") {
                it("includes 'repeating' when isRepeating is true") {
                    expect(metaLine(for: ReminderMeta(isRepeating: true))).to(contain("repeating"))
                }
                it("does not include 'repeating' when isRepeating is false") {
                    expect(metaLine(for: ReminderMeta(isRepeating: false))) == ""
                }
            }

            context("priority") {
                it("shows 'high' for priority 1") {
                    expect(metaLine(for: ReminderMeta(priority: 1))).to(contain("high"))
                }
                it("shows 'high' for priority 4") {
                    expect(metaLine(for: ReminderMeta(priority: 4))).to(contain("high"))
                }
                it("shows 'medium' for priority 5") {
                    expect(metaLine(for: ReminderMeta(priority: 5))).to(contain("medium"))
                }
                it("shows 'low' for priority 6") {
                    expect(metaLine(for: ReminderMeta(priority: 6))).to(contain("low"))
                }
                it("shows 'low' for priority 9") {
                    expect(metaLine(for: ReminderMeta(priority: 9))).to(contain("low"))
                }
                it("shows nothing for priority 0") {
                    expect(metaLine(for: ReminderMeta(priority: 0))) == ""
                }
                it("shows nothing for priority 10 (out of range)") {
                    expect(metaLine(for: ReminderMeta(priority: 10))) == ""
                }
            }

            context("note and url") {
                it("includes '+ note' when hasNote is true") {
                    expect(metaLine(for: ReminderMeta(hasNote: true))).to(contain("+ note"))
                }
                it("includes '+ url' when hasURL is true") {
                    expect(metaLine(for: ReminderMeta(hasURL: true))).to(contain("+ url"))
                }
                it("does not include '+ note' when hasNote is false") {
                    expect(metaLine(for: ReminderMeta(hasNote: false))) == ""
                }
                it("does not include '+ url' when hasURL is false") {
                    expect(metaLine(for: ReminderMeta(hasURL: false))) == ""
                }
            }

            context("format") {
                it("starts with '  ·  ' when any field is present") {
                    expect(metaLine(for: ReminderMeta(isRepeating: true))).to(beginWith("  ·  "))
                }
                it("joins multiple fields with ' · '") {
                    let meta = ReminderMeta(isRepeating: true, priority: 1)
                    expect(metaLine(for: meta)) == "  ·  repeating · high"
                }
                it("due appears before repeating") {
                    let meta = ReminderMeta(formattedDue: "Mon Apr 14", isRepeating: true)
                    expect(metaLine(for: meta)) == "  ·  Mon Apr 14 · repeating"
                }
                it("all fields produce correct full string") {
                    let meta = ReminderMeta(
                        formattedDue: "Mon Apr 14",
                        isRepeating: true,
                        priority: 1,
                        hasNote: true,
                        hasURL: true
                    )
                    expect(metaLine(for: meta)) == "  ·  Mon Apr 14 · repeating · high · + note · + url"
                }
            }
        }
    }
}

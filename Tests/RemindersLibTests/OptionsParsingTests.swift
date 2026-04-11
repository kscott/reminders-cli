// OptionsParsingTests.swift
//
// Tests for OptionsParsing — combined options string parsing into individual fields.

import Foundation
import RemindersLib

func runOptionsParsingTests(_ t: TestRunner) {
    t.suite("parseOptions — date only") {
        let o = parseOptions("friday at 3pm")
        t.expect("date captured",      o.date       == "friday at 3pm")
        t.expect("recurrence empty",   o.recurrence == "")
        t.expect("priority empty",     o.priority   == "")
        t.expect("note empty",         o.note       == "")
        t.expect("url empty",          o.url        == "")
    }

    t.suite("parseOptions — repeat") {
        let o = parseOptions("march 1 repeat monthly")
        t.expect("date part",   o.date       == "march 1")
        t.expect("recurrence",  o.recurrence == "monthly")
    }

    t.suite("parseOptions — priority") {
        t.expect("high",   parseOptions("priority high").priority   == "high")
        t.expect("medium", parseOptions("priority medium").priority == "medium")
        t.expect("low",    parseOptions("priority low").priority    == "low")
        t.expect("none",   parseOptions("priority none").priority   == "none")
    }

    t.suite("parseOptions — url") {
        let o = parseOptions("url https://example.com")
        t.expect("url captured", o.url  == "https://example.com")
        t.expect("date empty",   o.date == "")
    }

    t.suite("parseOptions — note captures to end of string") {
        let o = parseOptions("tomorrow note pick up dry cleaning priority urgent")
        t.expect("date part",                 o.date     == "tomorrow")
        t.expect("note captures everything",  o.note     == "pick up dry cleaning priority urgent")
        t.expect("priority not parsed",       o.priority == "")
    }

    t.suite("parseOptions — multiple fields") {
        let o = parseOptions("friday repeat weekly priority high url https://example.com note check the dashboard")
        t.expect("date",       o.date       == "friday")
        t.expect("recurrence", o.recurrence == "weekly")
        t.expect("priority",   o.priority   == "high")
        t.expect("url",        o.url        == "https://example.com")
        t.expect("note",       o.note       == "check the dashboard")
    }

    t.suite("parseOptions — fields without date") {
        let o = parseOptions("repeat daily priority low note take with food")
        t.expect("date empty",  o.date       == "")
        t.expect("recurrence",  o.recurrence == "daily")
        t.expect("priority",    o.priority   == "low")
        t.expect("note",        o.note       == "take with food")
    }

    t.suite("parseOptions — due keyword prefix stripped") {
        let o1 = parseOptions("due friday at 9am repeat weekly")
        t.expect("due prefix stripped from weekday+time", o1.date       == "friday at 9am")
        t.expect("repeat preserved after due prefix",     o1.recurrence == "weekly")

        let o2 = parseOptions("due 2026-03-20 at 9am")
        t.expect("due prefix stripped from ISO date",     o2.date == "2026-03-20 at 9am")

        let o3 = parseOptions("due friday")
        t.expect("due prefix stripped — bare weekday",    o3.date == "friday")

        let o4 = parseOptions("due none")
        t.expect("due none preserved as 'none'",          o4.date == "none")

        let o5 = parseOptions("friday at 9am repeat weekly")
        t.expect("no due prefix — unchanged",             o5.date == "friday at 9am")

        let o6 = parseOptions("date wednesday")
        t.expect("date prefix stripped — weekday",        o6.date == "wednesday")

        let o7 = parseOptions("date 2026-03-18")
        t.expect("date prefix stripped — ISO date",       o7.date == "2026-03-18")
    }

    t.suite("parseOptions — list keyword") {
        let o1 = parseOptions("list Ibotta")
        t.expect("list only",              o1.list == "Ibotta")
        t.expect("list only — date empty", o1.date == "")

        let o2 = parseOptions("friday list Ibotta")
        t.expect("date + list — date",     o2.date == "friday")
        t.expect("date + list — list",     o2.list == "Ibotta")

        let o3 = parseOptions("list My Work Tasks repeat weekly")
        t.expect("multi-word list name",   o3.list       == "My Work Tasks")
        t.expect("repeat after list",      o3.recurrence == "weekly")

        let o4 = parseOptions("friday repeat weekly list Ibotta priority high")
        t.expect("all fields — date",      o4.date       == "friday")
        t.expect("all fields — repeat",    o4.recurrence == "weekly")
        t.expect("all fields — list",      o4.list       == "Ibotta")
        t.expect("all fields — priority",  o4.priority   == "high")
    }

    t.suite("parseOptions — any keyword order") {
        let o1 = parseOptions("priority high repeat weekly")
        t.expect("priority before repeat — priority", o1.priority   == "high")
        t.expect("priority before repeat — repeat",   o1.recurrence == "weekly")

        let o2 = parseOptions("url https://example.com priority medium")
        t.expect("url before priority — url",      o2.url      == "https://example.com")
        t.expect("url before priority — priority", o2.priority == "medium")
    }
}

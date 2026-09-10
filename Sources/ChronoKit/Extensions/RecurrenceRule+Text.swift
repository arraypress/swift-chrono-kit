//
//  RecurrenceRule+Text.swift
//  ChronoKit
//
//  A rule as text, both ways: RFC 5545's RRULE and plain English.
//

import Foundation

extension RecurrenceRule {

    /// A rule from either an RRULE or a phrase — whichever the text is.
    ///
    /// `FREQ=MONTHLY;BYDAY=2TU` and "second tuesday of every month" are the
    /// same rule; a caller handed text from a calendar invite or from a
    /// person should not have to know which it got.
    ///
    /// - Throws: ``RecurrenceError`` naming what could not be read.
    public init(parsing text: String) throws {
        if RRuleParsing.looksLikeRRule(text) {
            self = try RRuleParsing.parseBlock(text)
        } else {
            self = try RecurrencePhrases.parse(text)
        }
    }

    /// A rule from iCalendar text only: one RRULE line, or a block with
    /// `EXDATE` and `RDATE` lines. `RRULE:` may be present; `DTSTART` in the
    /// rule itself may not.
    public init(rrule: String) throws {
        self = try RRuleParsing.parseBlock(rrule)
    }

    /// A rule from an English phrase only.
    public init(phrase: String) throws {
        self = try RecurrencePhrases.parse(phrase)
    }

    /// The RFC 5545 spelling, or nil for a quarterly or working-day rule,
    /// which the RFC cannot express.
    public var rruleString: String? { RRuleParsing.string(for: self) }

    /// The rule as iCalendar lines: `RRULE:`, then `EXDATE;VALUE=DATE:` and
    /// `RDATE:` when there are any. Nil when ``rruleString`` is.
    public var icsLines: [String]? { RRuleParsing.icsLines(for: self) }

    /// The rule in plain English: `the second Tuesday of every month`.
    ///
    /// Canonical, so it reads back to the same rule: what ``phrase`` says,
    /// ``init(phrase:)`` reads.
    public var phrase: String { RecurrencePhrases.describe(self) }
}

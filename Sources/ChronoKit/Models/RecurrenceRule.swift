//
//  RecurrenceRule.swift
//  ChronoKit
//

import Foundation

/// A repeating pattern of days: RFC 5545's `RRULE`, the parts people use.
///
/// Daily, weekly, monthly and yearly with an interval; days of the week with
/// ordinals; days of the month, counted from either end; months; a position
/// in the period's candidates; a count or an end date; the week's first day.
/// That is what calendar invites carry and what people say — "the second
/// Tuesday of every month", "every other Friday", "the last day of the month".
///
/// Two extensions the RFC does not have: ``RecurrenceFrequency/quarterly``,
/// and ``businessDayOrdinal`` for "the first working day of the month". A
/// rule using either has no ``rruleString``. The RFC's hourly, minutely and
/// secondly frequencies and its `BYWEEKNO`, `BYYEARDAY`, `BYHOUR`, `BYMINUTE`
/// and `BYSECOND` parts are refused rather than half-implemented.
public struct RecurrenceRule: Sendable, Hashable, Codable {

    /// How often the period repeats.
    public let frequency: RecurrenceFrequency

    /// Every `interval` periods: 2 is every other week, month or year.
    public let interval: Int

    /// Days of the week, with ordinals for monthly and yearly rules.
    public let byDay: [WeekdayRule]

    /// Days of the month, 1–31, or -1 for the last day, -2 the day before.
    public let byMonthDay: [Int]

    /// Months, 1–12.
    public let byMonth: [Int]

    /// Positions in each period's list of candidate days: 1 is the first,
    /// -1 the last, -2 the second-to-last.
    public let bySetPos: [Int]

    /// Stop after this many occurrences.
    public let count: Int?

    /// Stop after this instant, inclusive.
    public let until: Date?

    /// The day a week begins, for weekly rules with an interval above one.
    public let weekStart: Weekday

    /// The nth working day of the period: 1 is the first, -1 the last.
    ///
    /// Not an RRULE part. "The last working day of the quarter" cannot be
    /// spelt with `BYDAY` and `BYSETPOS`, because holidays are not a pattern.
    public let businessDayOrdinal: Int?

    /// Days the rule skips: `EXDATE`, matched by calendar day in ``Chrono/timeZone``.
    ///
    /// By day, because a feed's `EXDATE` carries the start's time of day and a
    /// caller's usually carries midnight, and both mean "not that day".
    public let exceptions: Set<Date>

    /// Extra occurrences outside the pattern: `RDATE`, merged in order.
    ///
    /// An addition with a time keeps it; one that is a bare date takes the
    /// start's time of day. An addition on a day the rule already produces
    /// is not a second occurrence.
    public let additions: Set<Date>

    /// A rule, checked.
    ///
    /// - Throws: ``RecurrenceError/badRule(_:)`` for an interval or count
    ///   below one, a month outside 1–12, a month day outside ±1–31, a set
    ///   position of zero, an ordinal on a daily or weekly rule, or month
    ///   days on a weekly rule (the RFC forbids them).
    public init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        byDay: [WeekdayRule] = [],
        byMonthDay: [Int] = [],
        byMonth: [Int] = [],
        bySetPos: [Int] = [],
        count: Int? = nil,
        until: Date? = nil,
        weekStart: Weekday = .monday,
        businessDayOrdinal: Int? = nil,
        exceptions: Set<Date> = [],
        additions: Set<Date> = []
    ) throws {
        try RuleValidation.check(
            frequency: frequency, interval: interval, byDay: byDay, byMonthDay: byMonthDay,
            byMonth: byMonth, bySetPos: bySetPos, count: count, businessDayOrdinal: businessDayOrdinal
        )
        self.frequency = frequency
        self.interval = interval
        self.byDay = byDay
        self.byMonthDay = byMonthDay
        self.byMonth = byMonth
        self.bySetPos = bySetPos
        self.count = count
        self.until = until
        self.weekStart = weekStart
        self.businessDayOrdinal = businessDayOrdinal
        self.exceptions = exceptions
        self.additions = additions
    }
}

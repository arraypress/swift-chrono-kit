//
//  DateRange.swift
//  ChronoKit
//

import Foundation

/// A run of whole days, inclusive at both ends.
///
/// `start` and `end` are the first instants of their days in ``Chrono/timeZone``,
/// so both format cleanly as calendar dates — which is what a report URL or a
/// query filter actually wants. A one-day range has `start == end`.
///
/// The ends are normalised on construction: whichever is earlier becomes
/// `start`. A range is a set of days, and "5 March to 1 March" names the same
/// five days as the other way round.
public struct DateRange: Sendable, Hashable, Codable {

    /// The first day, at its start.
    public let start: Date

    /// The last day, at its start.
    public let end: Date

    /// A range from one day to another, in either order.
    public init(start: Date, end: Date) {
        let calendar = Chrono.calendar
        self.start = calendar.startOfDay(for: min(start, end))
        self.end = calendar.startOfDay(for: max(start, end))
    }

    /// One day.
    public init(day: Date) {
        self.init(start: day, end: day)
    }

    /// How many days the range covers, counting both ends.
    public var days: Int {
        (Chrono.calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    /// The same days as a half-open interval, ending at the start of the day
    /// after `end` — the shape a database query or `DateInterval.contains`
    /// wants.
    public var interval: DateInterval {
        let after = Chrono.calendar.date(byAdding: .day, value: 1, to: end) ?? end
        return DateInterval(start: start, end: after)
    }

    /// Whether an instant falls on one of the range's days.
    public func contains(_ date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }
}

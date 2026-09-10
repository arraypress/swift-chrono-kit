//
//  RelativeSpan.swift
//  ChronoKit
//

import Foundation

/// How far a moment is from now, in the one unit a person would say.
///
/// "In 3 days", not "in 2 days, 23 hours and 51 minutes": the distance is
/// rounded to the largest unit that fits and carried as a count, a unit and
/// a direction, so a caller can render it its own way. Under 45 seconds it
/// is ``isNow`` — a count of zero seconds, said as "now".
public struct RelativeSpan: Sendable, Hashable, Codable {

    /// How many of ``unit``; zero only when ``isNow``.
    public let count: Int

    /// The unit the distance is said in: minutes up to an hour, hours up to
    /// a day, days up to a week, weeks up to two months, months up to a year,
    /// years after that.
    public let unit: CalendarUnit

    /// True when the moment has passed.
    public let isPast: Bool

    /// True within 45 seconds either way, when nobody would name a unit.
    public let isNow: Bool
}

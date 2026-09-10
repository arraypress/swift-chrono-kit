//
//  DurationPart.swift
//  ChronoKit
//

import Foundation

/// One unit's worth of a length of time: `3 hours`, `2 weeks`.
///
/// The pieces ``Chrono/describe(duration:style:units:)`` renders, exposed so
/// a table or a form can lay them out its own way. The unit is one of
/// ``CalendarUnit/week``, ``CalendarUnit/day``, ``CalendarUnit/hour``,
/// ``CalendarUnit/minute`` or ``CalendarUnit/second`` — never a month or a
/// year, which have no fixed length in seconds.
public struct DurationPart: Sendable, Hashable, Codable {

    /// How many of ``unit``, always one or more.
    public let count: Int

    /// The unit, from week down to second.
    public let unit: CalendarUnit

    /// One part, for a caller assembling a length by hand.
    public init(count: Int, unit: CalendarUnit) {
        self.count = count
        self.unit = unit
    }
}

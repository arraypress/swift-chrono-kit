//
//  ClockTime.swift
//  ChronoKit
//

import Foundation

/// A time on the clock face with no date attached: `22:30`.
///
/// The thing a rule like "between 22:00 and 06:00" is written in. It is not a
/// `Date`, because a `Date` is an instant and this recurs every day, and it
/// is not a `DateComponents`, because that can hold a year and a nanosecond
/// and the rule wants neither.
public struct ClockTime: Sendable, Hashable, Codable, Comparable {

    /// Hour of the day, 0–23.
    public let hour: Int

    /// Minute of the hour, 0–59.
    public let minute: Int

    /// A clock time, checked.
    ///
    /// - Throws: ``ChronoError/badClockTime(_:)`` for an hour outside 0–23 or
    ///   a minute outside 0–59. `24:00` is refused: as a start it is midnight
    ///   and as an end it is the next day, and a value that means two things
    ///   is not a value.
    public init(hour: Int, minute: Int = 0) throws {
        try DayParts.validate(hour: hour, minute: minute)
        self.hour = hour
        self.minute = minute
    }

    /// Minutes since midnight, 0–1439 — the number the comparisons use.
    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

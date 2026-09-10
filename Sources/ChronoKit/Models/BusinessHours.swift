//
//  BusinessHours.swift
//  ChronoKit
//

import Foundation

/// The hours somebody works: which days, from when to when, and the holidays
/// they take off.
///
/// One window a day, on the days named, and never across midnight. A shift
/// that runs 22:00 to 06:00 belongs to two calendar days, and there is no
/// single answer to which day's holiday it falls on or which weekday it
/// counts as — so it is refused rather than guessed, and a night shift is
/// two windows on two schedules.
public struct BusinessHours: Sendable, Hashable, Codable {

    /// The working days.
    public let days: Set<Weekday>

    /// When the day's window opens.
    public let opens: ClockTime

    /// When it closes; the last working minute is the one before.
    public let closes: ClockTime

    /// Days off, matched by calendar day like ``Chrono/isBusinessDay(_:holidays:)``.
    public let holidays: Set<Date>

    /// Monday to Friday, nine to five, no holidays.
    public static let nineToFive = BusinessHours(
        days: Weekday.weekdays, opens: ClockTime.nine, closes: ClockTime.seventeen, holidays: [], unchecked: ()
    )

    /// A schedule, checked.
    ///
    /// - Throws: ``ChronoError/badBusinessHours(_:)`` when `closes` is not
    ///   after `opens` (a window that wraps midnight, or an empty one) or
    ///   when no days are named, which would make every question about it
    ///   unanswerable.
    public init(days: Set<Weekday>, opens: ClockTime, closes: ClockTime, holidays: Set<Date> = []) throws {
        try WorkingHours.validate(days: days, opens: opens, closes: closes)
        self.init(days: days, opens: opens, closes: closes, holidays: holidays, unchecked: ())
    }

    init(days: Set<Weekday>, opens: ClockTime, closes: ClockTime, holidays: Set<Date>, unchecked: Void) {
        self.days = days
        self.opens = opens
        self.closes = closes
        self.holidays = holidays
    }
}

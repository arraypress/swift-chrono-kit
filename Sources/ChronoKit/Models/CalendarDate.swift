//
//  CalendarDate.swift
//  ChronoKit
//

import Foundation

/// A day as one calendar counts it: an era, a year, a month and a day.
///
/// The era is part of the date because in two of these calendars it is the
/// point — a Japanese date is "Reiwa 8", not 2026, and a Chinese year is a
/// position in a sixty-year cycle. Elsewhere it is a constant Foundation
/// numbers as it pleases (0 for the Islamic, Hebrew, Buddhist, Persian and
/// Indian calendars, 1 for Gregorian and Coptic), which is why leaving it
/// out means "the current era" rather than 1. A Chinese month may be a leap
/// month, which repeats the number of the one before it; ``isLeapMonth`` is
/// what tells them apart.
public struct CalendarDate: Sendable, Hashable, Codable {

    /// The calendar the numbers belong to.
    public let system: CalendarSystem

    /// The era as Foundation numbers it: the era number for Japanese (Reiwa
    /// is 236), the sixty-year cycle for Chinese (78 until 2044), and a
    /// constant everywhere else.
    public let era: Int

    /// The year within the era.
    public let year: Int

    /// The month, 1-based, as the calendar numbers it.
    public let month: Int

    /// The day of the month.
    public let day: Int

    /// Whether this is a Chinese leap month, which repeats the previous month's number.
    public let isLeapMonth: Bool

    /// A date to convert from. Leaving the era out means the calendar's
    /// current one — right for every calendar except a Japanese date from a
    /// past era or a Chinese date from a past cycle, which must say so.
    public init(system: CalendarSystem, era: Int? = nil, year: Int, month: Int, day: Int, isLeapMonth: Bool = false) {
        self.system = system
        self.era = era ?? CalendarSystems.currentEra(for: system)
        self.year = year
        self.month = month
        self.day = day
        self.isLeapMonth = isLeapMonth
    }
}

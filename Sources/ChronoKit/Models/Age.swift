//
//  Age.swift
//  ChronoKit
//

import Foundation

/// How old something is, in calendar units, and when its next birthday is.
///
/// Years come from the calendar, not from dividing days by 365.25 — which is
/// off by a day for anyone born on the wrong side of a leap year, and always
/// off on the birthday itself.
public struct Age: Sendable, Hashable, Codable {

    /// The moment measured from.
    public let born: Date

    /// The moment measured to.
    public let on: Date

    /// Whole years.
    public let years: Int

    /// Months past the last birthday.
    public let months: Int

    /// Days past the last month.
    public let days: Int

    /// Whole calendar days between the two, for "days old".
    public let totalDays: Int

    /// The breakdown as a sentence: `36 years, 3 months, 20 days`.
    public let described: String

    /// The next birthday on or after ``on``'s day; today when it is today.
    ///
    /// A 29 February birthday falls on 28 February in a common year — the
    /// calendar's rule from ``Chrono/nextOccurrence(month:day:after:)``,
    /// not Foundation's, which would hand back 1 March.
    public let nextBirthday: Date

    /// Calendar days until ``nextBirthday``: zero on the day.
    public let daysUntilNextBirthday: Int
}

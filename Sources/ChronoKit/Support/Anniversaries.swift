//
//  Anniversaries.swift
//  ChronoKit
//
//  Counting the days to something, and finding the next time a date comes
//  round.
//

import Foundation

extension Chrono {

    /// Calendar days from `from` to `date`: 0 today, 1 tomorrow, -1 yesterday.
    ///
    /// Counted between the starts of the two days, so 23:00 tonight to 01:00
    /// tomorrow is one day, and a clock change in between does not make it
    /// zero. Negative when `date` has passed: a countdown that has ended
    /// says so rather than folding back to zero.
    public static func daysUntil(_ date: Date, from: Date = Date()) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// The next time a month and day come round, on or after `after`'s day.
    ///
    /// The birthday and anniversary question. Today counts: a birthday today
    /// is zero days away, not a year. A 29 February birthday falls on
    /// 28 February in a common year — the convention chrono-cli's `age` verb
    /// has always used, and now the calendar's rule rather than the CLI's.
    /// Asking Foundation for `2027-02-29` would hand back 1 March, which is
    /// a different day and the wrong one.
    ///
    /// - Throws: ``ChronoError/badMonthDay(_:)`` for a month and day no year
    ///   contains, like 31 April.
    public static func nextOccurrence(month: Int, day: Int, after: Date = Date()) throws -> Date {
        try Anniversaries.validate(month: month, day: day)
        let today = calendar.startOfDay(for: after)
        let year = calendar.component(.year, from: today)
        let thisYear = Anniversaries.occurrence(month: month, day: day, year: year)
        if let thisYear, thisYear >= today { return thisYear }
        guard let nextYear = Anniversaries.occurrence(month: month, day: day, year: year + 1) else {
            throw ChronoError.outOfRange("\(month)/\(day) in \(year + 1)")
        }
        return nextYear
    }
}

/// The arithmetic behind anniversaries.
enum Anniversaries {

    /// The days each month can have, in a leap year.
    private static let longest = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    /// A month 1–12 and a day that month has in at least one year.
    static func validate(month: Int, day: Int) throws {
        guard (1...12).contains(month), day >= 1, day <= longest[month - 1] else {
            throw ChronoError.badMonthDay("\(month)/\(day)")
        }
    }

    /// The date in `year`, with 29 February landing on the 28th when the year
    /// has no 29th.
    static func occurrence(month: Int, day: Int, year: Int) -> Date? {
        let calendar = Chrono.calendar
        var components = DateComponents(year: year, month: month, day: day)
        if month == 2, day == 29, !isLeap(year) {
            components.day = 28
        }
        return calendar.date(from: components)
    }

    /// Gregorian leap years: every fourth, except centuries, except every fourth century.
    static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }
}

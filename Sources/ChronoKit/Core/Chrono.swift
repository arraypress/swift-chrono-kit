//
//  Chrono.swift
//  ChronoKit
//
//  The namespace, and the one calendar every operation here shares.
//

import Foundation

/// Date arithmetic that a calendar decides, not a multiplication.
///
/// Every answer in here is one a language model gives confidently and gets
/// wrong: what 31 January plus one month is, whether a day is 86,400 seconds
/// on the last Sunday in March, which ISO week 1 January falls in, and how
/// many working days lie between two dates. None of them have a formula —
/// they are calendar rules, and Foundation already knows them.
///
/// Everything is computed in ``calendar``, which is the Gregorian calendar in
/// an explicit time zone. The zone is settable because the answer changes with
/// it: "today" in Auckland is not "today" in Los Angeles, and a tool that
/// silently uses the machine's zone gives a different answer on a colleague's
/// laptop.
public enum Chrono {

    /// The zone every operation resolves in. Defaults to the machine's.
    ///
    /// Held rather than passed because it is read in a dozen places and a
    /// parameter that is threaded through everything is a parameter people
    /// forget to thread.
    public nonisolated(unsafe) static var timeZone: TimeZone = .current

    /// The calendar every operation uses: Gregorian, in ``timeZone``.
    ///
    /// Deliberately not `Calendar.current` — that carries the user's locale,
    /// and a locale changes the first day of the week, which changes what
    /// "this week" means. ISO 8601 fixes the week to start on Monday, and the
    /// week arithmetic here depends on that being true everywhere.
    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2       // Monday, per ISO 8601
        calendar.minimumDaysInFirstWeek = 4  // ISO 8601's rule for week 1
        return calendar
    }

    /// Runs `body` with ``timeZone`` set to `zone`, then restores it.
    ///
    /// The restore is what makes it safe to answer "what time is that in
    /// Tokyo" in the middle of a command that is otherwise working locally.
    public static func inZone<T>(_ zone: TimeZone, _ body: () throws -> T) rethrows -> T {
        let previous = timeZone
        timeZone = zone
        defer { timeZone = previous }
        return try body()
    }
}

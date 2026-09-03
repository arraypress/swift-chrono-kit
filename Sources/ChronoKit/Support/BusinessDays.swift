//
//  BusinessDays.swift
//  ChronoKit
//
//  Working days — the arithmetic behind "within 10 business days".
//

import Foundation

extension Chrono {

    /// Whether a date falls on a weekend.
    public static func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    /// Whether a date is a working day: not a weekend, not in `holidays`.
    ///
    /// Holidays are compared by CALENDAR DAY, not by instant. A holiday list
    /// read from a file carries midnight; the date being tested might carry
    /// 14:30, and `==` on two `Date`s would say no every time.
    public static func isBusinessDay(_ date: Date, holidays: Set<Date> = []) -> Bool {
        if isWeekend(date) { return false }
        let day = calendar.startOfDay(for: date)
        return !holidays.contains { calendar.isDate($0, inSameDayAs: day) }
    }

    /// Counts working days from `start` up to and including `end`.
    ///
    /// Counted by walking, not by `days / 7 * 5`. The closed-form version is
    /// right only when both ends fall on the same weekday offset, and wrong by
    /// one or two the rest of the time — which is exactly when somebody
    /// notices, because it is their deadline.
    public static func businessDaysBetween(
        _ start: Date, and end: Date, holidays: Set<Date> = []
    ) -> Int {
        let from = calendar.startOfDay(for: min(start, end))
        let to = calendar.startOfDay(for: max(start, end))
        guard from < to else { return 0 }

        var count = 0
        var cursor = from
        // Exclusive of the start, inclusive of the end: the span from Monday
        // to Tuesday is one working day, not two.
        while cursor < to {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            if isBusinessDay(cursor, holidays: holidays) { count += 1 }
        }
        return count
    }

    /// Moves `count` working days forward (or backward, if negative).
    ///
    /// Weekends and holidays are skipped, never counted. Ten business days
    /// from a Friday is a Friday a fortnight later, not the Monday after next.
    public static func shiftBusinessDays(
        _ date: Date, by count: Int, holidays: Set<Date> = []
    ) throws -> Date {
        guard count != 0 else { return date }
        let step = count > 0 ? 1 : -1
        var remaining = abs(count)
        var cursor = date

        // Bounded so a holiday list that somehow covers every day cannot spin
        // forever. Ten years of steps is far past any real "n business days".
        var guardRail = abs(count) * 7 + 3_650
        while remaining > 0 {
            guard guardRail > 0 else {
                throw ChronoError.outOfRange("\(count) business days from \(date)")
            }
            guardRail -= 1
            guard let next = calendar.date(byAdding: .day, value: step, to: cursor) else {
                throw ChronoError.outOfRange("\(count) business days from \(date)")
            }
            cursor = next
            if isBusinessDay(cursor, holidays: holidays) { remaining -= 1 }
        }
        return cursor
    }

    /// Reads a holiday list: one date per line, `#` comments and blanks ignored.
    ///
    /// - Throws: ``ChronoError/badDate(_:)`` naming the first line that is not
    ///   a date. A holiday file with a typo silently shifting somebody's
    ///   deadline by a day is worse than a refusal.
    public static func holidays(fromLines lines: [String]) throws -> Set<Date> {
        var result: Set<Date> = []
        for line in lines {
            // omittingEmptySubsequences is FALSE on purpose: it defaults to
            // true, so "# a holiday" splits to ["  a holiday"] and the comment
            // itself arrives as the date. Caught by a test, not by inspection.
            let text = line.split(separator: "#", maxSplits: 1,
                                  omittingEmptySubsequences: false).first.map(String.init) ?? ""
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            result.insert(calendar.startOfDay(for: try date(trimmed)))
        }
        return result
    }
}

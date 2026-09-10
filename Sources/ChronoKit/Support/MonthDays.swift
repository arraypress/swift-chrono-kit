//
//  MonthDays.swift
//  ChronoKit
//
//  Days of a month by number, from the end, and by weekday — shared by the
//  holiday rules and the recurrence engine.
//

import Foundation

/// Calendar-day arithmetic within a month, in ``Chrono/calendar``.
enum MonthDays {

    /// The start of a calendar day, or nil for a day the month does not have.
    static func date(year: Int, month: Int, day: Int) -> Date? {
        let calendar = Chrono.calendar
        guard (1...12).contains(month), day >= 1, day <= count(year: year, month: month) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// How many days a month has in a year.
    static func count(year: Int, month: Int) -> Int {
        let calendar = Chrono.calendar
        guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: first) else { return 0 }
        return range.count
    }

    /// A day counted from the end when negative: -1 is the last day.
    static func date(year: Int, month: Int, dayFromEitherEnd day: Int) -> Date? {
        if day > 0 { return date(year: year, month: month, day: day) }
        let length = count(year: year, month: month)
        let resolved = length + day + 1
        return resolved >= 1 ? date(year: year, month: month, day: resolved) : nil
    }

    /// Every date in the month that falls on `weekday`, first to last.
    static func dates(year: Int, month: Int, on weekday: Weekday) -> [Date] {
        (1...count(year: year, month: month)).compactMap { day in
            guard let date = date(year: year, month: month, day: day) else { return nil }
            return Chrono.calendar.component(.weekday, from: date) == weekday.rawValue ? date : nil
        }
    }

    /// The nth `weekday` of the month: 1 is the first, -1 the last, -2 the
    /// second-to-last. Nil when the month has no such occurrence.
    static func nth(_ ordinal: Int, _ weekday: Weekday, year: Int, month: Int) -> Date? {
        pick(ordinal, from: dates(year: year, month: month, on: weekday))
    }

    /// Every date in the year on `weekday`, first to last.
    static func dates(year: Int, on weekday: Weekday) -> [Date] {
        (1...12).flatMap { dates(year: year, month: $0, on: weekday) }
    }

    /// The nth `weekday` of the year, counted from either end.
    static func nth(_ ordinal: Int, _ weekday: Weekday, year: Int) -> Date? {
        pick(ordinal, from: dates(year: year, on: weekday))
    }

    /// The element at a 1-based position, or from the end when negative.
    static func pick<T>(_ ordinal: Int, from list: [T]) -> T? {
        guard ordinal != 0 else { return nil }
        let index = ordinal > 0 ? ordinal - 1 : list.count + ordinal
        return list.indices.contains(index) ? list[index] : nil
    }

    /// The weekday of a date.
    static func weekday(of date: Date) -> Weekday {
        Weekday(rawValue: Chrono.calendar.component(.weekday, from: date)) ?? .sunday
    }
}

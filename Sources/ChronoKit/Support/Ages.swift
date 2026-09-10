//
//  Ages.swift
//  ChronoKit
//
//  How old something is, and when its next birthday falls.
//

import Foundation

extension Chrono {

    /// How old something born at `born` is on `on`.
    ///
    /// The breakdown is the calendar's (``span(from:to:)``), so 31 January to
    /// 28 February is a month and no days, as a person would say. The next
    /// birthday is found with ``nextOccurrence(month:day:after:)``, which
    /// puts a 29 February birthday on the 28th in a common year; the old
    /// `chrono age` verb asked Foundation for the 29th and was handed 1 March.
    ///
    /// - Throws: ``ChronoError/futureBirth(_:)`` when `born` is after `on`:
    ///   nothing is a negative age, and answering with one would hide a
    ///   swapped pair of arguments.
    public static func age(born: Date, on: Date = Date()) throws -> Age {
        guard born <= on else {
            throw ChronoError.futureBirth("\(describe(born).date) is after \(describe(on).date)")
        }
        let span = span(from: born, to: on)
        let birthday = calendar.dateComponents([.month, .day], from: born)
        let next = try nextOccurrence(month: birthday.month ?? 1, day: birthday.day ?? 1, after: on)
        return Age(
            born: born,
            on: on,
            years: span.years,
            months: span.months,
            days: span.days,
            totalDays: span.totalDays,
            described: Ages.described(years: span.years, months: span.months, days: span.days),
            nextBirthday: next,
            daysUntilNextBirthday: daysUntil(next, from: on)
        )
    }
}

/// The wording behind ``Age``.
enum Ages {

    /// `36 years, 3 months, 20 days`, dropping zero parts, and `0 days` when
    /// everything is zero — a newborn is not "".
    static func described(years: Int, months: Int, days: Int) -> String {
        let parts: [(Int, String)] = [(years, "year"), (months, "month"), (days, "day")]
        let words = parts.filter { $0.0 != 0 }.map { "\($0.0) \($0.1)\($0.0 == 1 ? "" : "s")" }
        return words.isEmpty ? "0 days" : words.joined(separator: ", ")
    }
}

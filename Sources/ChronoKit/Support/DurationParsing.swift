//
//  DurationParsing.swift
//  ChronoKit
//
//  Compact durations — 90m, 4h, 7d, 2w, 6mo, 1y.
//
//  Ported from AgendaKit, where this grammar was internal to a package that
//  imports EventKit. Answering "what is 2w from now" should not require the
//  calendar permission, so it lives here and AgendaKit can drop its copy.
//

import Foundation

extension Chrono {

    /// Seconds per unit suffix, longest suffix first so `mo` wins over `m`.
    ///
    /// Months and years are NOMINAL here — 30 and 365 days. That is wrong for
    /// calendar arithmetic and right for a window: "roughly six months out" is
    /// the whole intent of `6mo`. Anything that must land on a real calendar
    /// boundary goes through ``Chrono/shift(_:by:_:)``, which asks the
    /// calendar instead of multiplying.
    private static let durationUnits: [(suffix: String, seconds: TimeInterval)] = [
        ("fortnight", 1_209_600),
        ("mo", 2_592_000),
        ("y",  31_536_000),
        ("w",  604_800),
        ("d",  86_400),
        ("h",  3_600),
        ("m",  60),
        ("s",  1),
    ]

    /// Parses `30m`, `4h`, `7d`, `2w`, `6mo`, `1y` into seconds.
    ///
    /// - Parameter raw: A positive number and a unit suffix. A bare number is
    ///   read as minutes, matching `agenda`.
    /// - Throws: ``ChronoError/badDuration(_:)`` on anything else.
    public static func duration(_ raw: String) throws -> TimeInterval {
        let text = spelledOut(raw)
        guard !text.isEmpty else { throw ChronoError.badDuration(raw) }

        if let bare = Double(text) {
            guard bare > 0 else { throw ChronoError.badDuration(raw) }
            return bare * 60
        }

        for (suffix, seconds) in durationUnits where text.hasSuffix(suffix) {
            let digits = String(text.dropLast(suffix.count))
            guard let value = Double(digits), value > 0 else { throw ChronoError.badDuration(raw) }
            return value * seconds
        }
        throw ChronoError.badDuration(raw)
    }

    /// Folds `two weeks` and `3 days` down to the compact `2w` and `3d`.
    ///
    /// Written out is how people type it, and `3 days` was previously a
    /// *failure* rather than three days: it ends in "s", which is the suffix
    /// for seconds, leaving "3 day" to parse as a number.
    ///
    /// Word by word rather than by substring, because "m" lives inside half
    /// the words here and a careless replace turns "month" into "1onth".
    private static func spelledOut(_ raw: String) -> String {
        let words = raw.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")

        return words.reduce(into: "") { result, word in
            let cleaned = word.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
            if let number = numberWords[cleaned] {
                result += String(number)
            } else if let suffix = unitWords[cleaned] {
                result += suffix
            } else {
                result += cleaned
            }
        }
    }

    /// Counts people write rather than type. "a week" is one week.
    private static let numberWords: [String: Int] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12,
    ]

    /// Unit names, mapped onto the compact suffixes above. Order does not
    /// matter here the way it does for suffixes — these are whole words.
    private static let unitWords: [String: String] = [
        "second": "s", "seconds": "s", "sec": "s", "secs": "s",
        "minute": "m", "minutes": "m", "min": "m", "mins": "m",
        "hour": "h", "hours": "h", "hr": "h", "hrs": "h",
        "day": "d", "days": "d",
        "week": "w", "weeks": "w",
        "fortnight": "fortnight", "fortnights": "fortnight",
        "month": "mo", "months": "mo",
        "year": "y", "years": "y", "yr": "y", "yrs": "y",
    ]

    /// Splits `2w`, `18mo`, `-3d` into a count and a unit, for CALENDAR
    /// arithmetic rather than a number of seconds.
    ///
    /// This is the half ``duration(_:)`` cannot do. `1mo` as 2,592,000 seconds
    /// added to 31 January is 2 March; asked as (1, .month) the calendar
    /// answers 28 February, which is what a person means. Both spellings had
    /// to exist for that reason, not by accident.
    public static func offset(_ raw: String) throws -> (count: Int, unit: CalendarUnit) {
        var text = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { throw ChronoError.badDuration(raw) }

        var sign = 1
        if text.hasPrefix("+") { text.removeFirst() }
        else if text.hasPrefix("-") { sign = -1; text.removeFirst() }

        // "3 days" and "3days" are the same request typed by two people.
        let digits = text.prefix { $0.isNumber }
        let rest = text.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        guard let value = Int(digits), !rest.isEmpty,
              let unit = CalendarUnit(loose: rest) else {
            throw ChronoError.badDuration(raw)
        }
        return (sign * value, unit)
    }
}

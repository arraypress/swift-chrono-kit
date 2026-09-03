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
        let text = raw.trimmingCharacters(in: .whitespaces).lowercased()
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

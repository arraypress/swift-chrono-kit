//
//  DurationWords.swift
//  ChronoKit
//
//  A number of seconds, said in words — the inverse of Chrono.duration.
//

import Foundation

extension Chrono {

    /// A length of time in words: `2 days, 3 hours`, `2d 3h`, `51:00:00`,
    /// `two days and three hours`.
    ///
    /// This is a LENGTH, not a calendar step. A day is 86,400 seconds and a
    /// week 604,800 here on purpose, because that is what a number of seconds
    /// is; the calendar's opinion that a day across a clock change is 23 or 25
    /// hours belongs to ``span(from:to:)`` and ``shift(_:by:_:)``, which are
    /// asked about dates rather than amounts. Months and years are not units
    /// for the same reason: they have no length in seconds, and a nominal
    /// thirty-day month is a lie this package refuses everywhere else.
    ///
    /// `units` caps how many parts appear, largest first. The parts left off
    /// are dropped, not rounded up: 90,061 seconds at two units is
    /// "1 day, 1 hour", not "1 day, 2 hours". Nothing at all — a duration
    /// under one second — reads as "0 seconds", "0s", "00:00" or
    /// "zero seconds". Fractional seconds are truncated. The clock style
    /// ignores `units`, except that three or more forces the hours field.
    ///
    /// - Throws: ``ChronoError/badDuration(_:)`` for a negative or non-finite
    ///   number — a duration is a length, and a length is zero or more — and
    ///   ``ChronoError/outOfRange(_:)`` beyond what an `Int` of seconds holds.
    public static func describe(
        duration seconds: TimeInterval, style: DurationStyle = .long, units: Int = 2
    ) throws -> String {
        let parts = try durationParts(seconds)
        return DurationWords.render(parts, style: style, units: max(1, units), wholeSeconds: DurationWords.whole(seconds))
    }

    /// The weeks, days, hours, minutes and seconds in a length of time,
    /// largest first, zero parts left out.
    ///
    /// Exactly a week is `[1 week]`; 90,061 seconds is a day, an hour, a
    /// minute and a second; anything under one second is empty.
    ///
    /// - Throws: ``ChronoError/badDuration(_:)`` for a negative or non-finite
    ///   number, ``ChronoError/outOfRange(_:)`` beyond an `Int` of seconds.
    public static func durationParts(_ seconds: TimeInterval) throws -> [DurationPart] {
        try DurationWords.validate(seconds)
        return DurationWords.parts(wholeSeconds: DurationWords.whole(seconds))
    }
}

/// The splitting and the spelling, on plain integers.
enum DurationWords {

    /// Seconds per unit, largest first. Fixed lengths, deliberately.
    static let unitLengths: [(unit: CalendarUnit, seconds: Int)] = [
        (.week, 604_800), (.day, 86_400), (.hour, 3_600), (.minute, 60), (.second, 1),
    ]

    /// A length is zero or more real seconds, and fits an `Int`.
    static func validate(_ seconds: TimeInterval) throws {
        guard seconds.isFinite, seconds >= 0 else {
            throw ChronoError.badDuration("\(seconds) seconds — a length of time is zero or more")
        }
        guard seconds < Double(Int.max) else {
            throw ChronoError.outOfRange("\(seconds) seconds")
        }
    }

    /// Whole seconds; the fraction is dropped, never rounded up.
    static func whole(_ seconds: TimeInterval) -> Int {
        Int(seconds.rounded(.down))
    }

    /// Splits whole seconds into nonzero parts, largest unit first.
    static func parts(wholeSeconds: Int) -> [DurationPart] {
        var remaining = wholeSeconds
        var parts: [DurationPart] = []
        for (unit, length) in unitLengths {
            let count = remaining / length
            remaining -= count * length
            if count > 0 { parts.append(DurationPart(count: count, unit: unit)) }
        }
        return parts
    }

    /// The parts in one of the four styles, capped at `units`.
    static func render(_ parts: [DurationPart], style: DurationStyle, units: Int, wholeSeconds: Int) -> String {
        if style == .clock { return clock(wholeSeconds: wholeSeconds, forceHours: units >= 3) }
        let shown = Array(parts.prefix(units))
        switch style {
        case .long:
            return shown.isEmpty ? "0 seconds"
                : shown.map { "\($0.count) \($0.unit.label(for: $0.count))" }.joined(separator: ", ")
        case .short:
            return shown.isEmpty ? "0s"
                : shown.map { "\($0.count)\(suffix(for: $0.unit))" }.joined(separator: " ")
        case .words:
            return shown.isEmpty ? "zero seconds"
                : sentence(shown.map { "\(spelled($0.count)) \($0.unit.label(for: $0.count))" })
        case .clock:
            return clock(wholeSeconds: wholeSeconds, forceHours: units >= 3)
        }
    }

    /// `hh:mm:ss`, days folded into hours; `mm:ss` under an hour unless forced.
    static func clock(wholeSeconds: Int, forceHours: Bool) -> String {
        let hours = wholeSeconds / 3_600
        let minutes = (wholeSeconds % 3_600) / 60
        let seconds = wholeSeconds % 60
        if hours == 0 && !forceHours {
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// The compact suffix ``Chrono/duration(_:)`` reads: `w d h m s`.
    static func suffix(for unit: CalendarUnit) -> String {
        switch unit {
        case .week: "w"
        case .day: "d"
        case .hour: "h"
        case .minute: "m"
        case .second: "s"
        case .month: "mo"
        case .quarter: "q"
        case .year: "y"
        }
    }

    /// Joins phrases the spoken way: `a, b and c`; `a and b`; `a`.
    static func sentence(_ phrases: [String]) -> String {
        guard phrases.count > 1 else { return phrases.first ?? "" }
        return phrases.dropLast().joined(separator: ", ") + " and " + phrases.last!
    }

    /// Counts up to twenty in words, digits after that.
    static func spelled(_ count: Int) -> String {
        guard (0...20).contains(count) else { return String(count) }
        return [
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
            "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
            "eighteen", "nineteen", "twenty",
        ][count]
    }
}

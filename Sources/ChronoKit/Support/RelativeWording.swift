//
//  RelativeWording.swift
//  ChronoKit
//
//  "In 3 days" and "2 hours ago" — the distance to a moment, in words.
//

import Foundation

extension Chrono {

    /// How far `then` is from `now`, in words: `in 3 days`, `2 hours ago`, `now`.
    ///
    /// Written here rather than taken from `RelativeDateTimeFormatter`, which
    /// is locale-driven and would print "in 3 Tagen" on a German machine —
    /// fine for a person, wrong for a field an agent parses or a test asserts
    /// on. The scale steps are fixed: minutes up to an hour, hours up to a
    /// day, days up to a week, weeks up to two months, months (of thirty
    /// days) up to a year, then years. Under 45 seconds either way is "now".
    public static func relative(from now: Date, to then: Date) -> String {
        relativeSpan(from: now, to: then).words
    }

    /// How far `date` is from now, in words.
    public static func relative(_ date: Date) -> String {
        relative(from: Date(), to: date)
    }

    /// The distance from `now` to `then` as a count, a unit and a direction.
    ///
    /// The parts behind ``relative(from:to:)``, for a caller that wants to
    /// render them differently or branch on the unit.
    public static func relativeSpan(from now: Date, to then: Date) -> RelativeSpan {
        RelativeWording.span(seconds: then.timeIntervalSince(now))
    }
}

/// The rounding and the wording, on plain seconds.
enum RelativeWording {

    /// Picks the unit a person would use for a distance in seconds.
    ///
    /// The thresholds are deliberately not the units' exact lengths: a
    /// distance of 50 days is "7 weeks" rather than "2 months" because up to
    /// sixty days people still count weeks, and 400 days is "1 year", because
    /// nobody says "13 months".
    static func span(seconds: TimeInterval) -> RelativeSpan {
        let magnitude = abs(seconds)
        if magnitude < 45 {
            return RelativeSpan(count: 0, unit: .second, isPast: false, isNow: true)
        }
        let (count, unit): (Int, CalendarUnit)
        switch magnitude {
        case ..<3_600:          (count, unit) = (Int((magnitude / 60).rounded()), .minute)
        case ..<86_400:         (count, unit) = (Int((magnitude / 3_600).rounded()), .hour)
        case ..<(86_400 * 7):   (count, unit) = (Int((magnitude / 86_400).rounded()), .day)
        case ..<(86_400 * 60):  (count, unit) = (Int((magnitude / (86_400 * 7)).rounded()), .week)
        case ..<(86_400 * 365): (count, unit) = (Int((magnitude / (86_400 * 30)).rounded()), .month)
        default:                (count, unit) = (Int((magnitude / (86_400 * 365)).rounded()), .year)
        }
        return RelativeSpan(count: count, unit: unit, isPast: seconds < 0, isNow: false)
    }

    /// `in 3 days`, `2 hours ago`, `now`.
    static func words(_ span: RelativeSpan) -> String {
        if span.isNow { return "now" }
        let phrase = "\(span.count) \(span.unit.label(for: span.count))"
        return span.isPast ? "\(phrase) ago" : "in \(phrase)"
    }
}

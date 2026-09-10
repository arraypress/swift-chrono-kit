//
//  DayParts.swift
//  ChronoKit
//
//  Which part of the day an instant falls in, whether a clock time is inside
//  a window that may cross midnight, and whether a day is one of every Nth.
//

import Foundation

extension Chrono {

    /// Which part of the day `date` falls in, by the clock in ``timeZone``.
    ///
    /// The hour is read in ``timeZone``, so the same instant is morning in
    /// London and evening in Tokyo — which is the point. A tool that reads
    /// the hour off the machine gives a colleague on the other side of the
    /// world a different greeting for the same message.
    public static func timeOfDay(
        _ date: Date, boundaries: TimeOfDay.Boundaries = .default
    ) -> TimeOfDay {
        let hour = calendar.component(.hour, from: date)
        return DayParts.part(forHour: hour, boundaries: boundaries)
    }

    /// Whether `date`'s clock time falls inside a window, which may cross midnight.
    ///
    /// The window is closed at the start and open at the end: `22:00` to
    /// `06:00` contains 22:00 and 05:59 but not 06:00, so two windows that
    /// meet share no minute. When `to` is not after `from`, the window wraps
    /// through midnight — that is what "between ten and six" means at night —
    /// and when the two are equal the window is the whole day, because a
    /// window that starts where it ends has gone all the way round.
    public static func isTime(_ date: Date, between from: ClockTime, and to: ClockTime) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return DayParts.contains(minutes, from: from.minutesSinceMidnight, to: to.minutesSinceMidnight)
    }

    /// Whether `date` falls in the daytime hours, by the clock.
    ///
    /// Six in the morning to eight at night by default — a convention for
    /// "is it a reasonable hour", not a statement about the sun. Sunrise is
    /// 03:43 in Reykjavik in June and 11:30 in December; a rule about the sun
    /// needs a solar calculation and a coordinate, not a calendar.
    ///
    /// - Throws: ``ChronoError/badClockTime(_:)`` if either hour is outside 0–23.
    public static func isDaytime(_ date: Date, from: Int = 6, to: Int = 20) throws -> Bool {
        isTime(date, between: try ClockTime(hour: from), and: try ClockTime(hour: to))
    }

    /// Whether `date` is one of every `interval` days counted from `anchor`.
    ///
    /// "Every third day from the 1st" is the 1st, the 4th, the 7th. Days are
    /// counted by the calendar, so a week across a daylight-saving change is
    /// still seven days and not six days and 23 hours. Days before the anchor
    /// are never interval days: the series starts at the anchor and runs
    /// forward, and the anchor itself is day zero, which counts.
    ///
    /// - Throws: ``ChronoError/badInterval(_:)`` for an interval below one.
    public static func isEveryNthDay(_ date: Date, from anchor: Date, every interval: Int) throws -> Bool {
        guard interval >= 1 else { throw ChronoError.badInterval(interval) }
        let start = calendar.startOfDay(for: anchor)
        let day = calendar.startOfDay(for: date)
        let elapsed = calendar.dateComponents([.day], from: start, to: day).day ?? 0
        return DayParts.isOnInterval(dayOffset: elapsed, every: interval)
    }
}

/// The arithmetic behind the parts of a day, on plain integers so it can be
/// tested without a calendar.
enum DayParts {

    /// The part of the day an hour falls in.
    static func part(forHour hour: Int, boundaries: TimeOfDay.Boundaries) -> TimeOfDay {
        switch hour {
        case boundaries.morning..<boundaries.afternoon: return .morning
        case boundaries.afternoon..<boundaries.evening: return .afternoon
        case boundaries.evening..<boundaries.night: return .evening
        default: return .night
        }
    }

    /// Whether a minute of the day lies in `[from, to)`, wrapping past midnight
    /// when `to` is not after `from`, and covering the whole day when equal.
    static func contains(_ minute: Int, from: Int, to: Int) -> Bool {
        if from == to { return true }
        if from < to { return minute >= from && minute < to }
        return minute >= from || minute < to
    }

    /// Whether a day offset from the anchor lands on the interval.
    static func isOnInterval(dayOffset: Int, every interval: Int) -> Bool {
        dayOffset >= 0 && dayOffset % interval == 0
    }

    /// Four hours in strictly rising order, each within a day.
    static func validate(morning: Int, afternoon: Int, evening: Int, night: Int) throws {
        let hours = [morning, afternoon, evening, night]
        guard hours.allSatisfy({ (0...23).contains($0) }) else {
            throw ChronoError.badBoundaries("hours must be 0–23, got \(hours)")
        }
        guard morning < afternoon, afternoon < evening, evening < night else {
            throw ChronoError.badBoundaries("hours must rise in order, got \(hours)")
        }
    }

    /// An hour of the day and a minute of the hour.
    static func validate(hour: Int, minute: Int) throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw ChronoError.badClockTime(String(format: "%02d:%02d", hour, minute))
        }
    }
}

//
//  WorkingHours.swift
//  ChronoKit
//
//  Working time between two instants, the next opening, and a deadline a
//  given number of working hours away.
//

import Foundation

extension Chrono {

    /// Seconds of working time between two instants under a schedule.
    ///
    /// Walked day by day: each working day contributes the overlap of its
    /// window with the interval, weekends and holidays contribute nothing.
    /// Friday 16:00 to Monday 10:00 under nine-to-five is two hours. The
    /// order of the two instants does not matter — the answer is a length,
    /// like ``span(from:to:)``'s totals.
    ///
    /// A day is a wall-clock day in ``timeZone``, so on the Sunday the clocks
    /// change the window is still 09:00 to 17:00 and still eight hours.
    public static func businessHours(from start: Date, to end: Date, hours: BusinessHours) -> TimeInterval {
        let (earlier, later) = start <= end ? (start, end) : (end, start)
        var total: TimeInterval = 0
        var day = calendar.startOfDay(for: earlier)
        let lastDay = calendar.startOfDay(for: later)
        while day <= lastDay {
            if let window = WorkingHours.window(on: day, hours: hours) {
                let from = max(window.start, earlier)
                let to = min(window.end, later)
                if to > from { total += to.timeIntervalSince(from) }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return total
    }

    /// Whether the schedule is open at `date`: a working day, and the clock
    /// inside the window (closed at the start, open at the end).
    public static func isOpen(_ date: Date, hours: BusinessHours) -> Bool {
        guard let window = WorkingHours.window(on: calendar.startOfDay(for: date), hours: hours) else { return false }
        return date >= window.start && date < window.end
    }

    /// The next moment the schedule is open on or after `date` — `date` itself
    /// when it is open then.
    ///
    /// - Throws: ``ChronoError/outOfRange(_:)`` if no working day is found
    ///   within ten years, which takes a holiday list that never ends.
    public static func nextOpening(after date: Date, hours: BusinessHours) throws -> Date {
        if isOpen(date, hours: hours) { return date }
        var day = calendar.startOfDay(for: date)
        for _ in 0..<3_660 {
            if let window = WorkingHours.window(on: day, hours: hours), window.start >= date {
                return window.start
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        throw ChronoError.outOfRange("no working day within ten years of \(describe(date).date)")
    }

    /// The moment `seconds` of working time after `date` — a deadline eight
    /// working hours away, say.
    ///
    /// Time before the next opening does not count, and neither does the
    /// evening, the weekend or a holiday: the clock only runs while the
    /// schedule is open. Zero seconds is the next opening.
    ///
    /// - Throws: ``ChronoError/badDuration(_:)`` for negative working time,
    ///   and ``ChronoError/outOfRange(_:)`` if the schedule never opens.
    public static func addBusinessHours(_ seconds: TimeInterval, to date: Date, hours: BusinessHours) throws -> Date {
        guard seconds >= 0, seconds.isFinite else { throw ChronoError.badDuration("\(seconds) seconds of working time") }
        var remaining = seconds
        var current = try nextOpening(after: date, hours: hours)
        while true {
            guard let window = WorkingHours.window(on: calendar.startOfDay(for: current), hours: hours) else {
                current = try nextOpening(after: current, hours: hours)
                continue
            }
            let available = window.end.timeIntervalSince(current)
            if remaining <= available { return current.addingTimeInterval(remaining) }
            remaining -= available
            current = try nextOpening(after: window.end, hours: hours)
        }
    }
}

/// The day-window arithmetic behind ``BusinessHours``.
enum WorkingHours {

    /// The window on a calendar day, or nil when the day is not worked.
    static func window(on day: Date, hours: BusinessHours) -> DateInterval? {
        let calendar = Chrono.calendar
        guard let weekday = Weekday(foundationWeekday: calendar.component(.weekday, from: day)),
              hours.days.contains(weekday),
              !hours.holidays.contains(where: { calendar.isDate($0, inSameDayAs: day) })
        else { return nil }
        guard let start = calendar.date(bySettingHour: hours.opens.hour, minute: hours.opens.minute, second: 0, of: day),
              let end = calendar.date(bySettingHour: hours.closes.hour, minute: hours.closes.minute, second: 0, of: day),
              end > start
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Days named, and a window that closes after it opens on the same day.
    static func validate(days: Set<Weekday>, opens: ClockTime, closes: ClockTime) throws {
        guard !days.isEmpty else {
            throw ChronoError.badBusinessHours("no working days named")
        }
        guard closes > opens else {
            throw ChronoError.badBusinessHours("closes \(closes.hour):\(String(format: "%02d", closes.minute)) is not after opens \(opens.hour):\(String(format: "%02d", opens.minute)) — a window across midnight belongs to two days; use two schedules")
        }
    }
}

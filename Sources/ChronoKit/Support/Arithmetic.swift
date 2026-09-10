//
//  Arithmetic.swift
//  ChronoKit
//
//  Adding and subtracting, asked of the calendar rather than multiplied.
//

import Foundation

extension Chrono {

    /// Shifts `date` by `count` of `unit`, the way a calendar does it.
    ///
    /// The two cases that make this worth a function rather than a
    /// multiplication:
    ///
    /// - **Month ends clamp.** 31 January plus one month is 28 February
    ///   (29 in a leap year), because there is no 31 February. Adding
    ///   2,592,000 seconds gives 2 March, which is a different month and the
    ///   wrong answer to the question asked.
    /// - **Days are not 86,400 seconds.** On the last Sunday in March a day
    ///   in Europe/London is 23 hours long, and in October it is 25. Adding
    ///   a day by seconds lands an hour off, in one direction each spring and
    ///   the other each autumn.
    ///
    /// - Throws: ``ChronoError/outOfRange(_:)`` if the result is beyond what
    ///   the calendar can represent.
    public static func shift(_ date: Date, by count: Int, _ unit: CalendarUnit) throws -> Date {
        guard let result = calendar.date(
            byAdding: unit.component,
            value: count * unit.multiplier,
            to: date
        ) else {
            throw ChronoError.outOfRange("\(count) \(unit.label(for: count)) from \(date)")
        }
        return result
    }

    /// Applies several offsets in order: `+1mo`, `-2d`.
    ///
    /// In order, because calendar arithmetic does not commute. From
    /// 31 January, one month then minus one day is 27 February; minus one day
    /// then one month is 28 February. Neither is wrong — they are different
    /// questions — so the sequence the caller wrote is the sequence applied.
    public static func shift(_ date: Date, by offsets: [String]) throws -> Date {
        try offsets.reduce(date) { current, text in
            let (count, unit) = try offset(text)
            return try shift(current, by: count, unit)
        }
    }

    /// Measures the distance between two instants.
    ///
    /// The order is normalised so the breakdown is always positive, and
    /// ``Span/isBackwards`` records which way round they were given.
    public static func span(from start: Date, to end: Date) -> Span {
        let backwards = end < start
        let (earlier, later) = backwards ? (end, start) : (start, end)

        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: earlier, to: later
        )

        // Day counts are taken between START OF DAY on each side. Between
        // 23:00 Monday and 01:00 Wednesday the calendar's raw day count is 1
        // — it is 26 hours — but every person and every invoice calls that
        // two days.
        let dayParts = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: earlier),
            to: calendar.startOfDay(for: later)
        )
        let totalDays = dayParts.day ?? 0
        let elapsed = later.timeIntervalSince(earlier)

        return Span(
            from: earlier,
            to: later,
            isBackwards: backwards,
            years: parts.year ?? 0,
            months: parts.month ?? 0,
            days: parts.day ?? 0,
            hours: parts.hour ?? 0,
            minutes: parts.minute ?? 0,
            seconds: parts.second ?? 0,
            totalDays: totalDays,
            totalWeeks: totalDays / 7,
            remainderDays: totalDays % 7,
            totalHours: Int(elapsed / 3600),
            totalMinutes: Int(elapsed / 60),
            totalSeconds: Int(elapsed),
            businessDays: businessDaysBetween(earlier, and: later)
        )
    }

    /// Describes an instant every way ``Instant`` carries.
    public static func describe(_ date: Date) -> Instant {
        let zone = timeZone
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .weekday,
             .weekOfYear, .yearForWeekOfYear, .quarter],
            from: date
        )

        let iso = ISO8601DateFormatter()
        iso.timeZone = zone
        iso.formatOptions = [.withInternetDateTime]

        let utcFormatter = ISO8601DateFormatter()
        utcFormatter.timeZone = TimeZone(identifier: "UTC")
        utcFormatter.formatOptions = [.withInternetDateTime]

        let plain = DateFormatter()
        plain.locale = Locale(identifier: "en_US_POSIX")
        plain.timeZone = zone
        plain.calendar = calendar

        func formatted(_ format: String) -> String {
            plain.dateFormat = format
            return plain.string(from: date)
        }

        let seconds = zone.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "-" : "+"
        let offsetText = String(format: "%@%02d:%02d", sign, abs(seconds) / 3600, (abs(seconds) % 3600) / 60)

        let weekdayNumber = parts.weekday ?? 1
        // Foundation's `quarter` component is documented but returns 0 on the
        // Gregorian calendar in practice, so it is derived from the month.
        let quarter = ((parts.month ?? 1) - 1) / 3 + 1

        return Instant(
            iso: iso.string(from: date),
            utc: utcFormatter.string(from: date),
            epoch: Int(date.timeIntervalSince1970),
            date: formatted("yyyy-MM-dd"),
            time: formatted("HH:mm:ss"),
            zone: zone.identifier,
            offset: offsetText,
            weekday: formatted("EEEE"),
            // `Calendar.Component.dayOfYear` is macOS 15+. `ordinality` has
            // answered the same question since macOS 10.4, and keeping it
            // costs nothing but holds the floor at 14 for every consumer.
            dayOfYear: calendar.ordinality(of: .day, in: .year, for: date) ?? 0,
            isoWeek: parts.weekOfYear ?? 0,
            isoWeekYear: parts.yearForWeekOfYear ?? 0,
            quarter: quarter,
            isDST: zone.isDaylightSavingTime(for: date),
            isWeekend: weekdayNumber == 1 || weekdayNumber == 7,
            timeOfDay: DayParts.part(forHour: parts.hour ?? 0, boundaries: .default)
        )
    }
}

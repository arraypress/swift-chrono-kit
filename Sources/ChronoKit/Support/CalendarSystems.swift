//
//  CalendarSystems.swift
//  ChronoKit
//
//  The same day, counted by another calendar.
//

import Foundation

extension Chrono {

    /// The calendar date of `date` in `system`, on the day it falls in ``timeZone``.
    ///
    /// The zone matters more than usual: a Hebrew or Islamic day begins at
    /// sunset and a Persian year at the vernal equinox as observed in Tehran,
    /// but every calendar here counts civil days from midnight in the zone
    /// asked for, which is what a printed calendar in that place shows.
    public static func calendarDate(_ date: Date, in system: CalendarSystem) -> CalendarDate {
        let calendar = CalendarSystems.calendar(for: system)
        let parts = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return CalendarDate(
            system: system,
            era: parts.era ?? 1,
            year: parts.year ?? 0,
            month: parts.month ?? 0,
            day: parts.day ?? 0,
            isLeapMonth: parts.isLeapMonth ?? false
        )
    }

    /// The moment a calendar date begins, in ``timeZone``.
    ///
    /// Checked by reading the components back: Foundation quietly rolls an
    /// impossible day into the next month, so 31 Muharram would come back as
    /// 1 Safar and nobody would notice.
    ///
    /// - Throws: ``ChronoError/badCalendarDate(_:)`` when the year has no such day.
    public static func date(from calendarDate: CalendarDate) throws -> Date {
        let calendar = CalendarSystems.calendar(for: calendarDate.system)
        var components = DateComponents(
            era: calendarDate.era, year: calendarDate.year, month: calendarDate.month, day: calendarDate.day
        )
        components.isLeapMonth = calendarDate.isLeapMonth
        guard let date = calendar.date(from: components) else {
            throw ChronoError.badCalendarDate(calendarDate.described)
        }
        let back = calendar.dateComponents([.era, .year, .month, .day], from: date)
        guard back.era == calendarDate.era, back.year == calendarDate.year,
              back.month == calendarDate.month, back.day == calendarDate.day,
              (back.isLeapMonth ?? false) == calendarDate.isLeapMonth
        else {
            throw ChronoError.badCalendarDate(calendarDate.described)
        }
        return date
    }

    /// The same day in another calendar.
    ///
    /// - Throws: ``ChronoError/badCalendarDate(_:)`` when the source date does not exist.
    public static func convert(_ calendarDate: CalendarDate, to system: CalendarSystem) throws -> CalendarDate {
        self.calendarDate(try date(from: calendarDate), in: system)
    }
}

/// The calendars, built in ``Chrono/timeZone``.
enum CalendarSystems {

    /// The era the calendar is in today: Reiwa for Japanese, cycle 78 for
    /// Chinese, and whichever constant Foundation uses for the rest.
    static func currentEra(for system: CalendarSystem) -> Int {
        calendar(for: system).component(.era, from: Date())
    }

    /// A calendar of the system, counting days from midnight in Chrono's zone.
    static func calendar(for system: CalendarSystem) -> Calendar {
        var calendar = Calendar(identifier: system.identifier)
        calendar.timeZone = Chrono.timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }
}

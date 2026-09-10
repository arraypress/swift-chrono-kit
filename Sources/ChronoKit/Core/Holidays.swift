//
//  Holidays.swift
//  ChronoKit
//
//  Public holidays computed by rule, for any year the rule was the law.
//

import Foundation

/// Public holidays by rule, so a deadline calculator does not need a file.
///
/// The dates move every year; the rules do not. "The last Monday in May",
/// "the fourth Thursday in November", "Easter Monday" and "the next weekday
/// when it lands on a weekend" describe every year at once, offline, and the
/// few holidays a government declared one at a time — a jubilee, a
/// coronation, a state funeral — are a short table. What comes back feeds
/// straight into ``Chrono/isBusinessDay(_:holidays:)`` through ``set(_:)``.
///
/// Days are the start of their day in ``Chrono/timeZone``, like everything
/// else here. Compute holidays in the zone the business keeps.
public enum Holidays {

    /// Easter Sunday in a Gregorian year.
    ///
    /// - Throws: ``HolidayError/yearNotCovered(year:region:from:)`` before
    ///   1583, the first full Gregorian year.
    public static func easter(year: Int) throws -> Date {
        guard year >= Easter.firstYear else {
            throw HolidayError.yearNotCovered(year: year, region: "Easter", from: Easter.firstYear)
        }
        let when = Easter.monthAndDay(year: year)
        guard let date = MonthDays.date(year: year, month: when.month, day: when.day) else {
            throw ChronoError.outOfRange("Easter \(year)")
        }
        return date
    }

    /// The United States federal holidays of `year`, with their observed days.
    ///
    /// The eleven of 5 U.S.C. § 6103 as the Office of Personnel Management
    /// lists them, each from the year it began. Observed days follow the
    /// federal rule — Saturday to Friday, Sunday to Monday — so New Year's
    /// Day 2022 is observed on 31 December 2021. Inauguration Day, which is
    /// a holiday in the District of Columbia only, is not here.
    ///
    /// - Throws: ``HolidayError/yearNotCovered(year:region:from:)`` before 1971.
    public static func unitedStatesFederal(year: Int) throws -> [Holiday] {
        try covered(year: year, region: .unitedStates)
        return USFederalHolidays.holidays(year: year)
    }

    /// The bank holidays of `year` for a UK region, with their substitute days.
    ///
    /// England and Wales unless asked otherwise. The rules are gov.uk's and
    /// describe every year from 1978; the years the government moved a day
    /// or added one — 1995, 1999, 2002, 2011, 2012, 2020, 2022 and 2023 —
    /// are applied automatically from ``unitedKingdomExtras(year:)`` and the
    /// moved dates inside the rules.
    ///
    /// - Throws: ``HolidayError/yearNotCovered(year:region:from:)`` before 1978.
    public static func unitedKingdom(year: Int, region: HolidayRegion = .englandAndWales) throws -> [Holiday] {
        let ukRegion = region == .unitedStates ? HolidayRegion.englandAndWales : region
        try covered(year: year, region: ukRegion)
        return UKBankHolidays.holidays(year: year, region: ukRegion)
    }

    /// The one-off UK bank holidays, as declared: jubilees, a royal wedding,
    /// a state funeral, a coronation, the millennium. Empty for most years.
    ///
    /// Already included by ``unitedKingdom(year:region:)``; exposed so a
    /// caller can show why a year has an extra day.
    public static func unitedKingdomExtras(year: Int) -> [Holiday] {
        UKBankHolidays.extras(year: year)
    }

    /// The holidays of `year` for any region this package knows.
    ///
    /// - Throws: ``HolidayError/yearNotCovered(year:region:from:)`` before the
    ///   region's rules applied.
    public static func holidays(year: Int, region: HolidayRegion) throws -> [Holiday] {
        switch region {
        case .unitedStates: return try unitedStatesFederal(year: year)
        default: return try unitedKingdom(year: year, region: region)
        }
    }

    /// The days taken, as the set ``Chrono/isBusinessDay(_:holidays:)`` takes.
    ///
    /// Observed days, not nominal ones: the office is shut on the Monday, not
    /// on the Saturday the calendar printed.
    public static func set(_ holidays: [Holiday]) -> Set<Date> {
        Set(holidays.map { Chrono.calendar.startOfDay(for: $0.observedDate) })
    }

    private static func covered(year: Int, region: HolidayRegion) throws {
        guard year >= region.firstCoveredYear else {
            throw HolidayError.yearNotCovered(year: year, region: region.label, from: region.firstCoveredYear)
        }
    }
}

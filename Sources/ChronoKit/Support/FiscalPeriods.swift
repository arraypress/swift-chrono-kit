//
//  FiscalPeriods.swift
//  ChronoKit
//
//  Quarters and years that do not start on 1 January.
//

import Foundation

extension Chrono {

    /// The fiscal quarter `date` falls in, for a year that starts when
    /// `fiscalYear` says.
    ///
    /// Quarters are three calendar months from the fiscal year's first day,
    /// so a UK Q1 is 6 April to 5 July and Q4 is 6 January to 5 April — and
    /// 5 April belongs to the *previous* fiscal year, which is the mistake
    /// every spreadsheet makes once. The default ``FiscalYear/calendar``
    /// gives the same quarters as ``Instant/quarter``.
    public static func fiscalQuarter(_ date: Date, fiscalYear: FiscalYear = .calendar) -> FiscalQuarter {
        let year = fiscalYearRange(date, fiscalYear: fiscalYear)
        let quarter = FiscalPeriods.quarter(containing: date, yearStart: year.start)
        return FiscalQuarter(
            number: quarter.number,
            startYear: calendar.component(.year, from: year.start),
            endYear: calendar.component(.year, from: year.end),
            days: quarter.days,
            fiscalYear: fiscalYear
        )
    }

    /// The days of the fiscal year `date` falls in.
    public static func fiscalYear(_ date: Date, fiscalYear: FiscalYear = .calendar) -> DateRange {
        fiscalYearRange(date, fiscalYear: fiscalYear)
    }

    private static func fiscalYearRange(_ date: Date, fiscalYear: FiscalYear) -> DateRange {
        let start = FiscalPeriods.yearStart(containing: date, fiscalYear: fiscalYear)
        let next = calendar.date(byAdding: .year, value: 1, to: start) ?? start
        let end = calendar.date(byAdding: .day, value: -1, to: next) ?? start
        return DateRange(start: start, end: end)
    }
}

/// The arithmetic behind fiscal periods.
enum FiscalPeriods {

    /// A month 1–12 and a day 1–28.
    static func validate(startMonth: Int, startDay: Int) throws {
        guard (1...12).contains(startMonth), (1...28).contains(startDay) else {
            throw ChronoError.badFiscalYear("month \(startMonth), day \(startDay)")
        }
    }

    /// The first day of the fiscal year containing `date`: this calendar
    /// year's start if it has happened, otherwise last year's.
    static func yearStart(containing date: Date, fiscalYear: FiscalYear) -> Date {
        let calendar = Chrono.calendar
        let day = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: day)
        let thisYear = calendar.date(from: DateComponents(year: year, month: fiscalYear.startMonth, day: fiscalYear.startDay)) ?? day
        if day >= thisYear { return thisYear }
        return calendar.date(byAdding: .year, value: -1, to: thisYear) ?? thisYear
    }

    /// The quarter, counted in three-month steps from the year's first day.
    static func quarter(containing date: Date, yearStart: Date) -> (number: Int, days: DateRange) {
        let calendar = Chrono.calendar
        let day = calendar.startOfDay(for: date)
        for number in 1...4 {
            let start = calendar.date(byAdding: .month, value: (number - 1) * 3, to: yearStart) ?? yearStart
            let next = calendar.date(byAdding: .month, value: number * 3, to: yearStart) ?? yearStart
            let end = calendar.date(byAdding: .day, value: -1, to: next) ?? start
            if number == 4 || day < next {
                return (number, DateRange(start: start, end: end))
            }
        }
        // Unreachable: the loop returns on the fourth pass.
        return (4, DateRange(day: yearStart))
    }

    /// `2026` when both ends share a year, `2026/27` otherwise.
    static func yearLabel(startYear: Int, endYear: Int) -> String {
        guard startYear != endYear else { return "\(startYear)" }
        return "\(startYear)/\(String(format: "%02d", endYear % 100))"
    }
}

//
//  USFederalHolidays.swift
//  ChronoKit
//
//  The eleven federal holidays of 5 U.S.C. § 6103, and the observed-day rule.
//

import Foundation

/// The United States federal rules.
enum USFederalHolidays {

    /// The holidays of `year`, nominal dates in calendar order.
    ///
    /// The list has grown: Washington's Birthday, Memorial Day and Columbus
    /// Day moved to Mondays in 1971, Martin Luther King Jr.'s birthday was
    /// first observed in 1986, and Juneteenth in 2021. Each appears from its
    /// first year, so an old year's list is that year's list.
    static func holidays(year: Int) -> [Holiday] {
        var list: [(String, Date?)] = [
            ("New Year's Day", MonthDays.date(year: year, month: 1, day: 1)),
        ]
        if year >= 1986 {
            list.append(("Birthday of Martin Luther King, Jr.", MonthDays.nth(3, .monday, year: year, month: 1)))
        }
        list.append(("Washington's Birthday", MonthDays.nth(3, .monday, year: year, month: 2)))
        list.append(("Memorial Day", MonthDays.nth(-1, .monday, year: year, month: 5)))
        if year >= 2021 {
            list.append(("Juneteenth National Independence Day", MonthDays.date(year: year, month: 6, day: 19)))
        }
        list.append(("Independence Day", MonthDays.date(year: year, month: 7, day: 4)))
        list.append(("Labor Day", MonthDays.nth(1, .monday, year: year, month: 9)))
        list.append(("Columbus Day", MonthDays.nth(2, .monday, year: year, month: 10)))
        list.append(("Veterans Day", MonthDays.date(year: year, month: 11, day: 11)))
        list.append(("Thanksgiving Day", MonthDays.nth(4, .thursday, year: year, month: 11)))
        list.append(("Christmas Day", MonthDays.date(year: year, month: 12, day: 25)))

        return list.compactMap { name, date in
            guard let date else { return nil }
            return Holiday(name: name, date: date, observedDate: observed(date), region: .unitedStates)
        }
    }

    /// The federal observed-day rule: a Saturday holiday is taken on the
    /// Friday before, a Sunday holiday on the Monday after.
    ///
    /// The Friday rule is what puts New Year's Day 2022 on 31 December 2021 —
    /// a holiday observed in the previous calendar year, which a set built
    /// for one year alone will miss. Union two years when the boundary matters.
    static func observed(_ date: Date) -> Date {
        let calendar = Chrono.calendar
        switch MonthDays.weekday(of: date) {
        case .saturday: return calendar.date(byAdding: .day, value: -1, to: date) ?? date
        case .sunday: return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        default: return date
        }
    }
}

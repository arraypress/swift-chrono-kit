//
//  UKBankHolidays.swift
//  ChronoKit
//
//  Bank holidays for the three UK regions: the rules, the substitute days,
//  and the years the government did something else.
//

import Foundation

/// The United Kingdom's rules, region by region.
enum UKBankHolidays {

    /// The holidays of `year` for a region, taken days in calendar order.
    ///
    /// The rules are the Banking and Financial Dealings Act 1971 as gov.uk
    /// applies it, and they cover every year from 1978 (when the Early May
    /// bank holiday began) except the ones in ``extras(year:)``, which were
    /// announced one at a time and are listed one at a time.
    static func holidays(year: Int, region: HolidayRegion) -> [Holiday] {
        let easter = Easter.monthAndDay(year: year)
        let calendar = Chrono.calendar
        guard let easterSunday = MonthDays.date(year: year, month: easter.month, day: easter.day) else { return [] }
        let goodFriday = calendar.date(byAdding: .day, value: -2, to: easterSunday)
        let easterMonday = calendar.date(byAdding: .day, value: 1, to: easterSunday)

        // Nominal days. Easter's two never fall on a weekend, so they carry no
        // substitute; the fixed dates do.
        var nominal: [(String, Date?)] = [("New Year's Day", MonthDays.date(year: year, month: 1, day: 1))]
        if region == .scotland {
            nominal.append(("2nd January", MonthDays.date(year: year, month: 1, day: 2)))
        }
        if region == .northernIreland {
            nominal.append(("St Patrick's Day", MonthDays.date(year: year, month: 3, day: 17)))
        }
        nominal.append(("Good Friday", goodFriday))
        if region != .scotland {
            nominal.append(("Easter Monday", easterMonday))
        }
        nominal.append(("Early May bank holiday", earlyMay(year: year)))
        nominal.append(("Spring bank holiday", spring(year: year)))
        if region == .northernIreland {
            nominal.append(("Battle of the Boyne (Orangemen's Day)", MonthDays.date(year: year, month: 7, day: 12)))
        }
        nominal.append(("Summer bank holiday", region == .scotland
                        ? MonthDays.nth(1, .monday, year: year, month: 8)
                        : MonthDays.nth(-1, .monday, year: year, month: 8)))
        if region == .scotland, year >= 2007 {
            nominal.append(("St Andrew's Day", MonthDays.date(year: year, month: 11, day: 30)))
        }
        nominal.append(("Christmas Day", MonthDays.date(year: year, month: 12, day: 25)))
        nominal.append(("Boxing Day", MonthDays.date(year: year, month: 12, day: 26)))

        let dated = nominal.compactMap { name, date in date.map { (name, $0) } }
        var holidays = substituted(dated, region: region)
        holidays.append(contentsOf: extras(year: year).map {
            Holiday(name: $0.name, date: $0.date, observedDate: $0.observedDate, region: region)
        })
        return holidays.sorted { $0.observedDate < $1.observedDate }
    }

    /// The first Monday in May — except in the years the government moved it.
    static func earlyMay(year: Int) -> Date? {
        switch year {
        case 1995: return MonthDays.date(year: year, month: 5, day: 8)   // VE Day 50
        case 2020: return MonthDays.date(year: year, month: 5, day: 8)   // VE Day 75
        default: return MonthDays.nth(1, .monday, year: year, month: 5)
        }
    }

    /// The last Monday in May — except in Jubilee years, when it moved to June.
    static func spring(year: Int) -> Date? {
        switch year {
        case 2002: return MonthDays.date(year: year, month: 6, day: 4)
        case 2012: return MonthDays.date(year: year, month: 6, day: 4)
        case 2022: return MonthDays.date(year: year, month: 6, day: 2)
        default: return MonthDays.nth(-1, .monday, year: year, month: 5)
        }
    }

    /// The UK substitute-day rule: a holiday on a weekend is taken on the
    /// next weekday that no other holiday has already taken.
    ///
    /// That last clause is the whole subtlety. When Christmas Day is a
    /// Saturday and Boxing Day a Sunday, Christmas takes the Monday and Boxing
    /// Day the Tuesday. When Christmas is a Sunday, Boxing Day keeps its own
    /// Monday and Christmas's substitute is the Tuesday — gov.uk's 2022 list.
    /// Scotland's 1 and 2 January work the same way.
    static func substituted(_ nominal: [(String, Date)], region: HolidayRegion) -> [Holiday] {
        let calendar = Chrono.calendar
        var taken: Set<Date> = Set(nominal.map(\.1).filter { !MonthDays.weekday(of: $0).isWeekend })
        var result: [Holiday] = []
        for (name, date) in nominal.sorted(by: { $0.1 < $1.1 }) {
            var observed = date
            if MonthDays.weekday(of: date).isWeekend {
                repeat {
                    observed = calendar.date(byAdding: .day, value: 1, to: observed) ?? observed
                } while MonthDays.weekday(of: observed).isWeekend || taken.contains(observed)
                taken.insert(observed)
            }
            result.append(Holiday(name: name, date: date, observedDate: observed, region: region))
        }
        return result
    }

    /// The one-off holidays, as gov.uk announced them. All regions had each.
    static func extras(year: Int) -> [Holiday] {
        let one: [(Int, Int, Int, String)] = [
            (1999, 12, 31, "Millennium bank holiday"),
            (2002, 6, 3, "Golden Jubilee bank holiday"),
            (2011, 4, 29, "Royal Wedding bank holiday"),
            (2012, 6, 5, "Diamond Jubilee bank holiday"),
            (2022, 6, 3, "Platinum Jubilee bank holiday"),
            (2022, 9, 19, "Bank Holiday for the State Funeral of Queen Elizabeth II"),
            (2023, 5, 8, "Bank holiday for the coronation of King Charles III"),
        ]
        return one.compactMap { entry in
            guard entry.0 == year, let date = MonthDays.date(year: entry.0, month: entry.1, day: entry.2) else { return nil }
            return Holiday(name: entry.3, date: date, observedDate: date, region: .englandAndWales)
        }
    }
}

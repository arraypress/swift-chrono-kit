//
//  HolidayTests.swift
//  ChronoKit
//
//  Every list here is a published one — gov.uk's bank holidays and OPM's
//  federal holidays — checked date by date, in the zone the government
//  keeps. A rule that is right for 2025 and wrong for 2027 is a rule that
//  never met Christmas on a Saturday.
//

import XCTest
@testable import ChronoKit

private let london = TimeZone(identifier: "Europe/London")!
private let newYork = TimeZone(identifier: "America/New_York")!

/// A calendar day as `yyyy-MM-dd` in the current zone.
private func day(_ date: Date) -> String { Chrono.describe(date).date }

/// The taken days of a list, as text, in order.
private func taken(_ holidays: [Holiday]) -> [String] { holidays.map { day($0.observedDate) } }

final class EasterTests: XCTestCase {

    func testKnownEasters() throws {
        try Chrono.inZone(london) {
            XCTAssertEqual(day(try Holidays.easter(year: 2024)), "2024-03-31")
            XCTAssertEqual(day(try Holidays.easter(year: 2025)), "2025-04-20")
            XCTAssertEqual(day(try Holidays.easter(year: 2026)), "2026-04-05")
            XCTAssertEqual(day(try Holidays.easter(year: 2027)), "2027-03-28")
            XCTAssertEqual(day(try Holidays.easter(year: 2038)), "2038-04-25")
            // The extremes of the cycle: the earliest and latest possible.
            XCTAssertEqual(day(try Holidays.easter(year: 1818)), "1818-03-22")
            XCTAssertEqual(day(try Holidays.easter(year: 1943)), "1943-04-25")
        }
    }

    func testEasterIsAlwaysASunday() throws {
        try Chrono.inZone(london) {
            for year in stride(from: 1900, through: 2100, by: 7) {
                XCTAssertEqual(MonthDays.weekday(of: try Holidays.easter(year: year)), .sunday, "\(year)")
            }
        }
    }

    func testBeforeTheGregorianCalendarIsRefused() {
        XCTAssertThrowsError(try Holidays.easter(year: 1582)) { error in
            XCTAssertEqual(error as? HolidayError, .yearNotCovered(year: 1582, region: "Easter", from: 1583))
            XCTAssertTrue(error.localizedDescription.contains("1583 onwards"))
        }
        XCTAssertNoThrow(try Holidays.easter(year: 1583))
    }
}

final class UnitedStatesHolidayTests: XCTestCase {

    func testTheOPMListFor2025() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(taken(try Holidays.unitedStatesFederal(year: 2025)), [
                "2025-01-01", "2025-01-20", "2025-02-17", "2025-05-26", "2025-06-19", "2025-07-04",
                "2025-09-01", "2025-10-13", "2025-11-11", "2025-11-27", "2025-12-25",
            ])
        }
    }

    func testTheOPMListFor2026HasIndependenceDayObservedOnFriday() throws {
        try Chrono.inZone(newYork) {
            let list = try Holidays.unitedStatesFederal(year: 2026)
            XCTAssertEqual(taken(list), [
                "2026-01-01", "2026-01-19", "2026-02-16", "2026-05-25", "2026-06-19", "2026-07-03",
                "2026-09-07", "2026-10-12", "2026-11-11", "2026-11-26", "2026-12-25",
            ])
            let fourth = try XCTUnwrap(list.first { $0.name == "Independence Day" })
            XCTAssertEqual(day(fourth.date), "2026-07-04")
            XCTAssertEqual(day(fourth.observedDate), "2026-07-03")
            XCTAssertTrue(fourth.isObservedShift)
            XCTAssertFalse(try XCTUnwrap(list.first { $0.name == "Labor Day" }).isObservedShift)
        }
    }

    func testChristmasOnASaturdayIsObservedOnTheFriday() throws {
        try Chrono.inZone(newYork) {
            let christmas = try XCTUnwrap(try Holidays.unitedStatesFederal(year: 2027).last)
            XCTAssertEqual(christmas.name, "Christmas Day")
            XCTAssertEqual(day(christmas.date), "2027-12-25")
            XCTAssertEqual(day(christmas.observedDate), "2027-12-24")
        }
    }

    func testNewYearsDayOnASaturdayIsObservedInThePreviousYear() throws {
        try Chrono.inZone(newYork) {
            let first = try XCTUnwrap(try Holidays.unitedStatesFederal(year: 2022).first)
            XCTAssertEqual(day(first.date), "2022-01-01")
            XCTAssertEqual(day(first.observedDate), "2021-12-31")
            // And a Sunday goes forward: 1 January 2023.
            let sunday = try XCTUnwrap(try Holidays.unitedStatesFederal(year: 2023).first)
            XCTAssertEqual(day(sunday.observedDate), "2023-01-02")
        }
    }

    func testTheListGrewOverTheYears() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try Holidays.unitedStatesFederal(year: 1980).count, 9, "no MLK Day, no Juneteenth")
            XCTAssertEqual(try Holidays.unitedStatesFederal(year: 1986).count, 10, "MLK Day from 1986")
            XCTAssertEqual(try Holidays.unitedStatesFederal(year: 2020).count, 10)
            XCTAssertEqual(try Holidays.unitedStatesFederal(year: 2021).count, 11, "Juneteenth from 2021")
            XCTAssertFalse(try Holidays.unitedStatesFederal(year: 2020).contains { $0.name.hasPrefix("Juneteenth") })
        }
    }

    func testYearsBeforeTheMondayHolidaysAreRefused() {
        XCTAssertThrowsError(try Holidays.unitedStatesFederal(year: 1970)) { error in
            XCTAssertEqual(error as? HolidayError, .yearNotCovered(year: 1970, region: "United States", from: 1971))
        }
        XCTAssertNoThrow(try Holidays.unitedStatesFederal(year: 1971))
    }
}

final class UnitedKingdomHolidayTests: XCTestCase {

    func testEnglandAndWales2025() throws {
        try Chrono.inZone(london) {
            XCTAssertEqual(taken(try Holidays.unitedKingdom(year: 2025)), [
                "2025-01-01", "2025-04-18", "2025-04-21", "2025-05-05", "2025-05-26", "2025-08-25",
                "2025-12-25", "2025-12-26",
            ])
        }
    }

    func testEnglandAndWales2026HasABoxingDaySubstitute() throws {
        try Chrono.inZone(london) {
            let list = try Holidays.unitedKingdom(year: 2026, region: .englandAndWales)
            XCTAssertEqual(taken(list), [
                "2026-01-01", "2026-04-03", "2026-04-06", "2026-05-04", "2026-05-25", "2026-08-31",
                "2026-12-25", "2026-12-28",
            ])
            let boxing = try XCTUnwrap(list.last)
            XCTAssertEqual(boxing.name, "Boxing Day")
            XCTAssertEqual(day(boxing.date), "2026-12-26")
            XCTAssertTrue(boxing.isObservedShift)
        }
    }

    func testScotland2025And2026() throws {
        try Chrono.inZone(london) {
            XCTAssertEqual(taken(try Holidays.unitedKingdom(year: 2025, region: .scotland)), [
                "2025-01-01", "2025-01-02", "2025-04-18", "2025-05-05", "2025-05-26", "2025-08-04",
                "2025-12-01", "2025-12-25", "2025-12-26",
            ])
            let andrew = try XCTUnwrap(try Holidays.unitedKingdom(year: 2025, region: .scotland).first { $0.name == "St Andrew's Day" })
            XCTAssertEqual(day(andrew.date), "2025-11-30", "a Sunday")
            XCTAssertEqual(day(andrew.observedDate), "2025-12-01")
            XCTAssertEqual(taken(try Holidays.unitedKingdom(year: 2026, region: .scotland)), [
                "2026-01-01", "2026-01-02", "2026-04-03", "2026-05-04", "2026-05-25", "2026-08-03",
                "2026-11-30", "2026-12-25", "2026-12-28",
            ])
        }
    }

    func testNorthernIreland2025And2026() throws {
        try Chrono.inZone(london) {
            XCTAssertEqual(taken(try Holidays.unitedKingdom(year: 2025, region: .northernIreland)), [
                "2025-01-01", "2025-03-17", "2025-04-18", "2025-04-21", "2025-05-05", "2025-05-26",
                "2025-07-14", "2025-08-25", "2025-12-25", "2025-12-26",
            ])
            XCTAssertEqual(taken(try Holidays.unitedKingdom(year: 2026, region: .northernIreland)), [
                "2026-01-01", "2026-03-17", "2026-04-03", "2026-04-06", "2026-05-04", "2026-05-25",
                "2026-07-13", "2026-08-31", "2026-12-25", "2026-12-28",
            ])
        }
    }

    func testChristmasAndBoxingDayBothOnTheWeekendTakeMondayAndTuesday() throws {
        // 2027: Christmas Saturday, Boxing Day Sunday → Monday 27, Tuesday 28.
        try Chrono.inZone(london) {
            let list = try Holidays.unitedKingdom(year: 2027)
            XCTAssertEqual(Array(taken(list).suffix(2)), ["2027-12-27", "2027-12-28"])
            // 2022: Christmas Sunday → Boxing Day keeps Monday 26, Christmas takes Tuesday 27.
            let christmas = try XCTUnwrap(try Holidays.unitedKingdom(year: 2022).first { $0.name == "Christmas Day" })
            let boxing = try XCTUnwrap(try Holidays.unitedKingdom(year: 2022).first { $0.name == "Boxing Day" })
            XCTAssertEqual(day(christmas.observedDate), "2022-12-27")
            XCTAssertEqual(day(boxing.observedDate), "2022-12-26")
            XCTAssertFalse(boxing.isObservedShift)
        }
    }

    func testScotlandsTwoNewYearDaysOnTheWeekend() throws {
        try Chrono.inZone(london) {
            // 2022: 1 January Saturday → Monday 3; 2 January Sunday → Tuesday 4.
            XCTAssertEqual(Array(taken(try Holidays.unitedKingdom(year: 2022, region: .scotland)).prefix(2)), ["2022-01-03", "2022-01-04"])
            // 2023: 1 January Sunday; 2 January keeps its Monday and New Year's Day takes Tuesday 3.
            let list = try Holidays.unitedKingdom(year: 2023, region: .scotland)
            XCTAssertEqual(day(try XCTUnwrap(list.first { $0.name == "New Year's Day" }).observedDate), "2023-01-03")
            XCTAssertEqual(day(try XCTUnwrap(list.first { $0.name == "2nd January" }).observedDate), "2023-01-02")
        }
    }

    func testNewYearsDayOnASaturdayMovesToMonday() throws {
        try Chrono.inZone(london) {
            let first = try XCTUnwrap(try Holidays.unitedKingdom(year: 2022).first)
            XCTAssertEqual(day(first.date), "2022-01-01")
            XCTAssertEqual(day(first.observedDate), "2022-01-03")
        }
    }

    func testTheYearsTheGovernmentDidSomethingElse() throws {
        try Chrono.inZone(london) {
            // 2020: Early May moved to Friday 8 May for VE Day.
            let earlyMay2020 = try XCTUnwrap(try Holidays.unitedKingdom(year: 2020).first { $0.name == "Early May bank holiday" })
            XCTAssertEqual(day(earlyMay2020.date), "2020-05-08")
            // 2022: Spring moved to Thursday 2 June, Platinum Jubilee Friday 3 June, State Funeral 19 September.
            let list2022 = try Holidays.unitedKingdom(year: 2022)
            XCTAssertEqual(day(try XCTUnwrap(list2022.first { $0.name == "Spring bank holiday" }).date), "2022-06-02")
            XCTAssertTrue(taken(list2022).contains("2022-06-03"))
            XCTAssertTrue(taken(list2022).contains("2022-09-19"))
            XCTAssertEqual(list2022.count, 10)
            // 2023: the Coronation, Monday 8 May, on top of the ordinary eight.
            let list2023 = try Holidays.unitedKingdom(year: 2023)
            XCTAssertTrue(taken(list2023).contains("2023-05-08"))
            XCTAssertEqual(list2023.count, 9)
            XCTAssertEqual(Holidays.unitedKingdomExtras(year: 2023).map(\.name), ["Bank holiday for the coronation of King Charles III"])
            XCTAssertTrue(Holidays.unitedKingdomExtras(year: 2026).isEmpty)
            // Every region gets the extras.
            XCTAssertTrue(taken(try Holidays.unitedKingdom(year: 2023, region: .scotland)).contains("2023-05-08"))
        }
    }

    func testTheListsAreInDateOrder() throws {
        try Chrono.inZone(london) {
            for region in HolidayRegion.allCases {
                for year in [2022, 2025, 2026, 2027] {
                    let days = taken(try Holidays.holidays(year: year, region: region))
                    XCTAssertEqual(days, days.sorted(), "\(region) \(year)")
                }
            }
        }
    }

    func testYearsBeforeTheRulesAreRefused() {
        XCTAssertThrowsError(try Holidays.unitedKingdom(year: 1977)) { error in
            XCTAssertEqual(error as? HolidayError, .yearNotCovered(year: 1977, region: "England and Wales", from: 1978))
        }
        XCTAssertNoThrow(try Holidays.unitedKingdom(year: 1978, region: .scotland))
        XCTAssertNoThrow(try Holidays.unitedKingdom(year: 2100, region: .northernIreland))
    }

    func testAskingTheUKForTheUnitedStatesFallsBackToEnglandAndWales() throws {
        try Chrono.inZone(london) {
            XCTAssertEqual(try Holidays.unitedKingdom(year: 2025, region: .unitedStates).map(\.region).first, .englandAndWales)
        }
    }
}

final class HolidaySetTests: XCTestCase {

    func testTheSetFeedsBusinessDays() throws {
        try Chrono.inZone(london) {
            let holidays = Holidays.set(try Holidays.unitedKingdom(year: 2026))
            XCTAssertEqual(holidays.count, 8)
            // Monday 28 December 2026 is the Boxing Day substitute — not a working day.
            XCTAssertFalse(Chrono.isBusinessDay(try Chrono.date("2026-12-28"), holidays: holidays))
            // Saturday 26 December is a weekend anyway; Tuesday 29 is a working day.
            XCTAssertTrue(Chrono.isBusinessDay(try Chrono.date("2026-12-29"), holidays: holidays))
            // Ten working days from 18 December 2026 skips Christmas Day and the substitute.
            let landed = try Chrono.shiftBusinessDays(try Chrono.date("2026-12-18"), by: 10, holidays: holidays)
            XCTAssertEqual(Chrono.describe(landed).date, "2027-01-05")
            XCTAssertEqual(Chrono.businessDaysBetween(try Chrono.date("2026-12-24"), and: try Chrono.date("2026-12-29"), holidays: holidays), 1)
        }
    }

    func testTheSetHoldsTheDaysTakenNotTheNominalOnes() throws {
        try Chrono.inZone(newYork) {
            let set = Holidays.set(try Holidays.unitedStatesFederal(year: 2026))
            XCTAssertTrue(set.contains(try Chrono.date("2026-07-03")))
            XCTAssertFalse(set.contains(try Chrono.date("2026-07-04")))
        }
    }

    func testHolidaysRoundTripThroughJSON() throws {
        try Chrono.inZone(london) {
            for holiday in try Holidays.unitedKingdom(year: 2026, region: .scotland) {
                let data = try JSONEncoder().encode(holiday)
                XCTAssertEqual(try JSONDecoder().decode(Holiday.self, from: data), holiday)
            }
            for region in HolidayRegion.allCases {
                XCTAssertEqual(try JSONDecoder().decode(HolidayRegion.self, from: JSONEncoder().encode(region)), region)
            }
            for weekday in Weekday.allCases {
                XCTAssertEqual(try JSONDecoder().decode(Weekday.self, from: JSONEncoder().encode(weekday)), weekday)
            }
        }
    }
}

final class WeekdayTests: XCTestCase {

    func testNumberingIsFoundationsAndISOIsAStepAway() {
        XCTAssertEqual(Weekday.sunday.rawValue, 1)
        XCTAssertEqual(Weekday.monday.isoNumber, 1)
        XCTAssertEqual(Weekday.sunday.isoNumber, 7)
        XCTAssertEqual(Weekday.allCases.count, 7)
        XCTAssertTrue(Weekday.saturday.isWeekend)
        XCTAssertFalse(Weekday.friday.isWeekend)
    }

    func testCodesAndNamesBothWays() {
        XCTAssertEqual(Weekday.tuesday.rruleCode, "TU")
        XCTAssertEqual(Weekday(rruleCode: "fr"), .friday)
        XCTAssertNil(Weekday(rruleCode: "XX"))
        XCTAssertEqual(Weekday.wednesday.name, "Wednesday")
        XCTAssertEqual(Weekday(name: "Mon"), .monday)
        XCTAssertEqual(Weekday(name: "sunday"), .sunday)
        XCTAssertEqual(Weekday(name: "THURSDAY"), .thursday)
        XCTAssertNil(Weekday(name: "mo"))
        XCTAssertNil(Weekday(name: "noon"))
    }

    func testMonthDayArithmetic() throws {
        try Chrono.inZone(london) {
            XCTAssertEqual(MonthDays.count(year: 2024, month: 2), 29)
            XCTAssertEqual(MonthDays.count(year: 2025, month: 2), 28)
            XCTAssertNil(MonthDays.date(year: 2025, month: 2, day: 29))
            XCTAssertEqual(day(try XCTUnwrap(MonthDays.date(year: 2025, month: 4, dayFromEitherEnd: -1))), "2025-04-30")
            XCTAssertEqual(day(try XCTUnwrap(MonthDays.nth(-1, .monday, year: 2026, month: 5))), "2026-05-25")
            XCTAssertEqual(day(try XCTUnwrap(MonthDays.nth(4, .thursday, year: 2025, month: 11))), "2025-11-27")
            XCTAssertNil(MonthDays.nth(5, .thursday, year: 2025, month: 11))
            XCTAssertEqual(day(try XCTUnwrap(MonthDays.nth(20, .monday, year: 1997))), "1997-05-19")
            XCTAssertNil(MonthDays.pick(0, from: [1, 2, 3]))
            XCTAssertEqual(MonthDays.pick(-2, from: [1, 2, 3]), 2)
        }
    }
}

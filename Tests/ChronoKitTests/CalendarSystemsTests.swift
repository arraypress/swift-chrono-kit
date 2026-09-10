//
//  CalendarSystemsTests.swift
//  ChronoKit
//
//  The same day in another calendar, checked against published equivalences:
//  the first of Muharram, Rosh Hashanah, Chinese New Year, Nowruz, and a
//  Japanese era year.
//

import XCTest
@testable import ChronoKit

private let utc = TimeZone(identifier: "UTC")!
private let tehran = TimeZone(identifier: "Asia/Tehran")!

private func at(_ text: String) throws -> Date {
    try Chrono.inZone(utc) { try Chrono.date(text) }
}

final class CalendarSystemsTests: XCTestCase {

    func testTheFirstOfMuharram1447() throws {
        // Umm al-Qura: 1 Muharram 1447 AH = Thursday 26 June 2025.
        try Chrono.inZone(utc) {
            let date = Chrono.calendarDate(try at("2025-06-26"), in: .islamicUmmAlQura)
            XCTAssertEqual(date.year, 1447)
            XCTAssertEqual(date.month, 1)
            XCTAssertEqual(date.day, 1)
            XCTAssertEqual(date.monthName, "Muharram")
            XCTAssertEqual(date.eraName, "AH")
            XCTAssertEqual(date.described, "1 Muharram 1447 AH")
            XCTAssertEqual(date.era, 0, "Foundation's constant for the Islamic era")
        }
    }

    func testRoshHashanah5786() throws {
        // 1 Tishri 5786 = 23 September 2025.
        try Chrono.inZone(utc) {
            let date = Chrono.calendarDate(try at("2025-09-23"), in: .hebrew)
            XCTAssertEqual(date.year, 5786)
            XCTAssertEqual(date.month, 1)
            XCTAssertEqual(date.day, 1)
            XCTAssertEqual(date.monthName, "Tishri")
            XCTAssertEqual(date.eraName, "AM")
            XCTAssertEqual(date.era, 0, "Foundation's constant for the Hebrew era")
        }
    }

    func testReiwaEight() throws {
        try Chrono.inZone(utc) {
            let date = Chrono.calendarDate(try at("2026-01-15"), in: .japanese)
            XCTAssertEqual(date.year, 8)
            XCTAssertEqual(date.eraName, "Reiwa")
            XCTAssertEqual(date.month, 1)
            XCTAssertEqual(date.day, 15)
            XCTAssertEqual(date.described, "Reiwa 8, 15 January")
            let heisei = Chrono.calendarDate(try at("2019-04-30"), in: .japanese)
            XCTAssertEqual(heisei.eraName, "Heisei")
            XCTAssertEqual(heisei.year, 31)
        }
    }

    func testChineseNewYear2026IsTheYearOfTheHorse() throws {
        try Chrono.inZone(utc) {
            let newYear = Chrono.calendarDate(try at("2026-02-17"), in: .chinese)
            XCTAssertEqual(newYear.month, 1)
            XCTAssertEqual(newYear.day, 1)
            XCTAssertEqual(newYear.zodiacAnimal, "Horse")
            XCTAssertEqual(newYear.era, 78)
            XCTAssertEqual(newYear.year, 43)
            let eve = Chrono.calendarDate(try at("2026-02-16"), in: .chinese)
            XCTAssertEqual(eve.month, 12)
            XCTAssertEqual(eve.zodiacAnimal, "Snake")
            XCTAssertNil(Chrono.calendarDate(try at("2026-02-17"), in: .gregorian).zodiacAnimal)
        }
    }

    func testNowruz1405InTehran() throws {
        // 1 Farvardin 1405 = 21 March 2026, on Tehran's calendar day.
        try Chrono.inZone(tehran) {
            let nowruz = Chrono.calendarDate(try Chrono.date("2026-03-21"), in: .persian)
            XCTAssertEqual(nowruz.year, 1405)
            XCTAssertEqual(nowruz.month, 1)
            XCTAssertEqual(nowruz.day, 1)
            XCTAssertEqual(nowruz.monthName, "Farvardin")
            let eve = Chrono.calendarDate(try Chrono.date("2026-03-20"), in: .persian)
            XCTAssertEqual(eve.year, 1404)
        }
    }

    func testTheBuddhistYearIsFiveHundredAndFortyThreeAhead() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.calendarDate(try at("2026-01-01"), in: .buddhist).year, 2569)
        }
    }

    func testEveryCalendarRoundTrips() throws {
        try Chrono.inZone(utc) {
            let day = try at("2026-09-10")
            for system in CalendarSystem.allCases {
                let converted = Chrono.calendarDate(day, in: system)
                XCTAssertEqual(try Chrono.date(from: converted), day, system.name)
                XCTAssertFalse(converted.monthName.isEmpty, system.name)
                XCTAssertFalse(converted.eraName.isEmpty, system.name)
                XCTAssertFalse(system.name.isEmpty)
            }
            let gregorian = Chrono.calendarDate(day, in: .gregorian)
            XCTAssertEqual(gregorian.year, 2026)
            XCTAssertEqual(gregorian.month, 9)
            XCTAssertEqual(gregorian.day, 10)
            XCTAssertEqual(gregorian.monthName, "September")
            XCTAssertEqual(gregorian.eraName, "AD")
        }
    }

    func testConvertingBetweenCalendars() throws {
        try Chrono.inZone(tehran) {
            let nowruz = try Chrono.convert(CalendarDate(system: .gregorian, year: 2026, month: 3, day: 21), to: .persian)
            XCTAssertEqual(nowruz.year, 1405)
            XCTAssertEqual(nowruz.month, 1)
            XCTAssertEqual(nowruz.day, 1)
        }
        try Chrono.inZone(utc) {
            let back = try Chrono.convert(CalendarDate(system: .islamicUmmAlQura, year: 1447, month: 1, day: 1), to: .gregorian)
            XCTAssertEqual(back.year, 2025)
            XCTAssertEqual(back.month, 6)
            XCTAssertEqual(back.day, 26)
        }
    }

    func testAnImpossibleDateIsRefusedNotRolledOver() throws {
        try Chrono.inZone(utc) {
            XCTAssertThrowsError(try Chrono.date(from: CalendarDate(system: .islamicUmmAlQura, year: 1447, month: 1, day: 31))) { error in
                guard case .badCalendarDate? = error as? ChronoError else { return XCTFail("\(error)") }
                XCTAssertTrue(error.localizedDescription.contains("not a date in that calendar"))
            }
            XCTAssertThrowsError(try Chrono.date(from: CalendarDate(system: .hebrew, year: 5786, month: 14, day: 1)))
            XCTAssertThrowsError(try Chrono.date(from: CalendarDate(system: .gregorian, year: 2027, month: 2, day: 29)))
            XCTAssertNoThrow(try Chrono.date(from: CalendarDate(system: .gregorian, year: 2028, month: 2, day: 29)))
        }
    }

    func testCalendarDatesRoundTripThroughJSON() throws {
        let date = CalendarDate(system: .chinese, era: 78, year: 43, month: 6, day: 1, isLeapMonth: true)
        let data = try JSONEncoder().encode(date)
        XCTAssertEqual(try JSONDecoder().decode(CalendarDate.self, from: data), date)
        for system in CalendarSystem.allCases {
            XCTAssertEqual(try JSONDecoder().decode(CalendarSystem.self, from: JSONEncoder().encode(system)), system)
        }
    }
}

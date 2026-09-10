//
//  AgeTests.swift
//  ChronoKit
//
//  Ages the calendar decides. The leap-day case is the one that mattered:
//  the CLI verb this moved from put a 29 February birthday on 1 March.
//

import XCTest
@testable import ChronoKit

private let utc = TimeZone(identifier: "UTC")!

private func at(_ text: String) throws -> Date {
    try Chrono.inZone(utc) { try Chrono.date(text) }
}

final class AgeTests: XCTestCase {

    func testABirthdayTodayIsZeroDaysAway() throws {
        try Chrono.inZone(utc) {
            let age = try Chrono.age(born: try at("1990-05-14"), on: try at("2026-05-14T10:00"))
            XCTAssertEqual(age.years, 36)
            XCTAssertEqual(age.months, 0)
            XCTAssertEqual(age.days, 0)
            XCTAssertEqual(age.described, "36 years")
            XCTAssertEqual(Chrono.describe(age.nextBirthday).date, "2026-05-14")
            XCTAssertEqual(age.daysUntilNextBirthday, 0)
        }
    }

    func testTheDayBeforeABirthday() throws {
        try Chrono.inZone(utc) {
            let age = try Chrono.age(born: try at("1990-05-14"), on: try at("2026-05-13"))
            XCTAssertEqual(age.years, 35)
            XCTAssertEqual(age.months, 11)
            // 14 April to 13 May is 29 days — April has thirty. The calendar
            // counts months from the birthday, not from the month's end.
            XCTAssertEqual(age.days, 29)
            XCTAssertEqual(age.described, "35 years, 11 months, 29 days")
            XCTAssertEqual(age.daysUntilNextBirthday, 1)
        }
    }

    func testALeapDayBirthdayFallsOnTheTwentyEighthInACommonYear() throws {
        // The bug this pins: DateComponents(month: 2, day: 29) in 2027 is
        // handed back by Foundation as 1 March. The calendar's rule is the 28th.
        try Chrono.inZone(utc) {
            let common = try Chrono.age(born: try at("2000-02-29"), on: try at("2027-01-10"))
            XCTAssertEqual(Chrono.describe(common.nextBirthday).date, "2027-02-28")
            XCTAssertEqual(common.daysUntilNextBirthday, 49)
            let leap = try Chrono.age(born: try at("2000-02-29"), on: try at("2028-01-10"))
            XCTAssertEqual(Chrono.describe(leap.nextBirthday).date, "2028-02-29")
        }
    }

    func testTheDayAfterALeapDayBirthdayInACommonYear() throws {
        try Chrono.inZone(utc) {
            let age = try Chrono.age(born: try at("2000-02-29"), on: try at("2027-03-01"))
            XCTAssertEqual(age.years, 27)
            XCTAssertEqual(age.months, 0)
            XCTAssertEqual(age.days, 1)
            XCTAssertEqual(Chrono.describe(age.nextBirthday).date, "2028-02-29")
        }
    }

    func testMonthEndBirths() throws {
        // 31 January to 28 February is a month and no days, because the
        // calendar clamps: that is what a person means by "a month later".
        try Chrono.inZone(utc) {
            let age = try Chrono.age(born: try at("1990-01-31"), on: try at("2026-02-28"))
            XCTAssertEqual(age.years, 36)
            XCTAssertEqual(age.months, 1)
            XCTAssertEqual(age.days, 0)
            XCTAssertEqual(Chrono.describe(age.nextBirthday).date, "2027-01-31")
        }
    }

    func testDaysOld() throws {
        try Chrono.inZone(utc) {
            let age = try Chrono.age(born: try at("2026-01-01"), on: try at("2026-01-03T00:30"))
            XCTAssertEqual(age.totalDays, 2)
            XCTAssertEqual(age.days, 2)
            XCTAssertEqual(age.described, "2 days")
            let newborn = try Chrono.age(born: try at("2026-01-01"), on: try at("2026-01-01"))
            XCTAssertEqual(newborn.described, "0 days")
            XCTAssertEqual(newborn.daysUntilNextBirthday, 0)
        }
    }

    func testABirthAfterTheDateIsRefused() throws {
        try Chrono.inZone(utc) {
            XCTAssertThrowsError(try Chrono.age(born: try at("2030-01-01"), on: try at("2026-01-01"))) { error in
                XCTAssertEqual(error as? ChronoError, .futureBirth("2030-01-01 is after 2026-01-01"))
                XCTAssertTrue(error.localizedDescription.contains("negative age"))
            }
        }
    }

    func testAgesRoundTripThroughJSON() throws {
        try Chrono.inZone(utc) {
            let age = try Chrono.age(born: try at("1990-05-14"), on: try at("2026-05-13"))
            let data = try JSONEncoder().encode(age)
            XCTAssertEqual(try JSONDecoder().decode(Age.self, from: data), age)
        }
    }

    func testTheWording() {
        XCTAssertEqual(Ages.described(years: 1, months: 1, days: 1), "1 year, 1 month, 1 day")
        XCTAssertEqual(Ages.described(years: 0, months: 0, days: 5), "5 days")
        XCTAssertEqual(Ages.described(years: 2, months: 0, days: 0), "2 years")
        XCTAssertEqual(Ages.described(years: 0, months: 0, days: 0), "0 days")
    }
}

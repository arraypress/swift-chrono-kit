//
//  BusinessHoursTests.swift
//  ChronoKit
//
//  Working time between two instants, walked day by day. Every case is a
//  fixed week in September 2026: the 4th is a Friday, the 7th a Monday.
//

import XCTest
@testable import ChronoKit

private let utc = TimeZone(identifier: "UTC")!
private let london = TimeZone(identifier: "Europe/London")!

private func at(_ text: String) throws -> Date {
    try Chrono.inZone(utc) { try Chrono.date(text) }
}

final class BusinessHoursTests: XCTestCase {

    private let hours = BusinessHours.nineToFive

    func testFridayAfternoonToMondayMorningIsTwoHours() throws {
        try Chrono.inZone(utc) {
            let worked = Chrono.businessHours(from: try at("2026-09-04T16:00"), to: try at("2026-09-07T10:00"), hours: hours)
            XCTAssertEqual(worked, 2 * 3600)
        }
    }

    func testAHolidayMondayTakesItsHourAway() throws {
        try Chrono.inZone(utc) {
            let schedule = try BusinessHours(days: Weekday.weekdays, opens: try ClockTime(hour: 9), closes: try ClockTime(hour: 17),
                                             holidays: [try at("2026-09-07")])
            let worked = Chrono.businessHours(from: try at("2026-09-04T16:00"), to: try at("2026-09-07T10:00"), hours: schedule)
            XCTAssertEqual(worked, 1 * 3600)
        }
    }

    func testTheWorkingDayAcrossAClockChangeIsStillEightHours() throws {
        // London springs forward at 01:00 on Sunday 29 March 2026. A schedule
        // that works Sundays still works 09:00 to 17:00 by the wall clock.
        try Chrono.inZone(london) {
            let everyDay = try BusinessHours(days: Set(Weekday.allCases), opens: try ClockTime(hour: 9), closes: try ClockTime(hour: 17))
            let start = try Chrono.date("2026-03-29T08:00"), end = try Chrono.date("2026-03-29T18:00")
            XCTAssertEqual(Chrono.businessHours(from: start, to: end, hours: everyDay), 8 * 3600)
            let autumn = Chrono.businessHours(from: try Chrono.date("2026-10-25T08:00"), to: try Chrono.date("2026-10-25T18:00"), hours: everyDay)
            XCTAssertEqual(autumn, 8 * 3600)
        }
    }

    func testStartsInsideBeforeAndAfterTheWindow() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.businessHours(from: try at("2026-09-07T10:00"), to: try at("2026-09-07T12:00"), hours: hours), 2 * 3600)
            XCTAssertEqual(Chrono.businessHours(from: try at("2026-09-07T07:00"), to: try at("2026-09-07T10:00"), hours: hours), 1 * 3600)
            XCTAssertEqual(Chrono.businessHours(from: try at("2026-09-07T18:00"), to: try at("2026-09-08T08:00"), hours: hours), 0)
            XCTAssertEqual(Chrono.businessHours(from: try at("2026-09-07T10:30"), to: try at("2026-09-08T10:30"), hours: hours), 8 * 3600)
        }
    }

    func testAWholeWeekIsFortyHours() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.businessHours(from: try at("2026-09-07"), to: try at("2026-09-14"), hours: hours), 40 * 3600)
        }
    }

    func testZeroLengthAndBackwardsInput() throws {
        try Chrono.inZone(utc) {
            let moment = try at("2026-09-07T10:00")
            XCTAssertEqual(Chrono.businessHours(from: moment, to: moment, hours: hours), 0)
            let forward = Chrono.businessHours(from: try at("2026-09-04T16:00"), to: try at("2026-09-07T10:00"), hours: hours)
            let backward = Chrono.businessHours(from: try at("2026-09-07T10:00"), to: try at("2026-09-04T16:00"), hours: hours)
            XCTAssertEqual(forward, backward)
        }
    }

    func testOpenClosedAtTheEdges() throws {
        try Chrono.inZone(utc) {
            XCTAssertTrue(Chrono.isOpen(try at("2026-09-07T09:00"), hours: hours))
            XCTAssertTrue(Chrono.isOpen(try at("2026-09-07T16:59:59"), hours: hours))
            XCTAssertFalse(Chrono.isOpen(try at("2026-09-07T17:00"), hours: hours))
            XCTAssertFalse(Chrono.isOpen(try at("2026-09-07T08:59:59"), hours: hours))
            XCTAssertFalse(Chrono.isOpen(try at("2026-09-05T12:00"), hours: hours), "Saturday")
            let holiday = try BusinessHours(days: Weekday.weekdays, opens: try ClockTime(hour: 9), closes: try ClockTime(hour: 17),
                                            holidays: [try at("2026-09-07")])
            XCTAssertFalse(Chrono.isOpen(try at("2026-09-07T12:00"), hours: holiday))
        }
    }

    func testTheNextOpening() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(try Chrono.nextOpening(after: try at("2026-09-04T18:00"), hours: hours), try at("2026-09-07T09:00"))
            XCTAssertEqual(try Chrono.nextOpening(after: try at("2026-09-06T12:00"), hours: hours), try at("2026-09-07T09:00"))
            XCTAssertEqual(try Chrono.nextOpening(after: try at("2026-09-07T07:00"), hours: hours), try at("2026-09-07T09:00"))
            let open = try at("2026-09-07T10:00")
            XCTAssertEqual(try Chrono.nextOpening(after: open, hours: hours), open, "already open: the moment itself")
            let holiday = try BusinessHours(days: Weekday.weekdays, opens: try ClockTime(hour: 9), closes: try ClockTime(hour: 17),
                                            holidays: [try at("2026-09-07")])
            XCTAssertEqual(try Chrono.nextOpening(after: try at("2026-09-04T18:00"), hours: holiday), try at("2026-09-08T09:00"))
        }
    }

    func testADeadlineInWorkingHours() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(try Chrono.addBusinessHours(2 * 3600, to: try at("2026-09-04T16:00"), hours: hours), try at("2026-09-07T10:00"))
            XCTAssertEqual(try Chrono.addBusinessHours(8 * 3600, to: try at("2026-09-07T09:00"), hours: hours), try at("2026-09-07T17:00"))
            XCTAssertEqual(try Chrono.addBusinessHours(8 * 3600 + 1, to: try at("2026-09-07T09:00"), hours: hours), try at("2026-09-08T09:00:01"))
            XCTAssertEqual(try Chrono.addBusinessHours(40 * 3600, to: try at("2026-09-07T09:00"), hours: hours), try at("2026-09-11T17:00"))
            XCTAssertEqual(try Chrono.addBusinessHours(0, to: try at("2026-09-05T12:00"), hours: hours), try at("2026-09-07T09:00"))
            XCTAssertEqual(try Chrono.addBusinessHours(3600, to: try at("2026-09-07T07:00"), hours: hours), try at("2026-09-07T10:00"))
            XCTAssertThrowsError(try Chrono.addBusinessHours(-1, to: try at("2026-09-07T09:00"), hours: hours))
        }
    }

    func testAScheduleIsChecked() throws {
        XCTAssertThrowsError(try BusinessHours(days: Weekday.weekdays, opens: try ClockTime(hour: 22), closes: try ClockTime(hour: 6))) { error in
            guard case .badBusinessHours(let what)? = error as? ChronoError else { return XCTFail("\(error)") }
            XCTAssertTrue(what.contains("two days"))
            XCTAssertTrue(error.localizedDescription.contains("not a working schedule"))
        }
        XCTAssertThrowsError(try BusinessHours(days: Weekday.weekdays, opens: try ClockTime(hour: 9), closes: try ClockTime(hour: 9)))
        XCTAssertThrowsError(try BusinessHours(days: [], opens: try ClockTime(hour: 9), closes: try ClockTime(hour: 17)))
        XCTAssertNoThrow(try BusinessHours(days: [.saturday], opens: try ClockTime(hour: 10), closes: try ClockTime(hour: 10, minute: 30)))
    }

    func testWeekdaysAreNumberedTheISOWay() {
        // Foundation's numbering is the raw value; ISO's is one property away.
        XCTAssertEqual(Weekday.sunday.rawValue, 1)
        XCTAssertEqual(Weekday.monday.isoNumber, 1)
        XCTAssertEqual(Weekday.sunday.isoNumber, 7)
        XCTAssertEqual(Weekday(isoNumber: 7), .sunday)
        XCTAssertEqual(Weekday(isoNumber: 1), .monday)
        XCTAssertNil(Weekday(isoNumber: 8))
        XCTAssertEqual(Weekday.sunday.foundationWeekday, 1)
        XCTAssertEqual(Weekday.monday.foundationWeekday, 2)
        XCTAssertEqual(Weekday.saturday.foundationWeekday, 7)
        for day in Weekday.allCases {
            XCTAssertEqual(Weekday(foundationWeekday: day.foundationWeekday), day)
        }
        XCTAssertNil(Weekday(foundationWeekday: 0))
        XCTAssertNil(Weekday(foundationWeekday: 8))
        XCTAssertEqual(Weekday.wednesday.name, "Wednesday")
        XCTAssertEqual(Weekday.weekdays.count, 5)
        XCTAssertEqual(Weekday.weekend, [.saturday, .sunday])
    }

    func testSchedulesRoundTripThroughJSON() throws {
        let schedule = try BusinessHours(days: [.monday, .wednesday], opens: try ClockTime(hour: 8, minute: 30), closes: try ClockTime(hour: 12),
                                         holidays: [try at("2026-12-25")])
        let data = try JSONEncoder().encode(schedule)
        XCTAssertEqual(try JSONDecoder().decode(BusinessHours.self, from: data), schedule)
        XCTAssertEqual(try JSONDecoder().decode(Weekday.self, from: JSONEncoder().encode(Weekday.friday)), .friday)
        XCTAssertEqual(BusinessHours.nineToFive.opens.hour, 9)
        XCTAssertEqual(BusinessHours.nineToFive.closes.hour, 17)
        XCTAssertEqual(BusinessHours.nineToFive.days, Weekday.weekdays)
    }
}

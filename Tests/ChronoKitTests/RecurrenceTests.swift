//
//  RecurrenceTests.swift
//  ChronoKit
//
//  The examples of RFC 5545 §3.8.5.3, with the dates the RFC lists, in the
//  zone the RFC uses — America/New_York, from 2 September 1997 at 09:00 —
//  plus the phrases people type and the refusals.
//

import XCTest
@testable import ChronoKit

private let newYork = TimeZone(identifier: "America/New_York")!
private let london = TimeZone(identifier: "Europe/London")!

/// The RFC's DTSTART, or another wall-clock moment in the current zone.
private func at(_ text: String) throws -> Date { try Chrono.date(text) }

/// Occurrences as `yyyy-MM-dd`, in the current zone.
private func days(_ rule: String, from start: String, limit: Int = 100, holidays: Set<Date> = []) throws -> [String] {
    let parsed = try RecurrenceRule(parsing: rule)
    return Chrono.occurrences(of: parsed, from: try at(start), limit: limit, holidays: holidays).map { Chrono.describe($0).date }
}

private func dates(_ list: String) -> [String] { list.split(separator: " ").map(String.init) }

final class RFC5545ExampleTests: XCTestCase {

    func testDailyForTenOccurrences() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=DAILY;COUNT=10", from: "1997-09-02T09:00"),
                           (2...11).map { "1997-09-\(String(format: "%02d", $0))" })
        }
    }

    func testDailyUntilChristmasEve() throws {
        try Chrono.inZone(newYork) {
            let list = try days("FREQ=DAILY;UNTIL=19971224T000000Z", from: "1997-09-02T09:00", limit: 1000)
            XCTAssertEqual(list.count, 113)
            XCTAssertEqual(list.first, "1997-09-02")
            XCTAssertEqual(list.last, "1997-12-23", "09:00 on the 24th is after 00:00Z on the 24th")
        }
    }

    func testEveryOtherDayAndEveryTenDays() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(Array(try days("FREQ=DAILY;INTERVAL=2", from: "1997-09-02T09:00", limit: 5)),
                           dates("1997-09-02 1997-09-04 1997-09-06 1997-09-08 1997-09-10"))
            XCTAssertEqual(try days("FREQ=DAILY;INTERVAL=10;COUNT=5", from: "1997-09-02T09:00"),
                           dates("1997-09-02 1997-09-12 1997-09-22 1997-10-02 1997-10-12"))
        }
    }

    func testEveryDayInJanuaryForThreeYearsBothSpellings() throws {
        try Chrono.inZone(newYork) {
            let yearly = try days("FREQ=YEARLY;UNTIL=20000131T140000Z;BYMONTH=1;BYDAY=SU,MO,TU,WE,TH,FR,SA", from: "1998-01-01T09:00", limit: 500)
            let daily = try days("FREQ=DAILY;UNTIL=20000131T140000Z;BYMONTH=1", from: "1998-01-01T09:00", limit: 500)
            XCTAssertEqual(yearly.count, 93)
            XCTAssertEqual(yearly, daily)
            XCTAssertEqual(yearly.first, "1998-01-01")
            XCTAssertEqual(yearly.last, "2000-01-31")
            XCTAssertFalse(yearly.contains("1998-02-01"))
        }
    }

    func testWeeklyForTenAndUntilChristmasEve() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=WEEKLY;COUNT=10", from: "1997-09-02T09:00"),
                           dates("1997-09-02 1997-09-09 1997-09-16 1997-09-23 1997-09-30 1997-10-07 1997-10-14 1997-10-21 1997-10-28 1997-11-04"))
            let until = try days("FREQ=WEEKLY;UNTIL=19971224T000000Z", from: "1997-09-02T09:00")
            XCTAssertEqual(until.count, 17)
            XCTAssertEqual(until.last, "1997-12-23")
        }
    }

    func testEveryOtherWeekForever() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=WEEKLY;INTERVAL=2;WKST=SU", from: "1997-09-02T09:00", limit: 12),
                           dates("1997-09-02 1997-09-16 1997-09-30 1997-10-14 1997-10-28 1997-11-11 1997-11-25 1997-12-09 1997-12-23 1998-01-06 1998-01-20 1998-02-03"))
        }
    }

    func testWeeklyOnTuesdayAndThursdayForFiveWeeks() throws {
        try Chrono.inZone(newYork) {
            let expected = dates("1997-09-02 1997-09-04 1997-09-09 1997-09-11 1997-09-16 1997-09-18 1997-09-23 1997-09-25 1997-09-30 1997-10-02")
            XCTAssertEqual(try days("FREQ=WEEKLY;UNTIL=19971007T000000Z;WKST=SU;BYDAY=TU,TH", from: "1997-09-02T09:00"), expected)
            XCTAssertEqual(try days("FREQ=WEEKLY;COUNT=10;WKST=SU;BYDAY=TU,TH", from: "1997-09-02T09:00"), expected)
        }
    }

    func testEveryOtherWeekOnMondayWednesdayFridayUntilChristmasEve() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=WEEKLY;INTERVAL=2;UNTIL=19971224T000000Z;WKST=SU;BYDAY=MO,WE,FR", from: "1997-09-01T09:00"),
                           dates("1997-09-01 1997-09-03 1997-09-05 1997-09-15 1997-09-17 1997-09-19 1997-09-29 1997-10-01 1997-10-03 1997-10-13 1997-10-15 1997-10-17 1997-10-27 1997-10-29 1997-10-31 1997-11-10 1997-11-12 1997-11-14 1997-11-24 1997-11-26 1997-11-28 1997-12-08 1997-12-10 1997-12-12 1997-12-22"))
        }
    }

    func testEveryOtherWeekOnTuesdayAndThursdayForEight() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=WEEKLY;INTERVAL=2;COUNT=8;WKST=SU;BYDAY=TU,TH", from: "1997-09-02T09:00"),
                           dates("1997-09-02 1997-09-04 1997-09-16 1997-09-18 1997-09-30 1997-10-02 1997-10-14 1997-10-16"))
        }
    }

    func testMonthlyOnTheFirstFriday() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;COUNT=10;BYDAY=1FR", from: "1997-09-05T09:00"),
                           dates("1997-09-05 1997-10-03 1997-11-07 1997-12-05 1998-01-02 1998-02-06 1998-03-06 1998-04-03 1998-05-01 1998-06-05"))
            XCTAssertEqual(try days("FREQ=MONTHLY;UNTIL=19971224T000000Z;BYDAY=1FR", from: "1997-09-05T09:00"),
                           dates("1997-09-05 1997-10-03 1997-11-07 1997-12-05"))
        }
    }

    func testEveryOtherMonthOnTheFirstAndLastSunday() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;INTERVAL=2;COUNT=10;BYDAY=1SU,-1SU", from: "1997-09-07T09:00"),
                           dates("1997-09-07 1997-09-28 1997-11-02 1997-11-30 1998-01-04 1998-01-25 1998-03-01 1998-03-29 1998-05-03 1998-05-31"))
        }
    }

    func testMonthlyOnTheSecondToLastMonday() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;COUNT=6;BYDAY=-2MO", from: "1997-09-22T09:00"),
                           dates("1997-09-22 1997-10-20 1997-11-17 1997-12-22 1998-01-19 1998-02-16"))
        }
    }

    func testMonthlyOnTheThirdToLastDay() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;BYMONTHDAY=-3", from: "1997-09-28T09:00", limit: 6),
                           dates("1997-09-28 1997-10-29 1997-11-28 1997-12-29 1998-01-29 1998-02-26"))
        }
    }

    func testMonthlyOnTheSecondAndFifteenth() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;COUNT=10;BYMONTHDAY=2,15", from: "1997-09-02T09:00"),
                           dates("1997-09-02 1997-09-15 1997-10-02 1997-10-15 1997-11-02 1997-11-15 1997-12-02 1997-12-15 1998-01-02 1998-01-15"))
        }
    }

    func testMonthlyOnTheFirstAndLastDay() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;COUNT=10;BYMONTHDAY=1,-1", from: "1997-09-30T09:00"),
                           dates("1997-09-30 1997-10-01 1997-10-31 1997-11-01 1997-11-30 1997-12-01 1997-12-31 1998-01-01 1998-01-31 1998-02-01"))
        }
    }

    func testEveryEighteenMonthsOnTheTenthThroughFifteenth() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;INTERVAL=18;COUNT=10;BYMONTHDAY=10,11,12,13,14,15", from: "1997-09-10T09:00"),
                           dates("1997-09-10 1997-09-11 1997-09-12 1997-09-13 1997-09-14 1997-09-15 1999-03-10 1999-03-11 1999-03-12 1999-03-13"))
        }
    }

    func testEveryTuesdayEveryOtherMonth() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;INTERVAL=2;BYDAY=TU", from: "1997-09-02T09:00", limit: 18),
                           dates("1997-09-02 1997-09-09 1997-09-16 1997-09-23 1997-09-30 1997-11-04 1997-11-11 1997-11-18 1997-11-25 1998-01-06 1998-01-13 1998-01-20 1998-01-27 1998-03-03 1998-03-10 1998-03-17 1998-03-24 1998-03-31"))
        }
    }

    func testYearlyInJuneAndJuly() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=YEARLY;COUNT=10;BYMONTH=6,7", from: "1997-06-10T09:00"),
                           dates("1997-06-10 1997-07-10 1998-06-10 1998-07-10 1999-06-10 1999-07-10 2000-06-10 2000-07-10 2001-06-10 2001-07-10"))
        }
    }

    func testEveryOtherYearInJanuaryFebruaryAndMarch() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=YEARLY;INTERVAL=2;COUNT=10;BYMONTH=1,2,3", from: "1997-03-10T09:00"),
                           dates("1997-03-10 1999-01-10 1999-02-10 1999-03-10 2001-01-10 2001-02-10 2001-03-10 2003-01-10 2003-02-10 2003-03-10"))
        }
    }

    func testEveryTwentiethMondayOfTheYear() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=YEARLY;BYDAY=20MO", from: "1997-05-19T09:00", limit: 3),
                           dates("1997-05-19 1998-05-18 1999-05-17"))
        }
    }

    func testEveryThursdayInMarch() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=YEARLY;BYMONTH=3;BYDAY=TH", from: "1997-03-13T09:00", limit: 11),
                           dates("1997-03-13 1997-03-20 1997-03-27 1998-03-05 1998-03-12 1998-03-19 1998-03-26 1999-03-04 1999-03-11 1999-03-18 1999-03-25"))
        }
    }

    func testEveryThursdayInJuneJulyAndAugust() throws {
        try Chrono.inZone(newYork) {
            let list = try days("FREQ=YEARLY;BYDAY=TH;BYMONTH=6,7,8", from: "1997-06-05T09:00", limit: 26)
            XCTAssertEqual(Array(list.prefix(13)),
                           dates("1997-06-05 1997-06-12 1997-06-19 1997-06-26 1997-07-03 1997-07-10 1997-07-17 1997-07-24 1997-07-31 1997-08-07 1997-08-14 1997-08-21 1997-08-28"))
            XCTAssertEqual(list[13], "1998-06-04")
            XCTAssertEqual(list[25], "1998-08-27")
        }
    }

    func testEveryFridayTheThirteenth() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13", from: "1997-09-02T09:00", limit: 5),
                           dates("1998-02-13 1998-03-13 1998-11-13 1999-08-13 2000-10-13"))
        }
    }

    func testTheFirstSaturdayThatFollowsTheFirstSunday() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;BYDAY=SA;BYMONTHDAY=7,8,9,10,11,12,13", from: "1997-09-13T09:00", limit: 10),
                           dates("1997-09-13 1997-10-11 1997-11-08 1997-12-13 1998-01-10 1998-02-07 1998-03-07 1998-04-11 1998-05-09 1998-06-13"))
        }
    }

    func testUSPresidentialElectionDay() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=YEARLY;INTERVAL=4;BYMONTH=11;BYDAY=TU;BYMONTHDAY=2,3,4,5,6,7,8", from: "1996-11-05T09:00", limit: 3),
                           dates("1996-11-05 2000-11-07 2004-11-02"))
        }
    }

    func testTheThirdInstanceOfTuesdayWednesdayOrThursday() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;COUNT=3;BYDAY=TU,WE,TH;BYSETPOS=3", from: "1997-09-04T09:00"),
                           dates("1997-09-04 1997-10-07 1997-11-06"))
        }
    }

    func testTheSecondToLastWeekdayOfTheMonth() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-2", from: "1997-09-29T09:00", limit: 7),
                           dates("1997-09-29 1997-10-30 1997-11-27 1997-12-30 1998-01-29 1998-02-26 1998-03-30"))
        }
    }

    func testTheWeekStartChangesWhichDaysAreGenerated() throws {
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU;WKST=MO", from: "1997-08-05T09:00"),
                           dates("1997-08-05 1997-08-10 1997-08-19 1997-08-24"))
            XCTAssertEqual(try days("FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU;WKST=SU", from: "1997-08-05T09:00"),
                           dates("1997-08-05 1997-08-17 1997-08-19 1997-08-31"))
        }
    }

    func testAnInvalidDateIsIgnored() throws {
        // The 30th of February does not happen; the RFC's example skips it.
        try Chrono.inZone(newYork) {
            XCTAssertEqual(try days("FREQ=MONTHLY;BYMONTHDAY=15,30;COUNT=5", from: "2007-01-15T09:00"),
                           dates("2007-01-15 2007-01-30 2007-02-15 2007-03-15 2007-03-30"))
        }
    }
}

final class RecurrenceBehaviourTests: XCTestCase {

    func testTheWallClockSurvivesAClockChange() throws {
        // Weekly at 09:00 London, across the spring-forward on 29 March 2026.
        try Chrono.inZone(london) {
            let rule = try RecurrenceRule(parsing: "FREQ=WEEKLY;COUNT=3")
            let times = Chrono.occurrences(of: rule, from: try at("2026-03-23T09:00")).map { Chrono.describe($0) }
            XCTAssertEqual(times.map(\.date), dates("2026-03-23 2026-03-30 2026-04-06"))
            XCTAssertEqual(Set(times.map(\.time)), ["09:00:00"])
            XCTAssertEqual(times.map(\.offset), ["+00:00", "+01:00", "+01:00"])
        }
    }

    func testTheThirtyFirstSkipsShortMonths() throws {
        try Chrono.inZone(london) {
            XCTAssertEqual(try days("FREQ=MONTHLY", from: "2026-01-31T12:00", limit: 5),
                           dates("2026-01-31 2026-03-31 2026-05-31 2026-07-31 2026-08-31"))
            XCTAssertEqual(try days("FREQ=YEARLY", from: "2024-02-29T12:00", limit: 3),
                           dates("2024-02-29 2028-02-29 2032-02-29"), "a leap-day birthday recurs on leap days only, as the RFC says")
        }
    }

    func testCountAndUntilBothStop() throws {
        try Chrono.inZone(london) {
            XCTAssertEqual(try days("FREQ=DAILY;COUNT=3", from: "2026-01-01T09:00", limit: 100).count, 3)
            XCTAssertEqual(try days("FREQ=DAILY;UNTIL=20260103", from: "2026-01-01T09:00", limit: 100),
                           dates("2026-01-01 2026-01-02 2026-01-03"), "a bare UNTIL date includes that day")
            XCTAssertEqual(try days("FREQ=DAILY;UNTIL=20260103T080000", from: "2026-01-01T09:00", limit: 100).count, 2)
            XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=DAILY;COUNT=3;UNTIL=20260103"))
        }
    }

    func testOccurrencesBeforeTheStartAreNotOccurrences() throws {
        try Chrono.inZone(london) {
            // Started on a Wednesday, weekly on Monday and Friday: the first is Friday.
            XCTAssertEqual(try days("FREQ=WEEKLY;BYDAY=MO,FR", from: "2026-09-02T09:00", limit: 3),
                           dates("2026-09-04 2026-09-07 2026-09-11"))
            XCTAssertEqual(Chrono.occurrences(of: try RecurrenceRule(parsing: "FREQ=DAILY"), from: Date(), limit: 0), [])
        }
    }

    func testNextOccurrenceAndIsOccurrence() throws {
        try Chrono.inZone(london) {
            let rule = try RecurrenceRule(parsing: "second tuesday of every month")
            let start = try at("2026-01-01T09:00")
            let next = try XCTUnwrap(Chrono.nextOccurrence(of: rule, from: start, after: try at("2026-02-10T09:00")))
            XCTAssertEqual(Chrono.describe(next).date, "2026-03-10")
            XCTAssertTrue(Chrono.isOccurrence(try at("2026-02-10T17:45"), of: rule, from: start))
            XCTAssertFalse(Chrono.isOccurrence(try at("2026-02-11T09:00"), of: rule, from: start))
            XCTAssertFalse(Chrono.isOccurrence(try at("2025-12-09T09:00"), of: rule, from: start), "before the start")
            let ended = try RecurrenceRule(parsing: "FREQ=DAILY;COUNT=2")
            XCTAssertNil(Chrono.nextOccurrence(of: ended, from: start, after: try at("2026-01-02T09:00")))
        }
    }

    func testARuleThatNeverMatchesStopsAtTheBudget() throws {
        try Chrono.inZone(london) {
            let rule = try RecurrenceRule(parsing: "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30")
            XCTAssertEqual(Chrono.occurrences(of: rule, from: try at("2026-01-01T09:00"), limit: 5), [])
        }
    }

    func testWorkingDaysOfTheMonthQuarterAndYearWithHolidays() throws {
        try Chrono.inZone(london) {
            let holidays = Holidays.set(try Holidays.unitedKingdom(year: 2026))
            // First working day of every month in 2026: 2 January (the 1st is a holiday), 2 February …, 1 May is a Friday, 1 June is a Monday.
            XCTAssertEqual(Array(try days("first working day of the month", from: "2026-01-01T09:00", limit: 6, holidays: holidays)),
                           dates("2026-01-02 2026-02-02 2026-03-02 2026-04-01 2026-05-01 2026-06-01"))
            // Last working day of each quarter of 2026: 31 Mar (Tue), 30 Jun (Tue), 30 Sep (Wed), 31 Dec (Thu).
            XCTAssertEqual(try days("last working day of the quarter", from: "2026-01-01T09:00", limit: 4, holidays: holidays),
                           dates("2026-03-31 2026-06-30 2026-09-30 2026-12-31"))
            // Last working day of 2027 is Friday 31 December; of 2026 is Thursday 31 December.
            XCTAssertEqual(try days("last working day of the year", from: "2026-01-01T09:00", limit: 2, holidays: holidays),
                           dates("2026-12-31 2027-12-31"))
            // Without the holiday set, 1 January 2026 is a working day.
            XCTAssertEqual(try days("first working day of the month", from: "2026-01-01T09:00", limit: 1), ["2026-01-01"])
        }
    }

    func testTheNthWeekdayOfAQuarter() throws {
        try Chrono.inZone(london) {
            XCTAssertEqual(try days("last friday of every quarter", from: "2026-01-01T09:00", limit: 4),
                           dates("2026-03-27 2026-06-26 2026-09-25 2026-12-25"))
        }
    }
}

final class RecurrencePhraseTests: XCTestCase {

    private func rrule(_ phrase: String) throws -> String? { try RecurrenceRule(parsing: phrase).rruleString }

    func testPhrasesBecomeRules() throws {
        XCTAssertEqual(try rrule("every day"), "FREQ=DAILY")
        XCTAssertEqual(try rrule("Daily"), "FREQ=DAILY")
        XCTAssertEqual(try rrule("every 3 days"), "FREQ=DAILY;INTERVAL=3")
        XCTAssertEqual(try rrule("every weekday"), "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR")
        XCTAssertEqual(try rrule("every week"), "FREQ=WEEKLY")
        XCTAssertEqual(try rrule("every 2 weeks on monday and wednesday"), "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE")
        XCTAssertEqual(try rrule("every other week on Friday"), "FREQ=WEEKLY;INTERVAL=2;BYDAY=FR")
        XCTAssertEqual(try rrule("fortnightly on fridays"), "FREQ=WEEKLY;INTERVAL=2;BYDAY=FR")
        XCTAssertEqual(try rrule("every monday"), "FREQ=WEEKLY;BYDAY=MO")
        XCTAssertEqual(try rrule("every Monday, Wednesday and Friday"), "FREQ=WEEKLY;BYDAY=MO,WE,FR")
        XCTAssertEqual(try rrule("second tuesday of every month"), "FREQ=MONTHLY;BYDAY=2TU")
        XCTAssertEqual(try rrule("The last Friday of the month"), "FREQ=MONTHLY;BYDAY=-1FR")
        XCTAssertEqual(try rrule("second to last thursday of each month"), "FREQ=MONTHLY;BYDAY=-2TH")
        XCTAssertEqual(try rrule("1st and 15th of every month"), "FREQ=MONTHLY;BYMONTHDAY=1,15")
        XCTAssertEqual(try rrule("every month on the 15th"), "FREQ=MONTHLY;BYMONTHDAY=15")
        XCTAssertEqual(try rrule("last day of the month"), "FREQ=MONTHLY;BYMONTHDAY=-1")
        XCTAssertEqual(try rrule("monthly"), "FREQ=MONTHLY")
        XCTAssertEqual(try rrule("every 3 months"), "FREQ=MONTHLY;INTERVAL=3")
        XCTAssertEqual(try rrule("every quarter"), "FREQ=MONTHLY;INTERVAL=3")
        XCTAssertEqual(try rrule("every year on 4 july"), "FREQ=YEARLY;BYMONTH=7;BYMONTHDAY=4")
        XCTAssertEqual(try rrule("every year on July 4th"), "FREQ=YEARLY;BYMONTH=7;BYMONTHDAY=4")
        XCTAssertEqual(try rrule("every 4th of July"), "FREQ=YEARLY;BYMONTH=7;BYMONTHDAY=4")
        XCTAssertEqual(try rrule("annually"), "FREQ=YEARLY")
        XCTAssertEqual(try rrule("first day of every year"), "FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=1")
        XCTAssertEqual(try rrule("every day, 10 times"), "FREQ=DAILY;COUNT=10")
        XCTAssertEqual(try rrule("every monday for 4 times"), "FREQ=WEEKLY;BYDAY=MO;COUNT=4")
    }

    func testTheWorkingDayRulesHaveNoRRuleSpelling() throws {
        let first = try RecurrenceRule(parsing: "first working day of the month")
        XCTAssertEqual(first.businessDayOrdinal, 1)
        XCTAssertEqual(first.frequency, .monthly)
        XCTAssertNil(first.rruleString)
        let last = try RecurrenceRule(parsing: "last business day of the quarter")
        XCTAssertEqual(last.businessDayOrdinal, -1)
        XCTAssertEqual(last.frequency, .quarterly)
        XCTAssertNil(last.rruleString)
        XCTAssertEqual(last.phrase, "the last working day of every quarter")
    }

    func testUntilInAPhrase() throws {
        try Chrono.inZone(london) {
            let rule = try RecurrenceRule(parsing: "every friday until 2026-03-31")
            XCTAssertEqual(rule.byDay.map(\.weekday), [.friday])
            XCTAssertEqual(Chrono.describe(try XCTUnwrap(rule.until)).date, "2026-03-31")
            XCTAssertEqual(rule.phrase, "every Friday, until 2026-03-31")
        }
    }

    func testRulesDescribeThemselvesAndReadBack() throws {
        try Chrono.inZone(london) {
            let cases: [(String, String)] = [
                ("every day", "every day"),
                ("every 3 days", "every 3 days"),
                ("every weekday", "every weekday"),
                ("every 2 weeks on monday and wednesday", "every 2 weeks on Monday and Wednesday"),
                ("every monday", "every Monday"),
                ("second tuesday of every month", "the second Tuesday of every month"),
                ("last friday of the month", "the last Friday of every month"),
                ("1st and 15th of every month", "the 1st and 15th of every month"),
                ("last day of the month", "the last day of every month"),
                ("every 3 months", "every 3 months"),
                ("every year on 4 july", "every year on 4 July"),
                ("first working day of the month", "the first working day of every month"),
                ("last working day of the quarter", "the last working day of every quarter"),
                ("last friday of every quarter", "the last Friday of every quarter"),
                ("every day, 10 times", "every day, 10 times"),
                ("FREQ=YEARLY;BYMONTH=11;BYDAY=1TU", "the first Tuesday of November every year"),
                ("FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-2", "every month on Monday, Tuesday, Wednesday, Thursday and Friday, second to last of those"),
            ]
            for (input, expected) in cases {
                let rule = try RecurrenceRule(parsing: input)
                XCTAssertEqual(rule.phrase, expected, input)
                XCTAssertEqual(try RecurrenceRule(parsing: rule.phrase), rule, "round trip of \(input)")
            }
        }
    }

    func testRRulesReadAndWriteBack() throws {
        for text in ["FREQ=MONTHLY;BYDAY=2TU", "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;COUNT=8;WKST=SU",
                     "FREQ=YEARLY;BYMONTH=6,7;BYMONTHDAY=10", "FREQ=DAILY;INTERVAL=10;COUNT=5",
                     "FREQ=MONTHLY;BYMONTHDAY=1,-1", "FREQ=DAILY;UNTIL=19971224T000000Z"] {
            XCTAssertEqual(try RecurrenceRule(parsing: text).rruleString, text)
        }
        XCTAssertEqual(try RecurrenceRule(parsing: "RRULE:FREQ=DAILY;COUNT=2").rruleString, "FREQ=DAILY;COUNT=2")
        XCTAssertEqual(try RecurrenceRule(parsing: "freq=weekly;byday=fr").rruleString, "FREQ=WEEKLY;BYDAY=FR")
    }

    func testRefusals() {
        for bad in ["", "sometimes", "every", "every 0 days", "every month on the 32nd", "every year on 31 february 2",
                    "fourth of nowhere of every month", "13th monday of every week"] {
            XCTAssertThrowsError(try RecurrenceRule(parsing: bad), bad)
        }
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=HOURLY")) { error in
            XCTAssertEqual(error as? RecurrenceError, .unsupported("FREQ=HOURLY"))
        }
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=DAILY;BYHOUR=9")) { error in
            XCTAssertEqual(error as? RecurrenceError, .unsupported("BYHOUR"))
            XCTAssertTrue(error.localizedDescription.contains("BYSETPOS"))
        }
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=YEARLY;BYWEEKNO=20"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=MONTHLY;BYYEARDAY=100"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=WEEKLY;BYMONTHDAY=1"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=WEEKLY;BYDAY=2TU"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=MONTHLY;BYMONTHDAY=0"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=MONTHLY;BYMONTH=13"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=MONTHLY;BYSETPOS=0"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=MONTHLY;INTERVAL=0"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=DAILY;COUNT=0"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=DAILY;UNTIL=tomorrow"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "DTSTART=19970902T090000;FREQ=DAILY"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=DAILY;BYDAY=XX"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "FREQ=DAILY;WKST=XX"))
        XCTAssertThrowsError(try RecurrenceRule(frequency: .quarterly), "a bare quarter picks nothing")
        XCTAssertThrowsError(try RecurrenceRule(frequency: .weekly, businessDayOrdinal: 1))
        XCTAssertThrowsError(try RecurrenceRule(frequency: .monthly, byDay: [WeekdayRule(weekday: .monday)], businessDayOrdinal: 1))
        XCTAssertTrue(RecurrenceError.badPhrase("x").localizedDescription.contains("second tuesday of every month"))
    }

    func testModelsRoundTripThroughJSON() throws {
        try Chrono.inZone(london) {
            let rule = try RecurrenceRule(parsing: "FREQ=MONTHLY;INTERVAL=2;BYDAY=1SU,-1SU;COUNT=10;UNTIL=19971224T000000Z".replacingOccurrences(of: ";COUNT=10", with: ""))
            let data = try JSONEncoder().encode(rule)
            XCTAssertEqual(try JSONDecoder().decode(RecurrenceRule.self, from: data), rule)
            for frequency in RecurrenceFrequency.allCases {
                XCTAssertEqual(try JSONDecoder().decode(RecurrenceFrequency.self, from: JSONEncoder().encode(frequency)), frequency)
            }
            let entry = WeekdayRule(ordinal: -2, weekday: .monday)
            XCTAssertEqual(try JSONDecoder().decode(WeekdayRule.self, from: JSONEncoder().encode(entry)), entry)
        }
    }

    func testTheWordsBehindTheGrammar() {
        XCTAssertEqual(RecurrencePhrases.dayWord(1), "1st")
        XCTAssertEqual(RecurrencePhrases.dayWord(2), "2nd")
        XCTAssertEqual(RecurrencePhrases.dayWord(3), "3rd")
        XCTAssertEqual(RecurrencePhrases.dayWord(4), "4th")
        XCTAssertEqual(RecurrencePhrases.dayWord(11), "11th")
        XCTAssertEqual(RecurrencePhrases.dayWord(12), "12th")
        XCTAssertEqual(RecurrencePhrases.dayWord(13), "13th")
        XCTAssertEqual(RecurrencePhrases.dayWord(21), "21st")
        XCTAssertEqual(RecurrencePhrases.dayWord(22), "22nd")
        XCTAssertEqual(RecurrencePhrases.dayWord(31), "31st")
        XCTAssertEqual(RecurrencePhrases.dayWord(-1), "last")
        XCTAssertEqual(RecurrencePhrases.ordinalWord(-2), "second to last")
        XCTAssertEqual(RecurrencePhrases.normalise("  The Second Tuesday of EACH month. "), "second tuesday of every month")
        XCTAssertEqual(RecurrencePhrases.normalise("every other business day"), "every 2 working day")
    }
}

final class RecurrenceSetTests: XCTestCase {

    private func text(_ dates: [Date]) -> [String] { dates.map { Chrono.describe($0).date } }

    func testAnExceptionRemovesExactlyOneOccurrence() throws {
        try Chrono.inZone(london) {
            let rule = try RecurrenceRule(parsing: "RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=4\nEXDATE;VALUE=DATE:20260112")
            let start = try at("2026-01-05T09:00")
            XCTAssertEqual(text(Chrono.occurrences(of: rule, from: start)), dates("2026-01-05 2026-01-19 2026-01-26"),
                           "COUNT counts the rule's four; the exception takes one away")
            XCTAssertFalse(Chrono.isOccurrence(try at("2026-01-12T09:00"), of: rule, from: start))
            XCTAssertEqual(Chrono.describe(try XCTUnwrap(Chrono.nextOccurrence(of: rule, from: start, after: try at("2026-01-05T10:00")))).date, "2026-01-19")
        }
    }

    func testAnExceptionMatchesByDayAcrossATimeDifference() throws {
        try Chrono.inZone(london) {
            // The feed's EXDATE carries the start's time in UTC; the rule runs at 09:00 London.
            let feed = try RecurrenceRule(parsing: "RRULE:FREQ=DAILY;COUNT=3\nEXDATE:20260602T080000Z")
            XCTAssertEqual(text(Chrono.occurrences(of: feed, from: try at("2026-06-01T09:00"))), dates("2026-06-01 2026-06-03"))
            // A caller's exception carries midnight.
            let caller = try RecurrenceRule(frequency: .daily, count: 3, exceptions: [try at("2026-06-02")])
            XCTAssertEqual(text(Chrono.occurrences(of: caller, from: try at("2026-06-01T09:00"))), dates("2026-06-01 2026-06-03"))
            // And one in another zone's TZID.
            let zoned = try RecurrenceRule(parsing: "RRULE:FREQ=DAILY;COUNT=3\nEXDATE;TZID=Asia/Tokyo:20260602T170000")
            XCTAssertEqual(text(Chrono.occurrences(of: zoned, from: try at("2026-06-01T09:00"))), dates("2026-06-01 2026-06-03"))
        }
    }

    func testAnExceptionThatMatchesNothingIsHarmless() throws {
        try Chrono.inZone(london) {
            let rule = try RecurrenceRule(parsing: "RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=3\nEXDATE;VALUE=DATE:20260107,20301225")
            XCTAssertEqual(text(Chrono.occurrences(of: rule, from: try at("2026-01-05T09:00"))), dates("2026-01-05 2026-01-12 2026-01-19"))
        }
    }

    func testAnAdditionAppearsInOrderAndIsNotDuplicated() throws {
        try Chrono.inZone(london) {
            let rule = try RecurrenceRule(parsing: """
                RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=3
                RDATE:20260108T090000Z,20260112T090000Z
                RDATE;VALUE=DATE:20260301
                """)
            let start = try at("2026-01-05T09:00")
            let all = Chrono.occurrences(of: rule, from: start)
            XCTAssertEqual(text(all), dates("2026-01-05 2026-01-08 2026-01-12 2026-01-19 2026-03-01"),
                           "the 8th slots in, the 12th is already a Monday, the 1st of March comes after the rule has ended")
            XCTAssertEqual(Set(all.map { Chrono.describe($0).time }), ["09:00:00"], "a bare RDATE day takes the start's time")
            XCTAssertTrue(Chrono.isOccurrence(try at("2026-03-01T12:00"), of: rule, from: start))
            XCTAssertEqual(Chrono.describe(try XCTUnwrap(Chrono.nextOccurrence(of: rule, from: start, after: try at("2026-01-19T10:00")))).date, "2026-03-01")
            // An addition before the start is not an occurrence; one on an exception day is not either.
            let odd = try RecurrenceRule(frequency: .daily, count: 2, exceptions: [try at("2026-01-06")], additions: [try at("2025-12-31T09:00"), try at("2026-01-06T15:00")])
            XCTAssertEqual(text(Chrono.occurrences(of: odd, from: start)), dates("2026-01-05"))
        }
    }

    func testTheICSLinesRoundTrip() throws {
        try Chrono.inZone(london) {
            let rule = try RecurrenceRule(parsing: """
                RRULE:FREQ=MONTHLY;BYDAY=2TU;COUNT=6
                EXDATE;VALUE=DATE:20260210
                RDATE:20260302T090000Z
                """)
            let lines = try XCTUnwrap(rule.icsLines)
            XCTAssertEqual(lines, ["RRULE:FREQ=MONTHLY;BYDAY=2TU;COUNT=6", "EXDATE;VALUE=DATE:20260210", "RDATE:20260302T090000Z"])
            XCTAssertEqual(try RecurrenceRule(parsing: lines.joined(separator: "\n")), rule)
            XCTAssertEqual(rule.rruleString, "FREQ=MONTHLY;BYDAY=2TU;COUNT=6")
            XCTAssertNil(try RecurrenceRule(parsing: "last working day of the quarter").icsLines)
            XCTAssertEqual(try RecurrenceRule(parsing: "FREQ=DAILY").icsLines, ["RRULE:FREQ=DAILY"])
        }
    }

    func testABlockToleratesDTSTARTAndRefusesStrangers() throws {
        XCTAssertNoThrow(try RecurrenceRule(parsing: "DTSTART;TZID=America/New_York:19970902T090000\nRRULE:FREQ=DAILY;COUNT=2"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "RRULE:FREQ=DAILY\nRRULE:FREQ=WEEKLY"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "RRULE:FREQ=DAILY\nSUMMARY:standup"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "RRULE:FREQ=DAILY\nEXDATE;TZID=Mars/Olympus:20260101T090000"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "RRULE:FREQ=DAILY\nEXDATE:tomorrow"))
        XCTAssertThrowsError(try RecurrenceRule(parsing: "EXDATE;VALUE=DATE:20260101"))
    }

    func testExceptionsInPhrases() throws {
        try Chrono.inZone(london) {
            let rule = try RecurrenceRule(parsing: "every monday except 2026-01-12 and 2026-01-26, plus 2026-01-08")
            XCTAssertEqual(rule.exceptions.count, 2)
            XCTAssertEqual(rule.additions.count, 1)
            XCTAssertEqual(rule.phrase, "every Monday, except 2026-01-12 and 2026-01-26, plus 2026-01-08")
            XCTAssertEqual(try RecurrenceRule(parsing: rule.phrase), rule)
            XCTAssertEqual(text(Chrono.occurrences(of: rule, from: try at("2026-01-05T09:00"), limit: 4)),
                           dates("2026-01-05 2026-01-08 2026-01-19 2026-02-02"))
            // A month and day without a year mean the next such day from today.
            let christmas = try RecurrenceRule(parsing: "every monday except 25 december")
            let exception = try XCTUnwrap(christmas.exceptions.first)
            let parts = Chrono.calendar.dateComponents([.month, .day], from: exception)
            XCTAssertEqual(parts.month, 12)
            XCTAssertEqual(parts.day, 25)
            XCTAssertGreaterThanOrEqual(exception, Chrono.calendar.startOfDay(for: Date()))
            XCTAssertEqual(try RecurrenceRule(parsing: "every day except december 25 2026").exceptions, [try at("2026-12-25")])
            XCTAssertThrowsError(try RecurrenceRule(parsing: "every day except never"))
        }
    }

    func testTheSetRoundTripsThroughJSON() throws {
        try Chrono.inZone(london) {
            let rule = try RecurrenceRule(frequency: .weekly, byDay: [WeekdayRule(weekday: .monday)], exceptions: [try at("2026-01-12")], additions: [try at("2026-01-08T09:00")])
            XCTAssertEqual(try JSONDecoder().decode(RecurrenceRule.self, from: JSONEncoder().encode(rule)), rule)
        }
    }
}

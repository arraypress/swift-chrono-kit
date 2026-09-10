//
//  ChronoKitTests.swift
//  ChronoKit
//
//  Every test here is a question with one right answer that multiplication
//  gets wrong. Fixed dates and a fixed zone throughout: a suite that says
//  "today" passes on the day it was written and fails on a Sunday.
//

import XCTest
@testable import ChronoKit

private let london = TimeZone(identifier: "Europe/London")!
private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
private let utc = TimeZone(identifier: "UTC")!

/// Parses in UTC so a test's expectation never depends on the machine.
private func at(_ text: String) throws -> Date {
    try Chrono.inZone(utc) { try Chrono.date(text) }
}

final class ArithmeticTests: XCTestCase {

    func testAddingAMonthClampsToTheEndOfAShortMonth() throws {
        // The headline case. 2,592,000 seconds after 31 January is 2 March.
        // A calendar says 28 February, which is what a person asking for
        // "a month later" means.
        try Chrono.inZone(utc) {
            let start = try Chrono.date("2026-01-31")
            let later = try Chrono.shift(start, by: 1, .month)
            XCTAssertEqual(Chrono.describe(later).date, "2026-02-28")
        }
    }

    func testAddingAMonthLandsOnTheTwentyNinthInALeapYear() throws {
        try Chrono.inZone(utc) {
            let start = try Chrono.date("2028-01-31")
            let later = try Chrono.shift(start, by: 1, .month)
            XCTAssertEqual(Chrono.describe(later).date, "2028-02-29")
        }
    }

    func testAddingAMonthDoesNotRoundTrip() throws {
        // 31 Jan + 1mo - 1mo is 28 Jan, not 31. Worth pinning because it
        // looks like a bug and is the only defensible answer: the clamp
        // threw information away, and no inverse can invent it back.
        try Chrono.inZone(utc) {
            let start = try Chrono.date("2026-01-31")
            let there = try Chrono.shift(start, by: 1, .month)
            let back = try Chrono.shift(there, by: -1, .month)
            XCTAssertEqual(Chrono.describe(back).date, "2026-01-28")
        }
    }

    func testADayAcrossTheSpringTransitionIsTwentyThreeHours() throws {
        // Europe/London springs forward on 29 March 2026. Adding "a day" by
        // seconds lands an hour late; the calendar keeps the wall clock.
        try Chrono.inZone(london) {
            let start = try Chrono.date("2026-03-28T12:00")
            let next = try Chrono.shift(start, by: 1, .day)
            XCTAssertEqual(Chrono.describe(next).time, "12:00:00")
            XCTAssertEqual(next.timeIntervalSince(start), 23 * 3600)
        }
    }

    func testADayAcrossTheAutumnTransitionIsTwentyFiveHours() throws {
        try Chrono.inZone(london) {
            let start = try Chrono.date("2026-10-24T12:00")
            let next = try Chrono.shift(start, by: 1, .day)
            XCTAssertEqual(Chrono.describe(next).time, "12:00:00")
            XCTAssertEqual(next.timeIntervalSince(start), 25 * 3600)
        }
    }

    func testOffsetsApplyInTheOrderGiven() throws {
        // Calendar arithmetic does not commute; the sequence is the question.
        try Chrono.inZone(utc) {
            let start = try Chrono.date("2026-01-31")
            let monthThenDay = try Chrono.shift(start, by: ["+1mo", "-1d"])
            let dayThenMonth = try Chrono.shift(start, by: ["-1d", "+1mo"])
            XCTAssertEqual(Chrono.describe(monthThenDay).date, "2026-02-27")
            XCTAssertEqual(Chrono.describe(dayThenMonth).date, "2026-02-28")
        }
    }

    func testWeeksAreSevenDaysAndQuartersAreThreeMonths() throws {
        try Chrono.inZone(utc) {
            let start = try Chrono.date("2026-09-03")
            XCTAssertEqual(Chrono.describe(try Chrono.shift(start, by: 2, .week)).date, "2026-09-17")
            XCTAssertEqual(Chrono.describe(try Chrono.shift(start, by: 1, .quarter)).date, "2026-12-03")
        }
    }
}

final class SpanTests: XCTestCase {

    func testTwoHoursAcrossMidnightIsTwoCalendarDays() throws {
        // 23:00 Monday to 01:00 Wednesday is 26 hours. Every invoice and
        // every person calls that two days; a raw component diff says one.
        try Chrono.inZone(utc) {
            let span = Chrono.span(from: try Chrono.date("2026-09-01T23:00"),
                                   to: try Chrono.date("2026-09-03T01:00"))
            XCTAssertEqual(span.totalDays, 2)
            XCTAssertEqual(span.totalHours, 26)
        }
    }

    func testBackwardsIsRecordedNotCorrected() throws {
        try Chrono.inZone(utc) {
            let span = Chrono.span(from: try Chrono.date("2026-09-10"),
                                   to: try Chrono.date("2026-09-01"))
            XCTAssertTrue(span.isBackwards)
            XCTAssertEqual(span.totalDays, 9)
        }
    }

    func testBreakdownDropsZeroComponents() throws {
        try Chrono.inZone(utc) {
            let span = Chrono.span(from: try Chrono.date("2026-09-03T09:00"),
                                   to: try Chrono.date("2026-09-03T11:30"))
            XCTAssertEqual(span.described, "2 hours, 30 minutes")
        }
    }

    func testYearsAndMonthsAreCalendarUnitsNotDivisions() throws {
        try Chrono.inZone(utc) {
            let span = Chrono.span(from: try Chrono.date("2024-02-29"),
                                   to: try Chrono.date("2026-09-03"))
            XCTAssertEqual(span.years, 2)
            XCTAssertEqual(span.months, 6)
            // Six, not five: the two-year step from 29 February lands on
            // 28 February 2026, because 2026 has no 29th. The clamp is
            // visible in the remainder.
            XCTAssertEqual(span.days, 6)
        }
    }

    func testZeroSpanReadsAsSeconds() throws {
        try Chrono.inZone(utc) {
            let moment = try Chrono.date("2026-09-03T09:00")
            XCTAssertEqual(Chrono.span(from: moment, to: moment).described, "0 seconds")
        }
    }
}

final class WeekAndInstantTests: XCTestCase {

    func testFirstOfJanuaryCanBelongToTheYearBefore() throws {
        // 1 January 2027 is a Friday, in the ISO week that began Monday
        // 28 December 2026 — week 53 of 2026. Printing "week 53, 2027" is a
        // real off-by-a-year that surfaces in weekly reporting every January.
        try Chrono.inZone(utc) {
            let instant = Chrono.describe(try Chrono.date("2027-01-01"))
            XCTAssertEqual(instant.isoWeek, 53)
            XCTAssertEqual(instant.isoWeekYear, 2026)
            XCTAssertEqual(instant.weekday, "Friday")
        }
    }

    func testTheOffsetIsForTheInstantNotTheZone() throws {
        // Europe/London is +00:00 in January and +01:00 in July. A tool that
        // names the zone without the offset has not answered the question.
        try Chrono.inZone(london) {
            XCTAssertEqual(Chrono.describe(try Chrono.date("2026-01-15T12:00")).offset, "+00:00")
            XCTAssertEqual(Chrono.describe(try Chrono.date("2026-07-15T12:00")).offset, "+01:00")
            XCTAssertFalse(Chrono.describe(try Chrono.date("2026-01-15T12:00")).isDST)
            XCTAssertTrue(Chrono.describe(try Chrono.date("2026-07-15T12:00")).isDST)
        }
    }

    func testTheSameInstantHasDifferentWallClocksInDifferentZones() throws {
        let moment = try at("2026-09-03T00:30:00Z")
        let inLondon = Chrono.inZone(london) { Chrono.describe(moment) }
        let inTokyo = Chrono.inZone(tokyo) { Chrono.describe(moment) }
        XCTAssertEqual(inLondon.date, "2026-09-03")
        XCTAssertEqual(inTokyo.date, "2026-09-03")
        XCTAssertEqual(inTokyo.time, "09:30:00")
        // Same epoch, two calendars.
        XCTAssertEqual(inLondon.epoch, inTokyo.epoch)
    }

    func testDayOfYearAndQuarter() throws {
        try Chrono.inZone(utc) {
            let instant = Chrono.describe(try Chrono.date("2026-12-31"))
            XCTAssertEqual(instant.dayOfYear, 365)
            XCTAssertEqual(instant.quarter, 4)
            XCTAssertEqual(Chrono.describe(try Chrono.date("2028-12-31")).dayOfYear, 366)
        }
    }

    func testWeekendDetection() throws {
        try Chrono.inZone(utc) {
            XCTAssertTrue(Chrono.describe(try Chrono.date("2026-09-05")).isWeekend)   // Saturday
            XCTAssertTrue(Chrono.describe(try Chrono.date("2026-09-06")).isWeekend)   // Sunday
            XCTAssertFalse(Chrono.describe(try Chrono.date("2026-09-07")).isWeekend)  // Monday
        }
    }
}

final class BusinessDayTests: XCTestCase {

    func testOneBusinessDayFromFridayIsMonday() throws {
        try Chrono.inZone(utc) {
            let friday = try Chrono.date("2026-09-04")
            let next = try Chrono.shiftBusinessDays(friday, by: 1)
            XCTAssertEqual(Chrono.describe(next).date, "2026-09-07")
        }
    }

    func testTenBusinessDaysFromFridayIsAFridayAFortnightLater() throws {
        // The answer a model gives is "+14 days" or "+10 days"; it is neither.
        try Chrono.inZone(utc) {
            let friday = try Chrono.date("2026-09-04")
            let later = try Chrono.shiftBusinessDays(friday, by: 10)
            XCTAssertEqual(Chrono.describe(later).date, "2026-09-18")
            XCTAssertEqual(Chrono.describe(later).weekday, "Friday")
        }
    }

    func testBusinessDaysGoBackwards() throws {
        try Chrono.inZone(utc) {
            let monday = try Chrono.date("2026-09-07")
            let back = try Chrono.shiftBusinessDays(monday, by: -1)
            XCTAssertEqual(Chrono.describe(back).date, "2026-09-04")
        }
    }

    func testHolidaysAreSkipped() throws {
        try Chrono.inZone(utc) {
            let holidays = try Chrono.holidays(fromLines: ["2026-09-07  # a Monday", "", "# comment only"])
            let friday = try Chrono.date("2026-09-04")
            XCTAssertEqual(Chrono.describe(try Chrono.shiftBusinessDays(friday, by: 1, holidays: holidays)).date,
                           "2026-09-08")
        }
    }

    func testCountingIsExclusiveOfTheStartAndInclusiveOfTheEnd() throws {
        try Chrono.inZone(utc) {
            let monday = try Chrono.date("2026-09-07")
            let tuesday = try Chrono.date("2026-09-08")
            XCTAssertEqual(Chrono.businessDaysBetween(monday, and: tuesday), 1)
            // Friday to the following Monday is one working day, not three.
            XCTAssertEqual(Chrono.businessDaysBetween(try Chrono.date("2026-09-04"), and: monday), 1)
        }
    }

    func testWholeWeekendCountsAsZero() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.businessDaysBetween(try Chrono.date("2026-09-05"),
                                                      and: try Chrono.date("2026-09-06")), 0)
        }
    }

    func testABadHolidayLineIsRefusedRatherThanIgnored() {
        // A typo silently shifting somebody's deadline by a day is worse than
        // a refusal.
        XCTAssertThrowsError(try Chrono.holidays(fromLines: ["2026-09-07", "not-a-date"]))
    }
}

final class ParsingTests: XCTestCase {

    func testISOAndPlainFormats() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.describe(try Chrono.date("2026-09-03")).date, "2026-09-03")
            XCTAssertEqual(Chrono.describe(try Chrono.date("2026-09-03T14:30")).time, "14:30:00")
            XCTAssertEqual(Chrono.describe(try Chrono.date("2026/09/03")).date, "2026-09-03")
            XCTAssertEqual(Chrono.describe(try Chrono.date("20260903")).date, "2026-09-03")
        }
    }

    func testAZoneDesignatorWinsOverTheAmbientZone() throws {
        // Noon UTC is 21:00 in Tokyo, whatever zone the tool is working in.
        try Chrono.inZone(tokyo) {
            XCTAssertEqual(Chrono.describe(try Chrono.date("2026-09-03T12:00:00Z")).time, "21:00:00")
        }
    }

    func testBareTimestamps() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(try Chrono.date("1772547000").timeIntervalSince1970, 1_772_547_000)
            XCTAssertEqual(try Chrono.date("1772547000000").timeIntervalSince1970, 1_772_547_000)
        }
    }

    func testDurationSuffixes() throws {
        XCTAssertEqual(try Chrono.duration("90m"), 5_400)
        XCTAssertEqual(try Chrono.duration("2w"), 1_209_600)
        XCTAssertEqual(try Chrono.duration("30"), 1_800)   // a bare number is minutes
        XCTAssertEqual(try Chrono.duration("6mo"), 15_552_000)
        XCTAssertThrowsError(try Chrono.duration("tuesday"))
        XCTAssertThrowsError(try Chrono.duration("-3d"))   // the sign is the caller's job
    }

    func testOffsetSplitsIntoCalendarUnits() throws {
        XCTAssertEqual(try Chrono.offset("+2w").count, 2)
        XCTAssertEqual(try Chrono.offset("+2w").unit, .week)
        XCTAssertEqual(try Chrono.offset("-18mo").count, -18)
        XCTAssertEqual(try Chrono.offset("-18mo").unit, .month)
        XCTAssertEqual(try Chrono.offset("3 days").unit, .day)
        // `m` is minutes and `mo` is months. The wrong way round is a factor
        // of 43,200.
        XCTAssertEqual(try Chrono.offset("5m").unit, .minute)
        XCTAssertThrowsError(try Chrono.offset("5"))       // no unit is not a unit
    }

    func testRelativeGrammar() throws {
        let now = Date()
        XCTAssertNotNil(Chrono.relativeDate("now"))
        XCTAssertNil(Chrono.relativeDate("the day after the fair"))

        let tomorrow = try XCTUnwrap(Chrono.relativeDate("tomorrow 9am"))
        XCTAssertEqual(Chrono.calendar.component(.hour, from: tomorrow), 9)
        XCTAssertEqual(Chrono.calendar.dateComponents([.day], from: Chrono.calendar.startOfDay(for: now),
                                                      to: Chrono.calendar.startOfDay(for: tomorrow)).day, 1)

        // "next friday" is always at least a week out; a bare "friday" may be
        // today. Guessing between them is how a meeting lands a week late.
        let friday = try XCTUnwrap(Chrono.relativeDate("friday"))
        let nextFriday = try XCTUnwrap(Chrono.relativeDate("next friday"))
        XCTAssertEqual(Chrono.calendar.dateComponents([.day],
            from: Chrono.calendar.startOfDay(for: friday),
            to: Chrono.calendar.startOfDay(for: nextFriday)).day, 7)

        // "last friday" never means today.
        let lastFriday = try XCTUnwrap(Chrono.relativeDate("last friday"))
        XCTAssertLessThan(lastFriday, Chrono.calendar.startOfDay(for: now).addingTimeInterval(1))
    }

    func testOutOfRangeTimesAreRefusedNotClamped() {
        XCTAssertNil(Chrono.relativeDate("today 25:00"))
        XCTAssertNil(Chrono.relativeDate("today 13pm"))
        XCTAssertNil(Chrono.relativeDate("today 9:99"))
    }

    func testNoiseIsAnErrorRatherThanNow() {
        XCTAssertThrowsError(try Chrono.date(""))
        XCTAssertThrowsError(try Chrono.date("sometime soon"))
    }
}

// MARK: - Zones

private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

final class ZoneTests: XCTestCase {

    func testAbbreviationsResolve() throws {
        XCTAssertEqual(try Chrono.zone("PST").identifier, "America/Los_Angeles")
        XCTAssertEqual(try Chrono.zone("pst").identifier, "America/Los_Angeles")
        XCTAssertEqual(try Chrono.zone("JST").identifier, "Asia/Tokyo")
    }

    func testAbbreviationsFoundationOmits() throws {
        // Foundation's table has no Australian entries at all, and none of the
        // bare US ones people actually write.
        XCTAssertNil(TimeZone(abbreviation: "AEST"))
        XCTAssertEqual(try Chrono.zone("AEST").identifier, "Australia/Sydney")
        XCTAssertEqual(try Chrono.zone("AWST").identifier, "Australia/Perth")
        XCTAssertEqual(try Chrono.zone("ET").identifier, "America/New_York")
        XCTAssertEqual(try Chrono.zone("PT").identifier, "America/Los_Angeles")
    }

    func testCitiesResolve() throws {
        XCTAssertEqual(try Chrono.zone("Tokyo").identifier, "Asia/Tokyo")
        XCTAssertEqual(try Chrono.zone("new york").identifier, "America/New_York")
        XCTAssertEqual(try Chrono.zone("Europe/London").identifier, "Europe/London")
    }

    func testOffsetsResolve() throws {
        XCTAssertEqual(try Chrono.zone("UTC+2").secondsFromGMT(), 7200)
        XCTAssertEqual(try Chrono.zone("GMT-5").secondsFromGMT(), -18000)
        XCTAssertEqual(try Chrono.zone("+05:30").secondsFromGMT(), 19800)
        XCTAssertEqual(try Chrono.zone("+0530").secondsFromGMT(), 19800)
    }

    func testABareSignedNumberIsNotAZone() {
        // "+2" is already a relative date here. If it resolved as UTC+2,
        // "tomorrow +2" would silently change meaning.
        XCTAssertNil(Chrono.resolveZone("+2"))
        XCTAssertThrowsError(try Chrono.zone("Narnia"))
    }

    func testTrailingZoneIsHonouredWhenParsing() throws {
        try Chrono.inZone(utc) {
            let there = try Chrono.date("2026-09-03 14:30 Tokyo")
            let explicit = try Chrono.date("2026-09-03T14:30:00+09:00")
            XCTAssertEqual(there, explicit)
        }
    }

    func testAnAbbreviationCarriesItsRegionsDaylightSaving() throws {
        // The point of resolving "PST" to a region rather than a fixed -8:
        // somebody writing "3pm PST" in July means 3pm in California, which
        // is UTC-7 that month. A fixed offset would be an hour out all summer.
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.describe(try Chrono.date("2026-07-01 15:00 PST")).utc,
                           "2026-07-01T22:00:00Z")
            XCTAssertEqual(Chrono.describe(try Chrono.date("2026-01-15 15:00 PST")).utc,
                           "2026-01-15T23:00:00Z")
        }
    }

    func testAMultiWordCityIsNotTestedByItsLastWord() throws {
        try Chrono.inZone(utc) {
            let there = try Chrono.date("2026-09-03 14:30 Hong Kong")
            XCTAssertEqual(there, try Chrono.date("2026-09-03T14:30:00+08:00"))
        }
    }

    func testASpacedMeridiemParses() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(try Chrono.date("tomorrow 9:30 am"),
                           try Chrono.date("tomorrow 9:30am"))
        }
    }

    func testABareTimeIsToday() throws {
        try Chrono.inZone(tokyo) {
            let parsed = try Chrono.date("3pm")
            XCTAssertEqual(Chrono.describe(parsed).time, "15:00:00")
            XCTAssertEqual(Chrono.describe(parsed).date,
                           Chrono.describe(Date()).date)
        }
    }

    func testABareTimeWithAZoneReadsOverThere() throws {
        // The selection-bar case: highlight "9:30 am PST", see it locally.
        try Chrono.inZone(london) {
            let parsed = try Chrono.date("9:30 am PST")
            XCTAssertEqual(Chrono.describe(parsed, in: losAngeles).time, "09:30:00")
        }
    }

    func testDescribingInAnotherZoneLeavesTheAmbientZoneAlone() throws {
        try Chrono.inZone(london) {
            let noon = try Chrono.date("2026-09-03T12:00:00Z")
            XCTAssertEqual(Chrono.describe(noon, in: tokyo).time, "21:00:00")
            XCTAssertEqual(Chrono.timeZone, london)
            XCTAssertEqual(Chrono.describe(noon).time, "13:00:00")
        }
    }

    func testDayPhrasesAreNotMistakenForZones() throws {
        // "friday" and "ago" have to survive the zone lookup untouched.
        try Chrono.inZone(utc) {
            XCTAssertNotNil(Chrono.relativeDate("next friday"))
            XCTAssertNotNil(Chrono.relativeDate("3d ago"))
            XCTAssertNotNil(Chrono.relativeDate("next monday 14:00"))
        }
    }
}

// MARK: - Natural language

final class NaturalLanguageTests: XCTestCase {

    /// The day a date lands on, in UTC, so an expectation never depends on
    /// the machine's zone.
    private func day(_ text: String) throws -> String {
        try Chrono.inZone(utc) { Chrono.describe(try Chrono.date(text)).date }
    }

    private func today(offsetByDays days: Int) -> String {
        Chrono.inZone(utc) {
            let date = Chrono.calendar.date(byAdding: .day, value: days, to: Date())!
            return Chrono.describe(date).date
        }
    }

    func testSpelledOutDurations() throws {
        // "3 days" used to throw: it ends in "s", the suffix for seconds,
        // which left "3 day" to parse as a number.
        XCTAssertEqual(try Chrono.duration("3 days"), 3 * 86_400)
        XCTAssertEqual(try Chrono.duration("two weeks"), 2 * 604_800)
        XCTAssertEqual(try Chrono.duration("a week"), 604_800)
        XCTAssertEqual(try Chrono.duration("six months"), 6 * 2_592_000)
        XCTAssertEqual(try Chrono.duration("90 minutes"), 5_400)
    }

    func testCompactDurationsAreUnchanged() throws {
        XCTAssertEqual(try Chrono.duration("2w"), 604_800 * 2)
        XCTAssertEqual(try Chrono.duration("6mo"), 6 * 2_592_000)
        XCTAssertEqual(try Chrono.duration("90m"), 5_400)
    }

    func testWrittenOutOffsets() throws {
        XCTAssertEqual(try day("two weeks from now"), today(offsetByDays: 14))
        XCTAssertEqual(try day("in 3 days"), today(offsetByDays: 3))
        XCTAssertEqual(try day("3 days ago"), today(offsetByDays: -3))
        XCTAssertEqual(try day("a week from now"), today(offsetByDays: 7))
    }

    func testTheDetectorReadsWhatTheGrammarDoesNot() throws {
        // Foundation's detector, reached only after everything exact fails.
        let sunday = try Chrono.date("this sunday")
        XCTAssertEqual(Chrono.describe(sunday).weekday, "Sunday")
        XCTAssertEqual(Chrono.describe(try Chrono.date("next sunday")).weekday, "Sunday")
    }

    func testTheDetectorIsMultilingual() throws {
        // The one thing an en_US_POSIX grammar can never be.
        XCTAssertEqual(Chrono.describe(try Chrono.date("el próximo domingo")).weekday, "Sunday")
        XCTAssertEqual(Chrono.describe(try Chrono.date("nächsten Sonntag")).weekday, "Sunday")
    }

    func testJunkIsStillRejected() {
        // The detector is conservative, which is what makes it safe to ask
        // last. None of these become a confident date.
        // Not "sat": this package's own grammar takes three-letter weekdays,
        // so that one is Saturday on purpose.
        for junk in ["hello", "chapter 7", "iPhone 15", "version 3", "the report"] {
            XCTAssertThrowsError(try Chrono.date(junk), junk)
        }
    }

    func testTheExactGrammarStillWinsFirst() throws {
        // The detector reads none of these, so they prove the order too.
        XCTAssertEqual(try day("+2d"), today(offsetByDays: 2))
        XCTAssertEqual(try Chrono.inZone(utc) { Chrono.describe(try Chrono.date("2026-09-03")).date },
                       "2026-09-03")
    }
}


// MARK: - Found by typing at it

final class SweepTests: XCTestCase {

    func testATwoDigitYearIsNeverTheYearSix() throws {
        // DateFormatter reads "6/5/26" as 26 May in the year 6 if allowed to.
        if let parsed = try? Chrono.inZone(utc, { try Chrono.date("6/5/26") }) {
            XCTAssertGreaterThan(Chrono.calendar.component(.year, from: parsed), 2000)
        }
        // And a real ISO date is untouched.
        XCTAssertEqual(try Chrono.inZone(utc) { Chrono.describe(try Chrono.date("2026-05-06")).date }, "2026-05-06")
    }

    func testNoonAndMidnight() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.describe(try Chrono.date("noon")).time, "12:00:00")
            XCTAssertEqual(Chrono.describe(try Chrono.date("tomorrow midnight")).time, "00:00:00")
            XCTAssertEqual(Chrono.describe(try Chrono.date("friday noon")).weekday, "Friday")
        }
    }

    func testCalendarUnitPhrases() throws {
        try Chrono.inZone(utc) {
            let now = Date()
            let nextWeek = try Chrono.date("next week")
            XCTAssertEqual(Chrono.calendar.dateComponents([.day], from: now, to: nextWeek).day, 7)
            let lastYear = try Chrono.date("last year")
            XCTAssertEqual(Chrono.calendar.component(.year, from: lastYear),
                           Chrono.calendar.component(.year, from: now) - 1)
        }
    }

    func testFortnight() throws {
        XCTAssertEqual(try Chrono.duration("a fortnight"), 14 * 86_400)
        XCTAssertEqual(try Chrono.duration("2 fortnights"), 28 * 86_400)
    }
}

// MARK: - Ranges

final class RangeTests: XCTestCase {

    /// Everything below runs in UTC, and "today" is asked of the same calendar
    /// the parser uses, so the relative cases hold at any hour on any day.
    private func inUTC(_ body: (_ today: Date) throws -> Void) rethrows {
        try Chrono.inZone(utc) {
            try body(Chrono.calendar.startOfDay(for: Date()))
        }
    }

    private func day(_ text: String) -> Date {
        try! Chrono.date(text)
    }

    func testExplicitPairIsInclusiveAtBothEnds() throws {
        try inUTC { _ in
            let range = try Chrono.range("2026-01-01 to 2026-01-31")
            XCTAssertEqual(range.start, day("2026-01-01"))
            XCTAssertEqual(range.end, day("2026-01-31"))
            XCTAssertEqual(range.days, 31)
            XCTAssertTrue(range.contains(day("2026-01-31T23:59")))
            XCTAssertFalse(range.contains(day("2026-02-01")))
        }
    }

    func testEverySpellingOfAPair() throws {
        try inUTC { _ in
            for text in ["2026-03-01 - 2026-03-05",
                         "2026-03-01 – 2026-03-05",
                         "from 2026-03-01 until 2026-03-05",
                         "between 2026-03-01 and 2026-03-05",
                         "2026-03-01 through 2026-03-05",
                         "1 Mar 2026 to 5 Mar 2026"] {
                let range = try Chrono.range(text)
                XCTAssertEqual(range.start, day("2026-03-01"), text)
                XCTAssertEqual(range.days, 5, text)
            }
        }
    }

    func testReversedPairNamesTheSameDays() throws {
        try inUTC { _ in
            let range = try Chrono.range("2026-03-05 to 2026-03-01")
            XCTAssertEqual(range.start, day("2026-03-01"))
            XCTAssertEqual(range.end, day("2026-03-05"))
        }
    }

    func testWholeMonths() throws {
        try inUTC { today in
            let this = try Chrono.range("this month")
            XCTAssertEqual(Chrono.calendar.component(.day, from: this.start), 1)
            XCTAssertTrue(this.contains(today))
            XCTAssertEqual(Chrono.calendar.date(byAdding: .day, value: 1, to: this.end).map {
                Chrono.calendar.component(.day, from: $0)
            }, 1, "the day after the end is the first of next month")

            let last = try Chrono.range("last month")
            XCTAssertEqual(Chrono.calendar.date(byAdding: .day, value: 1, to: last.end), this.start)
            XCTAssertEqual(Chrono.calendar.component(.day, from: last.start), 1)
        }
    }

    func testWeeksStartOnMonday() throws {
        try inUTC { today in
            let week = try Chrono.range("this week")
            XCTAssertEqual(Chrono.calendar.component(.weekday, from: week.start), 2)
            XCTAssertEqual(week.days, 7)
            XCTAssertTrue(week.contains(today))
        }
    }

    func testCountedWindowsEndToday() throws {
        try inUTC { today in
            let thirty = try Chrono.range("last 30 days")
            XCTAssertEqual(thirty.end, today)
            XCTAssertEqual(thirty.days, 30)

            XCTAssertEqual(try Chrono.range("past 2 weeks").days, 14)
            XCTAssertThrowsError(try Chrono.range("previous fortnight"), "fortnight is a duration, not a range unit")
        }
    }

    func testCountedMonthsUseTheCalendar() throws {
        try inUTC { today in
            let three = try Chrono.range("previous 3 months")
            XCTAssertEqual(three.end, today)
            let expectedStart = Chrono.calendar.date(
                byAdding: .day, value: 1,
                to: try Chrono.shift(today, by: -3, .month)
            )
            XCTAssertEqual(three.start, expectedStart)
        }
    }

    func testNextWindowStartsToday() throws {
        try inUTC { today in
            let week = try Chrono.range("next 7 days")
            XCTAssertEqual(week.start, today)
            XCTAssertEqual(week.days, 7)
        }
    }

    func testToDate() throws {
        try inUTC { today in
            let mtd = try Chrono.range("month to date")
            XCTAssertEqual(Chrono.calendar.component(.day, from: mtd.start), 1)
            XCTAssertEqual(mtd.end, today)
            let ytd = try Chrono.range("ytd")
            XCTAssertEqual(Chrono.calendar.component(.month, from: ytd.start), 1)
            XCTAssertEqual(Chrono.calendar.component(.day, from: ytd.start), 1)
            XCTAssertEqual(ytd.end, today)
        }
    }

    func testNamedPeriods() throws {
        try inUTC { _ in
            XCTAssertEqual(try Chrono.range("september 2026").start, day("2026-09-01"))
            XCTAssertEqual(try Chrono.range("sep 2026").end, day("2026-09-30"))
            XCTAssertEqual(try Chrono.range("2026-02").days, 28)
            XCTAssertEqual(try Chrono.range("2024-02").days, 29)
            let q3 = try Chrono.range("q3 2026")
            XCTAssertEqual(q3.start, day("2026-07-01"))
            XCTAssertEqual(q3.end, day("2026-09-30"))
            XCTAssertEqual(try Chrono.range("2026 q1").days, 90)
            XCTAssertEqual(try Chrono.range("2026").days, 365)
            XCTAssertEqual(try Chrono.range("2024").days, 366)
        }
    }

    func testSingleDays() throws {
        try inUTC { today in
            let yesterday = try Chrono.range("yesterday")
            XCTAssertEqual(yesterday.days, 1)
            XCTAssertEqual(Chrono.calendar.date(byAdding: .day, value: 1, to: yesterday.end), today)
            XCTAssertEqual(try Chrono.range("2026-09-03").days, 1)
            XCTAssertEqual(try Chrono.range("3 days ago").days, 1)
        }
    }

    func testOpenEnded() throws {
        try inUTC { today in
            let since = try Chrono.range("since 2026-01-01")
            XCTAssertEqual(since.start, day("2026-01-01"))
            XCTAssertEqual(since.end, today)
            let until = try Chrono.range("until 2099-12-31")
            XCTAssertEqual(until.start, today)
            XCTAssertEqual(until.end, day("2099-12-31"))
        }
    }

    func testRefusesWhatIsNotARange() {
        XCTAssertThrowsError(try Chrono.range("chapter 7"))
        XCTAssertThrowsError(try Chrono.range(""))
        XCTAssertThrowsError(try Chrono.range("last 0 days"))
    }
}

// MARK: - Parts of a day

final class DayPartsTests: XCTestCase {

    /// A wall-clock time on a fixed date, read in UTC so the hour is the hour.
    private func clock(_ time: String, on date: String = "2026-09-03") throws -> Date {
        try at("\(date)T\(time)")
    }

    // Time of day

    func testTheDefaultBoundariesAtEveryHandover() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.timeOfDay(try clock("00:00")), .night)
            XCTAssertEqual(Chrono.timeOfDay(try clock("04:59")), .night)
            XCTAssertEqual(Chrono.timeOfDay(try clock("05:00")), .morning)
            XCTAssertEqual(Chrono.timeOfDay(try clock("11:59")), .morning)
            XCTAssertEqual(Chrono.timeOfDay(try clock("12:00")), .afternoon)
            XCTAssertEqual(Chrono.timeOfDay(try clock("16:59")), .afternoon)
            XCTAssertEqual(Chrono.timeOfDay(try clock("17:00")), .evening)
            XCTAssertEqual(Chrono.timeOfDay(try clock("20:59")), .evening)
            XCTAssertEqual(Chrono.timeOfDay(try clock("21:00")), .night)
            XCTAssertEqual(Chrono.timeOfDay(try clock("23:59")), .night)
        }
    }

    func testABakeryStartsItsMorningAtThree() throws {
        let bakery = try TimeOfDay.Boundaries(morning: 3, afternoon: 11, evening: 15, night: 19)
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.timeOfDay(try clock("02:59"), boundaries: bakery), .night)
            XCTAssertEqual(Chrono.timeOfDay(try clock("03:00"), boundaries: bakery), .morning)
            XCTAssertEqual(Chrono.timeOfDay(try clock("11:00"), boundaries: bakery), .afternoon)
            XCTAssertEqual(Chrono.timeOfDay(try clock("15:00"), boundaries: bakery), .evening)
            XCTAssertEqual(Chrono.timeOfDay(try clock("19:00"), boundaries: bakery), .night)
        }
    }

    func testBoundariesThatDoNotRiseAreRefused() {
        // Equal, reversed, and off the clock face — none has one answer for every hour.
        XCTAssertThrowsError(try TimeOfDay.Boundaries(morning: 5, afternoon: 5, evening: 17, night: 21))
        XCTAssertThrowsError(try TimeOfDay.Boundaries(morning: 12, afternoon: 5, evening: 17, night: 21))
        XCTAssertThrowsError(try TimeOfDay.Boundaries(morning: 5, afternoon: 12, evening: 17, night: 24))
        XCTAssertThrowsError(try TimeOfDay.Boundaries(morning: -1, afternoon: 12, evening: 17, night: 21))
        XCTAssertThrowsError(try TimeOfDay.Boundaries(morning: 0, afternoon: 1, evening: 2, night: 2))
        XCTAssertThrowsError(try TimeOfDay.Boundaries(morning: 5, afternoon: 12, evening: 17, night: 21 + 24)) { error in
            XCTAssertEqual(error as? ChronoError, .badBoundaries("hours must be 0–23, got [5, 12, 17, 45]"))
            XCTAssertTrue(error.localizedDescription.contains("rising hours"))
        }
    }

    func testTheEarliestAndLatestBoundariesThatFit() throws {
        let edge = try TimeOfDay.Boundaries(morning: 0, afternoon: 1, evening: 2, night: 23)
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.timeOfDay(try clock("00:00"), boundaries: edge), .morning)
            XCTAssertEqual(Chrono.timeOfDay(try clock("01:00"), boundaries: edge), .afternoon)
            XCTAssertEqual(Chrono.timeOfDay(try clock("22:59"), boundaries: edge), .evening)
            XCTAssertEqual(Chrono.timeOfDay(try clock("23:00"), boundaries: edge), .night)
        }
        XCTAssertEqual(TimeOfDay.Boundaries.default, try TimeOfDay.Boundaries(morning: 5, afternoon: 12, evening: 17, night: 21))
    }

    func testTheSameInstantIsMorningInLondonAndEveningInTokyo() throws {
        // 09:00 UTC on 1 June: 10:00 BST, 18:00 JST.
        let instant = try at("2026-06-01T09:00")
        XCTAssertEqual(Chrono.inZone(london) { Chrono.timeOfDay(instant) }, .morning)
        XCTAssertEqual(Chrono.inZone(tokyo) { Chrono.timeOfDay(instant) }, .evening)
        XCTAssertEqual(Chrono.inZone(london) { Chrono.describe(instant).timeOfDay }, .morning)
        XCTAssertEqual(Chrono.inZone(tokyo) { Chrono.describe(instant).timeOfDay }, .evening)
    }

    func testAcrossADaylightSavingChangeTheClockDecides() throws {
        // 01:30 UTC on the morning London springs forward is 02:30 BST — the
        // clock reads 02:30, so it is night, whatever the sun is doing.
        let instant = try at("2026-03-29T01:30")
        XCTAssertEqual(Chrono.inZone(london) { Chrono.timeOfDay(instant) }, .night)
        XCTAssertEqual(Chrono.inZone(london) { Chrono.describe(instant).time }, "02:30:00")
    }

    func testWordsAndGreetings() {
        XCTAssertEqual(TimeOfDay.morning.label, "Morning")
        XCTAssertEqual(TimeOfDay.night.greeting, "Good night")
        XCTAssertEqual(TimeOfDay.allCases.map(\.rawValue), ["morning", "afternoon", "evening", "night"])
    }

    func testPartsOfADayRoundTripThroughJSON() throws {
        for part in TimeOfDay.allCases {
            let data = try JSONEncoder().encode(part)
            XCTAssertEqual(try JSONDecoder().decode(TimeOfDay.self, from: data), part)
        }
        let boundaries = try TimeOfDay.Boundaries(morning: 4, afternoon: 10, evening: 16, night: 22)
        let data = try JSONEncoder().encode(boundaries)
        XCTAssertEqual(try JSONDecoder().decode(TimeOfDay.Boundaries.self, from: data), boundaries)
    }

    // Clock times

    func testAClockTimeIsCheckedOnTheWayIn() throws {
        XCTAssertEqual(try ClockTime(hour: 0).minutesSinceMidnight, 0)
        XCTAssertEqual(try ClockTime(hour: 23, minute: 59).minutesSinceMidnight, 1439)
        XCTAssertThrowsError(try ClockTime(hour: 24))
        XCTAssertThrowsError(try ClockTime(hour: -1))
        XCTAssertThrowsError(try ClockTime(hour: 9, minute: 60))
        XCTAssertThrowsError(try ClockTime(hour: 9, minute: -1)) { error in
            XCTAssertEqual(error as? ChronoError, .badClockTime("09:-1"))
            XCTAssertTrue(error.localizedDescription.contains("0–23"))
        }
    }

    func testClockTimesCompareAndRoundTrip() throws {
        let early = try ClockTime(hour: 9, minute: 30), late = try ClockTime(hour: 9, minute: 31)
        XCTAssertLessThan(early, late)
        XCTAssertEqual(max(early, late), late)
        let data = try JSONEncoder().encode(late)
        XCTAssertEqual(try JSONDecoder().decode(ClockTime.self, from: data), late)
    }

    // Windows

    func testAWindowIsClosedAtTheStartAndOpenAtTheEnd() throws {
        let nine = try ClockTime(hour: 9), five = try ClockTime(hour: 17)
        try Chrono.inZone(utc) {
            XCTAssertFalse(Chrono.isTime(try clock("08:59"), between: nine, and: five))
            XCTAssertTrue(Chrono.isTime(try clock("09:00"), between: nine, and: five))
            XCTAssertTrue(Chrono.isTime(try clock("16:59"), between: nine, and: five))
            XCTAssertFalse(Chrono.isTime(try clock("17:00"), between: nine, and: five))
        }
    }

    func testAWindowThatCrossesMidnightWraps() throws {
        // "Between ten and six" at night is 22:00 → 05:59, through midnight.
        let ten = try ClockTime(hour: 22), six = try ClockTime(hour: 6)
        try Chrono.inZone(utc) {
            XCTAssertTrue(Chrono.isTime(try clock("22:00"), between: ten, and: six))
            XCTAssertTrue(Chrono.isTime(try clock("23:59"), between: ten, and: six))
            XCTAssertTrue(Chrono.isTime(try clock("00:00"), between: ten, and: six))
            XCTAssertTrue(Chrono.isTime(try clock("05:59"), between: ten, and: six))
            XCTAssertFalse(Chrono.isTime(try clock("06:00"), between: ten, and: six))
            XCTAssertFalse(Chrono.isTime(try clock("12:00"), between: ten, and: six))
            XCTAssertFalse(Chrono.isTime(try clock("21:59"), between: ten, and: six))
        }
    }

    func testAWindowThatStartsWhereItEndsIsTheWholeDay() throws {
        let noon = try ClockTime(hour: 12)
        try Chrono.inZone(utc) {
            for time in ["00:00", "11:59", "12:00", "12:01", "23:59"] {
                XCTAssertTrue(Chrono.isTime(try clock(time), between: noon, and: noon), time)
            }
        }
    }

    func testAOneMinuteWindow() throws {
        let from = try ClockTime(hour: 9, minute: 30), to = try ClockTime(hour: 9, minute: 31)
        try Chrono.inZone(utc) {
            XCTAssertFalse(Chrono.isTime(try clock("09:29"), between: from, and: to))
            XCTAssertTrue(Chrono.isTime(try clock("09:30"), between: from, and: to))
            XCTAssertFalse(Chrono.isTime(try clock("09:31"), between: from, and: to))
            // Seconds do not count: 09:30:59 is still 09:30.
            XCTAssertTrue(Chrono.isTime(try at("2026-09-03T09:30:59"), between: from, and: to))
        }
    }

    func testWindowsReadTheClockInTheZone() throws {
        // 09:00 UTC is inside a 9–5 window in London (10:00) and outside it in Tokyo (18:00).
        let nine = try ClockTime(hour: 9), five = try ClockTime(hour: 17)
        let instant = try at("2026-06-01T09:00")
        XCTAssertTrue(Chrono.inZone(london) { Chrono.isTime(instant, between: nine, and: five) })
        XCTAssertFalse(Chrono.inZone(tokyo) { Chrono.isTime(instant, between: nine, and: five) })
    }

    func testDaytimeIsSixToEightByDefault() throws {
        try Chrono.inZone(utc) {
            XCTAssertFalse(try Chrono.isDaytime(try clock("05:59")))
            XCTAssertTrue(try Chrono.isDaytime(try clock("06:00")))
            XCTAssertTrue(try Chrono.isDaytime(try clock("19:59")))
            XCTAssertFalse(try Chrono.isDaytime(try clock("20:00")))
            XCTAssertTrue(try Chrono.isDaytime(try clock("03:00"), from: 0, to: 23))
            XCTAssertFalse(try Chrono.isDaytime(try clock("23:30"), from: 0, to: 23))
        }
        XCTAssertThrowsError(try Chrono.isDaytime(Date(), from: 6, to: 24))
        XCTAssertThrowsError(try Chrono.isDaytime(Date(), from: -6, to: 20))
    }

    // Interval days

    func testEveryThirdDayFromTheFirst() throws {
        try Chrono.inZone(utc) {
            let anchor = try at("2026-01-01")
            XCTAssertTrue(try Chrono.isEveryNthDay(try at("2026-01-01"), from: anchor, every: 3))
            XCTAssertFalse(try Chrono.isEveryNthDay(try at("2026-01-02"), from: anchor, every: 3))
            XCTAssertFalse(try Chrono.isEveryNthDay(try at("2026-01-03"), from: anchor, every: 3))
            XCTAssertTrue(try Chrono.isEveryNthDay(try at("2026-01-04"), from: anchor, every: 3))
            XCTAssertTrue(try Chrono.isEveryNthDay(try at("2026-01-31"), from: anchor, every: 3))
            XCTAssertFalse(try Chrono.isEveryNthDay(try at("2026-02-01"), from: anchor, every: 3))
        }
    }

    func testDaysBeforeTheAnchorAreNeverIntervalDays() throws {
        try Chrono.inZone(utc) {
            let anchor = try at("2026-01-04")
            XCTAssertFalse(try Chrono.isEveryNthDay(try at("2026-01-01"), from: anchor, every: 3))
            XCTAssertFalse(try Chrono.isEveryNthDay(try at("2025-12-29"), from: anchor, every: 1))
        }
    }

    func testEveryDayIsEveryDay() throws {
        try Chrono.inZone(utc) {
            let anchor = try at("2026-01-01")
            for day in ["2026-01-01", "2026-01-02", "2026-06-15", "2027-03-01"] {
                XCTAssertTrue(try Chrono.isEveryNthDay(try at(day), from: anchor, every: 1), day)
            }
        }
    }

    func testTheTimeOfDayDoesNotMoveTheDay() throws {
        // 23:59 on the anchor day and 00:01 the next morning are one day apart.
        try Chrono.inZone(utc) {
            let anchor = try at("2026-01-01T23:59")
            XCTAssertTrue(try Chrono.isEveryNthDay(try at("2026-01-01T00:00"), from: anchor, every: 5))
            XCTAssertFalse(try Chrono.isEveryNthDay(try at("2026-01-02T00:01"), from: anchor, every: 5))
            XCTAssertTrue(try Chrono.isEveryNthDay(try at("2026-01-06T00:01"), from: anchor, every: 5))
        }
    }

    func testAWeekAcrossTheClockChangeIsStillSevenDays() throws {
        // London springs forward on 29 March 2026. Seven calendar days from
        // the 22nd is the 29th, even though only 167 hours have passed.
        try Chrono.inZone(london) {
            let anchor = try Chrono.date("2026-03-22")
            XCTAssertTrue(try Chrono.isEveryNthDay(try Chrono.date("2026-03-29"), from: anchor, every: 7))
            XCTAssertTrue(try Chrono.isEveryNthDay(try Chrono.date("2026-04-05"), from: anchor, every: 7))
            XCTAssertFalse(try Chrono.isEveryNthDay(try Chrono.date("2026-03-28"), from: anchor, every: 7))
            // And back in October, when the day is 25 hours long.
            let autumn = try Chrono.date("2026-10-18")
            XCTAssertTrue(try Chrono.isEveryNthDay(try Chrono.date("2026-10-25"), from: autumn, every: 7))
        }
    }

    func testLeapDaysAreCountedLikeAnyOther() throws {
        try Chrono.inZone(utc) {
            let anchor = try at("2028-02-28")
            XCTAssertTrue(try Chrono.isEveryNthDay(try at("2028-03-01"), from: anchor, every: 2))
            XCTAssertFalse(try Chrono.isEveryNthDay(try at("2028-03-02"), from: anchor, every: 2))
            let year = try at("2026-01-01")
            XCTAssertTrue(try Chrono.isEveryNthDay(try at("2027-01-01"), from: year, every: 365))
            XCTAssertFalse(try Chrono.isEveryNthDay(try at("2029-01-01"), from: try at("2028-01-01"), every: 365))
        }
    }

    func testAnIntervalBelowOneIsRefused() throws {
        let anchor = Date()
        XCTAssertThrowsError(try Chrono.isEveryNthDay(anchor, from: anchor, every: 0))
        XCTAssertThrowsError(try Chrono.isEveryNthDay(anchor, from: anchor, every: -7)) { error in
            XCTAssertEqual(error as? ChronoError, .badInterval(-7))
            XCTAssertTrue(error.localizedDescription.contains("7 for weekly"))
        }
    }

    // The arithmetic on its own

    func testTheWindowArithmeticOnPlainMinutes() {
        XCTAssertTrue(DayParts.contains(0, from: 0, to: 1))
        XCTAssertFalse(DayParts.contains(1, from: 0, to: 1))
        // 23:59 → 00:00 is one minute long: the end is open, so midnight is out.
        XCTAssertTrue(DayParts.contains(1439, from: 1439, to: 0))
        XCTAssertFalse(DayParts.contains(0, from: 1439, to: 0))
        XCTAssertFalse(DayParts.contains(1438, from: 1439, to: 0))
        XCTAssertTrue(DayParts.contains(720, from: 720, to: 720))
    }

    func testTheIntervalArithmeticOnPlainDays() {
        XCTAssertTrue(DayParts.isOnInterval(dayOffset: 0, every: 3))
        XCTAssertTrue(DayParts.isOnInterval(dayOffset: 9, every: 3))
        XCTAssertFalse(DayParts.isOnInterval(dayOffset: 10, every: 3))
        XCTAssertFalse(DayParts.isOnInterval(dayOffset: -3, every: 3))
    }

    func testThePartArithmeticOnPlainHours() {
        for hour in 0..<24 {
            let expected: TimeOfDay = hour < 5 ? .night : hour < 12 ? .morning : hour < 17 ? .afternoon : hour < 21 ? .evening : .night
            XCTAssertEqual(DayParts.part(forHour: hour, boundaries: .default), expected, "\(hour)")
        }
    }
}

// MARK: - Date tokens

final class DateTokenTests: XCTestCase {

    /// 2026-09-03T14:30:00Z — a Thursday in ISO week 36, Q3.
    private var reference: Date { try! at("2026-09-03T14:30") }

    private func fill(_ template: String, at now: Date? = nil, in zone: TimeZone = utc) -> String {
        Chrono.inZone(zone) { Chrono.fill(template, at: now ?? reference) }
    }

    private func unix(_ text: String) throws -> Int {
        try XCTUnwrap(Int(fill(text)), text)
    }

    func testTodayAndComponents() {
        XCTAssertEqual(fill("{today}"), "2026-09-03")
        XCTAssertEqual(fill("{year}-{month}-{day}"), "2026-09-03")
        XCTAssertEqual(fill("{hour}:{minute}:{second}"), "14:30:00")
        XCTAssertEqual(fill("{month_name} {day_name}"), "September Thursday")
        XCTAssertEqual(fill("{quarter} week {week_number}"), "Q3 week 36")
        XCTAssertEqual(fill("{now}"), "\(Int(reference.timeIntervalSince1970))")
        XCTAssertEqual(fill("{now_ms}"), "\(Int(reference.timeIntervalSince1970) * 1000)")
        XCTAssertEqual(fill("{now_iso}"), "2026-09-03T14:30:00Z")
    }

    func testWeekStartsOnMondayEverywhere() throws {
        let start = Date(timeIntervalSince1970: TimeInterval(try unix("{week_start}")))
        let end = Date(timeIntervalSince1970: TimeInterval(try unix("{week_end}")))
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.calendar.component(.weekday, from: start), 2, "ISO weeks start on Monday, whatever the locale says")
            XCTAssertEqual(start, Chrono.calendar.startOfDay(for: start))
            XCTAssertEqual(Chrono.describe(start).date, "2026-08-31")
        }
        XCTAssertEqual(Int(end.timeIntervalSince(start)) + 1, 7 * 86_400)
        // The same Monday, but Tokyo's midnight is nine hours before UTC's.
        let tokyoStart = Chrono.inZone(tokyo) { Chrono.fill("{week_start}", at: reference) }
        XCTAssertEqual(try XCTUnwrap(Int(tokyoStart)), try unix("{week_start}") - 9 * 3600)
    }

    func testMonthsAndYearsShiftByTheCalendar() throws {
        // "1 year ago" on 1 March 2025 is 1 March 2024 — not 29 February.
        let march = try at("2025-03-01T12:00")
        XCTAssertEqual(fill("{1_year_ago}", at: march), "\(Int(try at("2024-03-01T12:00").timeIntervalSince1970))")
        // Three months before 31 May is 28 February: the calendar clamps.
        let may = try at("2026-05-31T12:00")
        XCTAssertEqual(fill("{3_months_ago}", at: may), "\(Int(try at("2026-02-28T12:00").timeIntervalSince1970))")
        XCTAssertEqual(fill("{6_months_ago}", at: may), "\(Int(try at("2025-11-30T12:00").timeIntervalSince1970))")
    }

    func testDayOffsetsStepByCalendarDay() throws {
        // London springs forward on 29 March 2026; a week before 1 April is
        // still 25 March, though only 167 hours have passed.
        let april = try Chrono.inZone(london) { try Chrono.date("2026-04-01T12:00") }
        XCTAssertEqual(fill("{date_7d_ago}", at: april, in: london), "2026-03-25")
        XCTAssertEqual(fill("{date_30d_ago}", at: april, in: london), "2026-03-02")
        XCTAssertEqual(fill("{date_90d_ago}", at: april, in: london), "2026-01-01")
        // The unix twin is an exact duration and lands an hour off the calendar day.
        let exact = Int(april.timeIntervalSince1970) - 7 * 86_400
        XCTAssertEqual(fill("{7d_ago}", at: april, in: london), "\(exact)")
    }

    func testPeriodTwinsAgree() throws {
        let start = try unix("{month_start}")
        XCTAssertEqual(fill("{month_start_ms}"), "\(start * 1000)")
        XCTAssertEqual(fill("{month_start_date}"), "2026-09-01")
        XCTAssertEqual(fill("{month_start_iso}"), "2026-09-01T00:00:00Z")
        XCTAssertEqual(fill("{month_end_iso}"), "2026-09-30T23:59:59Z")
        XCTAssertEqual(fill("{month_end_date}"), "2026-09-30")
        XCTAssertEqual(try unix("{month_end}"), try unix("{month_start}") + 30 * 86_400 - 1)
        XCTAssertEqual(fill("{week_end_date}"), "2026-09-06")
        XCTAssertEqual(fill("{quarter_start_date}…{quarter_end_date}"), "2026-07-01…2026-09-30")
        XCTAssertEqual(fill("{year_start_date}…{year_end_date}"), "2026-01-01…2026-12-31")
        XCTAssertEqual(fill("{year_end_iso}"), "2026-12-31T23:59:59Z")
    }

    func testLastPeriodsEndASecondBeforeThisOneStarts() throws {
        XCTAssertEqual(fill("{last_week_start_date}…{last_week_end_date}"), "2026-08-24…2026-08-30")
        XCTAssertEqual(fill("{last_month_start_date}…{last_month_end_date}"), "2026-08-01…2026-08-31")
        XCTAssertEqual(fill("{last_quarter_start_date}…{last_quarter_end_date}"), "2026-04-01…2026-06-30")
        XCTAssertEqual(fill("{last_year_start_date}…{last_year_end_date}"), "2025-01-01…2025-12-31")
        XCTAssertEqual(try unix("{last_month_end}"), try unix("{month_start}") - 1)
        XCTAssertEqual(try unix("{last_week_end}"), try unix("{week_start}") - 1)
        XCTAssertEqual(try unix("{last_quarter_end}"), try unix("{quarter_start}") - 1)
        XCTAssertEqual(try unix("{last_year_end}"), try unix("{year_start}") - 1)
        XCTAssertEqual(fill("{last_year_end_iso}"), "2025-12-31T23:59:59Z")
        XCTAssertEqual(fill("{last_quarter_start_ms}"), "\(Int(try at("2026-04-01").timeIntervalSince1970) * 1000)")
    }

    func testTodayYesterdayAndTomorrowBoundaries() throws {
        let midnight = Int(try at("2026-09-03").timeIntervalSince1970)
        XCTAssertEqual(try unix("{today_start}"), midnight)
        XCTAssertEqual(try unix("{today_end}"), midnight + 86_399)
        XCTAssertEqual(fill("{today_start_ms}"), "\(midnight * 1000)")
        XCTAssertEqual(fill("{today_end_ms}"), "\((midnight + 86_399) * 1000)")
        XCTAssertEqual(fill("{today_iso}"), "2026-09-03T00:00:00Z")
        XCTAssertEqual(fill("{yesterday}"), "2026-09-02")
        XCTAssertEqual(fill("{yesterday_iso}"), "2026-09-02T00:00:00Z")
        XCTAssertEqual(try unix("{yesterday_start}"), midnight - 86_400)
        XCTAssertEqual(try unix("{yesterday_end}"), midnight - 1)
        XCTAssertEqual(fill("{tomorrow}"), "2026-09-04")
        XCTAssertEqual(try unix("{tomorrow_start}"), midnight + 86_400)
        XCTAssertEqual(try unix("{tomorrow_end}"), midnight + 2 * 86_400 - 1)
    }

    func testTomorrowIsTwentyThreeHoursLongOnTheClockChange() throws {
        // 28 March 2026 in London: tomorrow springs forward, so tomorrow's
        // end is 23 hours minus a second after its start.
        let saturday = try Chrono.inZone(london) { try Chrono.date("2026-03-28T12:00") }
        let start = try XCTUnwrap(Int(fill("{tomorrow_start}", at: saturday, in: london)))
        let end = try XCTUnwrap(Int(fill("{tomorrow_end}", at: saturday, in: london)))
        XCTAssertEqual(end - start + 1, 23 * 3600)
    }

    func testRelativeTokensAreExactDurations() throws {
        let now = Int(reference.timeIntervalSince1970)
        XCTAssertEqual(try unix("{1h_ago}"), now - 3600)
        XCTAssertEqual(try unix("{6h_ago}"), now - 6 * 3600)
        XCTAssertEqual(try unix("{12h_ago}"), now - 12 * 3600)
        XCTAssertEqual(try unix("{24h_ago}"), now - 86_400)
        XCTAssertEqual(try unix("{1d_ago}"), now - 86_400)
        XCTAssertEqual(try unix("{7d_ago}"), now - 7 * 86_400)
        XCTAssertEqual(try unix("{180d_ago}"), now - 180 * 86_400)
        XCTAssertEqual(try unix("{365d_ago}"), now - 365 * 86_400)
        XCTAssertEqual(try unix("{1_day_ago}"), now - 86_400)
        XCTAssertEqual(try unix("{7_days_ago}"), now - 7 * 86_400)
        XCTAssertEqual(try unix("{30_days_ago}"), now - 30 * 86_400)
        XCTAssertEqual(fill("{30d_ago_ms}"), "\((now - 30 * 86_400) * 1000)")
        XCTAssertEqual(fill("{1h_ago_ms}"), "\((now - 3600) * 1000)")
        XCTAssertEqual(fill("{7d_ago_iso}"), "2026-08-27T14:30:00Z")
        XCTAssertEqual(fill("{365d_ago_iso}"), "2025-09-03T14:30:00Z")
    }

    func testUnknownBracesPassThrough() {
        XCTAssertEqual(fill("{ user { id name } }"), "{ user { id name } }", "a GraphQL body is not a token")
        XCTAssertEqual(fill("https://x/{id}?q={today}"), "https://x/{id}?q=2026-09-03")
        XCTAssertEqual(fill("no braces"), "no braces")
        XCTAssertEqual(fill(""), "")
        XCTAssertEqual(fill("{TODAY}"), "{TODAY}", "names are lowercase")
        XCTAssertEqual(fill("{today"), "{today")
        XCTAssertEqual(fill("{{today}}"), "{2026-09-03}", "the inner braces are the token")
        XCTAssertEqual(fill("{basic_auth}"), "{basic_auth}", "credentials are the app's business, not the calendar's")
        XCTAssertEqual(fill("{currency} {uuid} {random}"), "{currency} {uuid} {random}")
    }

    func testEveryCatalogueTokenResolvesAndItsExampleIsTrue() throws {
        let tokens = Chrono.tokens
        XCTAssertEqual(tokens.count, 124)
        XCTAssertEqual(Set(tokens.map(\.name)).count, tokens.count, "names are unique")
        for token in tokens {
            let value = Chrono.inZone(utc) { Chrono.value(of: token.name, at: reference) }
            XCTAssertNotNil(value, token.name)
            XCTAssertFalse(value?.isEmpty ?? true, token.name)
            XCTAssertEqual(value, token.example, "the example is the value at the reference instant: \(token.name)")
            XCTAssertTrue(token.description.hasSuffix("."), token.name)
            XCTAssertEqual(token.id, token.name)
        }
        XCTAssertNil(Chrono.value(of: "not_a_token", at: reference))
        XCTAssertNil(Chrono.value(of: "2d_ago", at: reference), "only the catalogued durations exist")
        XCTAssertNil(Chrono.value(of: "week_start_seconds", at: reference))
    }

    func testDescriptionsSayWhatTheyMean() {
        let lookup = Dictionary(uniqueKeysWithValues: Chrono.tokens.map { ($0.name, $0.description) })
        XCTAssertEqual(lookup["last_quarter_end_iso"], "The last second of last quarter, in ISO 8601 (UTC).")
        XCTAssertEqual(lookup["week_start"], "The first instant of this week (Monday to Sunday), as a Unix timestamp in seconds.")
        XCTAssertEqual(lookup["30d_ago_ms"], "Exactly 30 days before now, as a Unix timestamp in milliseconds.")
        XCTAssertEqual(lookup["1h_ago"], "Exactly 1 hour before now, as a Unix timestamp in seconds.")
        XCTAssertEqual(lookup["date_90d_ago"], "The calendar date 90 days before today, as yyyy-MM-dd.")
        XCTAssertEqual(lookup["quarter"], "The calendar quarter, as Q1–Q4.")
    }

    func testTheZoneDecidesWhichDayItIs() throws {
        // 23:30 UTC is already tomorrow in London during British Summer Time.
        let late = try at("2026-09-03T23:30")
        XCTAssertEqual(fill("{today}", at: late, in: utc), "2026-09-03")
        XCTAssertEqual(fill("{today}", at: late, in: london), "2026-09-04")
        XCTAssertEqual(fill("{hour}", at: late, in: tokyo), "08")
        XCTAssertEqual(fill("{timezone}", in: tokyo), "Asia/Tokyo")
        // Foundation spells the UTC zone "GMT", and the token reports what the zone says.
        XCTAssertEqual(fill("{timezone}", in: utc), "GMT")
        // ISO tokens are always UTC, whatever the zone.
        XCTAssertEqual(fill("{now_iso}", at: late, in: tokyo), "2026-09-03T23:30:00Z")
        XCTAssertEqual(fill("{today_iso}", at: late, in: london), "2026-09-03T23:00:00Z", "London's midnight, written in UTC")
    }

    func testTokensRoundTripThroughJSON() throws {
        let token = try XCTUnwrap(Chrono.tokens.first)
        let data = try JSONEncoder().encode(token)
        XCTAssertEqual(try JSONDecoder().decode(DateToken.self, from: data), token)
    }
}

// MARK: - Fiscal periods

final class FiscalPeriodTests: XCTestCase {

    private func day(_ date: Date) -> String { Chrono.describe(date).date }

    func testTheUKTaxYearStartsOnTheSixthOfApril() throws {
        try Chrono.inZone(utc) {
            let may = Chrono.fiscalQuarter(try at("2026-05-10"), fiscalYear: .unitedKingdom)
            XCTAssertEqual(may.number, 1)
            XCTAssertEqual(day(may.days.start), "2026-04-06")
            XCTAssertEqual(day(may.days.end), "2026-07-05")
            XCTAssertEqual(may.startYear, 2026)
            XCTAssertEqual(may.endYear, 2027)
            XCTAssertEqual(may.yearLabel, "2026/27")
            XCTAssertEqual(may.label, "Q1 2026/27")

            let february = Chrono.fiscalQuarter(try at("2027-02-10"), fiscalYear: .unitedKingdom)
            XCTAssertEqual(february.number, 4)
            XCTAssertEqual(day(february.days.start), "2027-01-06")
            XCTAssertEqual(day(february.days.end), "2027-04-05")
            XCTAssertEqual(february.yearLabel, "2026/27")
        }
    }

    func testTheFifthOfAprilBelongsToThePreviousYear() throws {
        try Chrono.inZone(utc) {
            let fifth = Chrono.fiscalQuarter(try at("2026-04-05"), fiscalYear: .unitedKingdom)
            XCTAssertEqual(fifth.label, "Q4 2025/26")
            XCTAssertEqual(day(fifth.days.start), "2026-01-06")
            XCTAssertEqual(day(fifth.days.end), "2026-04-05")
            let sixth = Chrono.fiscalQuarter(try at("2026-04-06"), fiscalYear: .unitedKingdom)
            XCTAssertEqual(sixth.label, "Q1 2026/27")
            let year = Chrono.fiscalYear(try at("2026-04-05"), fiscalYear: .unitedKingdom)
            XCTAssertEqual(day(year.start), "2025-04-06")
            XCTAssertEqual(day(year.end), "2026-04-05")
            XCTAssertEqual(year.days, 365)
        }
    }

    func testTheUSFederalYearStartsInOctober() throws {
        try Chrono.inZone(utc) {
            let november = Chrono.fiscalQuarter(try at("2026-11-15"), fiscalYear: .unitedStatesFederal)
            XCTAssertEqual(november.label, "Q1 2026/27")
            XCTAssertEqual(day(november.days.start), "2026-10-01")
            XCTAssertEqual(day(november.days.end), "2026-12-31")
            let september = Chrono.fiscalQuarter(try at("2026-09-30"), fiscalYear: .unitedStatesFederal)
            XCTAssertEqual(september.label, "Q4 2025/26")
            XCTAssertEqual(day(september.days.start), "2026-07-01")
            XCTAssertEqual(day(september.days.end), "2026-09-30")
        }
    }

    func testTheCalendarYearMatchesTheInstantsQuarter() throws {
        try Chrono.inZone(utc) {
            for text in ["2026-01-01", "2026-03-31", "2026-04-01", "2026-06-30", "2026-07-01", "2026-09-30", "2026-10-01", "2026-12-31"] {
                let date = try at(text)
                XCTAssertEqual(Chrono.fiscalQuarter(date).number, Chrono.describe(date).quarter, text)
            }
            let q3 = Chrono.fiscalQuarter(try at("2026-09-03"))
            XCTAssertEqual(q3.yearLabel, "2026")
            XCTAssertEqual(q3.label, "Q3 2026")
            XCTAssertEqual(day(q3.days.start), "2026-07-01")
            XCTAssertEqual(day(q3.days.end), "2026-09-30")
            XCTAssertEqual(q3.days.days, 92)
            XCTAssertEqual(Chrono.fiscalYear(try at("2026-09-03")).days, 365)
            XCTAssertEqual(Chrono.fiscalYear(try at("2028-09-03")).days, 366)
        }
    }

    func testALeapDayInsideAQuarter() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.fiscalQuarter(try at("2028-02-29")).days.days, 91)
            XCTAssertEqual(Chrono.fiscalQuarter(try at("2027-02-28")).days.days, 90)
            let uk = Chrono.fiscalQuarter(try at("2028-02-29"), fiscalYear: .unitedKingdom)
            XCTAssertEqual(uk.label, "Q4 2027/28")
            XCTAssertEqual(uk.days.days, 91)
            XCTAssertTrue(uk.days.contains(try at("2028-02-29")))
        }
    }

    func testAStartDayLateInFebruary() throws {
        try Chrono.inZone(utc) {
            let fiscal = try FiscalYear(startMonth: 2, startDay: 28)
            XCTAssertEqual(day(Chrono.fiscalYear(try at("2028-02-28"), fiscalYear: fiscal).start), "2028-02-28")
            XCTAssertEqual(day(Chrono.fiscalYear(try at("2028-02-27"), fiscalYear: fiscal).start), "2027-02-28")
            XCTAssertEqual(day(Chrono.fiscalYear(try at("2028-02-27"), fiscalYear: fiscal).end), "2028-02-27")
        }
    }

    func testThePresetsAndTheRefusals() throws {
        XCTAssertEqual(FiscalYear.calendar, try FiscalYear(startMonth: 1))
        XCTAssertEqual(FiscalYear.unitedKingdom, try FiscalYear(startMonth: 4, startDay: 6))
        XCTAssertEqual(FiscalYear.unitedStatesFederal, try FiscalYear(startMonth: 10))
        XCTAssertEqual(FiscalYear.australia, try FiscalYear(startMonth: 7))
        XCTAssertEqual(FiscalYear.april, try FiscalYear(startMonth: 4))
        XCTAssertThrowsError(try FiscalYear(startMonth: 13))
        XCTAssertThrowsError(try FiscalYear(startMonth: 0))
        XCTAssertThrowsError(try FiscalYear(startMonth: 4, startDay: 0))
        XCTAssertThrowsError(try FiscalYear(startMonth: 2, startDay: 29)) { error in
            XCTAssertEqual(error as? ChronoError, .badFiscalYear("month 2, day 29"))
            XCTAssertTrue(error.localizedDescription.contains("1–28"))
        }
    }

    func testFiscalTypesRoundTripThroughJSON() throws {
        try Chrono.inZone(utc) {
            let quarter = Chrono.fiscalQuarter(try at("2026-05-10"), fiscalYear: .unitedKingdom)
            let data = try JSONEncoder().encode(quarter)
            XCTAssertEqual(try JSONDecoder().decode(FiscalQuarter.self, from: data), quarter)
            let year = try JSONEncoder().encode(FiscalYear.australia)
            XCTAssertEqual(try JSONDecoder().decode(FiscalYear.self, from: year), .australia)
        }
    }

    func testTheLabelArithmetic() {
        XCTAssertEqual(FiscalPeriods.yearLabel(startYear: 2026, endYear: 2026), "2026")
        XCTAssertEqual(FiscalPeriods.yearLabel(startYear: 2026, endYear: 2027), "2026/27")
        XCTAssertEqual(FiscalPeriods.yearLabel(startYear: 2099, endYear: 2100), "2099/00")
    }
}

// MARK: - Days until, and anniversaries

final class AnniversaryTests: XCTestCase {

    func testDaysUntilCountsCalendarDays() throws {
        try Chrono.inZone(utc) {
            let today = try at("2026-09-03T14:30")
            XCTAssertEqual(Chrono.daysUntil(try at("2026-09-03T02:00"), from: today), 0)
            XCTAssertEqual(Chrono.daysUntil(try at("2026-09-04"), from: today), 1)
            XCTAssertEqual(Chrono.daysUntil(try at("2026-09-02T23:59"), from: today), -1)
            XCTAssertEqual(Chrono.daysUntil(try at("2026-09-04T01:00"), from: try at("2026-09-03T23:00")), 1)
            XCTAssertEqual(Chrono.daysUntil(try at("2027-01-01"), from: try at("2026-01-01")), 365)
            XCTAssertEqual(Chrono.daysUntil(try at("2029-01-01"), from: try at("2028-01-01")), 366)
            XCTAssertEqual(Chrono.daysUntil(try at("2026-01-01"), from: try at("2026-12-31")), -364)
        }
    }

    func testDaysUntilAcrossTheClockChange() throws {
        try Chrono.inZone(london) {
            let saturday = try Chrono.date("2026-03-28T12:00")
            XCTAssertEqual(Chrono.daysUntil(try Chrono.date("2026-03-29T12:00"), from: saturday), 1)
            XCTAssertEqual(Chrono.daysUntil(try Chrono.date("2026-04-04"), from: saturday), 7)
            let autumn = try Chrono.date("2026-10-24T12:00")
            XCTAssertEqual(Chrono.daysUntil(try Chrono.date("2026-10-25T12:00"), from: autumn), 1)
        }
    }

    func testTheNextOccurrenceOfADate() throws {
        try Chrono.inZone(utc) {
            let today = try at("2026-09-03T14:30")
            XCTAssertEqual(Chrono.describe(try Chrono.nextOccurrence(month: 12, day: 25, after: today)).date, "2026-12-25")
            XCTAssertEqual(Chrono.describe(try Chrono.nextOccurrence(month: 5, day: 14, after: today)).date, "2027-05-14")
            XCTAssertEqual(Chrono.describe(try Chrono.nextOccurrence(month: 9, day: 3, after: today)).date, "2026-09-03", "today counts")
            XCTAssertEqual(Chrono.describe(try Chrono.nextOccurrence(month: 9, day: 2, after: today)).date, "2027-09-02")
            XCTAssertEqual(Chrono.describe(try Chrono.nextOccurrence(month: 12, day: 31, after: try at("2026-12-31"))).date, "2026-12-31")
            XCTAssertEqual(Chrono.describe(try Chrono.nextOccurrence(month: 1, day: 1, after: try at("2026-12-31"))).date, "2027-01-01")
            XCTAssertEqual(Chrono.daysUntil(try Chrono.nextOccurrence(month: 12, day: 25, after: today), from: today), 113)
        }
    }

    func testTwentyNinthOfFebruaryLandsOnTheTwentyEighthInACommonYear() throws {
        try Chrono.inZone(utc) {
            XCTAssertEqual(Chrono.describe(try Chrono.nextOccurrence(month: 2, day: 29, after: try at("2026-03-01"))).date, "2027-02-28")
            XCTAssertEqual(Chrono.describe(try Chrono.nextOccurrence(month: 2, day: 29, after: try at("2027-03-01"))).date, "2028-02-29")
            XCTAssertEqual(Chrono.describe(try Chrono.nextOccurrence(month: 2, day: 29, after: try at("2028-02-28"))).date, "2028-02-29")
            XCTAssertEqual(Chrono.describe(try Chrono.nextOccurrence(month: 2, day: 29, after: try at("2027-02-28"))).date, "2027-02-28", "the 28th is the birthday in a common year, and it is today")
            XCTAssertEqual(Chrono.describe(try Chrono.nextOccurrence(month: 2, day: 29, after: try at("2100-01-01"))).date, "2100-02-28", "2100 is not a leap year")
        }
    }

    func testAMonthAndDayNoYearContainsIsRefused() {
        XCTAssertThrowsError(try Chrono.nextOccurrence(month: 4, day: 31))
        XCTAssertThrowsError(try Chrono.nextOccurrence(month: 13, day: 1))
        XCTAssertThrowsError(try Chrono.nextOccurrence(month: 0, day: 5))
        XCTAssertThrowsError(try Chrono.nextOccurrence(month: 2, day: 30)) { error in
            XCTAssertEqual(error as? ChronoError, .badMonthDay("2/30"))
            XCTAssertTrue(error.localizedDescription.contains("29 February is allowed"))
        }
        XCTAssertNoThrow(try Chrono.nextOccurrence(month: 2, day: 29))
        XCTAssertNoThrow(try Chrono.nextOccurrence(month: 12, day: 31))
    }

    func testTheZoneDecidesWhetherTodayHasPassed() throws {
        // 20:00 UTC on Christmas Day is 05:00 on Boxing Day in Tokyo.
        let evening = try at("2026-12-25T20:00")
        XCTAssertEqual(Chrono.inZone(utc) { Chrono.describe(try! Chrono.nextOccurrence(month: 12, day: 25, after: evening)).date }, "2026-12-25")
        XCTAssertEqual(Chrono.inZone(tokyo) { Chrono.describe(try! Chrono.nextOccurrence(month: 12, day: 25, after: evening)).date }, "2027-12-25")
    }

    func testTheLeapRule() {
        XCTAssertTrue(Anniversaries.isLeap(2000))
        XCTAssertFalse(Anniversaries.isLeap(1900))
        XCTAssertTrue(Anniversaries.isLeap(2024))
        XCTAssertFalse(Anniversaries.isLeap(2026))
        XCTAssertFalse(Anniversaries.isLeap(2100))
        Chrono.inZone(utc) {
            XCTAssertEqual(Anniversaries.occurrence(month: 2, day: 29, year: 2027).map { Chrono.describe($0).date }, "2027-02-28")
            XCTAssertEqual(Anniversaries.occurrence(month: 2, day: 29, year: 2028).map { Chrono.describe($0).date }, "2028-02-29")
        }
    }
}

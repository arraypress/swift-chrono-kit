//
//  DurationWordsTests.swift
//  ChronoKit
//
//  A number of seconds, said four ways. Every expectation is a fixed number
//  with one right spelling — a day is 86,400 seconds here, on purpose.
//

import XCTest
@testable import ChronoKit

final class DurationWordsTests: XCTestCase {

    /// Two weeks, three days, four hours, five minutes and six seconds.
    private let everyUnit: TimeInterval = 1_209_600 + 259_200 + 14_400 + 300 + 6

    private func long(_ seconds: TimeInterval, units: Int = 2) throws -> String {
        try Chrono.describe(duration: seconds, style: .long, units: units)
    }

    // The long style

    func testTheSmallestLengths() throws {
        XCTAssertEqual(try long(0), "0 seconds")
        XCTAssertEqual(try long(1), "1 second")
        XCTAssertEqual(try long(59), "59 seconds")
        XCTAssertEqual(try long(60), "1 minute")
        XCTAssertEqual(try long(3_599), "59 minutes, 59 seconds")
        XCTAssertEqual(try long(3_600), "1 hour")
    }

    func testUnitsCapThePartsAndNeverRoundUp() throws {
        // 90,061 seconds is a day, an hour, a minute and a second.
        XCTAssertEqual(try long(90_061, units: 1), "1 day")
        XCTAssertEqual(try long(90_061), "1 day, 1 hour")
        XCTAssertEqual(try long(90_061, units: 3), "1 day, 1 hour, 1 minute")
        XCTAssertEqual(try long(90_061, units: 4), "1 day, 1 hour, 1 minute, 1 second")
        XCTAssertEqual(try long(90_061, units: 9), "1 day, 1 hour, 1 minute, 1 second")
    }

    func testWeeksAreFixedLengths() throws {
        XCTAssertEqual(try long(604_800), "1 week")
        XCTAssertEqual(try long(1_209_601, units: 1), "2 weeks")
        XCTAssertEqual(try long(1_209_601, units: 5), "2 weeks, 1 second")
        let nineDaysThreeHours: TimeInterval = 788_400
        XCTAssertEqual(try long(nineDaysThreeHours), "1 week, 2 days")
        XCTAssertEqual(try long(nineDaysThreeHours, units: 3), "1 week, 2 days, 3 hours")
    }

    func testMonthsAndYearsAreNotUnits() throws {
        // A year of seconds is 52 weeks and a day, because a year has no
        // length in seconds and this package will not pretend it does.
        XCTAssertEqual(try long(31_536_000, units: 5), "52 weeks, 1 day")
        XCTAssertEqual(try long(2_592_000, units: 5), "4 weeks, 2 days")
    }

    func testSingularAndPlural() throws {
        XCTAssertEqual(try long(86_400 + 3_600), "1 day, 1 hour")
        XCTAssertEqual(try long(183_600), "2 days, 3 hours")
        XCTAssertEqual(try long(60 + 1), "1 minute, 1 second")
        XCTAssertEqual(try long(120 + 2), "2 minutes, 2 seconds")
    }

    func testAUnitsCapBelowOneShowsOnePart() throws {
        XCTAssertEqual(try long(90_061, units: 0), "1 day")
        XCTAssertEqual(try long(90_061, units: -3), "1 day")
    }

    // The short style

    func testTheShortStyleUsesTheSuffixesTheParserReads() throws {
        XCTAssertEqual(try Chrono.describe(duration: 0, style: .short), "0s")
        XCTAssertEqual(try Chrono.describe(duration: 59, style: .short), "59s")
        XCTAssertEqual(try Chrono.describe(duration: 90_061, style: .short), "1d 1h")
        XCTAssertEqual(try Chrono.describe(duration: 90_061, style: .short, units: 4), "1d 1h 1m 1s")
        let seventeenDays: TimeInterval = 1_468_800
        XCTAssertEqual(try Chrono.describe(duration: seventeenDays, style: .short), "2w 3d")
    }

    func testEveryShortPartReadsBackThroughTheParser() throws {
        let text = try Chrono.describe(duration: everyUnit, style: .short, units: 5)
        XCTAssertEqual(text, "2w 3d 4h 5m 6s")
        var total: TimeInterval = 0
        for token in text.split(separator: " ") { total += try Chrono.duration(String(token)) }
        XCTAssertEqual(total, everyUnit)
    }

    func testARoundTripThroughTheParser() throws {
        let seconds = try Chrono.duration("2w")
        XCTAssertEqual(try Chrono.describe(duration: seconds), "2 weeks")
        XCTAssertEqual(try Chrono.duration(try Chrono.describe(duration: seconds, style: .short)), seconds)
        let ninety = try Chrono.duration("90m")
        XCTAssertEqual(try Chrono.describe(duration: ninety), "1 hour, 30 minutes")
        XCTAssertEqual(try Chrono.describe(duration: ninety, style: .short), "1h 30m")
    }

    // The clock style

    func testTheClockUnderAnHourLeavesTheHoursOff() throws {
        XCTAssertEqual(try Chrono.describe(duration: 0, style: .clock), "00:00")
        XCTAssertEqual(try Chrono.describe(duration: 185, style: .clock), "03:05")
        XCTAssertEqual(try Chrono.describe(duration: 3_599, style: .clock), "59:59")
    }

    func testTheClockFromAnHourUpShowsHours() throws {
        XCTAssertEqual(try Chrono.describe(duration: 3_600, style: .clock), "01:00:00")
        XCTAssertEqual(try Chrono.describe(duration: 3_661, style: .clock), "01:01:01")
    }

    func testTheClockFoldsDaysAndWeeksIntoHours() throws {
        XCTAssertEqual(try Chrono.describe(duration: 97_200, style: .clock), "27:00:00")
        XCTAssertEqual(try Chrono.describe(duration: 183_600, style: .clock), "51:00:00")
        XCTAssertEqual(try Chrono.describe(duration: 604_800, style: .clock), "168:00:00")
    }

    func testThreeUnitsForceTheHoursFieldOnTheClock() throws {
        XCTAssertEqual(try Chrono.describe(duration: 185, style: .clock, units: 3), "00:03:05")
        XCTAssertEqual(try Chrono.describe(duration: 0, style: .clock, units: 3), "00:00:00")
        // And fewer units never removes a field that is needed.
        XCTAssertEqual(try Chrono.describe(duration: 97_200, style: .clock, units: 1), "27:00:00")
    }

    // The words style

    func testWordsSpellTheCountsAndJoinLikeSpeech() throws {
        XCTAssertEqual(try Chrono.describe(duration: 0, style: .words), "zero seconds")
        XCTAssertEqual(try Chrono.describe(duration: 1, style: .words), "one second")
        XCTAssertEqual(try Chrono.describe(duration: 183_600, style: .words), "two days and three hours")
        XCTAssertEqual(try Chrono.describe(duration: 90_061, style: .words, units: 4), "one day, one hour, one minute and one second")
        XCTAssertEqual(try Chrono.describe(duration: 604_800, style: .words), "one week")
    }

    func testTheTwentyBoundary() throws {
        XCTAssertEqual(try Chrono.describe(duration: 20 * 60, style: .words), "twenty minutes")
        XCTAssertEqual(try Chrono.describe(duration: 21 * 60, style: .words), "21 minutes")
        XCTAssertEqual(try Chrono.describe(duration: 59, style: .words), "59 seconds")
        XCTAssertEqual(try Chrono.describe(duration: 604_800 * 52, style: .words, units: 1), "52 weeks")
        XCTAssertEqual(try Chrono.describe(duration: 604_800 * 19, style: .words, units: 1), "nineteen weeks")
    }

    // Edges

    func testFractionalSecondsAreTruncated() throws {
        XCTAssertEqual(try long(59.999), "59 seconds")
        XCTAssertEqual(try long(0.999), "0 seconds")
        XCTAssertEqual(try Chrono.describe(duration: 3_600.9, style: .clock), "01:00:00")
        XCTAssertEqual(try Chrono.durationParts(0.5), [])
    }

    func testNegativeAndNonFiniteLengthsAreRefused() {
        XCTAssertThrowsError(try Chrono.describe(duration: -1)) { error in
            guard case .badDuration(let text)? = error as? ChronoError else { return XCTFail("\(error)") }
            XCTAssertTrue(text.contains("zero or more"))
            XCTAssertTrue(error.localizedDescription.hasPrefix("not a duration: -1.0 seconds"))
        }
        XCTAssertThrowsError(try Chrono.describe(duration: .nan))
        XCTAssertThrowsError(try Chrono.describe(duration: .infinity))
        XCTAssertThrowsError(try Chrono.describe(duration: -.infinity))
        XCTAssertThrowsError(try Chrono.durationParts(-0.5))
        XCTAssertNoThrow(try Chrono.describe(duration: -0.0))
    }

    func testALengthBeyondAnIntOfSecondsIsOutOfRange() {
        XCTAssertThrowsError(try Chrono.describe(duration: 1e30)) { error in
            guard case .outOfRange? = error as? ChronoError else { return XCTFail("\(error)") }
        }
        XCTAssertNoThrow(try Chrono.describe(duration: 1e15))
    }

    func testEveryStyleAgreesOnAnEmptyLength() throws {
        XCTAssertEqual(try Chrono.describe(duration: 0, style: .long), "0 seconds")
        XCTAssertEqual(try Chrono.describe(duration: 0, style: .short), "0s")
        XCTAssertEqual(try Chrono.describe(duration: 0, style: .clock), "00:00")
        XCTAssertEqual(try Chrono.describe(duration: 0, style: .words), "zero seconds")
    }

    // The parts

    func testThePartsComeLargestFirstWithoutZeros() throws {
        XCTAssertEqual(try Chrono.durationParts(0), [])
        XCTAssertEqual(try Chrono.durationParts(1), [DurationPart(count: 1, unit: .second)])
        XCTAssertEqual(try Chrono.durationParts(604_800), [DurationPart(count: 1, unit: .week)])
        XCTAssertEqual(
            try Chrono.durationParts(90_061),
            [.init(count: 1, unit: .day), .init(count: 1, unit: .hour), .init(count: 1, unit: .minute), .init(count: 1, unit: .second)]
        )
        XCTAssertEqual(
            try Chrono.durationParts(1_209_600 + 45),
            [.init(count: 2, unit: .week), .init(count: 45, unit: .second)]
        )
        let units = try Chrono.durationParts(everyUnit).map(\.unit)
        XCTAssertEqual(units, [.week, .day, .hour, .minute, .second])
    }

    func testThePartsAddBackUpToTheSeconds() throws {
        for seconds in [1, 59, 60, 3_599, 3_600, 86_399, 86_400, 90_061, 604_799, 604_800, 1_209_601, 31_536_000] {
            let parts = try Chrono.durationParts(TimeInterval(seconds))
            let total = parts.reduce(0) { sum, part in
                sum + part.count * DurationWords.unitLengths.first { $0.unit == part.unit }!.seconds
            }
            XCTAssertEqual(total, seconds, "\(seconds)")
        }
    }

    func testPartsAndStylesRoundTripThroughJSON() throws {
        let part = DurationPart(count: 3, unit: .hour)
        XCTAssertEqual(try JSONDecoder().decode(DurationPart.self, from: JSONEncoder().encode(part)), part)
        for style in DurationStyle.allCases {
            XCTAssertEqual(try JSONDecoder().decode(DurationStyle.self, from: JSONEncoder().encode(style)), style)
        }
        XCTAssertEqual(DurationStyle.allCases.count, 4)
    }

    // The arithmetic on its own

    func testTheSpellingTable() {
        XCTAssertEqual(DurationWords.spelled(0), "zero")
        XCTAssertEqual(DurationWords.spelled(20), "twenty")
        XCTAssertEqual(DurationWords.spelled(21), "21")
        XCTAssertEqual(DurationWords.spelled(100), "100")
    }

    func testTheSpokenJoin() {
        XCTAssertEqual(DurationWords.sentence([]), "")
        XCTAssertEqual(DurationWords.sentence(["a"]), "a")
        XCTAssertEqual(DurationWords.sentence(["a", "b"]), "a and b")
        XCTAssertEqual(DurationWords.sentence(["a", "b", "c"]), "a, b and c")
    }

    func testTheClockArithmetic() {
        XCTAssertEqual(DurationWords.clock(wholeSeconds: 0, forceHours: false), "00:00")
        XCTAssertEqual(DurationWords.clock(wholeSeconds: 0, forceHours: true), "00:00:00")
        XCTAssertEqual(DurationWords.clock(wholeSeconds: 3_599, forceHours: false), "59:59")
        XCTAssertEqual(DurationWords.clock(wholeSeconds: 360_000, forceHours: false), "100:00:00")
    }

    func testTheSuffixTableCoversEveryUnit() {
        for unit in CalendarUnit.allCases {
            XCTAssertFalse(DurationWords.suffix(for: unit).isEmpty, unit.rawValue)
        }
        XCTAssertEqual(DurationWords.suffix(for: .minute), "m")
        XCTAssertEqual(DurationWords.suffix(for: .month), "mo")
    }
}

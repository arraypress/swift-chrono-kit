//
//  RelativeTests.swift
//  ChronoKit
//
//  The wording moved down from the chrono CLI, pinned exactly: a caller that
//  parsed "in 3 days" yesterday must parse it tomorrow.
//

import XCTest
@testable import ChronoKit

final class RelativeTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_772_547_000)

    private func words(_ seconds: TimeInterval) -> String {
        Chrono.relative(from: now, to: now.addingTimeInterval(seconds))
    }

    func testUnderFortyFiveSecondsIsNow() {
        XCTAssertEqual(words(20), "now")
        XCTAssertEqual(words(-20), "now")
        XCTAssertEqual(words(44), "now")
        XCTAssertEqual(words(0), "now")
        XCTAssertTrue(Chrono.relativeSpan(from: now, to: now).isNow)
    }

    func testDirectionIsCarriedInWords() {
        XCTAssertEqual(words(7_200), "in 2 hours")
        XCTAssertEqual(words(-7_200), "2 hours ago")
        XCTAssertTrue(Chrono.relativeSpan(from: now, to: now.addingTimeInterval(-7_200)).isPast)
        XCTAssertFalse(Chrono.relativeSpan(from: now, to: now.addingTimeInterval(7_200)).isPast)
    }

    func testSingularAndPlural() {
        XCTAssertEqual(words(45), "in 1 minute")
        XCTAssertEqual(words(3_600), "in 1 hour")
        XCTAssertEqual(words(86_400), "in 1 day")
        XCTAssertEqual(words(86_400 * 2), "in 2 days")
        XCTAssertEqual(words(-86_400 * 7), "1 week ago")
    }

    func testScaleSteps() {
        XCTAssertEqual(words(86_400 * 14), "in 2 weeks")
        XCTAssertEqual(words(86_400 * 50), "in 7 weeks")
        XCTAssertEqual(words(86_400 * 90), "in 3 months")
        XCTAssertEqual(words(86_400 * 400), "in 1 year")
        XCTAssertEqual(words(86_400 * 800), "in 2 years")
    }

    func testTheParts() {
        let span = Chrono.relativeSpan(from: now, to: now.addingTimeInterval(86_400 * 14))
        XCTAssertEqual(span.count, 2)
        XCTAssertEqual(span.unit, .week)
        XCTAssertFalse(span.isPast)
        XCTAssertFalse(span.isNow)
        XCTAssertEqual(span.words, "in 2 weeks")
        let data = try? JSONEncoder().encode(span)
        XCTAssertEqual(try JSONDecoder().decode(RelativeSpan.self, from: XCTUnwrap(data)), span)
    }

    func testWordingIsEnglishRegardlessOfLocale() {
        // Deliberately not RelativeDateTimeFormatter: that is locale-driven
        // and would emit "in 2 Stunden" on a German machine, which is fine
        // for a person and wrong for a field an agent parses.
        XCTAssertTrue(words(7_200).hasPrefix("in "))
        XCTAssertTrue(words(-7_200).hasSuffix(" ago"))
    }

    func testTheOneArgumentFormMeasuresFromNow() {
        XCTAssertEqual(Chrono.relative(Date().addingTimeInterval(86_400 * 3)), "in 3 days")
        XCTAssertEqual(Chrono.relative(Date()), "now")
    }
}

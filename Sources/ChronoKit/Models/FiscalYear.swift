//
//  FiscalYear.swift
//  ChronoKit
//

import Foundation

/// When a financial year begins: the month and the day.
///
/// A calendar year is one of these (1 January), and so is the UK tax year
/// (6 April), the US federal year (1 October) and Australia's (1 July).
/// The day is capped at 28 so a start date exists in every year — a fiscal
/// year that "starts on the 30th" has no February to start in.
public struct FiscalYear: Sendable, Hashable, Codable {

    /// The month the year begins, 1–12.
    public let startMonth: Int

    /// The day of that month the year begins, 1–28.
    public let startDay: Int

    /// A fiscal year beginning on a month and day.
    ///
    /// - Throws: ``ChronoError/badFiscalYear(_:)`` for a month outside 1–12
    ///   or a day outside 1–28.
    public init(startMonth: Int, startDay: Int = 1) throws {
        try FiscalPeriods.validate(startMonth: startMonth, startDay: startDay)
        self.startMonth = startMonth
        self.startDay = startDay
    }

    init(startMonth: Int, startDay: Int, unchecked: Void) {
        self.startMonth = startMonth
        self.startDay = startDay
    }
}

//
//  FiscalQuarter.swift
//  ChronoKit
//

import Foundation

/// One quarter of a fiscal year, and the year it belongs to.
///
/// The year is carried as two calendar years because a fiscal year that
/// starts in April lives in both: the UK's 2026/27 runs from April 2026 to
/// April 2027. When the fiscal year is the calendar year the two are equal.
public struct FiscalQuarter: Sendable, Hashable, Codable {

    /// The quarter, 1–4, counted from the fiscal year's first day.
    public let number: Int

    /// The calendar year the fiscal year began in.
    public let startYear: Int

    /// The calendar year the fiscal year ends in.
    public let endYear: Int

    /// The quarter's days, inclusive at both ends.
    public let days: DateRange

    /// The fiscal year the quarter is in.
    public let fiscalYear: FiscalYear
}

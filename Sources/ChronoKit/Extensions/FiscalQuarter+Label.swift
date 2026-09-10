//
//  FiscalQuarter+Label.swift
//  ChronoKit
//

import Foundation

extension FiscalQuarter {

    /// The year as people write it: `2026` when the fiscal year is the
    /// calendar year, `2026/27` when it straddles two.
    public var yearLabel: String { FiscalPeriods.yearLabel(startYear: startYear, endYear: endYear) }

    /// The quarter as people write it: `Q1 2026/27`.
    public var label: String { "Q\(number) \(yearLabel)" }
}

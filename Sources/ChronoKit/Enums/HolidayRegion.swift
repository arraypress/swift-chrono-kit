//
//  HolidayRegion.swift
//  ChronoKit
//

import Foundation

/// The jurisdictions whose public holidays this package computes by rule.
///
/// The United Kingdom is three regions, not one: Scotland takes 2 January
/// and St Andrew's Day and skips Easter Monday, Northern Ireland adds
/// St Patrick's Day and the Twelfth. A caller asking for "UK bank holidays"
/// has to say which, and the England and Wales list is what most people mean.
public enum HolidayRegion: String, CaseIterable, Sendable, Codable {

    /// United States federal holidays, as the Office of Personnel Management lists them.
    case unitedStates

    /// Bank holidays in England and Wales.
    case englandAndWales

    /// Bank holidays in Scotland.
    case scotland

    /// Bank holidays in Northern Ireland.
    case northernIreland

    /// The region as people write it: `England and Wales`.
    public var label: String {
        switch self {
        case .unitedStates: "United States"
        case .englandAndWales: "England and Wales"
        case .scotland: "Scotland"
        case .northernIreland: "Northern Ireland"
        }
    }

    /// The first year the rules here describe correctly for this region.
    ///
    /// Earlier years had different law: the US moved several holidays to
    /// Mondays in 1971, and the UK's Early May bank holiday began in 1978.
    /// Asking for 1965 would return a confident list that is wrong, so the
    /// request is refused instead.
    public var firstCoveredYear: Int {
        switch self {
        case .unitedStates: 1971
        case .englandAndWales, .scotland, .northernIreland: 1978
        }
    }
}

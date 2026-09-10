//
//  HolidayError.swift
//  ChronoKit
//

import Foundation

/// What a holiday request refused, in words a caller can print unchanged.
public enum HolidayError: Error, LocalizedError, Equatable, Sendable {

    /// A year before the rules here were the law, or before the Gregorian
    /// calendar existed for Easter.
    case yearNotCovered(year: Int, region: String, from: Int)

    public var errorDescription: String? {
        switch self {
        case .yearNotCovered(let year, let region, let from):
            return "no holiday rules for \(region) in \(year)\nthe rules here describe \(from) onwards; earlier years had different law"
        }
    }
}

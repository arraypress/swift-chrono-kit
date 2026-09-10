//
//  WeekdayRule.swift
//  ChronoKit
//

import Foundation

/// One `BYDAY` entry: a weekday, optionally the nth one of its period.
///
/// `2TU` is the second Tuesday, `-1FR` the last Friday, and a bare `TU` is
/// every Tuesday. Which period the ordinal counts within — the month or the
/// year — is decided by the rule's frequency, not by the entry.
public struct WeekdayRule: Sendable, Hashable, Codable {

    /// The position within the period: 1 is the first, -1 the last, nil is every one.
    public let ordinal: Int?

    /// The day of the week.
    public let weekday: Weekday

    /// A weekday entry; no ordinal means every such day in the period.
    public init(ordinal: Int? = nil, weekday: Weekday) {
        self.ordinal = ordinal
        self.weekday = weekday
    }
}

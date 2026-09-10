//
//  RecurrenceFrequency.swift
//  ChronoKit
//

import Foundation

/// How often a rule repeats: the `FREQ` of RFC 5545, plus quarters.
///
/// Quarters are not in the RFC — an invite says `MONTHLY;INTERVAL=3` and
/// leans on its start date — but "the last working day of the quarter" is
/// a rule people actually write, and it needs a period that starts on
/// 1 January, 1 April, 1 July and 1 October whatever the start date was.
/// A quarterly rule has no RRULE spelling; ``RecurrenceRule/rruleString``
/// is nil for it and says so.
public enum RecurrenceFrequency: String, CaseIterable, Sendable, Codable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case quarterly = "QUARTERLY"
    case yearly = "YEARLY"

    /// The word: `day`, `week`, `month`, `quarter`, `year`.
    public var unitName: String {
        switch self {
        case .daily: "day"
        case .weekly: "week"
        case .monthly: "month"
        case .quarterly: "quarter"
        case .yearly: "year"
        }
    }
}

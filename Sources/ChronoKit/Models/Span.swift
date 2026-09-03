//
//  Span.swift
//  ChronoKit
//

import Foundation

/// The distance between two instants, said two ways at once.
///
/// Both halves are needed and neither is redundant. The calendar breakdown
/// ("1 year, 2 months, 5 days") is what a person means and cannot be derived
/// from a total, because months are not a fixed length. The totals
/// ("432 days", "10,368 hours") are what arithmetic needs and cannot be
/// derived from the breakdown, for the same reason.
public struct Span: Sendable, Hashable, Codable {

    /// The earlier instant.
    public let from: Date

    /// The later instant.
    public let to: Date

    /// True when the caller gave them the other way round.
    ///
    /// Kept rather than corrected silently: `chrono diff tomorrow yesterday`
    /// is a question with a sign, and reporting a positive span for it would
    /// be answering a different one.
    public let isBackwards: Bool

    public let years: Int
    public let months: Int
    public let days: Int
    public let hours: Int
    public let minutes: Int
    public let seconds: Int

    /// Whole calendar days between the two dates.
    ///
    /// Counted by the calendar, not by dividing seconds: across a spring DST
    /// transition a "day" is 23 hours, and 23 hours divided by 24 is zero days.
    public let totalDays: Int

    /// Whole weeks, and the days left over.
    public let totalWeeks: Int
    public let remainderDays: Int

    /// Whole hours, minutes and seconds between the two instants.
    public let totalHours: Int
    public let totalMinutes: Int
    public let totalSeconds: Int

    /// Calendar days excluding Saturday and Sunday.
    public let businessDays: Int

    /// The breakdown as a sentence: `1 year, 2 months, 5 days`.
    ///
    /// Zero components are dropped, so a span of exactly two hours reads
    /// "2 hours" rather than "0 years, 0 months, 0 days, 2 hours".
    public var described: String {
        let parts: [(Int, String)] = [
            (years, "year"), (months, "month"), (days, "day"),
            (hours, "hour"), (minutes, "minute"), (seconds, "second"),
        ]
        let words = parts
            .filter { $0.0 != 0 }
            .map { "\($0.0) \($0.0 == 1 ? $0.1 : $0.1 + "s")" }
        return words.isEmpty ? "0 seconds" : words.joined(separator: ", ")
    }
}

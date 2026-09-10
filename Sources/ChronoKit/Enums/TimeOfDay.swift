//
//  TimeOfDay.swift
//  ChronoKit
//

import Foundation

/// The four parts of a day as people name them, not as the sun draws them.
///
/// "Morning", "afternoon", "evening" and "night" are conventions about the
/// clock — a greeting, a report bucket, a rule for when a notification may
/// fire. They are decided by hour boundaries (``TimeOfDay/Boundaries``), and
/// the boundaries are yours to set, because a bakery's morning and a bar's
/// morning are different hours. Sunrise and sunset are a different question
/// with a different answer at every latitude; that one belongs to a solar
/// calculation, not a calendar.
public enum TimeOfDay: String, CaseIterable, Sendable, Codable {
    case morning, afternoon, evening, night

    /// The word, capitalised: `Morning`.
    public var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// The greeting that goes with it: `Good morning`, `Good night`.
    public var greeting: String { "Good \(rawValue)" }
}

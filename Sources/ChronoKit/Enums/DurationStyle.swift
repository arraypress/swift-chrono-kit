//
//  DurationStyle.swift
//  ChronoKit
//

import Foundation

/// The four ways a length of time gets written down.
///
/// One number of seconds, four audiences: a sentence for a person, a
/// compact form for a column, a clock for a timer, and words for speech.
/// The style changes the spelling only — the parts underneath are the same
/// weeks, days, hours, minutes and seconds every time.
public enum DurationStyle: String, CaseIterable, Sendable, Codable {

    /// `2 days, 3 hours` — a sentence, units spelled out, joined by commas.
    case long

    /// `2d 3h` — the compact suffixes ``Chrono/duration(_:)`` reads back.
    case short

    /// `51:00:00` or `03:05` — hours, minutes and seconds on a clock face.
    /// Weeks and days are folded into the hours, because a clock has no
    /// day column; under an hour the hours are left off unless asked for.
    case clock

    /// `two days and three hours` — for a sentence that will be read aloud.
    /// Counts are spelled out up to twenty and written as digits after
    /// that, which is how prose style guides have it.
    case words
}

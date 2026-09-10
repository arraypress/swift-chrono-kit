//
//  ChronoError.swift
//  ChronoKit
//

import Foundation

/// What went wrong, in words a caller can print unchanged.
public enum ChronoError: Error, LocalizedError, Equatable, Sendable {

    /// The text is not a date this package can read.
    case badDate(String)

    /// The text is not a duration like `2w` or `90m`.
    case badDuration(String)

    /// The text is not a run of days this package can read.
    case badRange(String)

    /// The text is not an IANA time zone identifier.
    case unknownZone(String)

    /// A date fell outside what the calendar can represent.
    case outOfRange(String)

    /// A day interval below one — "every zeroth day" names nothing.
    case badInterval(Int)

    /// Part-of-day hours that are outside 0–23 or do not rise in order.
    case badBoundaries(String)

    /// A clock time whose hour or minute is off the face.
    case badClockTime(String)

    /// A fiscal year start that is not a month 1–12 and a day 1–28.
    case badFiscalYear(String)

    /// A month and day that no year contains, like 31 April.
    case badMonthDay(String)

    public var errorDescription: String? {
        switch self {
        case .badDate(let text):
            return """
                not a date: \(text.isEmpty ? "(empty)" : text)
                try 2026-09-03, 2026-09-03T14:30, today, tomorrow, next friday, +2w, or 3d ago
                """
        case .badDuration(let text):
            return """
                not a duration: \(text.isEmpty ? "(empty)" : text)
                try 90m, 4h, 7d, 2w, 6mo, 1y — note m is minutes and mo is months
                """
        case .badRange(let text):
            return """
                not a date range: \(text.isEmpty ? "(empty)" : text)
                try last 30 days, this month, q3 2026, 2026-03-01 to 2026-03-05, or since monday
                """
        case .unknownZone(let text):
            return "not a time zone: \(text)\nuse an IANA identifier like Europe/London or Asia/Tokyo"
        case .outOfRange(let what):
            return "outside the calendar's range: \(what)"
        case .badInterval(let interval):
            return "not a day interval: \(interval)\nuse 1 for every day, 2 for every other day, 7 for weekly"
        case .badBoundaries(let what):
            return "not a set of day-part boundaries: \(what)\nmorning, afternoon, evening and night must start at rising hours between 0 and 23"
        case .badClockTime(let what):
            return "not a clock time: \(what)\nhours run 0–23 and minutes 0–59"
        case .badFiscalYear(let what):
            return "not a fiscal year start: \(what)\nthe month runs 1–12 and the day 1–28, so the year can start in every calendar year"
        case .badMonthDay(let what):
            return "not a day of the year: \(what)\nthe month runs 1–12 and the day must exist in that month; 29 February is allowed and lands on the 28th in a common year"
        }
    }
}

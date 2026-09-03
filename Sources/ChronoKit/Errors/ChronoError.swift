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

    /// The text is not an IANA time zone identifier.
    case unknownZone(String)

    /// A date fell outside what the calendar can represent.
    case outOfRange(String)

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
        case .unknownZone(let text):
            return "not a time zone: \(text)\nuse an IANA identifier like Europe/London or Asia/Tokyo"
        case .outOfRange(let what):
            return "outside the calendar's range: \(what)"
        }
    }
}

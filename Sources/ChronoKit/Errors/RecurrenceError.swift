//
//  RecurrenceError.swift
//  ChronoKit
//

import Foundation

/// What a recurrence rule refused, in words a caller can print unchanged.
public enum RecurrenceError: Error, LocalizedError, Equatable, Sendable {

    /// An RRULE part this package does not implement: `BYHOUR`, `BYWEEKNO`,
    /// `BYYEARDAY`, `BYMINUTE`, `BYSECOND`, or an hourly or finer frequency.
    case unsupported(String)

    /// A rule whose parts do not make sense together or are out of range.
    case badRule(String)

    /// Text that is neither an RRULE nor a phrase this package reads.
    case badPhrase(String)

    public var errorDescription: String? {
        switch self {
        case .unsupported(let part):
            return "not supported in a recurrence rule: \(part)\nthis package reads FREQ, INTERVAL, BYDAY, BYMONTHDAY, BYMONTH, BYSETPOS, COUNT, UNTIL and WKST"
        case .badRule(let what):
            return "not a usable recurrence rule: \(what)"
        case .badPhrase(let text):
            return """
                not a recurrence: \(text.isEmpty ? "(empty)" : text)
                try every day, every 2 weeks on monday, second tuesday of every month, last day of the month, \
                every year on 4 july, first working day of the month, or an RRULE like FREQ=MONTHLY;BYDAY=2TU
                """
        }
    }
}

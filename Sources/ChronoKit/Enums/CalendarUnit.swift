//
//  CalendarUnit.swift
//  ChronoKit
//

import Foundation

/// The units this package adds, subtracts and counts in.
///
/// Split from `Calendar.Component` because that enum carries a dozen members
/// nobody offsets by (`era`, `nanosecond`, `weekdayOrdinal`), and a CLI flag
/// whose valid values are "any of these 20, six of which crash" is not a
/// contract.
public enum CalendarUnit: String, CaseIterable, Sendable, Codable {
    case second, minute, hour, day, week, month, quarter, year

    /// The Foundation component this maps to.
    ///
    /// Quarters are absent from Foundation's arithmetic in practice — adding
    /// `.quarter` is a documented no-op on the Gregorian calendar — so it is
    /// carried as three months. Weeks are added as days for the same reason
    /// they are elsewhere: `.weekOfYear` arithmetic is correct, but expressing
    /// it in days keeps one code path.
    var component: Calendar.Component {
        switch self {
        case .second: .second
        case .minute: .minute
        case .hour:   .hour
        case .day:    .day
        case .week:   .day
        case .month:  .month
        case .quarter: .month
        case .year:   .year
        }
    }

    /// How many of ``component`` one of these is worth.
    var multiplier: Int {
        switch self {
        case .week: 7
        case .quarter: 3
        default: 1
        }
    }

    /// The plural form, for printing a count.
    public func label(for count: Int) -> String {
        abs(count) == 1 ? rawValue : rawValue + "s"
    }

    /// Reads `d`, `day`, `days` and the rest of the spellings people type.
    ///
    /// A CLI takes whatever the caller wrote, and refusing `days` because the
    /// enum says `day` is a tool being difficult about its own vocabulary.
    public init?(loose text: String) {
        let word = text.trimmingCharacters(in: .whitespaces).lowercased()
        switch word {
        case "s", "sec", "secs", "second", "seconds": self = .second
        // `m` is minutes here and months nowhere, matching the duration
        // grammar. `mo` is months. Getting these the wrong way round is a
        // factor of 43,200.
        case "m", "min", "mins", "minute", "minutes": self = .minute
        case "h", "hr", "hrs", "hour", "hours": self = .hour
        case "d", "day", "days": self = .day
        case "w", "wk", "wks", "week", "weeks": self = .week
        case "mo", "mon", "mons", "month", "months": self = .month
        case "q", "qtr", "quarter", "quarters": self = .quarter
        case "y", "yr", "yrs", "year", "years": self = .year
        default: return nil
        }
    }
}

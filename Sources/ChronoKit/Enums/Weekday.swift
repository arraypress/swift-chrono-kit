//
//  Weekday.swift
//  ChronoKit
//

import Foundation

/// A day of the week, numbered the way Foundation numbers it: Sunday is 1.
///
/// Kept as Foundation's numbering rather than ISO's (Monday is 1) because
/// every `Calendar` call in this package speaks Foundation's, and a type
/// that silently renumbered would be a bug factory at each boundary. The
/// ISO position is one property away.
public enum Weekday: Int, CaseIterable, Sendable, Codable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    /// The two-letter code RFC 5545 uses: `MO`, `TU` … `SU`.
    public var rruleCode: String { WeekdayNames.code(for: self) }

    /// The English name, capitalised: `Monday`.
    public var name: String { WeekdayNames.name(for: self) }

    /// Monday is 1 and Sunday is 7, as ISO 8601 counts.
    public var isoNumber: Int { rawValue == 1 ? 7 : rawValue - 1 }

    /// Saturday or Sunday.
    public var isWeekend: Bool { self == .saturday || self == .sunday }

    /// A weekday from its RFC 5545 code, in either case.
    public init?(rruleCode: String) {
        guard let day = WeekdayNames.weekday(forCode: rruleCode) else { return nil }
        self = day
    }

    /// A weekday from an English name or its first three letters, in either case.
    public init?(name: String) {
        guard let day = WeekdayNames.weekday(forName: name) else { return nil }
        self = day
    }
}

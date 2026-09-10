//
//  WeekdayNames.swift
//  ChronoKit
//
//  The words and codes for the days of the week, both ways.
//

import Foundation

/// The tables behind ``Weekday``.
enum WeekdayNames {

    private static let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let codes = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

    static func name(for day: Weekday) -> String { names[day.rawValue - 1] }

    static func code(for day: Weekday) -> String { codes[day.rawValue - 1] }

    static func weekday(forCode code: String) -> Weekday? {
        guard let index = codes.firstIndex(of: code.uppercased()) else { return nil }
        return Weekday(rawValue: index + 1)
    }

    /// Whole names and three-letter forms, case-insensitively: `friday`, `Fri`, `FRI`.
    static func weekday(forName text: String) -> Weekday? {
        let wanted = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard wanted.count >= 3 else { return nil }
        guard let index = names.firstIndex(where: { name in
            let lower = name.lowercased()
            return lower == wanted || lower.prefix(3) == wanted
        }) else { return nil }
        return Weekday(rawValue: index + 1)
    }
}

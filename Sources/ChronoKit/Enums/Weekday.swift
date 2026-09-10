//
//  Weekday.swift
//  ChronoKit
//

import Foundation

/// A day of the week, numbered the ISO way: Monday is 1, Sunday is 7.
///
/// Foundation numbers Sunday as 1, and half the bugs in schedule code are
/// somebody remembering the other convention. Naming the days sidesteps
/// both numbers; the ISO one is the `rawValue` because it is the one written
/// down in a standard.
public enum Weekday: Int, CaseIterable, Sendable, Codable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    /// Monday to Friday.
    public static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    /// Saturday and Sunday.
    public static let weekend: Set<Weekday> = [.saturday, .sunday]

    /// The number Foundation's `.weekday` component uses: Sunday 1 … Saturday 7.
    public var foundationWeekday: Int { self == .sunday ? 1 : rawValue + 1 }

    /// The day for a Foundation `.weekday` value.
    public init?(foundationWeekday: Int) {
        switch foundationWeekday {
        case 1: self = .sunday
        case 2...7: self = Weekday(rawValue: foundationWeekday - 1)!
        default: return nil
        }
    }

    /// `Monday`.
    public var name: String { String(describing: self).prefix(1).uppercased() + String(describing: self).dropFirst() }
}

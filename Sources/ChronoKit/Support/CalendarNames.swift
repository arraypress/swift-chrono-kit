//
//  CalendarNames.swift
//  ChronoKit
//
//  Month, era and animal names for a date in another calendar.
//

import Foundation

/// Month and era names from the calendar's own formatter, in English.
enum CalendarNames {

    /// The twelve animals, in cycle order from the year of the Rat.
    static let animals = ["Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake", "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig"]

    static func monthName(for date: CalendarDate) -> String {
        formatted(date, pattern: "MMMM")
    }

    /// The short form — `AD`, `AH`, `AM`, `BE`, `AP` — because the long one
    /// is "Anno Hegirae" and nobody writes that on a date. Japanese eras have
    /// no short form and come back whole: `Reiwa`.
    static func eraName(for date: CalendarDate) -> String {
        formatted(date, pattern: "G")
    }

    /// The Chinese sexagenary cycle starts at Jia-Zi, the year of the Rat, so
    /// the animal is the year's position in the cycle, taken twelve at a time.
    static func zodiacAnimal(for date: CalendarDate) -> String? {
        guard date.system == .chinese, date.year >= 1 else { return nil }
        return animals[(date.year - 1) % 12]
    }

    static func described(_ date: CalendarDate) -> String {
        switch date.system {
        case .gregorian:
            return "\(date.day) \(monthName(for: date)) \(date.year)"
        case .japanese:
            return "\(eraName(for: date)) \(date.year), \(date.day) \(monthName(for: date))"
        case .chinese:
            let leap = date.isLeapMonth ? "leap " : ""
            return "cycle \(date.era) year \(date.year), \(leap)month \(date.month) day \(date.day)"
        default:
            return "\(date.day) \(monthName(for: date)) \(date.year) \(eraName(for: date))"
        }
    }

    /// Renders one field of the date through the calendar's own formatter.
    ///
    /// The date is rebuilt from its components rather than carried, so a name
    /// can be asked for a date that was typed and never converted; an
    /// impossible one falls back to the number.
    private static func formatted(_ date: CalendarDate, pattern: String) -> String {
        let calendar = CalendarSystems.calendar(for: date.system)
        var components = DateComponents(era: date.era, year: date.year, month: date.month, day: date.day)
        components.isLeapMonth = date.isLeapMonth
        guard let moment = calendar.date(from: components) else {
            return pattern == "MMMM" ? "\(date.month)" : "\(date.era)"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = Chrono.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: moment)
    }
}

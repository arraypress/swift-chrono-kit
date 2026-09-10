//
//  CalendarDate+Names.swift
//  ChronoKit
//

import Foundation

extension CalendarDate {

    /// The month's name in the calendar: `Muharram`, `Tishri`, `Farvardin`.
    public var monthName: String { CalendarNames.monthName(for: self) }

    /// The era's name: `AH`, `AM`, `BE`, `Reiwa`; `AD` for the Gregorian calendar.
    public var eraName: String { CalendarNames.eraName(for: self) }

    /// The animal of a Chinese year — `Horse` for 2026 — and nil for every other calendar.
    public var zodiacAnimal: String? { CalendarNames.zodiacAnimal(for: self) }

    /// `1 Muharram 1447 AH`, `Reiwa 8, 1 January`.
    public var described: String { CalendarNames.described(self) }
}

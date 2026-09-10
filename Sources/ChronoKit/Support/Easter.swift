//
//  Easter.swift
//  ChronoKit
//
//  The date of Easter Sunday, by the Anonymous Gregorian algorithm.
//

import Foundation

/// The computus.
enum Easter {

    /// The Gregorian calendar began in 1582; Easter by these rules before that
    /// is a different church's answer.
    static let firstYear = 1583

    /// The month and day of Easter Sunday in a Gregorian year.
    ///
    /// The "Anonymous Gregorian" algorithm (Meeus, *Astronomical Algorithms*,
    /// ch. 8), which is exact for every Gregorian year — the same arithmetic
    /// gov.uk's Good Friday and Easter Monday fall out of.
    static func monthAndDay(year: Int) -> (month: Int, day: Int) {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return (month, day)
    }
}

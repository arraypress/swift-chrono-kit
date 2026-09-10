//
//  ClockTime+Hours.swift
//  ChronoKit
//

import Foundation

extension ClockTime {

    /// `09:00`, the usual opening.
    static let nine = ClockTime(hour: 9, minute: 0, unchecked: ())

    /// `17:00`, the usual closing.
    static let seventeen = ClockTime(hour: 17, minute: 0, unchecked: ())

    /// A time known to be valid, for the presets.
    init(hour: Int, minute: Int, unchecked: Void) {
        self.hour = hour
        self.minute = minute
    }
}

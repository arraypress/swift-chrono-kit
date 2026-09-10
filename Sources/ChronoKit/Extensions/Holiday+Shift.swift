//
//  Holiday+Shift.swift
//  ChronoKit
//

import Foundation

extension Holiday {

    /// Whether the day taken is not the nominal day — a substitute or observed day.
    public var isObservedShift: Bool { date != observedDate }
}

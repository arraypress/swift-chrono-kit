//
//  TimeOfDay+Boundaries.swift
//  ChronoKit
//
//  Where one part of the day hands over to the next.
//

import Foundation

extension TimeOfDay {

    /// The hours at which each part of the day begins.
    ///
    /// Night is whatever is left: from `night` up to midnight and from
    /// midnight up to `morning`. The defaults are the common convention —
    /// morning from 5, afternoon from noon, evening from 5 pm, night from 9 pm
    /// — and they are a starting point, not a fact. Construct your own for a
    /// schedule that runs on different hours.
    public struct Boundaries: Sendable, Hashable, Codable {

        /// The hour (0–23) morning begins.
        public let morning: Int

        /// The hour (0–23) afternoon begins.
        public let afternoon: Int

        /// The hour (0–23) evening begins.
        public let evening: Int

        /// The hour (0–23) night begins.
        public let night: Int

        /// Morning at 5, afternoon at 12, evening at 17, night at 21.
        public static let `default` = Boundaries(morning: 5, afternoon: 12, evening: 17, night: 21, unchecked: ())

        /// Custom hours, which must rise in order and sit within a day.
        ///
        /// - Throws: ``ChronoError/badBoundaries(_:)`` when an hour is outside
        ///   0–23 or the four do not increase in order, because a boundary set
        ///   that doubles back has no single answer for some hours.
        public init(morning: Int, afternoon: Int, evening: Int, night: Int) throws {
            try DayParts.validate(morning: morning, afternoon: afternoon, evening: evening, night: night)
            self.init(morning: morning, afternoon: afternoon, evening: evening, night: night, unchecked: ())
        }

        init(morning: Int, afternoon: Int, evening: Int, night: Int, unchecked: Void) {
            self.morning = morning
            self.afternoon = afternoon
            self.evening = evening
            self.night = night
        }
    }
}

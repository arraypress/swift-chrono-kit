//
//  Holiday.swift
//  ChronoKit
//

import Foundation

/// One public holiday: the day it is, and the day it is taken.
///
/// The two differ when the holiday falls on a weekend. A US federal holiday
/// on a Saturday is observed the Friday before; a UK bank holiday on a
/// Saturday moves to the following Monday. Both dates are the start of their
/// day in ``Chrono/timeZone``.
public struct Holiday: Sendable, Hashable, Codable {

    /// The holiday's name as its government lists it: `Boxing Day`, `Labor Day`.
    public let name: String

    /// The nominal day — 25 December, whatever weekday that is.
    public let date: Date

    /// The day the holiday is actually taken.
    public let observedDate: Date

    /// Whose holiday it is.
    public let region: HolidayRegion

    /// A holiday with the day it is and the day it is taken.
    public init(name: String, date: Date, observedDate: Date, region: HolidayRegion) {
        self.name = name
        self.date = date
        self.observedDate = observedDate
        self.region = region
    }
}

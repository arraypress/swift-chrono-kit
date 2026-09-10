//
//  Instant.swift
//  ChronoKit
//

import Foundation

/// One moment, described every way something downstream might need it.
///
/// A parse verb that returned only an ISO string would send the caller
/// straight back to `date` for the epoch, and to a second tool for the week
/// number. The whole point is to answer once.
public struct Instant: Sendable, Hashable, Codable {

    /// ISO 8601 with the offset, e.g. `2026-09-03T14:30:00+01:00`.
    public let iso: String

    /// The same instant in UTC, e.g. `2026-09-03T13:30:00Z`.
    public let utc: String

    /// Seconds since 1970. Whole — sub-second precision is noise here.
    public let epoch: Int

    /// The date part alone, `2026-09-03`.
    public let date: String

    /// The wall-clock time alone, `14:30:00`.
    public let time: String

    /// The IANA zone this was resolved in.
    public let zone: String

    /// The zone's offset from UTC at this instant, `+01:00`.
    ///
    /// At this instant, not in general: the offset of `Europe/London` is
    /// +00:00 in January and +01:00 in July, and a tool that reports the zone
    /// without the offset has not answered the question.
    public let offset: String

    /// `Thursday`.
    public let weekday: String

    /// Day of the year, 1–366.
    public let dayOfYear: Int

    /// ISO week number, 1–53.
    public let isoWeek: Int

    /// The year that ISO week belongs to.
    ///
    /// Not always the calendar year: 1 January 2027 is in ISO week 53 of
    /// **2026**. Reporting week 53 next to year 2027 is a real off-by-a-year
    /// that shows up in weekly reporting every January.
    public let isoWeekYear: Int

    /// Quarter of the year, 1–4.
    public let quarter: Int

    /// Whether the zone is observing daylight saving at this instant.
    public let isDST: Bool

    /// Whether this falls on a Saturday or Sunday.
    public let isWeekend: Bool

    /// Which part of the day it is by the clock: `morning`, `afternoon`,
    /// `evening` or `night`, at the default ``TimeOfDay/Boundaries``.
    public let timeOfDay: TimeOfDay
}

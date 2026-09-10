//
//  RuleValidation.swift
//  ChronoKit
//
//  The checks on a rule's parts, on the way in.
//

import Foundation

/// What makes a set of RRULE parts usable together.
enum RuleValidation {

    static func check(
        frequency: RecurrenceFrequency, interval: Int, byDay: [WeekdayRule], byMonthDay: [Int],
        byMonth: [Int], bySetPos: [Int], count: Int?, businessDayOrdinal: Int?
    ) throws {
        guard interval >= 1 else { throw RecurrenceError.badRule("interval \(interval); it must be 1 or more") }
        if let count, count < 1 { throw RecurrenceError.badRule("count \(count); it must be 1 or more") }
        for month in byMonth where !(1...12).contains(month) {
            throw RecurrenceError.badRule("month \(month); months run 1–12")
        }
        for day in byMonthDay where day == 0 || abs(day) > 31 {
            throw RecurrenceError.badRule("month day \(day); use 1–31 or -1 to -31 counted from the end")
        }
        for position in bySetPos where position == 0 || abs(position) > 366 {
            throw RecurrenceError.badRule("set position \(position); use 1 or more, or -1 and below from the end")
        }
        for rule in byDay {
            if let ordinal = rule.ordinal {
                guard ordinal != 0, abs(ordinal) <= 53 else {
                    throw RecurrenceError.badRule("weekday ordinal \(ordinal); use 1–53 or -1 to -53")
                }
                guard frequency == .monthly || frequency == .yearly else {
                    throw RecurrenceError.badRule("an ordinal weekday like 2TU needs a monthly or yearly rule")
                }
            }
        }
        if frequency == .weekly, !byMonthDay.isEmpty {
            throw RecurrenceError.badRule("month days in a weekly rule; RFC 5545 forbids the combination")
        }
        if let businessDayOrdinal {
            guard businessDayOrdinal != 0, abs(businessDayOrdinal) <= 23 else {
                throw RecurrenceError.badRule("working-day ordinal \(businessDayOrdinal); use 1–23 or -1 to -23")
            }
            guard frequency != .daily, frequency != .weekly else {
                throw RecurrenceError.badRule("a working-day ordinal needs a monthly, quarterly or yearly rule")
            }
            guard byDay.isEmpty, byMonthDay.isEmpty, bySetPos.isEmpty else {
                throw RecurrenceError.badRule("a working-day ordinal stands alone; drop BYDAY, BYMONTHDAY and BYSETPOS")
            }
        }
        if frequency == .quarterly, businessDayOrdinal == nil, byMonthDay.isEmpty, byDay.isEmpty {
            throw RecurrenceError.badRule("a quarterly rule needs a working-day ordinal, month days or weekdays to pick within the quarter")
        }
    }
}

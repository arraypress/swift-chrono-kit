//
//  Recurrence.swift
//  ChronoKit
//
//  The occurrences of a rule from a start date.
//

import Foundation

extension Chrono {

    /// The first `limit` occurrences of a rule, from `start`, in order.
    ///
    /// `start` is the RFC's `DTSTART`: it fixes the wall-clock time every
    /// occurrence keeps — 09:00 stays 09:00 across a clock change — and the
    /// day the pattern is anchored to when the rule does not say ("every
    /// month" from the 15th is the 15th). Occurrences before it are not
    /// occurrences. A rule with `COUNT` or `UNTIL` stops there; one without
    /// stops at `limit`, so a forever rule cannot ask for forever.
    ///
    /// Exceptions are left out and additions merged in, by calendar day.
    /// `holidays` feed the working-day rules only; pass ``Holidays/set(_:)``.
    public static func occurrences(
        of rule: RecurrenceRule, from start: Date, limit: Int = 100, holidays: Set<Date> = []
    ) -> [Date] {
        guard limit > 0 else { return [] }
        var result: [Date] = []
        RecurrenceEngine.enumerateSet(rule, from: start, holidays: holidays) { date in
            result.append(date)
            return result.count < limit
        }
        return result
    }

    /// The first occurrence strictly after `after`, or nil when the rule has ended.
    public static func nextOccurrence(
        of rule: RecurrenceRule, from start: Date, after: Date, holidays: Set<Date> = []
    ) -> Date? {
        var found: Date?
        RecurrenceEngine.enumerateSet(rule, from: start, holidays: holidays) { date in
            if date > after { found = date; return false }
            return true
        }
        return found
    }

    /// Whether `date`'s calendar day carries an occurrence of the rule.
    ///
    /// By day, not by instant: the question is "is today one of the days",
    /// and today at 14:30 is not the 09:00 the rule generates.
    public static func isOccurrence(
        _ date: Date, of rule: RecurrenceRule, from start: Date, holidays: Set<Date> = []
    ) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
        var found = false
        RecurrenceEngine.enumerateSet(rule, from: start, holidays: holidays) { occurrence in
            if occurrence >= dayEnd { return false }
            if occurrence >= day { found = true; return false }
            return true
        }
        return found
    }
}

//
//  RecurrenceEngine.swift
//  ChronoKit
//
//  Walking a rule's periods and picking the days in each — the expansion
//  and limitation rules of RFC 5545 §3.3.10, for the parts kept.
//

import Foundation

/// The occurrence generator.
///
/// Every period — a day, a week, a month, a quarter, a year — yields its
/// candidate days from the rule's parts, `BYSETPOS` picks among them, the
/// start's wall-clock time is put back on each, and the walk stops at
/// `COUNT`, at `UNTIL`, when the visitor says so, or at a scan budget so a
/// rule that never matches (the 30th of February) cannot spin forever.
enum RecurrenceEngine {

    /// How many periods a walk may examine before giving up on a rule that
    /// yields nothing. Ten thousand days is 27 years; ten thousand months
    /// is a millennium.
    static let scanBudget = 10_000

    /// Calls `visit` with each occurrence of the whole set — the rule's
    /// instances with the exceptions taken out and the additions merged in —
    /// in order, until it returns false.
    ///
    /// `COUNT` counts the rule's own instances, as the RFC says, before an
    /// exception removes one; an addition never counts towards it and may
    /// fall after `UNTIL`. Exceptions match by calendar day; an addition on
    /// a day the rule already produces is dropped rather than doubled.
    static func enumerateSet(
        _ rule: RecurrenceRule, from start: Date, holidays: Set<Date>, visit: (Date) -> Bool
    ) {
        let calendar = Chrono.calendar
        let exceptionDays = Set(rule.exceptions.map { calendar.startOfDay(for: $0) })
        let time = calendar.dateComponents([.hour, .minute, .second], from: start)
        let additions = rule.additions.map { added -> Date in
            // A bare day takes the start's time of day.
            let parts = calendar.dateComponents([.hour, .minute, .second], from: added)
            if parts.hour == 0, parts.minute == 0, parts.second == 0 {
                return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: added) ?? added
            }
            return added
        }.filter { $0 >= start && !exceptionDays.contains(calendar.startOfDay(for: $0)) }.sorted()

        var pending = additions[...]
        var lastDay: Date?
        var stopped = false

        func emit(_ date: Date) -> Bool {
            let day = calendar.startOfDay(for: date)
            if let lastDay, day == lastDay { return true }
            lastDay = day
            return visit(date)
        }

        enumerate(rule, from: start, holidays: holidays) { instance in
            while let next = pending.first, next < instance {
                pending.removeFirst()
                if !emit(next) { stopped = true; return false }
            }
            if exceptionDays.contains(calendar.startOfDay(for: instance)) { return true }
            if !emit(instance) { stopped = true; return false }
            return true
        }
        guard !stopped else { return }
        for next in pending where !emit(next) { return }
    }

    /// Calls `visit` with each instance of the rule alone, in order, until it returns false.
    static func enumerate(
        _ rule: RecurrenceRule, from start: Date, holidays: Set<Date>, visit: (Date) -> Bool
    ) {
        let calendar = Chrono.calendar
        let startDay = calendar.startOfDay(for: start)
        let time = calendar.dateComponents([.hour, .minute, .second], from: start)
        let startDayOfMonth = calendar.component(.day, from: start)
        let startMonth = calendar.component(.month, from: start)
        let startWeekday = MonthDays.weekday(of: start)

        var produced = 0
        var periodStart = firstPeriodStart(for: rule, startDay: startDay)
        var scanned = 0

        while scanned < scanBudget {
            scanned += 1
            if let until = rule.until, periodStart > until { return }

            let days = candidates(
                in: periodStart, rule: rule, holidays: holidays,
                startDayOfMonth: startDayOfMonth, startMonth: startMonth, startWeekday: startWeekday
            )
            for day in days {
                guard let moment = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0,
                                                 second: time.second ?? 0, of: day) else { continue }
                guard moment >= start else { continue }
                if let until = rule.until, moment > until { return }
                produced += 1
                guard visit(moment) else { return }
                if let count = rule.count, produced >= count { return }
            }

            guard let next = nextPeriodStart(after: periodStart, rule: rule) else { return }
            periodStart = next
        }
    }

    // MARK: Periods

    /// The start of the period that contains the start date.
    static func firstPeriodStart(for rule: RecurrenceRule, startDay: Date) -> Date {
        let calendar = Chrono.calendar
        switch rule.frequency {
        case .daily:
            return startDay
        case .weekly:
            let offset = (MonthDays.weekday(of: startDay).isoNumber - rule.weekStart.isoNumber + 7) % 7
            return calendar.date(byAdding: .day, value: -offset, to: startDay) ?? startDay
        case .monthly:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: startDay)) ?? startDay
        case .quarterly:
            let month = calendar.component(.month, from: startDay)
            let year = calendar.component(.year, from: startDay)
            return MonthDays.date(year: year, month: ((month - 1) / 3) * 3 + 1, day: 1) ?? startDay
        case .yearly:
            return calendar.date(from: calendar.dateComponents([.year], from: startDay)) ?? startDay
        }
    }

    /// The start of the next period the rule visits.
    static func nextPeriodStart(after periodStart: Date, rule: RecurrenceRule) -> Date? {
        let calendar = Chrono.calendar
        switch rule.frequency {
        case .daily: return calendar.date(byAdding: .day, value: rule.interval, to: periodStart)
        case .weekly: return calendar.date(byAdding: .day, value: 7 * rule.interval, to: periodStart)
        case .monthly: return calendar.date(byAdding: .month, value: rule.interval, to: periodStart)
        case .quarterly: return calendar.date(byAdding: .month, value: 3 * rule.interval, to: periodStart)
        case .yearly: return calendar.date(byAdding: .year, value: rule.interval, to: periodStart)
        }
    }

    // MARK: Candidates

    /// The days in one period that the rule names, in order, after `BYSETPOS`.
    static func candidates(
        in periodStart: Date, rule: RecurrenceRule, holidays: Set<Date>,
        startDayOfMonth: Int, startMonth: Int, startWeekday: Weekday
    ) -> [Date] {
        let calendar = Chrono.calendar
        let year = calendar.component(.year, from: periodStart)
        let month = calendar.component(.month, from: periodStart)
        var days: [Date]

        switch rule.frequency {
        case .daily:
            days = [periodStart].filter { passesLimits($0, rule: rule) }

        case .weekly:
            let week = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: periodStart) }
            let wanted = rule.byDay.isEmpty ? [startWeekday] : rule.byDay.map(\.weekday)
            days = week.filter { wanted.contains(MonthDays.weekday(of: $0)) && passesMonth($0, rule: rule) }

        case .monthly:
            if let ordinal = rule.businessDayOrdinal {
                days = [businessDay(ordinal, in: monthDays(year: year, month: month), holidays: holidays)].compactMap { $0 }
            } else {
                days = monthCandidates(year: year, month: month, rule: rule, startDayOfMonth: startDayOfMonth)
            }
            days = days.filter { passesMonth($0, rule: rule) }

        case .quarterly:
            let months = (month...(month + 2))
            let quarterDays = months.flatMap { monthDays(year: year, month: $0) }
            if let ordinal = rule.businessDayOrdinal {
                days = [businessDay(ordinal, in: quarterDays, holidays: holidays)].compactMap { $0 }
            } else {
                days = quarterDays.filter { passesLimits($0, rule: rule) }
            }

        case .yearly:
            if let ordinal = rule.businessDayOrdinal {
                let yearDays = (1...12).flatMap { monthDays(year: year, month: $0) }
                days = [businessDay(ordinal, in: yearDays, holidays: holidays)].compactMap { $0 }
            } else {
                days = yearCandidates(year: year, rule: rule, startDayOfMonth: startDayOfMonth, startMonth: startMonth)
            }
        }

        let sorted = Array(Set(days)).sorted()
        guard !rule.bySetPos.isEmpty else { return sorted }
        return rule.bySetPos.compactMap { MonthDays.pick($0, from: sorted) }.sorted()
    }

    /// Monthly expansion: month days, else weekday rules, else the start's day.
    private static func monthCandidates(year: Int, month: Int, rule: RecurrenceRule, startDayOfMonth: Int) -> [Date] {
        if !rule.byMonthDay.isEmpty {
            let days = rule.byMonthDay.compactMap { MonthDays.date(year: year, month: month, dayFromEitherEnd: $0) }
            return rule.byDay.isEmpty ? days : days.filter { passesWeekdayRules($0, rule.byDay, year: year, month: month) }
        }
        if !rule.byDay.isEmpty {
            return rule.byDay.flatMap { entry -> [Date] in
                if let ordinal = entry.ordinal {
                    return [MonthDays.nth(ordinal, entry.weekday, year: year, month: month)].compactMap { $0 }
                }
                return MonthDays.dates(year: year, month: month, on: entry.weekday)
            }
        }
        return [MonthDays.date(year: year, month: month, day: startDayOfMonth)].compactMap { $0 }
    }

    /// Yearly expansion: months, then month days or weekday rules within them,
    /// or weekday ordinals over the whole year when no month is named.
    private static func yearCandidates(year: Int, rule: RecurrenceRule, startDayOfMonth: Int, startMonth: Int) -> [Date] {
        if !rule.byMonthDay.isEmpty {
            let months = rule.byMonth.isEmpty ? Array(1...12) : rule.byMonth
            return months.flatMap { month -> [Date] in
                let days = rule.byMonthDay.compactMap { MonthDays.date(year: year, month: month, dayFromEitherEnd: $0) }
                return rule.byDay.isEmpty ? days : days.filter { passesWeekdayRules($0, rule.byDay, year: year, month: month) }
            }
        }
        if !rule.byDay.isEmpty {
            if rule.byMonth.isEmpty {
                return rule.byDay.flatMap { entry -> [Date] in
                    if let ordinal = entry.ordinal {
                        return [MonthDays.nth(ordinal, entry.weekday, year: year)].compactMap { $0 }
                    }
                    return MonthDays.dates(year: year, on: entry.weekday)
                }
            }
            return rule.byMonth.flatMap { month in
                rule.byDay.flatMap { entry -> [Date] in
                    if let ordinal = entry.ordinal {
                        return [MonthDays.nth(ordinal, entry.weekday, year: year, month: month)].compactMap { $0 }
                    }
                    return MonthDays.dates(year: year, month: month, on: entry.weekday)
                }
            }
        }
        let months = rule.byMonth.isEmpty ? [startMonth] : rule.byMonth
        return months.compactMap { MonthDays.date(year: year, month: $0, day: startDayOfMonth) }
    }

    // MARK: Limits

    /// Daily rules and quarters only limit: month, month day, weekday.
    private static func passesLimits(_ day: Date, rule: RecurrenceRule) -> Bool {
        let calendar = Chrono.calendar
        guard passesMonth(day, rule: rule) else { return false }
        if !rule.byMonthDay.isEmpty {
            let year = calendar.component(.year, from: day), month = calendar.component(.month, from: day)
            let matches = rule.byMonthDay.contains { MonthDays.date(year: year, month: month, dayFromEitherEnd: $0) == day }
            guard matches else { return false }
        }
        if !rule.byDay.isEmpty {
            guard rule.byDay.contains(where: { $0.weekday == MonthDays.weekday(of: day) }) else { return false }
        }
        return true
    }

    private static func passesMonth(_ day: Date, rule: RecurrenceRule) -> Bool {
        rule.byMonth.isEmpty || rule.byMonth.contains(Chrono.calendar.component(.month, from: day))
    }

    /// Whether a day satisfies any weekday rule: the weekday, and the ordinal if one is given.
    private static func passesWeekdayRules(_ day: Date, _ rules: [WeekdayRule], year: Int, month: Int) -> Bool {
        rules.contains { entry in
            guard entry.weekday == MonthDays.weekday(of: day) else { return false }
            guard let ordinal = entry.ordinal else { return true }
            return MonthDays.nth(ordinal, entry.weekday, year: year, month: month) == day
        }
    }

    // MARK: Working days

    /// Every day of a month, first to last.
    private static func monthDays(year: Int, month: Int) -> [Date] {
        (1...MonthDays.count(year: year, month: month)).compactMap { MonthDays.date(year: year, month: month, day: $0) }
    }

    /// The nth working day among `days`, from either end.
    private static func businessDay(_ ordinal: Int, in days: [Date], holidays: Set<Date>) -> Date? {
        MonthDays.pick(ordinal, from: days.filter { Chrono.isBusinessDay($0, holidays: holidays) })
    }
}

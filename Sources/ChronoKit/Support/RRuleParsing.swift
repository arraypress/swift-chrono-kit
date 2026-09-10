//
//  RRuleParsing.swift
//  ChronoKit
//
//  RFC 5545's RRULE text, both ways.
//

import Foundation

/// Reading and writing `FREQ=MONTHLY;BYDAY=2TU;COUNT=6`.
enum RRuleParsing {

    /// The parts this package refuses, named so the error can say which.
    static let unsupported: Set<String> = ["BYHOUR", "BYMINUTE", "BYSECOND", "BYWEEKNO", "BYYEARDAY"]

    /// Whether text looks like an RRULE rather than a phrase.
    static func looksLikeRRule(_ text: String) -> Bool {
        text.uppercased().contains("FREQ=")
    }

    /// A rule from a block of iCalendar lines: `RRULE:`, any number of
    /// `EXDATE` and `RDATE` lines, and a `DTSTART` that is ignored (the
    /// start is passed beside the rule). A single-line RRULE, with or
    /// without its `RRULE:` prefix, is the one-line case of the same thing.
    ///
    /// `EXDATE` and `RDATE` values are comma-separated and may carry
    /// `;VALUE=DATE` and `;TZID=…` parameters: `20261225` is a day,
    /// `20261225T090000` a local time in the `TZID` zone or ``Chrono/timeZone``,
    /// and `20261225T090000Z` an instant. Exceptions are kept as days;
    /// additions keep their time.
    static func parseBlock(_ text: String) throws -> RecurrenceRule {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var ruleText: String?
        var exceptions: Set<Date> = []
        var additions: Set<Date> = []
        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix("RRULE") || upper.hasPrefix("FREQ=") {
                guard ruleText == nil else { throw RecurrenceError.badRule("two RRULE lines; a rule has one") }
                ruleText = line
            } else if upper.hasPrefix("EXDATE") {
                exceptions.formUnion(try dateValues(line, asDays: true))
            } else if upper.hasPrefix("RDATE") {
                additions.formUnion(try dateValues(line, asDays: false))
            } else if upper.hasPrefix("DTSTART") || upper.hasPrefix("BEGIN:") || upper.hasPrefix("END:") {
                continue
            } else {
                throw RecurrenceError.badRule("\(line) is not an RRULE, EXDATE or RDATE line")
            }
        }
        guard let ruleText else { throw RecurrenceError.badRule("no RRULE line") }
        let rule = try parse(ruleText)
        return try RecurrenceRule(
            frequency: rule.frequency, interval: rule.interval, byDay: rule.byDay, byMonthDay: rule.byMonthDay,
            byMonth: rule.byMonth, bySetPos: rule.bySetPos, count: rule.count, until: rule.until,
            weekStart: rule.weekStart, businessDayOrdinal: rule.businessDayOrdinal,
            exceptions: exceptions, additions: additions
        )
    }

    /// The dates on an `EXDATE` or `RDATE` line, honouring `TZID` and `VALUE=DATE`.
    static func dateValues(_ line: String, asDays: Bool) throws -> [Date] {
        guard let colon = line.firstIndex(of: ":") else { throw RecurrenceError.badRule("\(line) has no value") }
        // Parameter names are case-insensitive; a zone identifier is not.
        let params = line[..<colon].split(separator: ";").dropFirst().map(String.init)
        var zone = Chrono.timeZone
        for param in params {
            if param.uppercased().hasPrefix("TZID=") {
                let identifier = String(param.dropFirst(5))
                guard let found = TimeZone(identifier: identifier) else { throw RecurrenceError.badRule("TZID=\(identifier) is not a zone") }
                zone = found
            }
        }
        let values = line[line.index(after: colon)...].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return try values.map { value in
            let instant = try Chrono.inZone(zone) { try untilDate(value, endOfDay: false) }
            return asDays ? Chrono.calendar.startOfDay(for: instant) : instant
        }
    }

    /// A rule from RRULE text. An `RRULE:` prefix is tolerated; `DTSTART`
    /// is not part of the rule and is refused if it is glued on.
    static func parse(_ text: String) throws -> RecurrenceRule {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.uppercased().hasPrefix("RRULE:") { body = String(body.dropFirst(6)) }
        guard !body.isEmpty else { throw RecurrenceError.badPhrase(text) }

        var parts: [String: String] = [:]
        for pair in body.split(separator: ";") {
            let halves = pair.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard halves.count == 2 else { throw RecurrenceError.badRule("\(pair) is not NAME=VALUE") }
            let name = halves[0].uppercased()
            if unsupported.contains(name) { throw RecurrenceError.unsupported(name) }
            if name == "DTSTART" { throw RecurrenceError.badRule("DTSTART belongs beside the rule, not inside it — pass it as the start date") }
            parts[name] = halves[1]
        }

        guard let freqText = parts["FREQ"] else { throw RecurrenceError.badRule("no FREQ") }
        let freq = freqText.uppercased()
        if ["HOURLY", "MINUTELY", "SECONDLY"].contains(freq) { throw RecurrenceError.unsupported("FREQ=\(freq)") }
        guard let frequency = RecurrenceFrequency(rawValue: freq), frequency != .quarterly else {
            throw RecurrenceError.badRule("FREQ=\(freqText) is not DAILY, WEEKLY, MONTHLY or YEARLY")
        }

        func integers(_ name: String) throws -> [Int] {
            guard let value = parts[name] else { return [] }
            return try value.split(separator: ",").map {
                guard let number = Int($0.trimmingCharacters(in: .whitespaces)) else {
                    throw RecurrenceError.badRule("\(name)=\(value) is not a list of numbers")
                }
                return number
            }
        }

        let interval = try parts["INTERVAL"].map { text -> Int in
            guard let number = Int(text) else { throw RecurrenceError.badRule("INTERVAL=\(text) is not a number") }
            return number
        } ?? 1
        let count = try parts["COUNT"].map { text -> Int in
            guard let number = Int(text) else { throw RecurrenceError.badRule("COUNT=\(text) is not a number") }
            return number
        }
        let until = try parts["UNTIL"].map { try untilDate($0) }
        let byDay = try parts["BYDAY"].map { try weekdayRules($0) } ?? []
        let weekStart = try parts["WKST"].map { text -> Weekday in
            guard let day = Weekday(rruleCode: text) else { throw RecurrenceError.badRule("WKST=\(text) is not a weekday code") }
            return day
        } ?? .monday
        if count != nil, until != nil {
            throw RecurrenceError.badRule("both COUNT and UNTIL; the RFC allows one")
        }

        return try RecurrenceRule(
            frequency: frequency, interval: interval, byDay: byDay,
            byMonthDay: try integers("BYMONTHDAY"), byMonth: try integers("BYMONTH"),
            bySetPos: try integers("BYSETPOS"), count: count, until: until, weekStart: weekStart
        )
    }

    /// `2TU`, `-1FR`, `MO` — a list of them.
    static func weekdayRules(_ text: String) throws -> [WeekdayRule] {
        try text.split(separator: ",").map { entry in
            let item = entry.trimmingCharacters(in: .whitespaces).uppercased()
            guard let match = item.wholeMatch(of: #"^([+-]?\d{1,2})?([A-Z]{2})$"#),
                  let code = match[2], let weekday = Weekday(rruleCode: code) else {
                throw RecurrenceError.badRule("BYDAY entry \(item) is not like MO, 2TU or -1FR")
            }
            let ordinal = match[1].flatMap { Int($0.replacingOccurrences(of: "+", with: "")) }
            return WeekdayRule(ordinal: ordinal, weekday: weekday)
        }
    }

    /// `UNTIL` as the RFC writes it: `19971224T000000Z`, a local `19971224T090000`,
    /// or a bare date `19971224`. A local time is read in ``Chrono/timeZone``;
    /// a bare date means the end of that day, so an occurrence on it counts.
    static func untilDate(_ text: String, endOfDay: Bool = true) throws -> Date {
        let value = text.trimmingCharacters(in: .whitespaces)
        let calendar = Chrono.calendar
        if let match = value.wholeMatch(of: #"^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$"#) {
            var components = DateComponents()
            components.year = Int(match[1]!); components.month = Int(match[2]!); components.day = Int(match[3]!)
            if match[4] != nil {
                components.hour = Int(match[4]!); components.minute = Int(match[5]!); components.second = Int(match[6]!)
                var utc = calendar
                if match[7] != nil { utc.timeZone = TimeZone(identifier: "UTC")! }
                guard let date = utc.date(from: components) else { throw RecurrenceError.badRule("not a date: \(text)") }
                return date
            }
            if endOfDay { components.hour = 23; components.minute = 59; components.second = 59 }
            guard let date = calendar.date(from: components) else { throw RecurrenceError.badRule("not a date: \(text)") }
            return date
        }
        throw RecurrenceError.badRule("\(text) is not a date like 19971224T000000Z or 19971224")
    }

    /// The iCalendar lines for a rule: `RRULE:`, then `EXDATE;VALUE=DATE:` and
    /// `RDATE:` (UTC instants) when there are any. Nil when the rule itself
    /// has no RRULE spelling.
    static func icsLines(for rule: RecurrenceRule) -> [String]? {
        guard let rrule = string(for: rule) else { return nil }
        var lines = ["RRULE:" + rrule]
        if !rule.exceptions.isEmpty {
            let days = rule.exceptions.map { Chrono.describe($0).date.replacingOccurrences(of: "-", with: "") }.sorted()
            lines.append("EXDATE;VALUE=DATE:" + days.joined(separator: ","))
        }
        if !rule.additions.isEmpty {
            lines.append("RDATE:" + rule.additions.sorted().map(untilText).joined(separator: ","))
        }
        return lines
    }

    /// The RRULE text for a rule, or nil for a rule the RFC cannot spell.
    static func string(for rule: RecurrenceRule) -> String? {
        guard rule.frequency != .quarterly, rule.businessDayOrdinal == nil else { return nil }
        var parts = ["FREQ=\(rule.frequency.rawValue)"]
        if rule.interval != 1 { parts.append("INTERVAL=\(rule.interval)") }
        if !rule.byMonth.isEmpty { parts.append("BYMONTH=" + rule.byMonth.map(String.init).joined(separator: ",")) }
        if !rule.byMonthDay.isEmpty { parts.append("BYMONTHDAY=" + rule.byMonthDay.map(String.init).joined(separator: ",")) }
        if !rule.byDay.isEmpty {
            parts.append("BYDAY=" + rule.byDay.map { ($0.ordinal.map(String.init) ?? "") + $0.weekday.rruleCode }.joined(separator: ","))
        }
        if !rule.bySetPos.isEmpty { parts.append("BYSETPOS=" + rule.bySetPos.map(String.init).joined(separator: ",")) }
        if let count = rule.count { parts.append("COUNT=\(count)") }
        if let until = rule.until { parts.append("UNTIL=" + untilText(until)) }
        if rule.weekStart != .monday { parts.append("WKST=\(rule.weekStart.rruleCode)") }
        return parts.joined(separator: ";")
    }

    /// An instant as the RFC writes UNTIL: UTC, `19971224T000000Z`.
    static func untilText(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d%02d%02dT%02d%02d%02dZ", c.year!, c.month!, c.day!, c.hour!, c.minute!, c.second!)
    }
}

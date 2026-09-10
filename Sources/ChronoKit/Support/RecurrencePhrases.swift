//
//  RecurrencePhrases.swift
//  ChronoKit
//
//  Recurrence as people say it — "second tuesday of every month" — read,
//  and written back in a canonical form that reads to the same rule.
//

import Foundation

/// The English grammar for ``RecurrenceRule``.
///
/// Reads: `every day`, `every 3 days`, `every weekday`, `every week`,
/// `every 2 weeks on monday and wednesday`, `every monday`, `second tuesday
/// of every month`, `last friday of the month`, `first working day of the
/// month`, `last working day of the quarter`, `1st and 15th of every month`,
/// `last day of the month`, `every month on the 15th`, `every 3 months`,
/// `every year on 4 july`, `every july 4`, `every quarter`, the first
/// tuesday of november every year, and trailing `, 10 times`,
/// `, until 2026-12-31`, `, except 25 december` and `, plus 2026-01-02`. Case, "the", "each", "other",
/// "fortnightly", "daily", "monthly", "annually" and "business day" are all
/// folded before matching.
enum RecurrencePhrases {

    // MARK: Reading

    static func parse(_ text: String) throws -> RecurrenceRule {
        var phrase = normalise(text)
        guard !phrase.isEmpty else { throw RecurrenceError.badPhrase(text) }

        // The suffixes, in the order describe() writes them: ", 10 times",
        // ", until 2026-12-31", ", except 2026-12-25 and 2027-01-01", ", plus 2026-01-02".
        var count: Int?
        var until: Date?
        var exceptions: Set<Date> = []
        var additions: Set<Date> = []
        if let match = phrase.wholeMatch(of: #"^(.*?),? plus (.+)$"#) {
            additions = Set(try dateList(match[2]!, original: text))
            phrase = match[1]!
        }
        if let match = phrase.wholeMatch(of: #"^(.*?),? except (.+)$"#) {
            exceptions = Set(try dateList(match[2]!, original: text))
            phrase = match[1]!
        }
        if let match = phrase.wholeMatch(of: #"^(.*?),? until (\S+)$"#) {
            let day = Chrono.calendar.startOfDay(for: try Chrono.date(match[2]!))
            // A bare date as an end means the end of that day.
            until = Chrono.calendar.date(byAdding: .second, value: 86_399, to: day)
            phrase = match[1]!
        }
        if let match = phrase.wholeMatch(of: #"^(.*?)(?:,? for| ,|,)? (\d+) times?$"#), let n = Int(match[2]!) {
            count = n; phrase = match[1]!
        }
        phrase = phrase.trimmingCharacters(in: CharacterSet(charactersIn: " ,"))

        let rule = try body(phrase, original: text)
        return try RecurrenceRule(
            frequency: rule.frequency, interval: rule.interval, byDay: rule.byDay, byMonthDay: rule.byMonthDay,
            byMonth: rule.byMonth, bySetPos: rule.bySetPos, count: count, until: until,
            weekStart: rule.weekStart, businessDayOrdinal: rule.businessDayOrdinal,
            exceptions: exceptions, additions: additions
        )
    }

    /// "2026-12-25 and 2027-01-01", "25 december", "december 25 2026" — days,
    /// at their start. A month and day without a year mean the next such day
    /// from today, which is what "except christmas" means when somebody says it.
    static func dateList(_ text: String, original: String) throws -> [Date] {
        let parts = text.replacingOccurrences(of: " and ", with: ",").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let calendar = Chrono.calendar
        return try parts.map { part in
            if let iso = part.wholeMatch(of: #"^\d{4}-\d{2}-\d{2}$"#) {
                return calendar.startOfDay(for: try Chrono.date(iso[0]!))
            }
            if let m = part.wholeMatch(of: #"^(.+?) (\d{4})$"#), let year = Int(m[2]!),
               let (month, day) = try? monthAndDay(m[1]!, original: original),
               let date = MonthDays.date(year: year, month: month, day: day) {
                return date
            }
            if let (month, day) = try? monthAndDay(part, original: original) {
                return try Chrono.nextOccurrence(month: month, day: day, after: Date())
            }
            throw RecurrenceError.badPhrase(original)
        }
    }

    private static func body(_ phrase: String, original: String) throws -> RecurrenceRule {
        // every day / every 3 days
        if let m = phrase.wholeMatch(of: #"^every (?:(\d+) )?days?$"#) {
            return try RecurrenceRule(frequency: .daily, interval: Int(m[1] ?? "1") ?? 1)
        }
        // every weekday
        if phrase == "every weekday" {
            return try RecurrenceRule(frequency: .weekly, byDay: weekdays)
        }
        // every week / every 2 weeks on monday and wednesday
        if let m = phrase.wholeMatch(of: #"^every (?:(\d+) )?weeks?(?: on (.+))?$"#) {
            let days = try m[2].map { try dayList($0, original: original) } ?? []
            return try RecurrenceRule(frequency: .weekly, interval: Int(m[1] ?? "1") ?? 1, byDay: days)
        }
        // every monday / every monday and thursday / every 2 mondays? (no)
        if let m = phrase.wholeMatch(of: #"^every ((?:[a-z]+day|mon|tue|wed|thu|fri|sat|sun)(?:s)?(?:(?:,| and) (?:[a-z]+day|mon|tue|wed|thu|fri|sat|sun)s?)*)$"#),
           let days = try? dayList(m[1]!, original: original), !days.isEmpty {
            return try RecurrenceRule(frequency: .weekly, byDay: days)
        }
        // second tuesday of every month / last working day of the quarter / last day of the month / first day of every 2 years
        if let m = phrase.wholeMatch(of: #"^(first|second|third|fourth|fifth|last|second to last|second-to-last|penultimate|\d+(?:st|nd|rd|th)) (working day|day|[a-z]+day|mon|tue|wed|thu|fri|sat|sun) of (?:every|the) (?:(\d+) )?(month|quarter|year)s?$"#) {
            let ordinal = try ordinalNumber(m[1]!, original: original)
            let frequency: RecurrenceFrequency = m[4] == "month" ? .monthly : m[4] == "quarter" ? .quarterly : .yearly
            let interval = Int(m[3] ?? "1") ?? 1
            switch m[2]! {
            case "working day":
                return try RecurrenceRule(frequency: frequency, interval: interval, businessDayOrdinal: ordinal)
            case "day":
                guard frequency != .quarterly else { throw RecurrenceError.badPhrase(original) }
                if frequency == .yearly {
                    // "first day of the year" is 1 January; "last day of the year" 31 December.
                    return try RecurrenceRule(frequency: .yearly, interval: interval, byMonthDay: [ordinal > 0 ? ordinal : -1], byMonth: [ordinal > 0 ? 1 : 12])
                }
                return try RecurrenceRule(frequency: .monthly, interval: interval, byMonthDay: [ordinal])
            default:
                guard let weekday = Weekday(name: m[2]!) else { throw RecurrenceError.badPhrase(original) }
                if frequency == .quarterly {
                    // The nth weekday of a quarter has no RRULE; keep it as a quarterly pick.
                    return try RecurrenceRule(frequency: .quarterly, interval: interval, byDay: [WeekdayRule(weekday: weekday)], bySetPos: [ordinal])
                }
                return try RecurrenceRule(frequency: frequency, interval: interval, byDay: [WeekdayRule(ordinal: ordinal, weekday: weekday)])
            }
        }
        // 1st and 15th of every month / 15th of every 2 months
        if let m = phrase.wholeMatch(of: #"^(?:the )?(\d+(?:st|nd|rd|th)(?:(?:,| and) \d+(?:st|nd|rd|th))*) of (?:every|the) (?:(\d+) )?months?$"#) {
            return try RecurrenceRule(frequency: .monthly, interval: Int(m[2] ?? "1") ?? 1, byMonthDay: try dayNumbers(m[1]!, original: original))
        }
        // every month / every 3 months / every month on the 15th / every month on the 1st and 15th
        if let m = phrase.wholeMatch(of: #"^every (?:(\d+) )?months?(?: on (?:the )?(\d+(?:st|nd|rd|th)(?:(?:,| and) \d+(?:st|nd|rd|th))*))?$"#) {
            let days = try m[2].map { try dayNumbers($0, original: original) } ?? []
            return try RecurrenceRule(frequency: .monthly, interval: Int(m[1] ?? "1") ?? 1, byMonthDay: days)
        }
        // every quarter → every 3 months, anchored to the start
        if let m = phrase.wholeMatch(of: #"^every (?:(\d+) )?quarters?$"#) {
            return try RecurrenceRule(frequency: .monthly, interval: 3 * (Int(m[1] ?? "1") ?? 1))
        }
        // every year / every 2 years / every year on 4 july / every july 4 / every 4th of july
        if let m = phrase.wholeMatch(of: #"^every (?:(\d+) )?years?(?: on (.+))?$"#) {
            let interval = Int(m[1] ?? "1") ?? 1
            guard let dateText = m[2] else { return try RecurrenceRule(frequency: .yearly, interval: interval) }
            let (month, day) = try monthAndDay(dateText, original: original)
            return try RecurrenceRule(frequency: .yearly, interval: interval, byMonthDay: [day], byMonth: [month])
        }
        // the first tuesday of november every year / every 2 years
        if let m = phrase.wholeMatch(of: #"^(first|second|third|fourth|fifth|last|second to last|second-to-last|penultimate|\d+(?:st|nd|rd|th)) ([a-z]+day|mon|tue|wed|thu|fri|sat|sun) of ([a-z]+) every (?:(\d+) )?years?$"#),
           let weekday = Weekday(name: m[2]!), let month = monthNumber(m[3]!) {
            let ordinal = try ordinalNumber(m[1]!, original: original)
            return try RecurrenceRule(frequency: .yearly, interval: Int(m[4] ?? "1") ?? 1, byDay: [WeekdayRule(ordinal: ordinal, weekday: weekday)], byMonth: [month])
        }
        // The general form describe() falls back to:
        // every [N] month[s]|year[s] [in <months>] [on the <day numbers>] [on <weekdays with ordinals>] [, <positions> of those]
        if let m = phrase.wholeMatch(of: #"^every (?:(\d+) )?(month|year)s?(?: in ([a-z, ]+?))?(?: on the ((?:last|\d+(?:st|nd|rd|th)|\d+th from last)(?:(?:,| and) (?:last|\d+(?:st|nd|rd|th)|\d+th from last))*))?(?: on ((?:(?:first|second|third|fourth|fifth|last|second to last|\d+(?:st|nd|rd|th)) )?(?:[a-z]+day)(?:(?:,| and) (?:(?:first|second|third|fourth|fifth|last|second to last|\d+(?:st|nd|rd|th)) )?(?:[a-z]+day))*))?(?:, ((?:first|second|third|fourth|fifth|last|second to last|\d+(?:st|nd|rd|th)|\d+th from last)(?:(?:,| and) (?:first|second|third|fourth|fifth|last|second to last|\d+(?:st|nd|rd|th)|\d+th from last))*) of those)?$"#) {
            let frequency: RecurrenceFrequency = m[2] == "month" ? .monthly : .yearly
            let months = try m[3].map { try monthList($0, original: original) } ?? []
            let monthDays = try m[4].map { try signedDayNumbers($0, original: original) } ?? []
            let weekdays = try m[5].map { try weekdayRuleList($0, original: original) } ?? []
            let positions = try m[6].map { try signedDayNumbers($0, original: original) } ?? []
            return try RecurrenceRule(frequency: frequency, interval: Int(m[1] ?? "1") ?? 1, byDay: weekdays, byMonthDay: monthDays, byMonth: months, bySetPos: positions)
        }
        if let m = phrase.wholeMatch(of: #"^every (.+)$"#), let (month, day) = try? monthAndDay(m[1]!, original: original) {
            return try RecurrenceRule(frequency: .yearly, byMonthDay: [day], byMonth: [month])
        }
        throw RecurrenceError.badPhrase(original)
    }

    private static func monthNumber(_ word: String) -> Int? {
        monthNames.firstIndex { $0.lowercased() == word || ($0.lowercased().hasPrefix(word) && word.count >= 3) }.map { $0 + 1 }
    }

    /// "january and february", "march, june and september"
    private static func monthList(_ text: String, original: String) throws -> [Int] {
        try text.replacingOccurrences(of: " and ", with: ",").split(separator: ",").map { part in
            guard let month = monthNumber(part.trimmingCharacters(in: .whitespaces)) else { throw RecurrenceError.badPhrase(original) }
            return month
        }
    }

    /// "1st and 15th", "last", "3rd from last", "second to last"
    private static func signedDayNumbers(_ text: String, original: String) throws -> [Int] {
        try text.replacingOccurrences(of: " and ", with: ",").split(separator: ",").map { part in
            let word = part.trimmingCharacters(in: .whitespaces)
            if let known = ordinals[word] { return known }
            if let m = word.wholeMatch(of: #"^(\d+)th from last$"#), let n = Int(m[1]!) { return -n }
            if let m = word.wholeMatch(of: #"^(\d+)(?:st|nd|rd|th)$"#), let n = Int(m[1]!), n >= 1 { return n }
            throw RecurrenceError.badPhrase(original)
        }
    }

    /// "first monday, last friday and wednesday"
    private static func weekdayRuleList(_ text: String, original: String) throws -> [WeekdayRule] {
        try text.replacingOccurrences(of: " and ", with: ",").split(separator: ",").map { part in
            let words = part.trimmingCharacters(in: .whitespaces)
            if let m = words.wholeMatch(of: #"^(first|second|third|fourth|fifth|last|second to last|\d+(?:st|nd|rd|th)) ([a-z]+day)$"#),
               let weekday = Weekday(name: m[2]!) {
                return WeekdayRule(ordinal: try ordinalNumber(m[1]!, original: original), weekday: weekday)
            }
            guard let weekday = Weekday(name: words) else { throw RecurrenceError.badPhrase(original) }
            return WeekdayRule(weekday: weekday)
        }
    }

    // MARK: Writing

    /// The canonical phrase for a rule.
    static func describe(_ rule: RecurrenceRule) -> String {
        var text: String
        let every = rule.interval == 1 ? "every \(rule.frequency.unitName)" : "every \(rule.interval) \(rule.frequency.unitName)s"
        switch rule.frequency {
        case .daily:
            text = every
            if !rule.byDay.isEmpty { text += " on " + join(rule.byDay.map(\.weekday.name)) }
        case .weekly:
            if rule.interval == 1, Set(rule.byDay.map(\.weekday)) == Set(weekdays.map(\.weekday)), rule.byDay.count == 5 {
                text = "every weekday"
            } else if rule.interval == 1, !rule.byDay.isEmpty {
                text = "every " + join(rule.byDay.map(\.weekday.name))
            } else {
                text = every
                if !rule.byDay.isEmpty { text += " on " + join(rule.byDay.map(\.weekday.name)) }
            }
        case .monthly, .quarterly, .yearly:
            let period = rule.interval == 1 ? "every \(rule.frequency.unitName)" : "every \(rule.interval) \(rule.frequency.unitName)s"
            if let ordinal = rule.businessDayOrdinal {
                text = "the \(ordinalWord(ordinal)) working day of \(period)"
            } else if rule.frequency == .quarterly, rule.byDay.count == 1, rule.bySetPos.count == 1 {
                text = "the \(ordinalWord(rule.bySetPos[0])) \(rule.byDay[0].weekday.name) of \(period)"
            } else if rule.frequency == .yearly, rule.byMonth.count == 1, rule.byMonthDay.count == 1, rule.byDay.isEmpty, rule.bySetPos.isEmpty {
                let day = rule.byMonthDay[0]
                text = day == -1 ? "the last day of \(period)" : "\(period) on \(day) \(monthNames[rule.byMonth[0] - 1])"
            } else if rule.frequency == .yearly, rule.byMonth.count == 1, rule.byDay.count == 1, rule.byMonthDay.isEmpty, rule.bySetPos.isEmpty, let ordinal = rule.byDay[0].ordinal {
                text = "the \(ordinalWord(ordinal)) \(rule.byDay[0].weekday.name) of \(monthNames[rule.byMonth[0] - 1]) \(period)"
            } else if !rule.byDay.isEmpty, rule.byDay.allSatisfy({ $0.ordinal != nil }), rule.byMonth.isEmpty, rule.byMonthDay.isEmpty, rule.bySetPos.isEmpty {
                text = "the " + join(rule.byDay.map { "\(ordinalWord($0.ordinal!)) \($0.weekday.name)" }) + " of \(period)"
            } else if !rule.byMonthDay.isEmpty, rule.byDay.isEmpty, rule.byMonth.isEmpty, rule.bySetPos.isEmpty {
                if rule.byMonthDay == [-1] {
                    text = "the last day of \(period)"
                } else {
                    text = "the " + join(rule.byMonthDay.map(dayWord)) + " of \(period)"
                }
            } else {
                text = period
                if !rule.byMonth.isEmpty { text += " in " + join(rule.byMonth.map { monthNames[$0 - 1] }) }
                if !rule.byMonthDay.isEmpty { text += " on the " + join(rule.byMonthDay.map(dayWord)) }
                if !rule.byDay.isEmpty {
                    text += " on " + join(rule.byDay.map { ($0.ordinal.map { ordinalWord($0) + " " } ?? "") + $0.weekday.name })
                }
                if !rule.bySetPos.isEmpty { text += ", " + join(rule.bySetPos.map(ordinalWord)) + " of those" }
            }
        }
        if let count = rule.count { text += ", \(count) time\(count == 1 ? "" : "s")" }
        if let until = rule.until { text += ", until \(Chrono.describe(until).date)" }
        if !rule.exceptions.isEmpty {
            text += ", except " + join(rule.exceptions.map { Chrono.describe($0).date }.sorted())
        }
        if !rule.additions.isEmpty {
            text += ", plus " + join(rule.additions.map { Chrono.describe($0).date }.sorted())
        }
        return text
    }

    // MARK: Words

    static let weekdays: [WeekdayRule] = [.monday, .tuesday, .wednesday, .thursday, .friday].map { WeekdayRule(weekday: $0) }
    static let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private static let ordinals = ["first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5, "last": -1,
                                   "second to last": -2, "second-to-last": -2, "penultimate": -2]

    static func normalise(_ text: String) -> String {
        var s = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: #"[.!]+$"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "&", with: " and ")
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        for (from, to) in [("business days", "working day"), ("business day", "working day"), ("workdays", "working day"),
                           ("workday", "working day"), ("working days", "working day"), ("weekdays", "weekday"),
                           ("every other", "every 2"), ("fortnightly", "every 2 weeks"), ("biweekly", "every 2 weeks"),
                           ("daily", "every day"), ("weekly", "every week"), ("monthly", "every month"),
                           ("quarterly", "every quarter"), ("yearly", "every year"), ("annually", "every year"),
                           ("each", "every"), ("once a ", "every "), ("of every single", "of every")] {
            s = s.replacingOccurrences(of: from, with: to)
        }
        s = s.replacingOccurrences(of: #"^(?:on |the )+"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^every the "#, with: "every ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    private static func ordinalNumber(_ word: String, original: String) throws -> Int {
        if let known = ordinals[word] { return known }
        if let m = word.wholeMatch(of: #"^(\d+)(?:st|nd|rd|th)$"#), let n = Int(m[1]!), n >= 1 { return n }
        throw RecurrenceError.badPhrase(original)
    }

    /// "monday and wednesday", "mondays, wednesdays and fridays", "mon, wed"
    private static func dayList(_ text: String, original: String) throws -> [WeekdayRule] {
        let parts = text.replacingOccurrences(of: " and ", with: ",").split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"s$"#, with: "", options: .regularExpression)
        }
        return try parts.map { part in
            guard let day = Weekday(name: part) else { throw RecurrenceError.badPhrase(original) }
            return WeekdayRule(weekday: day)
        }
    }

    /// "1st and 15th", "1st, 15th and 28th"
    private static func dayNumbers(_ text: String, original: String) throws -> [Int] {
        let parts = text.replacingOccurrences(of: " and ", with: ",").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return try parts.map { part in
            guard let m = part.wholeMatch(of: #"^(\d+)(?:st|nd|rd|th)$"#), let n = Int(m[1]!), (1...31).contains(n) else {
                throw RecurrenceError.badPhrase(original)
            }
            return n
        }
    }

    /// "4 july", "july 4", "4th of july", "july 4th", "4/7"? (no — words only)
    private static func monthAndDay(_ text: String, original: String) throws -> (Int, Int) {
        let cleaned = text.replacingOccurrences(of: #"(\d+)(?:st|nd|rd|th)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: " of ", with: " ")
        let words = cleaned.split(separator: " ").map(String.init)
        guard words.count == 2 else { throw RecurrenceError.badPhrase(original) }
        func month(_ word: String) -> Int? {
            monthNames.firstIndex { $0.lowercased() == word || $0.lowercased().prefix(3) == word.prefix(3) && word.count >= 3 }.map { $0 + 1 }
        }
        if let day = Int(words[0]), let month = month(words[1]), (1...31).contains(day) { return (month, day) }
        if let month = month(words[0]), let day = Int(words[1]), (1...31).contains(day) { return (month, day) }
        throw RecurrenceError.badPhrase(original)
    }

    private static func join(_ words: [String]) -> String {
        switch words.count {
        case 0: return ""
        case 1: return words[0]
        default: return words.dropLast().joined(separator: ", ") + " and " + words.last!
        }
    }

    static func ordinalWord(_ n: Int) -> String {
        switch n {
        case 1: "first"
        case 2: "second"
        case 3: "third"
        case 4: "fourth"
        case 5: "fifth"
        case -1: "last"
        case -2: "second to last"
        default: n > 0 ? dayWord(n) : "\(-n)th from last"
        }
    }

    static func dayWord(_ n: Int) -> String {
        guard n > 0 else { return n == -1 ? "last" : "\(-n)th from last" }
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

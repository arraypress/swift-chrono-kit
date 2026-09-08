//
//  RangeParsing.swift
//  ChronoKit
//
//  Plain language in, a run of days out.
//
//  Every report page on the web has a from/to pair, and every one of them is
//  filled in by someone thinking "last 30 days" and then working out what
//  that is. This reads the thought.
//

import Foundation

extension Chrono {

    /// Parses a run of whole days from plain language.
    ///
    /// | Input | Means |
    /// |---|---|
    /// | `today`, `yesterday`, `next friday`, `2026-09-03` | that one day |
    /// | `this week`, `last month`, `next quarter`, `this year` | the whole calendar unit |
    /// | `last 30 days`, `past 2 weeks`, `previous 3 months` | that many, ending today |
    /// | `next 7 days` | that many, starting today |
    /// | `month to date`, `mtd`, `wtd`, `qtd`, `ytd` | the unit's start through today |
    /// | `september`, `sep 2026`, `2026-09`, `q3`, `q3 2026`, `2026` | that month, quarter or year |
    /// | `1 jan 2026 to 5 feb 2026`, `2026-03-01 - 2026-03-05` | both ends, inclusive |
    /// | `since monday`, `from 2026-01-01` | that day through today |
    /// | `until friday`, `through 2026-12-31` | today through that day |
    ///
    /// Counted windows include today: `last 7 days` is a week of days ending
    /// today, not the week before it. Weeks start on Monday, per ISO 8601 and
    /// ``Chrono/calendar``. Everything resolves in ``Chrono/timeZone``.
    ///
    /// - Throws: ``ChronoError/badRange(_:)`` when nothing matches.
    public static func range(_ raw: String) throws -> DateRange {
        let text = normaliseRange(raw)
        guard !text.isEmpty else { throw ChronoError.badRange(raw) }
        let today = calendar.startOfDay(for: Date())

        // Fixed grammars first, single dates last: "last month" is also a
        // date to ``date(_:)``, and it must mean the whole month here.
        if let whole = wholeUnit(text, today: today) { return whole }
        if let toDate = unitToDate(text, today: today) { return toDate }
        if let counted = countedWindow(text, today: today) { return counted }
        if let named = namedPeriod(text, today: today) { return named }
        if let pair = twoSided(text) { return pair }
        if let open = openEnded(text, today: today) { return open }
        if let day = try? date(text) { return DateRange(day: day) }

        throw ChronoError.badRange(raw)
    }

    // MARK: - Normalising

    /// Lower-cased, single-spaced, with the dash people paste from a document
    /// folded into the one on the keyboard.
    private static func normaliseRange(_ raw: String) -> String {
        var text = raw.lowercased()
            .replacingOccurrences(of: "–", with: " - ")
            .replacingOccurrences(of: "—", with: " - ")
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("the ") { text = String(text.dropFirst(4)) }
        return text
    }

    // MARK: - Whole calendar units

    /// `this week`, `last month`, `next quarter`, `previous year`.
    private static func wholeUnit(_ text: String, today: Date) -> DateRange? {
        let words = text.split(separator: " ").map(String.init)
        guard words.count == 2, let unit = rangeUnit(words[1]) else { return nil }
        let step: Int
        switch words[0] {
        case "this", "current": step = 0
        case "last", "previous": step = -1
        case "next": step = 1
        default: return nil
        }
        guard let anchor = try? shift(today, by: step, unit) else { return nil }
        return period(of: unit, containing: anchor)
    }

    /// `month to date`, `mtd`, `wtd`, `qtd`, `ytd`: the unit's start through today.
    private static func unitToDate(_ text: String, today: Date) -> DateRange? {
        let unit: CalendarUnit?
        switch text {
        case "wtd", "week to date": unit = .week
        case "mtd", "month to date": unit = .month
        case "qtd", "quarter to date": unit = .quarter
        case "ytd", "year to date": unit = .year
        default: unit = nil
        }
        guard let unit, let start = startOf(unit, containing: today) else { return nil }
        return DateRange(start: start, end: today)
    }

    // MARK: - Counted windows

    /// `last 30 days`, `past 2 weeks`, `previous 3 months`, `next 7 days`,
    /// and the bare `30 days`, which reads as the last thirty.
    ///
    /// Months and years are shifted by the calendar, so "last 3 months" from
    /// the 31st lands where a person expects and not 90 days back.
    private static func countedWindow(_ text: String, today: Date) -> DateRange? {
        var words = text.split(separator: " ").map(String.init)
        var forward = false
        if let first = words.first, ["last", "past", "previous", "next"].contains(first) {
            forward = first == "next"
            words.removeFirst()
        }
        guard words.count == 2,
              let count = rangeCount(words[0]), count > 0,
              let unit = rangeUnit(words[1])
        else { return nil }

        if forward {
            guard let after = try? shift(today, by: count, unit),
                  let end = calendar.date(byAdding: .day, value: -1, to: after)
            else { return nil }
            return DateRange(start: today, end: end)
        }
        guard let before = try? shift(today, by: -count, unit),
              let start = calendar.date(byAdding: .day, value: 1, to: before)
        else { return nil }
        return DateRange(start: start, end: today)
    }

    // MARK: - Named periods

    /// `september`, `sep 2026`, `2026-09`, `q3`, `q3 2026`, `2026 q3`, `2026`.
    private static func namedPeriod(_ text: String, today: Date) -> DateRange? {
        let thisYear = calendar.component(.year, from: today)
        let words = text.split(separator: " ").map(String.init)

        // A month, this year unless one is given.
        if let first = words.first, let month = monthNumber(first) {
            guard words.count <= 2 else { return nil }
            let year = words.count == 2 ? Int(words[1]) : thisYear
            guard let year, isPlausibleYear(year) else { return nil }
            return monthRange(year: year, month: month)
        }

        // `2026-09`
        if let match = text.wholeMatch(of: #"^(\d{4})-(\d{1,2})$"#),
           let year = Int(match[1]), let month = Int(match[2]), (1...12).contains(month) {
            return monthRange(year: year, month: month)
        }

        // `q3`, `q3 2026`, `2026 q3`
        if let match = text.wholeMatch(of: #"^(?:(\d{4}) )?q([1-4])(?: (\d{4}))?$"#) {
            let year = Int(match[1]) ?? Int(match[3]) ?? thisYear
            guard let quarter = Int(match[2]), isPlausibleYear(year) else { return nil }
            let firstMonth = (quarter - 1) * 3 + 1
            guard let start = calendar.date(from: DateComponents(year: year, month: firstMonth, day: 1)),
                  let next = calendar.date(byAdding: .month, value: 3, to: start),
                  let end = calendar.date(byAdding: .day, value: -1, to: next)
            else { return nil }
            return DateRange(start: start, end: end)
        }

        // `2026`
        if let year = Int(text), text.count == 4, isPlausibleYear(year),
           let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
           let next = calendar.date(byAdding: .year, value: 1, to: start),
           let end = calendar.date(byAdding: .day, value: -1, to: next) {
            return DateRange(start: start, end: end)
        }

        return nil
    }

    // MARK: - Two ends

    /// `X to Y`, `X until Y`, `X through Y`, `X - Y`, `from X to Y`,
    /// `between X and Y`. Each side is read by ``date(_:)``, so either can be
    /// anything that is.
    private static func twoSided(_ text: String) -> DateRange? {
        var body = text
        let between = body.hasPrefix("between ")
        if between { body = String(body.dropFirst("between ".count)) }
        if body.hasPrefix("from ") { body = String(body.dropFirst("from ".count)) }

        var separators = [" to ", " until ", " till ", " through ", " thru ", " - "]
        if between { separators.insert(" and ", at: 0) }

        for separator in separators {
            guard let split = body.range(of: separator) else { continue }
            let left = String(body[..<split.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(body[split.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !left.isEmpty, !right.isEmpty,
                  let start = try? date(left), let end = try? date(right)
            else { continue }
            return DateRange(start: start, end: end)
        }
        return nil
    }

    /// `since X` and `from X` run through today; `until X`, `till X`,
    /// `through X`, `to X` and `up to X` start today.
    private static func openEnded(_ text: String, today: Date) -> DateRange? {
        for prefix in ["since ", "from "] where text.hasPrefix(prefix) {
            guard let start = try? date(String(text.dropFirst(prefix.count))) else { return nil }
            return DateRange(start: start, end: today)
        }
        for prefix in ["until ", "till ", "through ", "up to ", "to "] where text.hasPrefix(prefix) {
            guard let end = try? date(String(text.dropFirst(prefix.count))) else { return nil }
            return DateRange(start: today, end: end)
        }
        return nil
    }

    // MARK: - Calendar helpers

    /// The whole of the unit that `date` falls in.
    private static func period(of unit: CalendarUnit, containing date: Date) -> DateRange? {
        guard let start = startOf(unit, containing: date),
              let next = try? shift(start, by: 1, unit),
              let end = calendar.date(byAdding: .day, value: -1, to: next)
        else { return nil }
        return DateRange(start: start, end: end)
    }

    /// The first day of the week, month, quarter or year that `date` falls in.
    private static func startOf(_ unit: CalendarUnit, containing date: Date) -> Date? {
        switch unit {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start
        case .quarter:
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)
            return calendar.date(from: DateComponents(year: year, month: ((month - 1) / 3) * 3 + 1, day: 1))
        case .year:
            return calendar.dateInterval(of: .year, for: date)?.start
        default:
            return nil
        }
    }

    private static func monthRange(year: Int, month: Int) -> DateRange? {
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let next = calendar.date(byAdding: .month, value: 1, to: start),
              let end = calendar.date(byAdding: .day, value: -1, to: next)
        else { return nil }
        return DateRange(start: start, end: end)
    }

    /// Only the units a run of days is counted in — hours and minutes are
    /// durations, not ranges.
    private static func rangeUnit(_ word: String) -> CalendarUnit? {
        switch word {
        case "day", "days": return .day
        case "week", "weeks": return .week
        case "month", "months": return .month
        case "quarter", "quarters": return .quarter
        case "year", "years": return .year
        default: return nil
        }
    }

    /// `30`, `thirty` or `a`.
    private static func rangeCount(_ word: String) -> Int? {
        Int(word) ?? numberWords[word]
    }

    private static func monthNumber(_ word: String) -> Int? {
        let names = ["january", "february", "march", "april", "may", "june", "july",
                     "august", "september", "october", "november", "december"]
        if let index = names.firstIndex(of: word) { return index + 1 }
        // Three-letter forms, plus "sept"; "may" is caught above.
        if word.count == 3 || word == "sept",
           let index = names.firstIndex(where: { $0.hasPrefix(word.count == 4 ? "sept" : word) }) {
            return index + 1
        }
        return nil
    }

    /// Wide enough for any report, narrow enough that a stray number is not a year.
    private static func isPlausibleYear(_ year: Int) -> Bool {
        (1900...2200).contains(year)
    }
}

private extension String {
    /// The whole-string match of a pattern, as its capture groups (index 0 is the whole).
    ///
    /// Returns `nil` for a group that did not participate, so a caller can
    /// write `Int(match[1]) ?? Int(match[3])` without an intermediate dance.
    func wholeMatch(of pattern: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: utf16.count))
        else { return nil }
        let text = self as NSString
        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            return range.location == NSNotFound ? nil : text.substring(with: range)
        }
    }
}

private extension Int {
    /// `Int("2026")` for an optional capture.
    init?(_ capture: String?) {
        guard let capture, let value = Int(capture) else { return nil }
        self = value
    }
}

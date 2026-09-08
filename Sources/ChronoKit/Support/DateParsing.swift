//
//  DateParsing.swift
//  ChronoKit
//
//  Plain language in, an instant out.
//
//  The relative grammar is ported from AgendaKit, where it was `internal` to a
//  package that imports EventKit. It is the half that was already built.
//

import Foundation

extension Chrono {

    /// Parses a date, accepting plain-language and ISO 8601 forms alike.
    ///
    /// Relative phrases are tried first — `now`, `today`, `tomorrow`,
    /// `next friday`, `+2d`, `3d ago`, and any of those with a time
    /// (`tomorrow 9am`). Failing that, `2026-09-03` resolves to the start of
    /// that day and `2026-09-03T14:30` to that wall-clock time, both in
    /// ``Chrono/timeZone``. A trailing `Z` or an explicit offset overrides the
    /// zone and is honoured as written.
    ///
    /// A trailing zone is honoured too, so `9:30 am PST`, `tomorrow 9am Tokyo`
    /// and `2026-09-03 14:30 UTC+2` all read as that wall clock over there.
    ///
    /// - Throws: ``ChronoError/badDate(_:)`` when nothing matches.
    public static func date(_ raw: String) throws -> Date {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { throw ChronoError.badDate(raw) }

        // A trailing zone rewrites where the rest is read, not what it says,
        // so it is peeled off and the remainder parsed over there.
        if let (rest, zone) = splitZone(text) {
            return try inZone(zone) { try date(rest) }
        }

        // Relative phrases go first: they are unambiguous, and an ISO date can
        // never look like one.
        if let relative = relativeDate(text) { return relative }

        // Only try the ISO parser on input that actually carries a zone
        // designator. Left to itself it assumes UTC for zone-less input, which
        // silently shifts every bare wall-clock time by the local offset.
        if text.hasSuffix("Z") || text.range(of: #"[+-]\d{2}:?\d{2}$"#, options: .regularExpression) != nil {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let parsed = iso.date(from: text) { return parsed }
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = iso.date(from: text) { return parsed }
        }

        // Only on input that starts with a four-digit year. DateFormatter is
        // lenient about `yyyy`, and left to itself reads "6/5/26" as the 26th
        // of May in the year 6 — a confidently wrong answer for an ambiguous
        // date that the detector below at least refuses to guess at.
        let isoShaped = text.range(of: #"^\d{4}([-/]\d|\d{4}$)"#, options: .regularExpression) != nil
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.calendar = calendar
        // Longest first: "yyyy-MM-dd" matches the front of a timestamp and
        // DateFormatter is happy to ignore the tail, which would drop the time.
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm",
                       "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm",
                       "yyyy/MM/dd", "yyyy-MM-dd", "yyyyMMdd"] where isoShaped {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: text) { return parsed }
        }

        // A bare Unix timestamp, which is what half the JSON in the world
        // carries. Ten digits is seconds until 2286; thirteen is milliseconds.
        if text.allSatisfy(\.isNumber) {
            if text.count == 10, let seconds = TimeInterval(text) {
                return Date(timeIntervalSince1970: seconds)
            }
            if text.count == 13, let millis = TimeInterval(text) {
                return Date(timeIntervalSince1970: millis / 1000)
            }
        }

        // Last, Foundation's detector: "this sunday", "a week on tuesday",
        // "el próximo domingo". Everything above is tried first because it is
        // exact and this is a guess, but it is a conservative guess — it reads
        // nothing at all out of "chapter 7" — so it costs nothing to ask.
        if let detected = detect(text) { return detected }

        throw ChronoError.badDate(raw)
    }

    /// Parses a relative date phrase, or returns nil when the text is not one.
    ///
    /// | Input | Means |
    /// |---|---|
    /// | `now` | this instant |
    /// | `today`, `tomorrow`, `yesterday` | that day, at midnight unless a time is given |
    /// | `monday` … `sunday` (or `mon`, `tue`) | the next such day, today included |
    /// | `next monday` | the same, but always at least a week out |
    /// | `last monday` | the most recent one, today excluded |
    /// | `+2d`, `90m`, `2w ago` | an offset from now |
    /// | `two weeks from now`, `in 3 days` | the same, written out |
    /// | `3pm`, `9:30 am`, `noon`, `midnight` | that time today |
    /// | `next week`, `last month`, `this year` | one calendar unit away |
    /// | any of the above `PST`, `Tokyo`, `UTC+2` | the same, read in that zone |
    ///
    /// - Note: A bare weekday resolves to *today* when today is that weekday.
    ///   Say `next monday` for the following week — guessing between the two
    ///   silently is how an agent books a meeting seven days from where the
    ///   user meant.
    public static func relativeDate(_ raw: String) -> Date? {
        // "9:30 am" is how people write it and "9:30am" is what the time
        // grammar reads, so the space in front of a meridiem is closed first.
        let text = raw.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: #"(\d)\s+(am|pm)\b"#, with: "$1$2", options: .regularExpression)
        guard !text.isEmpty else { return nil }

        if text == "now" { return Date() }

        if let (rest, zone) = splitZone(text) {
            return inZone(zone) { relativeDate(rest) }
        }

        // "2d ago" exists because a leading `-` is read as an option name by
        // most argument parsers, making `--at -1w` unusable without `=`.
        if text.hasSuffix(" ago") {
            let body = String(text.dropLast(" ago".count)).trimmingCharacters(in: .whitespaces)
            guard let seconds = try? duration(body) else { return nil }
            return Date().addingTimeInterval(-seconds)
        }

        // "next week", "last month", "this year": one calendar unit either
        // way, asked of the calendar so "next month" from 31 January is the
        // 28th of February and not the 3rd of March.
        if let shifted = calendarUnitPhrase(text) { return shifted }

        // The long way round to the same place as "+2w". Both spellings exist
        // because people type the short one and speak the long one.
        for phrase in [" from now", " from today", " ahead"] where text.hasSuffix(phrase) {
            let body = String(text.dropLast(phrase.count)).trimmingCharacters(in: .whitespaces)
            guard let seconds = try? duration(body) else { return nil }
            return Date().addingTimeInterval(seconds)
        }
        if text.hasPrefix("in ") {
            let body = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            if let seconds = try? duration(body) {
                return Date().addingTimeInterval(seconds)
            }
        }

        // A leading sign means a pure offset from now, with no day/time split.
        if text.hasPrefix("+") || text.hasPrefix("-") {
            guard let seconds = try? duration(String(text.dropFirst())) else { return nil }
            return Date().addingTimeInterval(text.hasPrefix("-") ? -seconds : seconds)
        }

        let (dayPhrase, timePhrase) = splitDayAndTime(text)
        guard let day = resolveDay(dayPhrase) else { return nil }
        guard let timePhrase else { return calendar.startOfDay(for: day) }
        guard let time = parseTime(timePhrase) else { return nil }

        return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day)
    }

    private static func calendarUnitPhrase(_ text: String) -> Date? {
        let words = text.split(separator: " ")
        guard words.count == 2 else { return nil }
        let step: Int
        switch words[0] {
        case "next": step = 1
        case "last": step = -1
        case "this": step = 0
        default: return nil
        }
        let component: Calendar.Component
        switch words[1] {
        case "week": component = .weekOfYear
        case "month": component = .month
        case "year": component = .year
        default: return nil
        }
        return calendar.date(byAdding: component, value: step, to: Date())
    }

    /// Peels a trailing zone off `9am PST` or `2pm Hong Kong`.
    ///
    /// Tried longest first, so `Hong Kong` is never tested as `Kong`, and
    /// never long enough to swallow the whole phrase — something has to be
    /// left to read in that zone.
    private static func splitZone(_ text: String) -> (rest: String, zone: TimeZone)? {
        let words = text.split(separator: " ").map(String.init)
        guard words.count > 1 else { return nil }

        for length in stride(from: min(3, words.count - 1), through: 1, by: -1) {
            let candidate = words.suffix(length).joined(separator: " ")
            guard let zone = resolveZone(candidate) else { continue }
            return (words.dropLast(length).joined(separator: " "), zone)
        }
        return nil
    }

    /// Splits `"tomorrow 9am"` into its day and time halves.
    ///
    /// The time is recognised by shape rather than position, so `next monday
    /// 14:00` keeps its two-word day phrase intact.
    private static func splitDayAndTime(_ text: String) -> (day: String, time: String?) {
        let words = text.split(separator: " ").map(String.init)

        // A bare time is about today. Refusing it would make "3pm PST" —
        // which is most of what anybody wants a zone for — unreadable.
        if words.count == 1, looksLikeTime(words[0]) { return ("today", words[0]) }

        guard words.count > 1, let last = words.last, looksLikeTime(last) else {
            return (text, nil)
        }
        return (words.dropLast().joined(separator: " "), last)
    }

    /// Whether a word could be a time of day.
    private static func looksLikeTime(_ word: String) -> Bool {
        word == "noon" || word == "midnight"
            || word.range(of: #"^\d{1,2}(:\d{2})?(am|pm)?$"#, options: .regularExpression) != nil
    }

    /// Resolves a day phrase to some moment on that day, or nil if unrecognised.
    private static func resolveDay(_ phrase: String) -> Date? {
        let now = Date()
        switch phrase {
        case "today":     return now
        case "tomorrow":  return calendar.date(byAdding: .day, value: 1, to: now)
        case "yesterday": return calendar.date(byAdding: .day, value: -1, to: now)
        default: break
        }

        let wantsNextWeek = phrase.hasPrefix("next ")
        let wantsLastWeek = phrase.hasPrefix("last ")
        var name = phrase
        if wantsNextWeek { name = String(phrase.dropFirst("next ".count)) }
        if wantsLastWeek { name = String(phrase.dropFirst("last ".count)) }
        guard let weekday = weekdayNumber(name) else { return nil }

        let today = calendar.component(.weekday, from: now)

        if wantsLastWeek {
            // `last friday` on a Friday means a week ago, not today: the word
            // "last" is only ever used about a day that has been and gone.
            var behind = (today - weekday + 7) % 7
            if behind == 0 { behind = 7 }
            return calendar.date(byAdding: .day, value: -behind, to: now)
        }

        var ahead = (weekday - today + 7) % 7
        // `next monday` always means the occurrence after the upcoming one. On
        // a Sunday, `monday` is tomorrow and `next monday` is eight days out —
        // without the unconditional week the two phrases collapse and "next"
        // means nothing.
        if wantsNextWeek { ahead += 7 }
        return calendar.date(byAdding: .day, value: ahead, to: now)
    }

    /// Maps a weekday name or three-letter abbreviation to a `Calendar` number.
    private static func weekdayNumber(_ name: String) -> Int? {
        let names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        if let index = names.firstIndex(of: name) { return index + 1 }
        if name.count == 3, let index = names.firstIndex(where: { $0.hasPrefix(name) }) {
            return index + 1
        }
        return nil
    }

    /// Parses `9am`, `9:30`, `14:00`, `5:15pm` into hour and minute.
    ///
    /// Returns nil rather than clamping an out-of-range hour — `25:00` is a
    /// typo, and silently reading it as 1am schedules something on the wrong
    /// day.
    private static func parseTime(_ text: String) -> (hour: Int, minute: Int)? {
        // Midnight is the start of the named day, matching what "today" and
        // "tomorrow" already mean on their own.
        if text == "noon" { return (12, 0) }
        if text == "midnight" { return (0, 0) }

        let pattern = #"^(\d{1,2})(?::(\d{2}))?(am|pm)?$"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
        let body = String(text[match])

        let meridiem = body.hasSuffix("am") ? "am" : (body.hasSuffix("pm") ? "pm" : nil)
        let digits = body.replacingOccurrences(of: "am", with: "").replacingOccurrences(of: "pm", with: "")
        let parts = digits.split(separator: ":").map(String.init)

        guard var hour = Int(parts[0]) else { return nil }
        let minute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        guard (0...59).contains(minute) else { return nil }

        switch meridiem {
        case "am": guard (1...12).contains(hour) else { return nil }; if hour == 12 { hour = 0 }
        case "pm": guard (1...12).contains(hour) else { return nil }; if hour != 12 { hour += 12 }
        default:   guard (0...23).contains(hour) else { return nil }
        }
        return (hour, minute)
    }
}

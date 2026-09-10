//
//  DateTokens.swift
//  ChronoKit
//
//  `{today}`, `{month_start_iso}`, `{30d_ago_ms}` — the tokens a request
//  template carries, filled in from the calendar.
//

import Foundation

extension Chrono {

    /// Replaces every `{token}` this package knows with its value at `now`.
    ///
    /// Unknown braces are left exactly as written: `{ user { id name } }` is
    /// a GraphQL body, not a request for a date, and a template engine that
    /// eats it silently is the kind of bug that only shows up as a 400 from
    /// somebody else's server. Only lowercase names of letters, digits and
    /// underscores are even considered.
    ///
    /// The catalogue is MetricBar's, kept name for name so its templates keep
    /// working. Period tokens use ``Chrono/calendar`` — Gregorian, ISO weeks,
    /// ``Chrono/timeZone`` — so `{week_start}` names the same Monday on every
    /// machine; months and years are shifted by the calendar rather than by
    /// 30 or 365 days, day offsets step by calendar day so a clock change
    /// cannot move `{date_7d_ago}` to the wrong date, and the `Nd_ago` unix
    /// tokens stay exact durations, because that is what they say.
    public static func fill(_ template: String, at now: Date = Date()) -> String {
        guard template.contains("{") else { return template }
        let moments = DateTokens.Moments(now: now)
        var result = template
        let nsString = result as NSString
        let matches = DateTokens.pattern.matches(in: result, range: NSRange(location: 0, length: nsString.length))
        for match in matches.reversed() {
            let name = nsString.substring(with: match.range(at: 1))
            guard let value = DateTokens.value(of: name, moments: moments) else { continue }
            result = (result as NSString).replacingCharacters(in: match.range(at: 0), with: value)
        }
        return result
    }

    /// The value of one token at `now`, or nil when the name is not a token.
    public static func value(of token: String, at now: Date = Date()) -> String? {
        DateTokens.value(of: token, moments: DateTokens.Moments(now: now))
    }

    /// Every token ``fill(_:at:)`` understands, with a description and a
    /// real example — for a picker, or for a help screen.
    public static var tokens: [DateToken] {
        DateTokens.catalogue()
    }
}

/// The token table, and the arithmetic that fills it.
enum DateTokens {

    /// `{name}` where the name is lowercase letters, digits and underscores.
    static let pattern = try! NSRegularExpression(pattern: #"\{([a-z0-9_]+)\}"#)

    /// The reference instant every ``DateToken/example`` is computed at.
    static let referenceInstant = Date(timeIntervalSince1970: 1_788_445_800)   // 2026-09-03T14:30:00Z

    // MARK: Names

    /// The full catalogue, in the order a picker should show it. Names are
    /// MetricBar's, exactly; nothing is added here that its templates could
    /// not already say.
    static let names: [String] = {
        var names = ["now", "now_ms", "now_iso"]
        names += ["today", "today_iso", "today_start", "today_end",
                  "yesterday", "yesterday_iso", "yesterday_start", "yesterday_end",
                  "tomorrow", "tomorrow_start", "tomorrow_end"]
        let periods = ["week", "month", "quarter", "year"]
        for period in periods { names += ["\(period)_start", "\(period)_end"] }
        for period in periods { names += ["last_\(period)_start", "last_\(period)_end"] }
        for suffix in ["_iso", "_date", "_ms"] {
            for period in periods { names += ["\(period)_start\(suffix)", "\(period)_end\(suffix)"] }
            for period in periods { names += ["last_\(period)_start\(suffix)", "last_\(period)_end\(suffix)"] }
        }
        names += ["today_start_ms", "today_end_ms"]
        names += ["1h_ago", "6h_ago", "12h_ago", "24h_ago"]
        names += ["1h_ago_ms", "6h_ago_ms", "12h_ago_ms", "24h_ago_ms"]
        names += ["1d_ago", "7d_ago", "30d_ago", "90d_ago", "180d_ago", "365d_ago"]
        names += ["1d_ago_ms", "7d_ago_ms", "30d_ago_ms", "90d_ago_ms", "365d_ago_ms"]
        names += ["1d_ago_iso", "7d_ago_iso", "30d_ago_iso", "90d_ago_iso", "365d_ago_iso"]
        names += ["1_day_ago", "7_days_ago", "30_days_ago", "3_months_ago", "6_months_ago", "1_year_ago"]
        names += ["date_7d_ago", "date_30d_ago", "date_90d_ago"]
        names += ["year", "month", "month_name", "day", "day_name", "hour", "minute", "second", "week_number", "quarter"]
        names += ["timezone"]
        return names
    }()

    static let nameSet = Set(names)

    // MARK: Catalogue

    /// Every token with its description and its value at the reference instant.
    static func catalogue() -> [DateToken] {
        // Computed inside the zone, values included: a `_date` rendered in the
        // machine's zone would put the example's month end on the first of the
        // next month for anyone east of Greenwich.
        Chrono.inZone(TimeZone(identifier: "UTC")!) {
            let moments = Moments(now: referenceInstant)
            return names.map { name in
                DateToken(name: name, description: describe(name), example: value(of: name, moments: moments) ?? "")
            }
        }
    }

    /// A sentence for each token, built from its shape.
    static func describe(_ name: String) -> String {
        if let fixed = fixedDescriptions[name] { return fixed }
        if let relative = Relative(name) {
            let amount = relative.unit == "h" ? "\(relative.count) hour\(relative.count == 1 ? "" : "s")"
                                              : "\(relative.count) day\(relative.count == 1 ? "" : "s")"
            return "Exactly \(amount) before now, \(Rendering(suffix: relative.suffix).description)."
        }
        if let period = Period(name) {
            let which = period.isLast ? "last" : "this"
            let edge = period.edge == .start ? "The first instant of" : "The last second of"
            let unit = period.unit == "week" ? "week (Monday to Sunday)" : period.unit
            return "\(edge) \(which) \(unit), \(Rendering(suffix: period.suffix).description)."
        }
        if let days = calendarDaysAgo(name) {
            return "The calendar date \(days) days before today, as yyyy-MM-dd."
        }
        return name
    }

    private static let fixedDescriptions: [String: String] = [
        "now": "The current instant as a Unix timestamp in seconds.",
        "now_ms": "The current instant as a Unix timestamp in milliseconds.",
        "now_iso": "The current instant in ISO 8601, in UTC.",
        "today": "Today's date as yyyy-MM-dd.",
        "today_iso": "The start of today in ISO 8601, in UTC.",
        "today_start": "The first second of today as a Unix timestamp.",
        "today_end": "The last second of today as a Unix timestamp.",
        "today_start_ms": "The first instant of today in milliseconds.",
        "today_end_ms": "The last second of today in milliseconds.",
        "yesterday": "Yesterday's date as yyyy-MM-dd.",
        "yesterday_iso": "The start of yesterday in ISO 8601, in UTC.",
        "yesterday_start": "The first second of yesterday as a Unix timestamp.",
        "yesterday_end": "The last second of yesterday as a Unix timestamp.",
        "tomorrow": "Tomorrow's date as yyyy-MM-dd.",
        "tomorrow_start": "The first second of tomorrow as a Unix timestamp.",
        "tomorrow_end": "The last second of tomorrow as a Unix timestamp.",
        "1_day_ago": "Exactly 24 hours before now, as a Unix timestamp.",
        "7_days_ago": "Exactly 7 days before now, as a Unix timestamp.",
        "30_days_ago": "Exactly 30 days before now, as a Unix timestamp.",
        "3_months_ago": "Three calendar months before now, as a Unix timestamp.",
        "6_months_ago": "Six calendar months before now, as a Unix timestamp.",
        "1_year_ago": "One calendar year before now, as a Unix timestamp.",
        "year": "The year, four digits.",
        "month": "The month, two digits.",
        "month_name": "The month's English name.",
        "day": "The day of the month, two digits.",
        "day_name": "The weekday's English name.",
        "hour": "The hour, two digits, 00–23.",
        "minute": "The minute, two digits.",
        "second": "The second, two digits.",
        "week_number": "The ISO week number, 1–53.",
        "quarter": "The calendar quarter, as Q1–Q4.",
        "timezone": "The IANA identifier of the zone everything is resolved in.",
    ]

    // MARK: Resolving

    /// The value for a bare name, or nil when it is not in the catalogue.
    static func value(of name: String, moments: Moments) -> String? {
        guard nameSet.contains(name) else { return nil }
        let now = moments.now
        switch name {
        case "now": return Render.unix(now)
        case "now_ms": return Render.unixMs(now)
        case "now_iso": return Render.iso(now)
        case "today": return Render.day(now)
        case "today_iso": return Render.iso(moments.startOfToday)
        case "today_start": return Render.unix(moments.startOfToday)
        case "today_end": return Render.unix(moments.endOfToday)
        case "today_start_ms": return Render.unixMs(moments.startOfToday)
        case "today_end_ms": return Render.unixMs(moments.endOfToday)
        case "yesterday": return Render.day(moments.yesterdayStart)
        case "yesterday_iso": return Render.iso(moments.yesterdayStart)
        case "yesterday_start": return Render.unix(moments.yesterdayStart)
        case "yesterday_end": return Render.unix(moments.startOfToday.addingTimeInterval(-1))
        case "tomorrow": return Render.day(moments.tomorrowStart)
        case "tomorrow_start": return Render.unix(moments.tomorrowStart)
        case "tomorrow_end": return Render.unix(moments.tomorrowEnd)
        case "1_day_ago": return Render.unix(now.addingTimeInterval(-86_400))
        case "7_days_ago": return Render.unix(now.addingTimeInterval(-7 * 86_400))
        case "30_days_ago": return Render.unix(now.addingTimeInterval(-30 * 86_400))
        case "3_months_ago": return Render.unix(moments.shifted(by: -3, .month))
        case "6_months_ago": return Render.unix(moments.shifted(by: -6, .month))
        case "1_year_ago": return Render.unix(moments.shifted(by: -1, .year))
        case "year": return Render.component("yyyy", now)
        case "month": return Render.component("MM", now)
        case "month_name": return Render.component("MMMM", now)
        case "day": return Render.component("dd", now)
        case "day_name": return Render.component("EEEE", now)
        case "hour": return Render.component("HH", now)
        case "minute": return Render.component("mm", now)
        case "second": return Render.component("ss", now)
        case "week_number": return "\(Chrono.calendar.component(.weekOfYear, from: now))"
        case "quarter": return "Q\((Chrono.calendar.component(.month, from: now) - 1) / 3 + 1)"
        case "timezone": return Chrono.timeZone.identifier
        default: break
        }
        if let relative = Relative(name) {
            let seconds = Double(relative.count) * (relative.unit == "h" ? 3_600 : 86_400)
            return Rendering(suffix: relative.suffix).render(now.addingTimeInterval(-seconds))
        }
        if let period = Period(name) {
            return Rendering(suffix: period.suffix).render(moments.boundary(of: period))
        }
        if let days = calendarDaysAgo(name) {
            return Render.day(moments.shifted(by: -days, .day))
        }
        return nil
    }

    // MARK: Token shapes

    /// `1h_ago`, `30d_ago_ms`, `7d_ago_iso`: an exact duration before now.
    struct Relative {
        let count: Int
        let unit: String
        let suffix: String

        init?(_ name: String) {
            guard let match = name.wholeMatch(of: #"^(\d+)([hd])_ago(_ms|_iso)?$"#),
                  let count = match[1].flatMap({ Int($0) }), let unit = match[2] else { return nil }
            self.count = count
            self.unit = unit
            self.suffix = match[3] ?? ""
        }
    }

    /// `week_start`, `last_quarter_end_iso`, `month_end_date`: a period boundary.
    struct Period {
        enum Edge { case start, end }
        let isLast: Bool
        let unit: String
        let edge: Edge
        let suffix: String

        init?(_ name: String) {
            guard let match = name.wholeMatch(of: #"^(last_)?(week|month|quarter|year)_(start|end)(_iso|_date|_ms)?$"#),
                  let unit = match[2], let edge = match[3] else { return nil }
            self.isLast = match[1] != nil
            self.unit = unit
            self.edge = edge == "start" ? .start : .end
            self.suffix = match[4] ?? ""
        }
    }

    /// `date_30d_ago`: a calendar date some days back.
    static func calendarDaysAgo(_ name: String) -> Int? {
        name.wholeMatch(of: #"^date_(\d+)d_ago$"#)?[1].flatMap { Int($0) }
    }

    /// How a suffix wants the instant written.
    struct Rendering {
        let suffix: String

        func render(_ date: Date) -> String {
            switch suffix {
            case "_ms": return Render.unixMs(date)
            case "_iso": return Render.iso(date)
            case "_date": return Render.day(date)
            default: return Render.unix(date)
            }
        }

        var description: String {
            switch suffix {
            case "_ms": return "as a Unix timestamp in milliseconds"
            case "_iso": return "in ISO 8601 (UTC)"
            case "_date": return "as yyyy-MM-dd"
            default: return "as a Unix timestamp in seconds"
            }
        }
    }

    // MARK: Rendering

    /// The four spellings of an instant.
    enum Render {

        static func unix(_ date: Date) -> String { "\(Int(date.timeIntervalSince1970))" }

        static func unixMs(_ date: Date) -> String { "\(Int(date.timeIntervalSince1970 * 1_000))" }

        /// RFC 3339 in UTC, `2026-09-03T14:30:00Z` — what a date-time range
        /// API wants, whatever zone the template was filled in.
        static func iso(_ date: Date) -> String {
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.string(from: date)
        }

        /// `yyyy-MM-dd` in ``Chrono/timeZone``.
        static func day(_ date: Date) -> String { component("yyyy-MM-dd", date) }

        /// A fixed-locale field: English names, ASCII digits, in ``Chrono/timeZone``.
        static func component(_ format: String, _ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Chrono.calendar
            formatter.timeZone = Chrono.timeZone
            formatter.dateFormat = format
            return formatter.string(from: date)
        }
    }

    // MARK: Moments

    /// The boundaries around `now`, computed once per fill.
    ///
    /// Ends are the last second of their period — a second before the next
    /// one starts — because that is what `_end` has always meant here and
    /// what an inclusive `until=` parameter expects.
    struct Moments {
        let now: Date
        let calendar: Calendar
        let startOfToday: Date
        let endOfToday: Date
        let yesterdayStart: Date
        let tomorrowStart: Date
        let tomorrowEnd: Date

        init(now: Date) {
            self.now = now
            calendar = Chrono.calendar
            startOfToday = calendar.startOfDay(for: now)
            tomorrowStart = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
            endOfToday = tomorrowStart.addingTimeInterval(-1)
            yesterdayStart = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
            tomorrowEnd = (calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? tomorrowStart).addingTimeInterval(-1)
        }

        /// `now` moved by whole calendar units.
        func shifted(by count: Int, _ component: Calendar.Component) -> Date {
            calendar.date(byAdding: component, value: count, to: now) ?? now
        }

        /// The first instant of the week, month, quarter or year containing `now`.
        func start(of unit: String) -> Date {
            switch unit {
            case "week": return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
            case "month": return calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            case "quarter":
                let month = calendar.component(.month, from: now)
                let year = calendar.component(.year, from: now)
                return calendar.date(from: DateComponents(year: year, month: ((month - 1) / 3) * 3 + 1, day: 1)) ?? startOfToday
            default: return calendar.dateInterval(of: .year, for: now)?.start ?? startOfToday
            }
        }

        /// The first instant of the period after the one containing `now`.
        func next(of unit: String) -> Date {
            let start = start(of: unit)
            switch unit {
            case "week": return calendar.date(byAdding: .day, value: 7, to: start) ?? start
            case "month": return calendar.date(byAdding: .month, value: 1, to: start) ?? start
            case "quarter": return calendar.date(byAdding: .month, value: 3, to: start) ?? start
            default: return calendar.date(byAdding: .year, value: 1, to: start) ?? start
            }
        }

        /// The first instant of the period before the one containing `now`.
        func previous(of unit: String) -> Date {
            let start = start(of: unit)
            switch unit {
            case "week": return calendar.date(byAdding: .day, value: -7, to: start) ?? start
            case "month": return calendar.date(byAdding: .month, value: -1, to: start) ?? start
            case "quarter": return calendar.date(byAdding: .month, value: -3, to: start) ?? start
            default: return calendar.date(byAdding: .year, value: -1, to: start) ?? start
            }
        }

        /// The instant a period token names.
        func boundary(of period: Period) -> Date {
            switch (period.isLast, period.edge) {
            case (false, .start): return start(of: period.unit)
            case (false, .end): return next(of: period.unit).addingTimeInterval(-1)
            case (true, .start): return previous(of: period.unit)
            case (true, .end): return start(of: period.unit).addingTimeInterval(-1)
            }
        }
    }
}

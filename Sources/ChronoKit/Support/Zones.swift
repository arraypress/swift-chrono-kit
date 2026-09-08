//
//  Zones.swift
//  ChronoKit
//
//  Naming a zone the way people write one.
//

import Foundation

extension Chrono {

    /// Resolves a time zone from an identifier, abbreviation, city or offset.
    ///
    /// | Written | Resolves to |
    /// |---|---|
    /// | `Europe/London` | itself, the IANA identifier |
    /// | `PST`, `pst` | `America/Los_Angeles` |
    /// | `AEST` | `Australia/Sydney` |
    /// | `ET`, `PT`, `CT`, `MT` | the US zones people write without the S or D |
    /// | `Tokyo`, `new york` | the identifier ending in that city |
    /// | `UTC+2`, `GMT-5`, `+05:30` | a fixed offset from UTC |
    ///
    /// - Throws: ``ChronoError/unknownZone(_:)`` when nothing matches.
    public static func zone(_ raw: String) throws -> TimeZone {
        guard let zone = resolveZone(raw) else { throw ChronoError.unknownZone(raw) }
        return zone
    }

    /// Describes an instant as it reads in another zone, leaving ``timeZone`` alone.
    ///
    /// The instant does not move — only the wall clock put against it does.
    public static func describe(_ date: Date, in zone: TimeZone) -> Instant {
        inZone(zone) { describe(date) }
    }

    // MARK: - Resolution

    /// The lenient lookup behind ``zone(_:)``, also used when parsing a date.
    static func resolveZone(_ raw: String) -> TimeZone? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else { return nil }

        // Offsets first. `TimeZone(identifier:)` accepts "GMT+2" but not
        // "UTC+2", and people write both, so neither goes through Foundation.
        if let offset = offsetZone(text) { return offset }

        // Canonical identifiers first, and deliberately not via
        // `TimeZone(identifier:)`, which also accepts legacy aliases —
        // including "PST", where it hands back a zone whose identifier is
        // literally "PST". That shadows the abbreviation table and reports a
        // name no map has. The alias fallback is kept, but last.
        let lowered = text.lowercased()
        if let known = TimeZone.knownTimeZoneIdentifiers
            .first(where: { $0.lowercased() == lowered })
            .flatMap(TimeZone.init(identifier:)) {
            return known
        }

        // Foundation's own table, which is right about DST: "PST" is the
        // Pacific *region*, so a July date in it is read as PDT — which is
        // what somebody writing "3pm PST" in July means.
        let upper = text.uppercased()
        if let known = TimeZone(abbreviation: upper) { return known }
        if let extra = extraAbbreviations[upper].flatMap(TimeZone.init(identifier:)) { return extra }

        // A city, matched on the last path component: "new york" and
        // "New_York" both find America/New_York. No two identifiers in the
        // database end in the same city, so this can't be ambiguous.
        if let city = TimeZone.knownTimeZoneIdentifiers
            .first(where: { identifier in
                identifier.split(separator: "/").last?
                    .replacingOccurrences(of: "_", with: " ")
                    .lowercased() == lowered
            })
            .flatMap(TimeZone.init(identifier:)) {
            return city
        }

        // Legacy aliases nothing above knows: "US/Pacific", "Japan", "Zulu".
        return TimeZone(identifier: text)
    }

    /// Reads `UTC+2`, `GMT-5`, `+05:30` or `+0530` as a fixed offset.
    ///
    /// A bare `+2` is deliberately not an offset: `+2` is already a relative
    /// date in this package, and one grammar should not quietly eat the other.
    private static func offsetZone(_ text: String) -> TimeZone? {
        var body = text.uppercased()
        var named = false
        for prefix in ["UTC", "GMT"] where body.hasPrefix(prefix) {
            body.removeFirst(prefix.count)
            named = true
            break
        }
        body = body.trimmingCharacters(in: .whitespaces)

        guard let sign = body.first, sign == "+" || sign == "-" else { return nil }
        let digits = body.dropFirst().replacingOccurrences(of: ":", with: "")
        guard !digits.isEmpty, digits.count <= 4, digits.allSatisfy(\.isNumber) else { return nil }

        let hours: Int, minutes: Int
        if digits.count <= 2 {
            // Requiring the name here is what keeps "+2" a duration.
            guard named else { return nil }
            hours = Int(digits) ?? 0
            minutes = 0
        } else {
            hours = Int(digits.dropLast(2)) ?? 0
            minutes = Int(digits.suffix(2)) ?? 0
        }

        // UTC+14 is the real maximum, in Kiritimati.
        guard hours <= 14, minutes <= 59 else { return nil }
        let total = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: total)
    }

    /// Abbreviations Foundation's table leaves out.
    ///
    /// Only additions — nothing here overrides Foundation, including the
    /// spellings it resolves in a way somebody will disagree with. `IST` is
    /// India rather than Ireland or Israel, `CST` is Chicago rather than
    /// China, and `MST` is Phoenix, which never leaves standard time. Those
    /// are real ambiguities in the abbreviations themselves; write the
    /// identifier or the city when it matters.
    private static let extraAbbreviations: [String: String] = [
        // Written constantly in American English, and in no Foundation table.
        "ET": "America/New_York",
        "CT": "America/Chicago",
        "MT": "America/Denver",
        "PT": "America/Los_Angeles",

        // Australia, which Foundation omits entirely.
        "AEST": "Australia/Sydney",
        "AEDT": "Australia/Sydney",
        "ACST": "Australia/Adelaide",
        "ACDT": "Australia/Adelaide",
        "AWST": "Australia/Perth",

        "SAST": "Africa/Johannesburg",
        "WIB": "Asia/Jakarta",
    ]
}

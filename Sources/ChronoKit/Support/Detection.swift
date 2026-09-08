//
//  Detection.swift
//  ChronoKit
//
//  The phrasings a hand-written grammar never finishes.
//

import Foundation

extension Chrono {

    /// A date read by Foundation's own detector — the engine behind the dates
    /// iOS underlines and offers to add to your calendar.
    ///
    /// This is the answer to "there are too many phrasings to enumerate", and
    /// it is not a language model: it is instant, offline, free, and already on
    /// the device. It reads what this package's grammar deliberately does not:
    ///
    /// | Written | Read as |
    /// |---|---|
    /// | `this sunday`, `next sunday` | that Sunday |
    /// | `a week on tuesday` | the Tuesday after the coming one |
    /// | `tomorrow at 3pm` | tomorrow, 15:00 |
    /// | `el próximo domingo`, `nächsten Sonntag` | that Sunday, in Spanish and German |
    ///
    /// It is also multilingual for free, being the same detector the OS ships
    /// for every language it supports — which is the one thing this package's
    /// `en_US_POSIX` grammar can never be.
    ///
    /// Safe to reach for last because it is conservative to a fault. `sat`,
    /// `chapter 7`, `iPhone 15`, `version 3` and `100` are all nil, so it
    /// cannot turn junk into a confident date.
    ///
    /// - Note: What it does *not* read is this package's compact grammar —
    ///   `+2w`, `3 days ago` and `90m` are all nil to it. The two halves are
    ///   complementary, which is why ``date(_:)`` tries both.
    public static func detect(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.date.rawValue
        ) else { return nil }

        let range = NSRange(location: 0, length: (text as NSString).length)
        guard let match = detector.matches(in: text, range: range).first,
              let found = match.date
        else { return nil }

        // The text named a zone, so the instant is absolute — "9:30 am PST" is
        // one moment wherever it is read. Take it exactly as given.
        if match.timeZone != nil { return found }

        // Otherwise the detector resolved a wall clock, and it did so in the
        // *system* zone, which is not necessarily Chrono's. Rebuilding the same
        // clock face in ``timeZone`` is what keeps `inZone` meaning anything.
        var system = Calendar(identifier: .gregorian)
        system.timeZone = .current
        let face = system.dateComponents([.year, .month, .day, .hour, .minute, .second], from: found)
        return calendar.date(from: face) ?? found
    }
}

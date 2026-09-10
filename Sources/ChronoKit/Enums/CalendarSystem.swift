//
//  CalendarSystem.swift
//  ChronoKit
//

import Foundation

/// The calendars Foundation already knows how to count in.
///
/// A date-conversion action needs a closed list with names people use, not
/// `Calendar.Identifier`'s full set, which carries variants nobody asks for
/// by name. Two Islamic calendars are kept because they give different days:
/// Umm al-Qura is what Saudi Arabia and most of the Gulf print, and the
/// civil (tabular) one is what a rule-based system computes.
public enum CalendarSystem: String, CaseIterable, Sendable, Codable {
    case gregorian, islamicUmmAlQura, islamicCivil, hebrew, japanese, chinese, buddhist, persian, coptic, indian

    /// Foundation's identifier for the calendar.
    public var identifier: Calendar.Identifier {
        switch self {
        case .gregorian: .gregorian
        case .islamicUmmAlQura: .islamicUmmAlQura
        case .islamicCivil: .islamicCivil
        case .hebrew: .hebrew
        case .japanese: .japanese
        case .chinese: .chinese
        case .buddhist: .buddhist
        case .persian: .persian
        case .coptic: .coptic
        case .indian: .indian
        }
    }

    /// The calendar as people name it: `Islamic (Umm al-Qura)`.
    public var name: String {
        switch self {
        case .gregorian: "Gregorian"
        case .islamicUmmAlQura: "Islamic (Umm al-Qura)"
        case .islamicCivil: "Islamic (civil)"
        case .hebrew: "Hebrew"
        case .japanese: "Japanese"
        case .chinese: "Chinese"
        case .buddhist: "Buddhist"
        case .persian: "Persian"
        case .coptic: "Coptic"
        case .indian: "Indian national"
        }
    }
}

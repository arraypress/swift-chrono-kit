//
//  DateToken.swift
//  ChronoKit
//

import Foundation

/// One `{token}` a template can carry, described for a picker.
///
/// The catalogue exists so an app can show what it accepts instead of
/// sending people to read a source file. `example` is the token's value at a
/// fixed reference instant, so it is always true and never "e.g. some date".
public struct DateToken: Sendable, Hashable, Codable, Identifiable {

    /// The bare name, without braces: `month_start_iso`.
    public let name: String

    /// What it resolves to, in a sentence.
    public let description: String

    /// Its value at the catalogue's reference instant,
    /// 2026-09-03T14:30:00Z read in UTC.
    public let example: String

    /// The name, which is unique in the catalogue.
    public var id: String { name }
}

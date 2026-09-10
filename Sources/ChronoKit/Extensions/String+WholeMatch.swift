//
//  String+WholeMatch.swift
//  ChronoKit
//
//  One regex helper, shared by the range grammar and the token table rather
//  than written twice.
//

import Foundation

extension String {

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

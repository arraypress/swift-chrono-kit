//
//  RelativeSpan+Words.swift
//  ChronoKit
//

import Foundation

extension RelativeSpan {

    /// The span as people say it: `in 3 days`, `2 hours ago`, `now`.
    public var words: String { RelativeWording.words(self) }
}

//
//  FiscalYear+Presets.swift
//  ChronoKit
//
//  The fiscal years people actually ask about, named.
//

import Foundation

extension FiscalYear {

    /// 1 January — the calendar year, so quarters match ``Instant/quarter``.
    public static let calendar = FiscalYear(startMonth: 1, startDay: 1, unchecked: ())

    /// 6 April — the UK tax year, a date inherited from the Julian calendar's
    /// Lady Day and never moved.
    public static let unitedKingdom = FiscalYear(startMonth: 4, startDay: 6, unchecked: ())

    /// 1 October — the US federal government's fiscal year.
    public static let unitedStatesFederal = FiscalYear(startMonth: 10, startDay: 1, unchecked: ())

    /// 1 July — Australia's financial year, and New Zealand's for many entities.
    public static let australia = FiscalYear(startMonth: 7, startDay: 1, unchecked: ())

    /// 1 April — India, Japan, Canada's government and much of the UK public sector.
    public static let april = FiscalYear(startMonth: 4, startDay: 1, unchecked: ())
}

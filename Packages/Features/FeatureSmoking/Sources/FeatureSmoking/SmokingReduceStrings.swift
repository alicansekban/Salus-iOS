// The accessors for the keys the REDUCE main screen owns — an extension of ``SmokingStrings`` so the
// enum itself stays inside SwiftLint's 300-line `type_body_length`. The key names are in
// `SmokingStrings.Key`, which an extension cannot add cases to.

import Foundation

extension SmokingStrings {
    // MARK: - Plain strings

    public static var quitErrorOverlap: String { localized(.quitErrorOverlap) }
    public static var reduceAdded: String { localized(.reduceAdded) }
    public static var reduceAtBody: String { localized(.reduceAtBody) }
    public static var reduceAtTitle: String { localized(.reduceAtTitle) }
    public static var reduceChartNoData: String { localized(.reduceChartNoData) }
    public static var reduceChartTitle: String { localized(.reduceChartTitle) }
    public static var reduceEmptyTitle: String { localized(.reduceEmptyTitle) }
    public static var reduceNoneToday: String { localized(.reduceNoneToday) }
    public static var reduceOverTitle: String { localized(.reduceOverTitle) }
    public static var reduceOverline: String { localized(.reduceOverline) }
    public static var reducePlusOne: String { localized(.reducePlusOne) }
    public static var reducePlusOneCd: String { localized(.reducePlusOneCd) }
    public static var reduceReady: String { localized(.reduceReady) }
    public static var reduceTimelineBody: String { localized(.reduceTimelineBody) }
    public static var reduceTimelineTitle: String { localized(.reduceTimelineTitle) }
    public static var reduceUnderTitle: String { localized(.reduceUnderTitle) }
    public static var reduceWeekNone: String { localized(.reduceWeekNone) }

    // MARK: - Formatted strings

    /// `smoking_reduce_chart_baseline`: the old average's caption on the chart.
    public static func reduceChartBaseline(_ units: Int) -> String {
        String(format: localized(.reduceChartBaseline), locale: .current, units)
    }

    /// `smoking_reduce_chart_cd`: the chart's spoken summary around its day values.
    public static func reduceChartCd(_ dayValues: String) -> String {
        String(format: localized(.reduceChartCd), locale: .current, dayValues)
    }

    /// `smoking_reduce_chart_day_value`: "Sal 7", one spoken day.
    public static func reduceChartDayValue(_ day: String, _ value: String) -> String {
        String(format: localized(.reduceChartDayValue), locale: .current, day, value)
    }

    /// `smoking_reduce_empty_body`.
    public static func reduceEmptyBody(_ limit: Int) -> String {
        String(format: localized(.reduceEmptyBody), locale: .current, limit)
    }

    /// `smoking_reduce_over_baseline`.
    public static func reduceOverBaseline(_ units: Int) -> String {
        String(format: localized(.reduceOverBaseline), locale: .current, units)
    }

    /// `smoking_reduce_over_body`.
    public static func reduceOverBody(_ over: Int) -> String {
        String(format: localized(.reduceOverBody), locale: .current, over)
    }

    /// `smoking_reduce_over_chip`: "+2".
    public static func reduceOverChip(_ over: Int) -> String {
        String(format: localized(.reduceOverChip), locale: .current, over)
    }

    /// `smoking_reduce_over_chip_cd`: the chip spoken in words.
    public static func reduceOverChipCd(_ over: Int) -> String {
        String(format: localized(.reduceOverChipCd), locale: .current, over)
    }

    /// `smoking_reduce_ring_limit`: " / 10", the ring's smaller figure.
    public static func reduceRingLimit(_ limit: Int) -> String {
        String(format: localized(.reduceRingLimit), locale: .current, limit)
    }

    /// `smoking_reduce_ring_semantics`: the ring and its numbers, spoken once.
    public static func reduceRingSemantics(_ today: Int, _ limit: Int) -> String {
        String(format: localized(.reduceRingSemantics), locale: .current, today, limit)
    }

    /// `smoking_reduce_under_body`.
    public static func reduceUnderBody(_ remaining: Int) -> String {
        String(format: localized(.reduceUnderBody), locale: .current, remaining)
    }

    /// `smoking_reduce_week_full`: units and money.
    public static func reduceWeekFull(_ units: Int64, _ money: String) -> String {
        String(format: localized(.reduceWeekFull), locale: .current, units, money)
    }

    /// `smoking_reduce_week_money`: money only (a vape).
    public static func reduceWeekMoney(_ money: String) -> String {
        String(format: localized(.reduceWeekMoney), locale: .current, money)
    }
}

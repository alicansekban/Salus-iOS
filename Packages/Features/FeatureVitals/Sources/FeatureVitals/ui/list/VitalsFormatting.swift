// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsFormatting.kt` — every number, label and line the list writes, in one place.
//
// It is a new file on this side only in the sense that Android grew one too: iOS-M7 kept the same
// functions at the bottom of `VitalsListSections.swift`, and M15 gave them a file of their own on
// both platforms. Free functions and extensions rather than methods on a view, so what they write
// can be asserted in a test without rendering anything (`VitalsLocaleFormattingTests`).
//
// **`locale` is an argument, never `Locale.current`.** Android's `Locale.getDefault()` follows
// `setApplicationLocales`; nothing moves iOS's `Locale.current`, so the in-app pick only reaches a
// formatter if it is carried there — the shell publishes it as `\.locale` and every view below
// reads it from the environment.

import Foundation
import SalusModel

/// Measurement units, not translatable copy: kg, mmHg, mg/dL, mmol/L and bpm are written the same
/// way in every locale the app ships (`VitalsFormatting.kt:15-20`; `bpm` is
/// `BloodPressureEditorScreen.kt:149`).
enum VitalsUnits {
    static let kilograms = "kg"
    static let mmHg = "mmHg"
    static let mgDl = "mg/dL"
    static let mmolL = "mmol/L"
    static let bpm = "bpm"
}

/// `VitalsFormatting.kt:22`.
private let separator = " · "
/// `VitalsFormatting.kt:23`.
private let plus = "+"
/// U+2212, the typographic minus — it lines up with digits where a hyphen does not
/// (`VitalsFormatting.kt:25-26`).
private let minus = "−"

/// `VitalsFormatting.kt:28-29`.
func formatKg(_ kilograms: Double, locale: Locale) -> String {
    String(format: "%.1f kg", locale: locale, kilograms)
}

/// Systolic over diastolic, without a unit: the row and the chip append their own
/// (`VitalsFormatting.kt:31-33`).
func formatBloodPressure(_ item: VitalsListItem.BloodPressure, locale: Locale) -> String {
    String(format: "%lld/%lld", locale: locale, item.systolic, item.diastolic)
}

/// `VitalsFormatting.kt:35-38`.
func formatGlucose(_ value: Double, unit: GlucoseUnit, locale: Locale) -> String {
    switch unit {
    case .mgDl: String(format: "%.0f mg/dL", locale: locale, value)
    case .mmolL: String(format: "%.1f mmol/L", locale: locale, value)
    }
}

extension VitalsListItem {
    /// `VitalsFormatting.kt:40-45`.
    func headline(locale: Locale) -> String {
        switch self {
        case let .weight(item):
            formatKg(item.kilograms, locale: locale)

        case let .bloodPressure(item):
            "\(formatBloodPressure(item, locale: locale)) \(VitalsUnits.mmHg)"

        case let .glucose(item):
            formatGlucose(item.value, unit: item.unit, locale: locale)
        }
    }

    /// The signed change against the previous reading, in this row's own unit
    /// (`VitalsFormatting.kt:47-64`).
    func deltaText(locale: Locale) -> String? {
        guard let change = delta else { return nil }
        let magnitude = switch self {
        case .weight:
            String(format: "%.1f", locale: locale, abs(change))

        case .bloodPressure:
            String(format: "%.0f", locale: locale, abs(change))

        case let .glucose(item):
            switch item.unit {
            case .mgDl: String(format: "%.0f", locale: locale, abs(change))
            case .mmolL: String(format: "%.1f", locale: locale, abs(change))
            }
        }
        let sign = if change > 0 {
            plus
        } else if change < 0 {
            minus
        } else {
            ""
        }
        return sign + magnitude
    }

    /// Date · time · context, in one secondary line (`VitalsFormatting.kt:66-79`).
    func metaLine(locale: Locale) -> String {
        let context: String? = switch self {
        case .weight: nil
        case let .bloodPressure(item): item.pulse.map(VitalsStrings.pulseValue)
        case let .glucose(item): item.measurementContext?.vitalsLabel
        }
        return [
            measuredAt.formatted(pattern: datePattern, locale: locale),
            measuredAt.formatted(pattern: timePattern, locale: locale),
            context
        ]
        .compactMap(\.self)
        .joined(separator: separator)
    }

    /// Date · time of one reading, for the chart card header (`VitalsFormatting.kt:81-92`).
    ///
    /// ``metaLine(locale:)`` is the row's version of the same line; this one leaves the measurement
    /// context out, because the header already prints the value that context would qualify.
    func measuredAtLine(locale: Locale) -> String {
        measuredAt.formatted(pattern: datePattern, locale: locale)
            + separator
            + measuredAt.formatted(pattern: timePattern, locale: locale)
    }
}

extension VitalsUiState {
    /// The latest reading of `type` without its unit: the chart card's header tile prints the unit
    /// in its own slot. `nil` when that type has nothing recorded in the selected window, which is
    /// where the caller falls back to the em dash (`VitalsFormatting.kt:94-108`).
    func latestValue(_ type: VitalType, locale: Locale) -> String? {
        switch type {
        case .weight:
            latestKilograms.map { String(format: "%.1f", locale: locale, $0) }

        case .bloodPressure:
            latestBloodPressure.map { formatBloodPressure($0, locale: locale) }

        case .bloodGlucose:
            latestGlucose.map { entry in
                switch entry.unit {
                case .mgDl: String(format: "%.0f", locale: locale, entry.value)
                case .mmolL: String(format: "%.1f", locale: locale, entry.value)
                }
            }
        }
    }

    /// Prints a summary number the way the charted series prints its own values
    /// (`VitalsFormatting.kt:140-148`).
    func formatMetric(_ value: Double, locale: Locale) -> String {
        switch selectedType {
        case .weight:
            String(format: "%.1f", locale: locale, value)

        case .bloodPressure:
            String(format: "%.0f", locale: locale, value)

        case .bloodGlucose:
            switch glucoseUnit {
            case .mgDl: String(format: "%.0f", locale: locale, value)
            case .mmolL: String(format: "%.1f", locale: locale, value)
            }
        }
    }
}

extension VitalType {
    /// `VitalsFormatting.kt:116-120`.
    var vitalsLabel: String {
        switch self {
        case .weight: VitalsStrings.typeWeight
        case .bloodPressure: VitalsStrings.typeBloodPressure
        case .bloodGlucose: VitalsStrings.typeGlucose
        }
    }

    /// Short form for the KPI chips, where the value needs the room the full name would take
    /// (`VitalsFormatting.kt:122-127`).
    var vitalsKpiLabel: String {
        switch self {
        case .weight: VitalsStrings.kpiWeight
        case .bloodPressure: VitalsStrings.kpiBloodPressure
        case .bloodGlucose: VitalsStrings.kpiGlucose
        }
    }

    /// `VitalsFormatting.kt:129-133`.
    func vitalsUnitLabel(glucoseUnit: GlucoseUnit) -> String {
        switch self {
        case .weight: VitalsUnits.kilograms
        case .bloodPressure: VitalsUnits.mmHg
        case .bloodGlucose: glucoseUnit.vitalsUnitLabel
        }
    }
}

extension GlucoseUnit {
    /// `VitalsFormatting.kt:135-138`.
    var vitalsUnitLabel: String {
        switch self {
        case .mgDl: VitalsUnits.mgDl
        case .mmolL: VitalsUnits.mmolL
        }
    }
}

extension MeasurementContext {
    /// `VitalsFormatting.kt:150-155`.
    var vitalsLabel: String {
        switch self {
        case .fasting: VitalsStrings.contextFasting
        case .postMeal: VitalsStrings.contextPostMeal
        case .bedtime: VitalsStrings.contextBedtime
        case .random: VitalsStrings.contextRandom
        }
    }
}

extension ChartRange {
    /// `VitalsFormatting.kt:157-162`.
    var vitalsLabel: String {
        switch self {
        case .week: VitalsStrings.rangeWeek
        case .month: VitalsStrings.rangeMonth
        case .quarter: VitalsStrings.rangeQuarter
        case .year: VitalsStrings.rangeYear
        }
    }
}

/// `VitalsFormatting.kt:69`, `:88`.
private let datePattern = "d MMM yyyy"
/// `VitalsFormatting.kt:70`, `:89`.
private let timePattern = "HH:mm"

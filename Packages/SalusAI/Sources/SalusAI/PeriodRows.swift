// Ported 1:1 from Android
// `core/ai/src/main/kotlin/com/alicansekban/salus/core/ai/PeriodRows.kt`.

import SalusModel

/// The individual records of one period, reduced to the fields a printed table shows.
///
/// Deliberately not the same payload as `HealthPeriodStats`, and the difference is a privacy
/// boundary rather than a convenience: the aggregated statistics are the only thing that ever
/// reaches the model, while these rows never leave the device — they are laid out into a PDF the
/// user chooses to share themselves.
///
/// Free-form text is absent by construction here too. There is no note, no medication name and
/// no identifier on any of these types, only numbers, enum values and local days, so a report
/// cannot print something the user typed into a note field.
public struct HealthPeriodRows: Equatable, Sendable {
    public let bloodPressure: [BloodPressureRow]
    public let glucose: [GlucoseRow]
    public let weight: [WeightRow]

    public init(
        bloodPressure: [BloodPressureRow],
        glucose: [GlucoseRow],
        weight: [WeightRow]
    ) {
        self.bloodPressure = bloodPressure
        self.glucose = glucose
        self.weight = weight
    }

    /// True when the period holds no measurement at all, whatever the dose log says.
    public var isEmpty: Bool {
        bloodPressure.isEmpty && glucose.isEmpty && weight.isEmpty
    }

    public static let empty = HealthPeriodRows(bloodPressure: [], glucose: [], weight: [])
}

/// One blood-pressure reading.
///
/// - `epochDay`: local day the reading falls on, cut in the zone the period was read with, so the
///   table's dates match the days the rest of the app buckets the reading into.
/// - `diastolic`: nil for a reading stored without one; the table prints a dash.
public struct BloodPressureRow: Equatable, Sendable {
    public let epochDay: Int
    public let systolic: Double
    public let diastolic: Double?
    public let pulse: Double?

    public init(epochDay: Int, systolic: Double, diastolic: Double?, pulse: Double?) {
        self.epochDay = epochDay
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
    }
}

/// One glucose reading, in the canonical mg/dL the column is stored in.
public struct GlucoseRow: Equatable, Sendable {
    public let epochDay: Int
    public let mgDl: Double
    public let context: MeasurementContext?

    public init(epochDay: Int, mgDl: Double, context: MeasurementContext?) {
        self.epochDay = epochDay
        self.mgDl = mgDl
        self.context = context
    }
}

/// One weight reading, in kilograms.
public struct WeightRow: Equatable, Sendable {
    public let epochDay: Int
    public let kilograms: Double

    public init(epochDay: Int, kilograms: Double) {
        self.epochDay = epochDay
        self.kilograms = kilograms
    }
}

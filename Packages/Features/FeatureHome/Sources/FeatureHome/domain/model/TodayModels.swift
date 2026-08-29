// Ported 1:1 from Android
// `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/domain/model/TodayModels.kt`.
//
// The dashboard's own read models: everything the Home screen draws, already joined and
// status-resolved, and nothing it does not. They are deliberately *not* the feature domains'
// types — a `Medication` plus its schedules, an `Appointment`, a `CyclePeriod` and a
// `VitalsMeasurement` would make Home depend on four feature packages, which the "features never
// depend on each other" rule forbids on both platforms. The join happens in `data/`, over
// `SalusDatabase`'s records, and only these five types leave it.
//
// Kotlin's `data class` gives `equals`/`hashCode`; the Swift twins are `Equatable, Hashable,
// Sendable` structs. `Sendable` is what lets a whole `TodayOverview` cross from the repository's
// stream to the `@MainActor` ViewModel.

import SalusModel

/// What happened to one of today's dose slots (`TodayModels.kt:5-11`).
public enum DoseStatus: Sendable {
    case taken
    case snoozed
    case pending
    /// Derived, never persisted: the slot passed the grace window without a TAKEN log.
    case missed
}

/// One dose slot on the dashboard (`TodayModels.kt:13-20`).
public struct TodayDose: Equatable, Hashable, Sendable {
    public let scheduleId: String
    public let medicationId: String
    public let medicationName: String
    public let minuteOfDay: Int
    public let doseAmount: Double
    public let status: DoseStatus

    public init(
        scheduleId: String,
        medicationId: String,
        medicationName: String,
        minuteOfDay: Int,
        doseAmount: Double,
        status: DoseStatus
    ) {
        self.scheduleId = scheduleId
        self.medicationId = medicationId
        self.medicationName = medicationName
        self.minuteOfDay = minuteOfDay
        self.doseAmount = doseAmount
        self.status = status
    }
}

/// One of the next few appointments (`TodayModels.kt:22-28`). The start stays an instant plus its
/// zone, exactly as it is stored: a day would lose the time and a `Date` alone would lose the zone
/// the appointment was made in.
public struct UpcomingAppointment: Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let doctorName: String?
    public let startsAtEpochMs: Int64
    public let timeZoneId: String

    public init(id: String, title: String, doctorName: String?, startsAtEpochMs: Int64, timeZoneId: String) {
        self.id = id
        self.title = title
        self.doctorName = doctorName
        self.startsAtEpochMs = startsAtEpochMs
        self.timeZoneId = timeZoneId
    }
}

/// The cycle card's whole content (`TodayModels.kt:30-39`).
public struct CycleSnapshot: Equatable, Hashable, Sendable {
    /// 1-based day within the current cycle, `nil` when there is no recorded period yet.
    public let cycleDay: Int?
    public let isPeriodOpen: Bool
    /// Coarse average of the gaps between recorded period starts, for the dashboard progress bar
    /// only. Real predictions live in `FeatureCycle`'s `CyclePredictor`.
    public let averageCycleLengthDays: Int?

    public init(cycleDay: Int?, isPeriodOpen: Bool, averageCycleLengthDays: Int? = nil) {
        self.cycleDay = cycleDay
        self.isPeriodOpen = isPeriodOpen
        self.averageCycleLengthDays = averageCycleLengthDays
    }
}

/// The vitals card's whole content (`TodayModels.kt:41-49`).
public struct VitalsSnapshot: Equatable, Hashable, Sendable {
    public let latestWeightKg: Double?
    /// Oldest → newest weight values of the last 30 days, for the sparkline.
    public let weightTrend: [Float]
    public let latestSystolic: Double?
    public let latestDiastolic: Double?
    /// Always the stored mg/dL number; `glucoseUnit` is what the screen converts for.
    public let latestGlucoseMgdl: Double?
    public let glucoseUnit: GlucoseUnit

    public init(
        latestWeightKg: Double?,
        weightTrend: [Float],
        latestSystolic: Double?,
        latestDiastolic: Double?,
        latestGlucoseMgdl: Double?,
        glucoseUnit: GlucoseUnit
    ) {
        self.latestWeightKg = latestWeightKg
        self.weightTrend = weightTrend
        self.latestSystolic = latestSystolic
        self.latestDiastolic = latestDiastolic
        self.latestGlucoseMgdl = latestGlucoseMgdl
        self.glucoseUnit = glucoseUnit
    }
}

/// One emission of the dashboard (`TodayModels.kt:51-56`).
///
/// `cycle` and `vitals` are **non-optional**: an empty database still produces a snapshot with
/// `nil` fields, so the screen draws its empty lines rather than branching on a missing card.
public struct TodayOverview: Equatable, Hashable, Sendable {
    public let doses: [TodayDose]
    public let appointments: [UpcomingAppointment]
    public let cycle: CycleSnapshot
    public let vitals: VitalsSnapshot

    public init(
        doses: [TodayDose],
        appointments: [UpcomingAppointment],
        cycle: CycleSnapshot,
        vitals: VitalsSnapshot
    ) {
        self.doses = doses
        self.appointments = appointments
        self.cycle = cycle
        self.vitals = vitals
    }
}

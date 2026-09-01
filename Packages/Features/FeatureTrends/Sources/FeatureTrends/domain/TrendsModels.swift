// Ported 1:1 from Android
// `feature/trends/src/main/kotlin/com/alicansekban/salus/feature/trends/domain/TrendsModels.kt`.

import SalusModel

/// The windows the screen can be looking at, each expressed as an inclusive number of local days
/// ending on today (`TrendsModels.kt:18-23`).
///
/// They are deliberately coarse. Every analysis this screen produces needs weeks of records
/// before it can say anything honest, so a "last 7 days" option would exist only to show empty
/// cards.
public enum TrendsRange: Int, CaseIterable, Equatable, Hashable, Sendable {
    case month = 30
    case quarter = 90
    case halfYear = 180
    case year = 365

    /// `TrendsModels.kt:19-22` — the inclusive number of days the window spans.
    public var days: Int { rawValue }
}

/// One stored measurement, reduced to the numbers the analyses need (`TrendsModels.kt:38-45`).
///
/// Note text, medication names and the profile are never carried: this type is the outer edge of
/// what `TrendsDataReader` is allowed to hand out, so a field that does not exist here is a field
/// no analysis can accidentally start depending on.
public struct TrendMeasurement: Equatable, Hashable, Sendable {
    public let type: VitalType
    /// The local day the measurement falls on, in the zone it was bucketed with.
    public let epochDay: Int
    /// Local hour * 60 + minute, so time-of-day analyses need no instant maths.
    public let minuteOfDay: Int
    /// Weight in kg, systolic in mmHg, or glucose in mg/dL, by `type`.
    public let primary: Double
    /// Diastolic for blood pressure; `nil` for every other type.
    public let secondary: Double?
    /// Pulse for blood pressure; `nil` for every other type.
    public let tertiary: Double?

    public init(
        type: VitalType,
        epochDay: Int,
        minuteOfDay: Int,
        primary: Double,
        secondary: Double?,
        tertiary: Double?
    ) {
        self.type = type
        self.epochDay = epochDay
        self.minuteOfDay = minuteOfDay
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
    }
}

/// One logged dose and whether it was marked taken (`TrendsModels.kt:55`).
///
/// Only these two facts are read: the medication the dose belonged to is never carried, because
/// the one thing this screen asks of medication data is how many of the doses the user wrote
/// down were ticked off. A dose that was never logged has no row here at all, which is why every
/// ratio built on this type has to be described in terms of *recorded* doses.
public struct TrendDose: Equatable, Hashable, Sendable {
    public let epochDay: Int
    public let taken: Bool

    public init(epochDay: Int, taken: Bool) {
        self.epochDay = epochDay
        self.taken = taken
    }
}

/// Everything one `TrendsRange` worth of records amounts to, before any analysis runs
/// (`TrendsModels.kt:57-61`).
public struct TrendsRecords: Equatable, Sendable {
    public let measurements: [TrendMeasurement]
    public let doses: [TrendDose]

    public init(measurements: [TrendMeasurement], doses: [TrendDose]) {
        self.measurements = measurements
        self.doses = doses
    }

    /// True when the window holds nothing at all — neither a measurement nor a logged dose
    /// (`TrendsModels.kt:64-65`).
    public var isEmpty: Bool {
        measurements.isEmpty && doses.isEmpty
    }
}

/// What the trends screen has to show, for one load (`TrendsModels.kt:74-115`).
///
/// `locked` is a first-class member rather than a flag next to the data, because a free user's
/// load never reads a single record: the repository answers `locked` before touching the
/// database, so there is no half-populated state for the screen to render.
public enum TrendsData: Equatable, Sendable {
    /// Not entitled. The screen shows the locked body and offers the paywall
    /// (`TrendsModels.kt:77`).
    case locked

    /// Entitled, but the window holds no records to analyse (`TrendsModels.kt:80`).
    case empty

    /// Entitled, with records (`TrendsModels.kt:100-105`).
    ///
    /// One field per analysis, added task by task. Each is nullable, and `nil` is the only way a
    /// card is left out: an analysis that has nothing to say produces no model at all rather than
    /// an empty one, so a card with an empty chart in it cannot be built by mistake. Task 1 ships
    /// the empty shell; Task 2's `timeOfDay`, Task 3's `overlay`, Task 4's `doseWeeks` and Task
    /// 5's `summaries` each land on it as their own task.
    case ready(_ ready: TrendsReady)

    /// The records could not be read (`TrendsModels.kt:115`).
    ///
    /// Carries no message on purpose: the underlying text is an untranslated platform failure
    /// kept for the log. Every line this screen shows is ours and localized, and the only thing
    /// the user can do about it is try again.
    case failed
}

/// The body of a `TrendsData.ready` answer (`TrendsModels.kt:100-105`).
///
/// One field per analysis. Task 1 ships the skeleton empty; each later task adds the field its
/// analysis fills, so the type grows with the milestone rather than declaring fields for analysis
/// modules that do not exist yet. `Equatable` and `Sendable` by construction: every field that
/// lands is a plain value type.
public struct TrendsReady: Equatable, Sendable {
    public init() {}
}

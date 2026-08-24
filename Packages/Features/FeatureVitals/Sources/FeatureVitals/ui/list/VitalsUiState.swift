// Ported 1:1 from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsUiState.kt`.
//
// All three `VitalsListItem` cases are here, not only the weight one M2 can produce: the state is
// the contract the screen draws against, and porting a sealed hierarchy in halves would leave the
// screen's `when` incomplete and the M7 diff touching this file for shape rather than for
// behaviour.
//
// `ImmutableList` is dropped rather than imitated — a Swift `Array` in a `struct` already is what
// `kotlinx.collections.immutable` promises Compose (`ChartUiModel.swift` records the same ruling).

import SalusModel
import SalusUI

/// How far back the list and the chart reach (`VitalsUiState.kt:11-16`).
///
/// `CaseIterable` is Kotlin's `entries`, which is what the range selector iterates.
public enum ChartRange: CaseIterable, Equatable, Hashable, Sendable {
    case week
    case month
    case quarter
    case year

    /// `VitalsUiState.kt:12-15`.
    public var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
        }
    }
}

/// One row of the list (`VitalsUiState.kt:18-47`).
///
/// Kotlin's `sealed interface` with three `data class` members and three shared properties is a
/// Swift enum with three payload cases: same closed set, same value semantics, and the shared
/// properties become computed ones so a call site reads `item.id` exactly as it does there.
public enum VitalsListItem: Equatable, Hashable, Sendable, Identifiable {
    case weight(Weight)
    case bloodPressure(BloodPressure)
    case glucose(Glucose)

    /// `VitalsUiState.kt:23-28`.
    public struct Weight: Equatable, Hashable, Sendable {
        public let id: String
        public let measuredAt: LocalDateTime
        public let kilograms: Double
        public let note: String?

        public init(id: String, measuredAt: LocalDateTime, kilograms: Double, note: String?) {
            self.id = id
            self.measuredAt = measuredAt
            self.kilograms = kilograms
            self.note = note
        }
    }

    /// `VitalsUiState.kt:30-37`.
    public struct BloodPressure: Equatable, Hashable, Sendable {
        public let id: String
        public let measuredAt: LocalDateTime
        public let systolic: Int
        public let diastolic: Int
        public let pulse: Int?
        public let note: String?

        public init(
            id: String,
            measuredAt: LocalDateTime,
            systolic: Int,
            diastolic: Int,
            pulse: Int?,
            note: String?
        ) {
            self.id = id
            self.measuredAt = measuredAt
            self.systolic = systolic
            self.diastolic = diastolic
            self.pulse = pulse
            self.note = note
        }
    }

    /// `VitalsUiState.kt:39-46`.
    public struct Glucose: Equatable, Hashable, Sendable {
        public let id: String
        public let measuredAt: LocalDateTime
        public let value: Double
        public let unit: GlucoseUnit
        public let measurementContext: MeasurementContext?
        public let note: String?

        public init(
            id: String,
            measuredAt: LocalDateTime,
            value: Double,
            unit: GlucoseUnit,
            measurementContext: MeasurementContext?,
            note: String?
        ) {
            self.id = id
            self.measuredAt = measuredAt
            self.value = value
            self.unit = unit
            self.measurementContext = measurementContext
            self.note = note
        }
    }

    /// `VitalsUiState.kt:19`. Also the `Identifiable` conformance the list is keyed by, which is
    /// what `items(items = state.entries, key = { it.id })` does on Android (`VitalsScreen.kt:238`).
    public var id: String {
        switch self {
        case let .weight(item): item.id
        case let .bloodPressure(item): item.id
        case let .glucose(item): item.id
        }
    }

    /// `VitalsUiState.kt:20`.
    public var measuredAt: LocalDateTime {
        switch self {
        case let .weight(item): item.measuredAt
        case let .bloodPressure(item): item.measuredAt
        case let .glucose(item): item.measuredAt
        }
    }

    /// `VitalsUiState.kt:21`.
    public var note: String? {
        switch self {
        case let .weight(item): item.note
        case let .bloodPressure(item): item.note
        case let .glucose(item): item.note
        }
    }

    /// `VitalsScreen.kt:347-351` — which editor a row opens.
    public var vitalType: VitalType {
        switch self {
        case .weight: .weight
        case .bloodPressure: .bloodPressure
        case .glucose: .bloodGlucose
        }
    }
}

/// What the vitals list draws (`VitalsUiState.kt:49-61`).
///
/// Deliberately **not** `Equatable`: `chart` is a `ChartUiModel`, which carries two closures and is
/// not comparable (`ChartUiModel.swift:29-33`). Kotlin's `data class` equality exists to conflate
/// `StateFlow` emissions; an `@Observable` property needs no such thing.
public struct VitalsUiState: Sendable {
    public var isLoading: Bool
    public var selectedType: VitalType
    public var entries: [VitalsListItem]
    public var chart: ChartUiModel?
    public var selectedRange: ChartRange
    public var latestKilograms: Double?
    public var latestBloodPressure: VitalsListItem.BloodPressure?
    public var latestGlucose: VitalsListItem.Glucose?
    public var glucoseUnit: GlucoseUnit
    /// The entry the delete confirmation is about, or nil when no dialog is open
    /// (`VitalsUiState.kt:59-60`).
    public var pendingDeleteId: String?

    public init(
        isLoading: Bool = true,
        selectedType: VitalType = .weight,
        entries: [VitalsListItem] = [],
        chart: ChartUiModel? = nil,
        selectedRange: ChartRange = .month,
        latestKilograms: Double? = nil,
        latestBloodPressure: VitalsListItem.BloodPressure? = nil,
        latestGlucose: VitalsListItem.Glucose? = nil,
        glucoseUnit: GlucoseUnit = .mgDl,
        pendingDeleteId: String? = nil
    ) {
        self.isLoading = isLoading
        self.selectedType = selectedType
        self.entries = entries
        self.chart = chart
        self.selectedRange = selectedRange
        self.latestKilograms = latestKilograms
        self.latestBloodPressure = latestBloodPressure
        self.latestGlucose = latestGlucose
        self.glucoseUnit = glucoseUnit
        self.pendingDeleteId = pendingDeleteId
    }
}

/// Everything the screen can ask the ViewModel to do (`VitalsUiState.kt:63-74`).
public enum VitalsEvent: Equatable, Sendable {
    case typeSelected(VitalType)
    case rangeSelected(ChartRange)
    /// Opens the confirmation; nothing is deleted until it is confirmed (`VitalsUiState.kt:68-69`).
    case deleteRequested(String)
    case deleteDismissed
    case deleteConfirmed
}

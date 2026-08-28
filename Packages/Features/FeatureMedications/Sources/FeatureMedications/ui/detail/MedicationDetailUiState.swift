// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/ui/detail/MedicationDetailUiState.kt`.
//
// `ImmutableList` is dropped rather than imitated — a Swift `Array` in a `struct` already is what
// `kotlinx.collections.immutable` promises Compose (`MedicationsUiState.swift` records the same
// ruling for the list, and `ChartUiModel`/`VitalsUiState`/`AppointmentsUiState` before it).

import SalusModel

/// One past dose, newest first; the detail screen shows the last 30 days
/// (`MedicationDetailUiState.kt:9-15`).
public struct IntakeHistoryItem: Equatable, Hashable, Sendable {
    public let epochDay: Int
    public let minuteOfDay: Int
    public let status: IntakeStatus
    public let doseAmount: Double

    public init(epochDay: Int, minuteOfDay: Int, status: IntakeStatus, doseAmount: Double) {
        self.epochDay = epochDay
        self.minuteOfDay = minuteOfDay
        self.status = status
        self.doseAmount = doseAmount
    }
}

/// What one medication's detail screen draws (`MedicationDetailUiState.kt:17-27`).
public struct MedicationDetailUiState: Equatable, Sendable {
    public var isLoading: Bool
    /// Null once the medication is gone — the screen closes itself rather than showing a blank
    /// (`MedicationDetailUiState.kt:19-20`).
    public var medication: Medication?
    public var schedules: [MedicationSchedule]
    public var history: [IntakeHistoryItem]
    public var showDeleteConfirm: Bool

    /// Supply is hidden entirely when stock tracking is off (`MedicationDetailUiState.kt:25-26`).
    public var showSupply: Bool { medication?.stockCount != nil }

    public init(
        isLoading: Bool = true,
        medication: Medication? = nil,
        schedules: [MedicationSchedule] = [],
        history: [IntakeHistoryItem] = [],
        showDeleteConfirm: Bool = false
    ) {
        self.isLoading = isLoading
        self.medication = medication
        self.schedules = schedules
        self.history = history
        self.showDeleteConfirm = showDeleteConfirm
    }
}

/// Everything the screen can ask the ViewModel to do (`MedicationDetailUiState.kt:29-42`).
public enum MedicationDetailEvent: Equatable, Sendable {
    /// Opens the confirmation; nothing is deleted until it is confirmed
    /// (`MedicationDetailUiState.kt:30-31`).
    case deleteClicked

    case deleteDismissed

    case deleteConfirmed

    /// Written immediately, like the cycle reminder switch — not an editor field. One tap
    /// silences a medication for now; the medication stays active and its doses stay on Home.
    ///
    /// (`MedicationDetailUiState.kt:37-41`.)
    case remindersToggled(Bool)
}

/// How far back the history section looks (`MedicationDetailUiState.kt:44-45`).
///
/// Internal rather than `public`, unlike Kotlin's top-level `const val`: nothing outside this
/// package reads it, and the `@testable import` the suite already uses reaches it as it is.
let historyWindowDays = 30

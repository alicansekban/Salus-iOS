// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/ui/detail/MedicationDetailUiState.kt`.
//
// `ImmutableList` is dropped rather than imitated — a Swift `Array` in a `struct` already is what
// `kotlinx.collections.immutable` promises Compose (`MedicationsUiState.swift` records the same
// ruling for the list, and `ChartUiModel`/`VitalsUiState`/`AppointmentsUiState` before it).

import SalusModel

/// One past dose, newest first; the detail screen shows the last 30 days
/// (`MedicationDetailUiState.kt:10-16`).
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

/// What one medication's detail screen draws (`MedicationDetailUiState.kt:18-40`).
public struct MedicationDetailUiState: Equatable, Sendable {
    public var isLoading: Bool
    /// Null once the medication is gone — the screen closes itself rather than showing a blank
    /// (`MedicationDetailUiState.kt:20-21`).
    public var medication: Medication?
    public var schedules: [MedicationSchedule]
    public var history: [IntakeHistoryItem]
    public var showDeleteConfirm: Bool

    /// Whole days the remaining stock covers, rounded down; nil when stock is not tracked or when no
    /// dose leaves the box on a given day (`MedicationDetailUiState.kt:25-29`).
    public var daysOfSupply: Int?

    /// Today's earliest unrecorded dose whose time has passed; what "record now" writes
    /// (`MedicationDetailUiState.kt:30-31`).
    public var pendingDose: PendingDose?

    /// Today, which the seven-day rhythm row counts back from. It comes from the view model's clock
    /// rather than from the view: a screen never asks the machine what day it is
    /// (`MedicationDetailUiState.kt:32-36`).
    public var todayEpochDay: Int

    /// Supply is hidden entirely when stock tracking is off (`MedicationDetailUiState.kt:38-39`).
    public var showSupply: Bool { medication?.stockCount != nil }

    public init(
        isLoading: Bool = true,
        medication: Medication? = nil,
        schedules: [MedicationSchedule] = [],
        history: [IntakeHistoryItem] = [],
        showDeleteConfirm: Bool = false,
        daysOfSupply: Int? = nil,
        pendingDose: PendingDose? = nil,
        todayEpochDay: Int = 0
    ) {
        self.isLoading = isLoading
        self.medication = medication
        self.schedules = schedules
        self.history = history
        self.showDeleteConfirm = showDeleteConfirm
        self.daysOfSupply = daysOfSupply
        self.pendingDose = pendingDose
        self.todayEpochDay = todayEpochDay
    }
}

/// Everything the screen can ask the ViewModel to do (`MedicationDetailUiState.kt:42-61`).
public enum MedicationDetailEvent: Equatable, Sendable {
    /// Opens the confirmation; nothing is deleted until it is confirmed
    /// (`MedicationDetailUiState.kt:43-44`).
    case deleteClicked

    case deleteDismissed

    case deleteConfirmed

    /// Written immediately, like the cycle reminder switch — not an editor field. One tap
    /// silences a medication for now; the medication stays active and its doses stay on Home.
    ///
    /// (`MedicationDetailUiState.kt:50-54`.)
    case remindersToggled(Bool)

    /// Records the dose that is due now. Goes through the same use case as the notification action,
    /// so this screen is not a second write path (`MedicationDetailUiState.kt:56-60`).
    case takeDoseClicked(PendingDose)
}

/// How far back the history section looks (`MedicationDetailUiState.kt:63-64`).
///
/// Internal rather than `public`, unlike Kotlin's top-level `const val`: nothing outside this
/// package reads it, and the `@testable import` the suite already uses reaches it as it is.
let historyWindowDays = 30

/// How many days the rhythm row draws, newest last (`MedicationDetailUiState.kt:66-67`).
let rhythmWindowDays = 7

// Ported 1:1 from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/
// medications/ui/editor/MedicationEditorViewModel.kt`.
//
// `MutableStateFlow` + `update { it.copy(…) }` becomes an `@Observable` `state` mutated in place,
// and `viewModelScope.launch` becomes `Task { }` inside a `@MainActor` type —
// `AppointmentEditorViewModel` set both spellings, and this file follows them member for member.
//
// `formatNumber` has no twin here: the same "whole numbers lose their .0" rule already lives in
// `MedicationFormatting.swift` as `formatAmount`, which is the single copy this port keeps of the
// three Android spells (that file's header records the ruling).
//
// One arm has no Kotlin twin, and it is the `getMedication` failure. Kotlin's repository does not
// throw, so its `load` has exactly two outcomes; the iOS protocol declares `async throws` (a
// database read can fail, and the mapper can reject an unreadable `form`), and a failed read leaves
// this editor with nothing to edit. It is therefore treated as the medication not being there —
// `navigator.pop()`, the same exit Kotlin takes for a missing id — rather than as a blank form the
// user could save over a row they never saw.

import Foundation
import Observation
import SalusCommon
import SalusModel
import SalusNavigation
import SalusUI

/// Drives the medication editor, new or existing (`MedicationEditorViewModel.kt:24-231`).
@MainActor
@Observable
public final class MedicationEditorViewModel {
    /// `MedicationEditorViewModel.kt:34-35` — what the screen draws.
    public private(set) var state = MedicationEditorUiState()

    private let medicationId: String?
    private let repository: any MedicationRepository
    private let saveMedication: SaveMedicationUseCase
    private let deleteMedication: DeleteMedicationUseCase
    private let idGenerator: any IdGenerator
    private let navigator: Navigator
    private let undoableDelete: UndoableDelete

    /// `MedicationEditorViewModel.kt:229` — where a new medication's one dose row starts.
    private static let defaultDoseMinutes = 8 * 60

    /// The existing medication's load. Boxed so `deinit` can cancel it — see `CancellationBox`.
    private let loadTask = CancellationBox()

    public init(
        medicationId: String?,
        repository: any MedicationRepository,
        saveMedication: SaveMedicationUseCase,
        deleteMedication: DeleteMedicationUseCase,
        clock: any SalusClock,
        idGenerator: any IdGenerator,
        navigator: Navigator,
        undoableDelete: UndoableDelete
    ) {
        self.medicationId = medicationId
        self.repository = repository
        self.saveMedication = saveMedication
        self.deleteMedication = deleteMedication
        self.idGenerator = idGenerator
        self.navigator = navigator
        self.undoableDelete = undoableDelete

        // `MedicationEditorViewModel.kt:37-51`.
        guard let medicationId else {
            state.isLoading = false
            state.isNew = true
            state.startDateEpochDay = clock.todayEpochDay()
            state.doseTimes = [
                DoseTimeUi(existingScheduleId: nil, minuteOfDay: Self.defaultDoseMinutes, amountInput: "1")
            ]
            return
        }
        loadTask.replace(with: Task { [weak self, repository] in
            let existing = try? await repository.getMedication(id: medicationId)
            guard let self else { return }
            guard let existing else {
                // `MedicationEditorViewModel.kt:55-58` — an id that resolves to nothing has no
                // form to fill in, so the editor closes rather than offering an empty one.
                navigator.pop()
                return
            }
            apply(existing)
        })
    }

    deinit {
        loadTask.cancel()
    }

    /// `MedicationEditorViewModel.kt:53-79`.
    private func apply(_ existing: MedicationWithSchedules) {
        let medication = existing.medication
        let first = existing.schedules.first
        state.isLoading = false
        state.isNew = false
        state.name = medication.name
        state.form = medication.form
        state.strengthValueInput = medication.strengthValue.map(formatAmount) ?? ""
        state.strengthUnitInput = medication.strengthUnit ?? ""
        state.instructions = medication.instructions ?? ""
        state.stockCountInput = medication.stockCount.map(formatAmount) ?? ""
        state.stockThresholdInput = medication.stockThreshold.map(formatAmount) ?? ""
        state.startDateEpochDay = medication.startDateEpochDay
        state.endDateEpochDay = medication.endDateEpochDay
        state.recurrence = first?.recurrence ?? .daily
        state.daysOfWeekMask = first?.daysOfWeekMask ?? 0
        state.intervalDaysInput = String(first?.intervalDays ?? 2)
        state.doseTimes = existing.schedules
            .sorted { $0.timeOfDayMinutes < $1.timeOfDayMinutes }
            .map { schedule in
                DoseTimeUi(
                    existingScheduleId: schedule.id,
                    minuteOfDay: schedule.timeOfDayMinutes,
                    amountInput: formatAmount(schedule.doseAmount)
                )
            }
    }

    // Kotlin's `when (event)` has twenty arms and the switch below is its twin, arm for arm.
    // Splitting it to get under the complexity threshold would invent a dispatch layer Android does
    // not have, and would put the rule above the 1:1 shape the port exists for — so the rule is
    // waived here rather than the shape bent, exactly as `MedicationsModule.swift` waives
    // `function_parameter_count`.
    // swiftlint:disable cyclomatic_complexity

    /// `MedicationEditorViewModel.kt:81-155`.
    ///
    /// Which events clear `error` is Kotlin's list and not a rule to generalise: the eight that do
    /// are the eight whose fields a `SaveMedicationUseCase.Result` can name. Typing a strength or a
    /// stock count cannot fix any of the five failures, so it must not wipe the message that is
    /// still true.
    public func onEvent(_ event: MedicationEditorEvent) {
        switch event {
        case let .nameChanged(value):
            state.name = value
            state.error = nil

        case let .formSelected(value):
            state.form = value

        case let .strengthValueChanged(value):
            state.strengthValueInput = value

        case let .strengthUnitChanged(value):
            state.strengthUnitInput = value

        case let .instructionsChanged(value):
            state.instructions = value

        case let .stockCountChanged(value):
            state.stockCountInput = value

        case let .stockThresholdChanged(value):
            state.stockThresholdInput = value

        case let .startDateSelected(epochDay):
            state.startDateEpochDay = epochDay
            state.error = nil

        case let .endDateSelected(epochDay):
            state.endDateEpochDay = epochDay
            state.error = nil

        case let .recurrenceSelected(value):
            state.recurrence = value
            state.error = nil

        case let .dayOfWeekToggled(index):
            state.daysOfWeekMask ^= (1 << index)
            state.error = nil

        case let .intervalDaysChanged(value):
            state.intervalDaysInput = value
            state.error = nil

        case let .doseTimeAdded(minuteOfDay):
            // `MedicationEditorViewModel.kt:122-131` — appended, then sorted, and deliberately not
            // de-duplicated: two rows at the same minute are two doses, which is what a split dose
            // looks like.
            state.doseTimes.append(
                DoseTimeUi(existingScheduleId: nil, minuteOfDay: minuteOfDay, amountInput: "1")
            )
            state.doseTimes.sort { $0.minuteOfDay < $1.minuteOfDay }
            state.error = nil

        case let .doseTimeChanged(index, minuteOfDay):
            // The three index-carrying events all check the range first, which is what Kotlin's
            // `mapIndexed` / `filterIndexed` do implicitly: an index that no longer names a row
            // changes nothing. A Swift subscript would trap instead — the guard is the translation
            // of that "nothing", not a new rule.
            guard state.doseTimes.indices.contains(index) else { return }
            state.doseTimes[index].minuteOfDay = minuteOfDay

        case let .doseAmountChanged(index, value):
            guard state.doseTimes.indices.contains(index) else { return }
            state.doseTimes[index].amountInput = value

        case let .doseTimeRemoved(index):
            guard state.doseTimes.indices.contains(index) else { return }
            state.doseTimes.remove(at: index)
            state.error = nil

        case .saveClicked:
            save()

        case .deleteClicked:
            state.showDeleteConfirm = true

        case .deleteDismissed:
            state.showDeleteConfirm = false

        case .deleteConfirmed:
            delete()
        }
    }

    // swiftlint:enable cyclomatic_complexity

    /// `MedicationEditorViewModel.kt:157-193`.
    ///
    /// The form is read *before* the task starts, as Kotlin reads `_state.value` before `launch`:
    /// what is saved is what was on screen when the button was tapped.
    private func save() {
        let current = state
        let id = medicationId ?? idGenerator.newId()
        let medication = Medication(
            id: id,
            name: current.name,
            form: current.form,
            strengthValue: Self.decimal(current.strengthValueInput),
            strengthUnit: Self.blankToNil(current.strengthUnitInput),
            instructions: Self.blankToNil(current.instructions),
            stockCount: Self.decimal(current.stockCountInput),
            stockThreshold: Self.decimal(current.stockThresholdInput),
            startDateEpochDay: current.startDateEpochDay,
            endDateEpochDay: current.endDateEpochDay,
            isActive: true
            // `remindersEnabled` is left at its default and never sent from this form: the
            // repository preserves the stored value, so a stale editor cannot undo the toggle the
            // detail screen made (`MedicationRepository.setRemindersEnabled` is its one write path).
        )
        let schedules = buildSchedules(current, medicationId: id)

        Task { [weak self] in
            guard let self else { return }
            do {
                switch try await saveMedication(medication, schedules: schedules) {
                case .success:
                    navigator.pop()

                case .emptyName:
                    state.error = .emptyName

                case .noDoseTimes:
                    state.error = .noDoseTimes

                case .invalidInterval:
                    state.error = .invalidInterval

                case .noDaysSelected:
                    state.error = .noDaysSelected

                case .endBeforeStart:
                    state.error = .endBeforeStart
                }
            } catch {
                // No Kotlin twin, and the same arm `AppointmentEditorViewModel.save()` grew for the
                // same reason: the iOS repository declares `throws`, so a write failure can reach
                // here rather than ending quietly. The editor stays open with its form intact,
                // which is the only thing the user can act on — there is no retry affordance on
                // either platform.
            }
        }
    }

    /// `MedicationEditorViewModel.kt:195-217`.
    private func buildSchedules(
        _ current: MedicationEditorUiState,
        medicationId: String
    ) -> [MedicationSchedule] {
        // AS_NEEDED has no clock times: a single schedule row keeps ad-hoc logging possible
        // (`MedicationEditorViewModel.kt:197`).
        let rows = if current.recurrence == .asNeeded {
            [current.doseTimes.first ?? DoseTimeUi(existingScheduleId: nil, minuteOfDay: 0, amountInput: "1")]
        } else {
            current.doseTimes
        }
        return rows.map { row in
            MedicationSchedule(
                id: row.existingScheduleId ?? idGenerator.newId(),
                medicationId: medicationId,
                recurrence: current.recurrence,
                daysOfWeekMask: current.daysOfWeekMask,
                intervalDays: Int(current.intervalDaysInput),
                anchorDateEpochDay: current.startDateEpochDay,
                timeOfDayMinutes: current.recurrence == .asNeeded ? 0 : row.minuteOfDay,
                doseAmount: Self.decimal(row.amountInput) ?? 1.0,
                isActive: true
            )
        }
    }

    /// `MedicationEditorViewModel.kt:219-226`.
    private func delete() {
        guard let medicationId else { return }
        state.showDeleteConfirm = false
        // Held for the undo window by an app-scoped controller, so popping this editor — and with
        // it this ViewModel — does not cancel the deletion.
        undoableDelete(medicationId, message: MedicationsStrings.deleted) { [deleteMedication] in
            // Swallowed as everywhere else in this feature: the commit runs after the editor is
            // gone, so there is nothing left to tell and nobody to act on it.
            try? await deleteMedication(id: medicationId)
        }
        navigator.pop()
    }

    /// Kotlin's `replace(',', '.').toDoubleOrNull()` (`MedicationEditorViewModel.kt:164`).
    ///
    /// The comma swap is what makes a Turkish keyboard's "0,5" a number; the trim is what makes
    /// Swift agree with `toDoubleOrNull`, whose screening regex allows surrounding ASCII whitespace
    /// where `Double.init(_: String)` rejects it.
    private static func decimal(_ input: String) -> Double? {
        Double(
            input.replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// Kotlin's `ifBlank { null }` (`MedicationEditorViewModel.kt:165`) — and, as there, what
    /// survives is the *untrimmed* text: blankness is the only thing being judged.
    private static func blankToNil(_ input: String) -> String? {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : input
    }
}

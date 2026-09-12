// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/MedicationFormatting.kt:103-128` — the four label/tone tables M15 added there
// (`MedicationDayStatus.labelRes/chipStatus`, `IntakeStatus.labelRes/chipStatus`).
//
// They are here rather than in `MedicationFormatting.swift` for that file's own reason: it must
// stay importable by the reminder handler, which draws nothing, and a `SalusStatus` is a drawing
// decision that arrives with `SalusUI`. The `IntakeStatus` pair was `fileprivate` in
// `MedicationDetailSections.swift` until M15 gave the list card a status chip of its own; moving it
// here is what keeps the two screens saying the same thing about the same row.
//
// A resolved `String`, not a key: a Swift accessor on ``MedicationsStrings`` already *is* the
// resolved string, so there is nothing for a `stringResource` call site to do with a raw value.

import SalusModel
import SalusUI

extension MedicationDayStatus {
    /// `MedicationDayStatus.labelRes()` (`MedicationFormatting.kt:103-109`).
    ///
    /// The cases are in the repo's alphabetical order (`.swiftformat`'s `sortSwitchCases`) rather
    /// than Kotlin's; the four arms and what they answer are the same.
    var label: String {
        switch self {
        case .asNeeded: MedicationsStrings.statusAsNeeded
        case .pending: MedicationsStrings.intakeStatusPending
        case .skipped: MedicationsStrings.intakeStatusSkipped
        case .taken: MedicationsStrings.intakeStatusTaken
        }
    }

    /// `MedicationDayStatus.chipStatus()` (`MedicationFormatting.kt:111-116`).
    ///
    /// A day with something still outstanding is `neutral`, not a warning: the dose has not been
    /// missed, it has not come round yet or has not been recorded, and the chip must not editorialise
    /// about it (spec §7, §12).
    var chipStatus: SalusStatus {
        switch self {
        case .asNeeded: .accent
        case .pending: .neutral
        case .skipped: .warning
        case .taken: .success
        }
    }
}

extension IntakeStatus {
    /// `IntakeStatus.labelRes()` (`MedicationFormatting.kt:118-125`) — the `intake_status_*` four.
    ///
    /// The cases are in the repo's alphabetical order rather than Kotlin's; the four arms and what
    /// they answer are the same.
    var label: String {
        switch self {
        case .missed: MedicationsStrings.intakeStatusMissed
        case .pending: MedicationsStrings.intakeStatusPending
        case .skipped: MedicationsStrings.intakeStatusSkipped
        case .taken: MedicationsStrings.intakeStatusTaken
        }
    }

    /// `IntakeStatus.chipStatus()` (`MedicationFormatting.kt:127-131`), ported arm for arm.
    ///
    /// **`missed` is `warning`, not `error`**, and `skipped` shares `neutral` with `pending`: a dose
    /// with no record against it is a gap in the record, not a fault, and a skip the user entered
    /// deliberately carries no verdict at all. Reading the four any other way would let the screen
    /// editorialise where Android does not.
    var chipStatus: SalusStatus {
        switch self {
        case .missed: .warning
        case .pending, .skipped: .neutral
        case .taken: .success
        }
    }
}

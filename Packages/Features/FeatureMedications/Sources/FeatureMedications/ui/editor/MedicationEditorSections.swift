// The sections of `MedicationEditorScreen`, split out under the 500-line rule; the file they
// belong to is `MedicationEditorScreen.swift` and its header carries the Material → SwiftUI
// mapping they follow.
//
// Ported from `MedicationEditorScreen.kt:121-235` and its `FormSelector`, `RecurrenceSelector`,
// `DaysOfWeekRow` and `DateRow` composables (`:275-345`).
//
// **The date row is the one place the port changes what is on screen, and it is `SalusDateField`'s
// doing.** Kotlin draws two `OutlinedButton`s whose *text* is the date — "From 12 Aug 2026" /
// "Until 12 Sep 2026" — and opens a `DatePickerDialog` on tap. `SalusDateField` is the button and
// its picker in one view, and what it shows is the system date control, so the Kotlin sentence
// moves to the field's title and the title is hidden from the eye (`.labelsHidden()`, the shape M4
// settled for two half-width pickers in one row). VoiceOver still reads "From 12 Aug 2026"; the eye
// reads the date the control itself draws. `editor_no_end_date` keeps its exact job — it is the
// placeholder, which is what an unset end date shows — and the clear button beside it is Kotlin's,
// down to `editor_clear_end_date` naming it.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

extension MedicationEditorScreen {
    /// `MedicationEditorScreen.kt:125-136`.
    var nameField: some View {
        TextField(
            MedicationsStrings.editorName,
            text: Binding(get: { state.name }, set: { onEvent(.nameChanged($0)) })
        )
        .textFieldStyle(.roundedBorder)
        #if os(iOS)
            .textInputAutocapitalization(.words)
        #endif
    }

    /// `MedicationEditorScreen.kt:138` and `:276-289` — the label, then every form as a chip.
    var formSelector: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            fieldLabel(MedicationsStrings.editorForm)
            ChipFlowLayout(spacing: SalusSpacing.sm) {
                ForEach(MedicationForm.allCases, id: \.self) { form in
                    SalusFilterChip(label: form.label, isSelected: form == state.form) {
                        onEvent(.formSelected(form))
                    }
                }
            }
        }
    }

    /// `MedicationEditorScreen.kt:140-162` — value and unit, side by side.
    var strengthRow: some View {
        HStack(spacing: SalusSpacing.md) {
            TextField(
                MedicationsStrings.editorStrength,
                text: Binding(get: { state.strengthValueInput }, set: { onEvent(.strengthValueChanged($0)) })
            )
            .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif

            TextField(
                MedicationsStrings.editorStrengthUnit,
                text: Binding(get: { state.strengthUnitInput }, set: { onEvent(.strengthUnitChanged($0)) })
            )
            .textFieldStyle(.roundedBorder)
        }
    }

    /// `MedicationEditorScreen.kt:164-173` — free text, so it grows with what is typed.
    var instructionsField: some View {
        TextField(
            MedicationsStrings.editorInstructions,
            text: Binding(get: { state.instructions }, set: { onEvent(.instructionsChanged($0)) }),
            axis: .vertical
        )
        .textFieldStyle(.roundedBorder)
        .lineLimit(1 ... 6)
        #if os(iOS)
            // `KeyboardCapitalization.Sentences` (`MedicationEditorScreen.kt:171`): free text with
            // no autofill category, so capitalization is what buys the user the IME's own
            // suggestion strip and inline correction.
            .textInputAutocapitalization(.sentences)
        #endif
    }

    /// `MedicationEditorScreen.kt:175-197` — how many are left, and when to warn.
    var stockRow: some View {
        HStack(spacing: SalusSpacing.md) {
            TextField(
                MedicationsStrings.editorStock,
                text: Binding(get: { state.stockCountInput }, set: { onEvent(.stockCountChanged($0)) })
            )
            .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif

            TextField(
                MedicationsStrings.editorStockThreshold,
                text: Binding(get: { state.stockThresholdInput }, set: { onEvent(.stockThresholdChanged($0)) })
            )
            .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
        }
    }

    /// `MedicationEditorScreen.kt:199-205` and `:311-345` — the start date, the optional end, and
    /// the way to clear it. See this file's header for what the row looks like here.
    var dateRow: some View {
        HStack(spacing: SalusSpacing.md) {
            SalusDateField(
                title: startDateLabel,
                epochDay: state.startDateEpochDay,
                // Unreachable — the ViewModel sets a start date at init in both modes and no event
                // clears it — but the field takes one, and the honest value is the row's own label.
                placeholder: startDateLabel,
                seedEpochDay: state.startDateEpochDay
            ) { onEvent(.startDateSelected(epochDay: $0)) }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

            SalusDateField(
                title: endDateLabel,
                epochDay: state.endDateEpochDay,
                placeholder: MedicationsStrings.editorNoEndDate,
                // `initialEpochDay = endDateEpochDay ?: startDateEpochDay`
                // (`MedicationEditorScreen.kt:340`).
                seedEpochDay: state.endDateEpochDay ?? state.startDateEpochDay
            ) { onEvent(.endDateSelected(epochDay: $0)) }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

            // `MedicationEditorScreen.kt:326-333`.
            if state.endDateEpochDay != nil {
                Button {
                    onEvent(.endDateSelected(epochDay: nil))
                } label: {
                    Label(MedicationsStrings.editorClearEndDate, systemImage: "xmark")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
    }

    /// `MedicationEditorScreen.kt:207-210` — the screen's one section title.
    var scheduleSectionLabel: some View {
        Text(MedicationsStrings.editorScheduleSection)
            .font(SalusTypography.titleMedium.font)
            .foregroundStyle(theme.colorScheme.onSurface)
    }

    /// `MedicationEditorScreen.kt:212-215` and `:291-297` — the four recurrences as chips.
    var recurrenceSelector: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            ForEach(Recurrence.allCases, id: \.self) { recurrence in
                SalusFilterChip(
                    label: Self.recurrenceLabel(recurrence),
                    isSelected: recurrence == state.recurrence
                ) { onEvent(.recurrenceSelected(recurrence)) }
            }
        }
    }

    /// `MedicationEditorScreen.kt:217-234` — the one extra field the chosen recurrence needs, and
    /// nothing at all for `DAILY` and `AS_NEEDED`.
    @ViewBuilder
    var recurrenceDetail: some View {
        switch state.recurrence {
        case .daysOfWeek:
            daysOfWeekRow

        case .intervalDays:
            intervalDaysField

        case .asNeeded, .daily:
            EmptyView()
        }
    }

    /// `MedicationEditorScreen.kt:299-309` — Monday first, and bit 0 is Monday.
    private var daysOfWeekRow: some View {
        ChipFlowLayout(spacing: SalusSpacing.xs) {
            ForEach(Array(Self.dayLabels.enumerated()), id: \.offset) { index, label in
                SalusFilterChip(label: label, isSelected: state.daysOfWeekMask & (1 << index) != 0) {
                    onEvent(.dayOfWeekToggled(mondayBasedIndex: index))
                }
            }
        }
    }

    /// `MedicationEditorScreen.kt:222-233`.
    private var intervalDaysField: some View {
        TextField(
            MedicationsStrings.editorIntervalDays,
            text: Binding(get: { state.intervalDaysInput }, set: { onEvent(.intervalDaysChanged($0)) })
        )
        .textFieldStyle(.roundedBorder)
        #if os(iOS)
            .keyboardType(.numberPad)
        #endif
    }

    /// The small label Kotlin writes above a chip group (`labelLarge`,
    /// `MedicationEditorScreen.kt:279-282`) — not `SalusSectionHeader`, which is the screen-level
    /// title `scheduleSectionLabel` is.
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(SalusTypography.labelLarge.font)
            .foregroundStyle(theme.colorScheme.onSurface)
    }

    /// "From 12 Aug 2026" (`MedicationEditorScreen.kt:316-322`).
    private var startDateLabel: String {
        MedicationsStrings.editorStartDate(formattedDay(state.startDateEpochDay))
    }

    /// "Until 12 Sep 2026", or `editor_no_end_date` while there is none
    /// (`MedicationEditorScreen.kt:324-325`).
    private var endDateLabel: String {
        guard let endDateEpochDay = state.endDateEpochDay else {
            return MedicationsStrings.editorNoEndDate
        }
        return MedicationsStrings.editorEndDate(formattedDay(endDateEpochDay))
    }

    /// Kotlin's `DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)`
    /// (`MedicationEditorScreen.kt:313-315`) as this port spells a date: a fixed pattern through
    /// `LocalDate.formatted(pattern:locale:)`, never a `Calendar`. The pattern is the day-only twin
    /// of the one the vitals rows and the appointment notifications already use.
    private func formattedDay(_ epochDay: Int) -> String {
        LocalDate(epochDay: epochDay).formatted(pattern: Self.dateLabelPattern, locale: locale)
    }

    /// `MedicationEditorScreen.kt:349-354`.
    private static func recurrenceLabel(_ recurrence: Recurrence) -> String {
        switch recurrence {
        case .asNeeded: MedicationsStrings.recurrenceAsNeeded
        case .daily: MedicationsStrings.recurrenceDaily
        case .daysOfWeek: MedicationsStrings.recurrenceDaysOfWeek
        case .intervalDays: MedicationsStrings.recurrenceInterval
        }
    }

    /// `MedicationEditorScreen.kt:300-303` — Monday .. Sunday, the order the mask's bits are in.
    ///
    /// Computed rather than stored, for `ScheduleSummaryStrings.localized`'s reason: a stored
    /// static resolves once per process and would keep the locale that was current when the first
    /// editor opened.
    private static var dayLabels: [String] { [
        MedicationsStrings.dayMon,
        MedicationsStrings.dayTue,
        MedicationsStrings.dayWed,
        MedicationsStrings.dayThu,
        MedicationsStrings.dayFri,
        MedicationsStrings.daySat,
        MedicationsStrings.daySun
    ] }

    private static let dateLabelPattern = "d MMM yyyy"
}

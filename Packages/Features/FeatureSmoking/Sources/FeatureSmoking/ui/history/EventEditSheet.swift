// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/history/
// EventEditSheet.kt`.
//
// Edits one log entry: its day and time, the unit count of a smoked entry, the trigger and the
// intensity, with "Kaydet" and "Kaydı sil". Every field starts at the entry's value and is the
// sheet's own until "Kaydet" hands the lot out; closing or swiping away writes nothing.
//
// The day and time are read and shown in the entry's own zone, the one its day was stored in, so a
// slip logged abroad does not slide to another day when it is edited at home. A moment after "now"
// is refused inline with the button off. "Kaydı sil" only asks: the confirmation is the screen's,
// and it is drawn on this sheet — an alert can only be presented by the topmost presentation.
//
// Compose → SwiftUI:
//   `SalusBottomSheet(onDismiss:, title:)`  → `.salusBottomSheet(isPresented:)`, applied by the
//                           `eventEditSheet(…)` modifier below; ``EventEditSheet`` is the sheet's
//                           body, so a preview can draw it.
//   `SalusListItem` + `AlertDialog { TimePicker }` → `SalusUI.SalusTimeField`: iOS has no
//                           time-picker dialog, the wheel is the control.
//   `FlowRow` of chips                       → `ChipFlowLayout`.
//   `rememberSaveable(row.id)`               → `@State`, with the sheet keyed by the entry's id.

import SalusCommon
import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

/// The zone an entry was stored in; the clock's own when the stored id is one this device does not
/// know.
func zoneOf(tzId: String, fallback: TimeZone) -> TimeZone {
    TimeZone(identifier: tzId) ?? fallback
}

/// The body of the editor sheet, with its own state.
struct EventEditSheet: View {
    let row: EventRowUi
    let writing: Bool
    let clock: any SalusClock
    let onSave: (EventEdit) -> Void
    let onDelete: () -> Void

    @State private var epochDay: Int
    @State private var minuteOfDay: Int
    @State private var units: Int
    @State private var trigger: CravingTrigger?
    @State private var intensity: Int?

    init(
        row: EventRowUi,
        writing: Bool,
        clock: any SalusClock,
        onSave: @escaping (EventEdit) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.row = row
        self.writing = writing
        self.clock = clock
        self.onSave = onSave
        self.onDelete = onDelete
        let zone = zoneOf(tzId: row.tzId, fallback: clock.timeZone())
        _epochDay = State(initialValue: Int(localEpochDay(of: row.atMs, in: zone)))
        _minuteOfDay = State(initialValue: localMinuteOfDay(of: row.atMs, in: zone))
        _units = State(initialValue: row.units ?? 0)
        _trigger = State(initialValue: row.trigger)
        _intensity = State(initialValue: row.intensity)
    }

    private var zone: TimeZone {
        zoneOf(tzId: row.tzId, fallback: clock.timeZone())
    }

    private var chosenMs: Int64 {
        instantMs(epochDay: Int64(epochDay), minuteOfDay: minuteOfDay, zone: zone)
    }

    var body: some View {
        EventEditSheetContent(
            type: row.type,
            isMarker: row.isMarker,
            epochDay: epochDay,
            minuteOfDay: minuteOfDay,
            units: units,
            trigger: trigger,
            intensity: intensity,
            isFuture: chosenMs > clock.nowEpochMilliseconds(),
            writing: writing,
            onDayChange: { epochDay = $0 },
            onMinuteChange: { minuteOfDay = $0 },
            onUnitsChange: { units = $0 },
            onTriggerChange: { trigger = $0 },
            onIntensityChange: { intensity = $0 },
            onSave: {
                onSave(
                    EventEdit(
                        eventId: row.id,
                        atMs: chosenMs,
                        units: row.type == .smoked ? units : nil,
                        trigger: trigger,
                        intensity: intensity
                    )
                )
            },
            onDelete: onDelete
        )
        // A swipe during the write would close a sheet the ViewModel keeps open until it ends.
        .interactiveDismissDisabled(writing)
    }
}

/// The sheet's body without its state, so a preview can draw every case.
struct EventEditSheetContent: View {
    let type: SmokingEventType
    let isMarker: Bool
    let epochDay: Int
    let minuteOfDay: Int
    let units: Int
    let trigger: CravingTrigger?
    let intensity: Int?
    let isFuture: Bool
    let writing: Bool
    let onDayChange: (Int) -> Void
    let onMinuteChange: (Int) -> Void
    let onUnitsChange: (Int) -> Void
    let onTriggerChange: (CravingTrigger?) -> Void
    let onIntensityChange: (Int?) -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            SalusDateField(
                title: SmokingStrings.historyEditTitle,
                epochDay: epochDay,
                placeholder: "",
                seedEpochDay: epochDay,
                onChange: onDayChange
            )
            .labelsHidden()
            SalusTimeField(
                title: SmokingStrings.historyEditTime,
                minuteOfDay: minuteOfDay,
                placeholder: "",
                seedMinuteOfDay: minuteOfDay,
                onChange: onMinuteChange
            )
            if isFuture {
                SalusInfoNote(
                    text: SmokingStrings.historyErrorFuture,
                    systemImage: "exclamationmark.triangle",
                    tone: .warning
                )
            }

            if type == .smoked {
                SetupIntStepper(
                    label: SmokingStrings.slipUnitsLabel,
                    value: units,
                    unit: SmokingStrings.slipUnitsUnit,
                    // A "none today" marker may stay at 0; a real entry is at least one.
                    minimum: isMarker ? 0 : 1,
                    onChange: onUnitsChange
                )
                if isMarker {
                    Text(verbatim: SmokingStrings.historyEditMarkerHint)
                        .font(SalusTypography.bodySmall.font)
                        .tracking(SalusTypography.bodySmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
            }

            Text(verbatim: SmokingStrings.triggerTitle)
                .font(SalusTypography.titleMedium.font)
                .tracking(SalusTypography.titleMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
            ChipFlowLayout(spacing: SalusSpacing.sm) {
                ForEach(CravingTrigger.allCases, id: \.self) { option in
                    SalusChoiceChip(
                        label: option.label,
                        isSelected: trigger == option,
                        systemImage: option.symbol,
                        accent: accent
                    ) {
                        // Tapping the chosen one again takes it back: the trigger is optional.
                        onTriggerChange(trigger == option ? nil : option)
                    }
                }
            }

            Text(verbatim: SmokingStrings.triggerIntensity)
                .font(SalusTypography.titleMedium.font)
                .tracking(SalusTypography.titleMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
            HStack(spacing: SalusSpacing.sm) {
                ForEach(TriggerDefaults.intensities, id: \.self) { level in
                    SalusChoiceChip(label: String(level), isSelected: intensity == level, accent: accent) {
                        onIntensityChange(intensity == level ? nil : level)
                    }
                }
            }

            SalusButton(
                SmokingStrings.settingsSave,
                accent: accent,
                enabled: !writing && !isFuture,
                action: onSave
            )
            SalusButton(
                SmokingStrings.historyEditDelete,
                variant: .outlined,
                enabled: !writing,
                action: onDelete
            )
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.bottom, SalusSpacing.xl)
    }
}

// MARK: - Hosting

struct EventEditSheetModifier: ViewModifier {
    let row: EventRowUi?
    let writing: Bool
    let deleteConfirm: Bool
    let clock: any SalusClock
    let onEvent: (SmokingHistoryEvent) -> Void

    /// The row last edited. While the sheet slides away `row` is already `nil`; drawing the last
    /// content through the animation keeps it from emptying out first.
    @State private var shown: EventRowUi?

    func body(content: Content) -> some View {
        content
            .salusBottomSheet(
                isPresented: Binding(
                    get: { row != nil },
                    set: { presented in
                        if !presented {
                            onEvent(.editDismissed)
                        }
                    }
                ),
                title: SmokingStrings.historyEditTitle,
                sizing: .detents([.medium, .large])
            ) {
                if let current = row ?? shown {
                    EventEditSheet(
                        row: current,
                        writing: writing,
                        clock: clock,
                        onSave: { onEvent(.editSaved($0)) },
                        onDelete: { onEvent(.deleteTapped) }
                    )
                    // Opening another entry starts from its own values, not the last one's edits.
                    .id(current.id)
                    // The sheet is the topmost presentation, so it hosts the alert; while the
                    // write runs the alert has been answered and must not come back.
                    .salusConfirmDialog(
                        isPresented: Binding(
                            get: { deleteConfirm && !writing },
                            set: { presented in
                                if !presented {
                                    onEvent(.deleteDismissed)
                                }
                            }
                        ),
                        title: SmokingStrings.historyDeleteTitle,
                        message: SmokingStrings.historyDeleteMessage,
                        confirm: SalusDialogAction(label: SalusUIStrings.delete) { onEvent(.deleteConfirmed) },
                        dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.deleteDismissed) },
                        // The one destructive style in this feature is the reset; an entry is a
                        // record, not the whole plan.
                        confirmIsDestructive: false
                    )
                }
            }
            .onChange(of: row, initial: true) { _, new in
                if let new {
                    shown = new
                }
            }
    }
}

extension View {
    /// Hosts the history screen's entry editor and its delete confirmation.
    func eventEditSheet(
        row: EventRowUi?,
        writing: Bool,
        deleteConfirm: Bool,
        clock: any SalusClock,
        onEvent: @escaping (SmokingHistoryEvent) -> Void
    ) -> some View {
        modifier(
            EventEditSheetModifier(
                row: row,
                writing: writing,
                deleteConfirm: deleteConfirm,
                clock: clock,
                onEvent: onEvent
            )
        )
    }
}

// MARK: - Previews

private enum EventEditPreviewDefaults {
    /// 2026-03-10 in epoch days.
    static let epochDay = 20522
    static let morning = 9 * 60 + 15
    static let evening = 21 * 60
}

#Preview("Event editor — smoked, craving in the future, marker") {
    SalusPreviewPalettes {
        EventEditSheetContent(
            type: .smoked,
            isMarker: false,
            epochDay: EventEditPreviewDefaults.epochDay,
            minuteOfDay: EventEditPreviewDefaults.morning,
            units: 2,
            trigger: .stress,
            intensity: 4,
            isFuture: false,
            writing: false,
            onDayChange: { _ in },
            onMinuteChange: { _ in },
            onUnitsChange: { _ in },
            onTriggerChange: { _ in },
            onIntensityChange: { _ in },
            onSave: {},
            onDelete: {}
        )
        // A craving has no unit count, and a refused future time shows its note with "Kaydet" off.
        EventEditSheetContent(
            type: .cravingResisted,
            isMarker: false,
            epochDay: EventEditPreviewDefaults.epochDay + 1,
            minuteOfDay: EventEditPreviewDefaults.evening,
            units: 0,
            trigger: nil,
            intensity: nil,
            isFuture: true,
            writing: false,
            onDayChange: { _ in },
            onMinuteChange: { _ in },
            onUnitsChange: { _ in },
            onTriggerChange: { _ in },
            onIntensityChange: { _ in },
            onSave: {},
            onDelete: {}
        )
        // The "none today" marker: the stepper may rest at 0 and says what 0 means.
        EventEditSheetContent(
            type: .smoked,
            isMarker: true,
            epochDay: EventEditPreviewDefaults.epochDay,
            minuteOfDay: EventEditPreviewDefaults.morning,
            units: 0,
            trigger: nil,
            intensity: nil,
            isFuture: false,
            writing: false,
            onDayChange: { _ in },
            onMinuteChange: { _ in },
            onUnitsChange: { _ in },
            onTriggerChange: { _ in },
            onIntensityChange: { _ in },
            onSave: {},
            onDelete: {}
        )
    }
}

#Preview("Event editor — accessibility3") {
    EventEditSheetContent(
        type: .smoked,
        isMarker: true,
        epochDay: EventEditPreviewDefaults.epochDay + 1,
        minuteOfDay: EventEditPreviewDefaults.evening,
        units: 0,
        trigger: .coffee,
        intensity: 5,
        isFuture: true,
        writing: false,
        onDayChange: { _ in },
        onMinuteChange: { _ in },
        onUnitsChange: { _ in },
        onTriggerChange: { _ in },
        onIntensityChange: { _ in },
        onSave: {},
        onDelete: {}
    )
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
    .dynamicTypeSize(.accessibility3)
}

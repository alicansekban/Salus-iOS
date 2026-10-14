// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/sheet/
// QuitDateSheet.kt`.
//
// Picks the moment a quit began: a day and a time of day. A past moment is fine — most people pick
// the quit up days after it happened — but a future one is refused here, inline, with the confirm
// button off, so it can never be handed to a use case that would refuse it later.
//
// Compose → SwiftUI:
//   `SalusBottomSheet(onDismiss:, title:)`  → `.salusBottomSheet(isPresented:)`, applied by the
//                                             `quitDateSheet(…)` modifier below; ``QuitDateSheet``
//                                             is the sheet's body, so a preview can draw it.
//   `SalusDateField`                         → `SalusUI.SalusDateField`, its label hidden (the
//                                             sheet's own title says what is being picked).
//   `SalusListItem` + `AlertDialog { TimePicker }` → `SalusUI.SalusTimeField`: iOS has no
//                                             time-picker dialog, the wheel is the control, so
//                                             `smoking_quit_sheet_time_dialog` ("Saati seç") has
//                                             no reader here and stays in the catalog for parity.
//   `salus_ok`                                → `SalusUIStrings.ok`.
//
// "Now" and the zone come from the injected `SalusClock` (the app's), so the check and the shown
// time agree with every other figure on the screens; previews pass a fixed one.

import SalusCommon
import SalusDesignSystem
import SalusUI
import SwiftUI

/// The body of the quit-date sheet (`QuitDateSheet.kt:826-854`).
///
/// `onConfirm` is handed the chosen instant and `onDismiss` follows it, so the host closes the
/// sheet the same way for a confirm as for a swipe.
struct QuitDateSheet: View {
    let onConfirm: (Int64) -> Void
    let onDismiss: () -> Void
    let clock: any SalusClock

    @State private var epochDay: Int
    @State private var minuteOfDay: Int

    init(
        initialMs: Int64,
        onConfirm: @escaping (Int64) -> Void,
        onDismiss: @escaping () -> Void,
        clock: any SalusClock
    ) {
        let zone = clock.timeZone()
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        self.clock = clock
        _epochDay = State(initialValue: Int(localEpochDay(of: initialMs, in: zone)))
        _minuteOfDay = State(initialValue: localMinuteOfDay(of: initialMs, in: zone))
    }

    private var chosenMs: Int64 {
        instantMs(epochDay: Int64(epochDay), minuteOfDay: minuteOfDay, zone: clock.timeZone())
    }

    var body: some View {
        QuitDateSheetContent(
            epochDay: epochDay,
            minuteOfDay: minuteOfDay,
            isFuture: chosenMs > clock.nowEpochMilliseconds(),
            onDayChange: { epochDay = $0 },
            onMinuteChange: { minuteOfDay = $0 },
            onConfirm: {
                onConfirm(chosenMs)
                onDismiss()
            }
        )
    }
}

/// The sheet's body without its state, so a preview can draw every case (`QuitDateSheet.kt:857-909`).
struct QuitDateSheetContent: View {
    let epochDay: Int
    let minuteOfDay: Int
    let isFuture: Bool
    let onDayChange: (Int) -> Void
    let onMinuteChange: (Int) -> Void
    let onConfirm: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            SalusDateField(
                title: SmokingStrings.quitSheetTitle,
                epochDay: epochDay,
                placeholder: "",
                seedEpochDay: epochDay,
                onChange: onDayChange
            )
            .labelsHidden()
            SalusTimeField(
                title: SmokingStrings.quitSheetTime,
                minuteOfDay: minuteOfDay,
                placeholder: "",
                seedMinuteOfDay: minuteOfDay,
                onChange: onMinuteChange
            )
            if isFuture {
                SalusInfoNote(
                    text: SmokingStrings.quitSheetFuture,
                    systemImage: "exclamationmark.triangle",
                    tone: .warning
                )
            }
            SalusButton(
                SalusUIStrings.ok,
                accent: theme.extendedColors.smoking,
                enabled: !isFuture,
                action: onConfirm
            )
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.bottom, SalusSpacing.xl)
    }
}

extension View {
    /// Presents ``QuitDateSheet`` as the app's bottom sheet, titled "Ne zaman bıraktın?".
    func quitDateSheet(
        isPresented: Binding<Bool>,
        initialMs: Int64,
        clock: any SalusClock,
        onConfirm: @escaping (Int64) -> Void
    ) -> some View {
        salusBottomSheet(
            isPresented: isPresented,
            title: SmokingStrings.quitSheetTitle,
            sizing: .fitted
        ) {
            QuitDateSheet(
                initialMs: initialMs,
                onConfirm: onConfirm,
                onDismiss: { isPresented.wrappedValue = false },
                clock: clock
            )
        }
    }
}

// MARK: - Previews

private enum QuitDateSheetPreviewDefaults {
    /// 2026-03-10 in epoch days.
    static let epochDay = 20522
    static let afternoon = 14 * 60 + 30
    static let morning = 9 * 60
}

#Preview("Quit-date sheet — past moment") {
    SalusPreviewPalettes {
        QuitDateSheetContent(
            epochDay: QuitDateSheetPreviewDefaults.epochDay,
            minuteOfDay: QuitDateSheetPreviewDefaults.afternoon,
            isFuture: false,
            onDayChange: { _ in },
            onMinuteChange: { _ in },
            onConfirm: {}
        )
    }
}

#Preview("Quit-date sheet — future moment refused") {
    SalusPreviewPalettes {
        QuitDateSheetContent(
            epochDay: QuitDateSheetPreviewDefaults.epochDay + 1,
            minuteOfDay: QuitDateSheetPreviewDefaults.morning,
            isFuture: true,
            onDayChange: { _ in },
            onMinuteChange: { _ in },
            onConfirm: {}
        )
    }
}

#Preview("Quit-date sheet — accessibility3") {
    QuitDateSheetContent(
        epochDay: QuitDateSheetPreviewDefaults.epochDay + 1,
        minuteOfDay: QuitDateSheetPreviewDefaults.morning,
        isFuture: true,
        onDayChange: { _ in },
        onMinuteChange: { _ in },
        onConfirm: {}
    )
    .dynamicTypeSize(.accessibility3)
}

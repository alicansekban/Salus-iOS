// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/sheet/
// LimitSheet.kt`.
//
// The daily limit of a REDUCE plan, from 1 on. The same sheet asks for the limit when a quit attempt
// is switched to reducing: then `note` says nothing is deleted, `baselineUnitsPerDay` shows the 80 %
// suggestion the setup gives (`nil` hides it, for a vape that counts sessions) and `confirmLabel`
// names the act. Nothing is handed out until the confirm; `writing` disables it while the write is
// in flight.
//
// Compose → SwiftUI:
//   `SalusBottomSheet(onDismiss:, title:)`  → `.salusBottomSheet(isPresented:)`, applied by the
//                           settings screen's one sheet host (`SettingsSheetModifier`); ``LimitSheet``
//                           is the sheet's body, so a preview can draw it.
//   `SalusStepperField(range:)`  → `SetupIntStepper`, the setup's stepper over `1…maxUnits`.
//   `rememberSaveable`           → `@State` in ``LimitSheet``.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The body of the limit sheet, with its own state.
struct LimitSheet: View {
    let confirmLabel: String
    let note: String?
    let baselineUnitsPerDay: Int?
    let writing: Bool
    let onConfirm: (Int) -> Void

    @State private var limit: Int

    init(
        confirmLabel: String,
        initialLimit: Int,
        writing: Bool,
        note: String? = nil,
        baselineUnitsPerDay: Int? = nil,
        onConfirm: @escaping (Int) -> Void
    ) {
        self.confirmLabel = confirmLabel
        self.note = note
        self.baselineUnitsPerDay = baselineUnitsPerDay
        self.writing = writing
        self.onConfirm = onConfirm
        _limit = State(initialValue: LimitDefaults.clamped(initialLimit))
    }

    var body: some View {
        LimitSheetContent(
            limit: limit,
            confirmLabel: confirmLabel,
            note: note,
            baselineUnitsPerDay: baselineUnitsPerDay,
            writing: writing,
            onLimitChange: { limit = LimitDefaults.clamped($0) },
            onConfirm: { onConfirm(limit) }
        )
        // A swipe during the write would close a sheet the ViewModel keeps open until it ends.
        .interactiveDismissDisabled(writing)
    }
}

enum LimitDefaults {
    static let limits = 1 ... SetupDefaults.maxUnits

    static func clamped(_ value: Int) -> Int {
        min(limits.upperBound, max(limits.lowerBound, value))
    }
}

/// The sheet's body without its state, so a preview can draw every case.
struct LimitSheetContent: View {
    let limit: Int
    let confirmLabel: String
    let note: String?
    let baselineUnitsPerDay: Int?
    let writing: Bool
    let onLimitChange: (Int) -> Void
    let onConfirm: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            if let note {
                SalusInfoNote(text: note, systemImage: "info.circle")
            }
            SetupIntStepper(
                label: SmokingStrings.setupDailyLimit,
                value: limit,
                unit: SmokingStrings.setupDailyLimitUnit,
                onChange: onLimitChange
            )
            if let baselineUnitsPerDay {
                Text(verbatim: SmokingStrings.setupLimitSuggestion(baselineUnitsPerDay))
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
            SalusButton(confirmLabel, accent: theme.extendedColors.smoking, enabled: !writing, action: onConfirm)
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.bottom, SalusSpacing.xl)
    }
}

// MARK: - Previews

#Preview("Limit sheet — limit") {
    SalusPreviewPalettes {
        LimitSheetContent(
            limit: 10,
            confirmLabel: SmokingStrings.settingsSave,
            note: nil,
            baselineUnitsPerDay: nil,
            writing: false,
            onLimitChange: { _ in },
            onConfirm: {}
        )
    }
}

#Preview("Limit sheet — switch to reducing") {
    SalusPreviewPalettes {
        LimitSheetContent(
            limit: 16,
            confirmLabel: SmokingStrings.settingsReduceSheetConfirm,
            note: SmokingStrings.settingsSwitchToReduceDesc,
            baselineUnitsPerDay: 20,
            writing: false,
            onLimitChange: { _ in },
            onConfirm: {}
        )
    }
}

#Preview("Limit sheet — accessibility3") {
    LimitSheetContent(
        limit: 16,
        confirmLabel: SmokingStrings.settingsReduceSheetConfirm,
        note: SmokingStrings.settingsSwitchToReduceDesc,
        baselineUnitsPerDay: 20,
        writing: true,
        onLimitChange: { _ in },
        onConfirm: {}
    )
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
    .dynamicTypeSize(.accessibility3)
}

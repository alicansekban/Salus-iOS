// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/sheet/
// SlipSheet.kt`.
//
// The sheet a QUIT slip is logged from. Two equal-weight choices (a radio pair, so an accidental
// tap cannot restart an attempt) and one confirm; "Şimdilik kapat", the close button and a swipe
// all leave through `onDismiss` and write nothing.
//
// Compose → SwiftUI:
//   `SalusBottomSheet(onDismiss:, title:)` → `.salusBottomSheet(isPresented:)`, applied by
//                           ``MainSheetModifier``, which hosts both sheets in one presentation;
//                           ``SlipSheetContent`` is the body, so a preview can draw it.
//   `rememberSaveable` units / restart    → `@State` in ``SlipSheet``, seeded from `initialUnits`.
//   `SalusStepperField(range:)`           → `SetupIntStepper`, which clamps `1…200` and answers.
//
// The stepper and the choice are the sheet's own; only the confirm hands them out. `writing`
// disables the confirm — and the dismissals, which the ViewModel ignores while a write is in
// flight — so a second tap cannot start a second write.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The sheet's body with its own state.
struct SlipSheet: View {
    let writing: Bool
    let onConfirm: (_ units: Int, _ restart: Bool) -> Void
    let onDismiss: () -> Void

    @State private var units: Int
    @State private var restart = false

    init(
        initialUnits: Int,
        writing: Bool,
        onConfirm: @escaping (_ units: Int, _ restart: Bool) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.writing = writing
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        _units = State(initialValue: SlipDefaults.clamped(initialUnits))
    }

    var body: some View {
        SlipSheetContent(
            units: units,
            restart: restart,
            writing: writing,
            onUnitsChange: { units = SlipDefaults.clamped($0) },
            onRestartChange: { restart = $0 },
            onConfirm: { onConfirm(units, restart) },
            onDismiss: onDismiss
        )
        // A swipe during the write would close a sheet the ViewModel keeps open until it ends.
        .interactiveDismissDisabled(writing)
    }
}

enum SlipDefaults {
    static let units = 1 ... SetupDefaults.maxUnits

    static func clamped(_ value: Int) -> Int {
        min(units.upperBound, max(units.lowerBound, value))
    }
}

/// The sheet's body without its state, so a preview can draw every case.
struct SlipSheetContent: View {
    let units: Int
    let restart: Bool
    let writing: Bool
    let onUnitsChange: (Int) -> Void
    let onRestartChange: (Bool) -> Void
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            Text(verbatim: SmokingStrings.slipBody)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .padding(.horizontal, SalusSpacing.lg)
            SetupIntStepper(
                label: SmokingStrings.slipUnitsLabel,
                value: units,
                unit: SmokingStrings.slipUnitsUnit,
                onChange: onUnitsChange
            )
            .padding(.horizontal, SalusSpacing.lg)
            // Two choices of equal weight: the same row, the same type, neither one pre-coloured.
            // The rows pad themselves `lg`, as the twin's do (`SalusSelectableRow.kt:65`).
            VStack(spacing: 0) {
                SalusSelectableRow(
                    title: SmokingStrings.slipContinue,
                    subtitle: SmokingStrings.slipContinueDesc,
                    accent: theme.extendedColors.smoking,
                    isSelected: !restart
                ) { onRestartChange(false) }
                SalusSelectableRow(
                    title: SmokingStrings.slipRestart,
                    subtitle: SmokingStrings.slipRestartDesc,
                    accent: theme.extendedColors.smoking,
                    isSelected: restart
                ) { onRestartChange(true) }
            }
            .accessibilityElement(children: .contain)
            SalusButton(
                SmokingStrings.slipConfirm,
                accent: theme.extendedColors.smoking,
                enabled: !writing,
                action: onConfirm
            )
            .padding(.horizontal, SalusSpacing.lg)
            Button(action: onDismiss) {
                Text(verbatim: SmokingStrings.slipDismiss)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
                    .frame(minHeight: SalusTouchTarget.min)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .disabled(writing)
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, SalusSpacing.xl)
    }
}

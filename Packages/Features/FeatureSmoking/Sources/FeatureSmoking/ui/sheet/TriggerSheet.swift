// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/sheet/
// TriggerSheet.kt`.
//
// "What triggered it?": one optional trigger, one optional intensity from 1 to 5, "Kaydet" or
// "Atla". It describes an entry that is already written, so skipping costs nothing; the close
// button and a swipe are the same as "Atla". Shared by the slip sheet's follow-up and the craving
// flow (plan Task 12).
//
// "Kaydet" is on only once something is chosen, and off while `writing`.
//
// Compose → SwiftUI:
//   `FlowRow` of chips                   → `ChipFlowLayout`.
//   `SalusChoiceChip(icon:, accent:)`    → `SalusChoiceChip(systemImage:, accent:)`, the accent knob
//                           iOS-M17 Task 10 ported into `SalusUI`.
//   `rememberSaveable` trigger / intensity → `@State` in ``TriggerSheet``.

import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

/// The sheet's body with its own state.
struct TriggerSheet: View {
    let writing: Bool
    let onSave: (_ trigger: CravingTrigger?, _ intensity: Int?) -> Void
    let onSkip: () -> Void

    @State private var trigger: CravingTrigger?
    @State private var intensity: Int?

    init(
        writing: Bool,
        onSave: @escaping (_ trigger: CravingTrigger?, _ intensity: Int?) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.writing = writing
        self.onSave = onSave
        self.onSkip = onSkip
    }

    var body: some View {
        TriggerSheetContent(
            trigger: trigger,
            intensity: intensity,
            writing: writing,
            onTriggerChange: { trigger = $0 },
            onIntensityChange: { intensity = $0 },
            onSave: { onSave(trigger, intensity) },
            onSkip: onSkip
        )
        .interactiveDismissDisabled(writing)
    }
}

/// The sheet's body without its state, so a preview can draw every case.
struct TriggerSheetContent: View {
    let trigger: CravingTrigger?
    let intensity: Int?
    let writing: Bool
    let onTriggerChange: (CravingTrigger?) -> Void
    let onIntensityChange: (Int?) -> Void
    let onSave: () -> Void
    let onSkip: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        VStack(alignment: .leading, spacing: SalusSpacing.md) {
            ChipFlowLayout(spacing: SalusSpacing.sm) {
                ForEach(CravingTrigger.allCases, id: \.self) { option in
                    SalusChoiceChip(
                        label: option.label,
                        isSelected: trigger == option,
                        systemImage: option.symbol,
                        accent: accent
                    ) {
                        // Tapping the chosen one again takes it back: the sheet's answer is optional.
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
            HStack {
                caption(SmokingStrings.triggerIntensityLow)
                Spacer()
                caption(SmokingStrings.triggerIntensityHigh)
            }

            SalusButton(
                SmokingStrings.triggerSave,
                accent: accent,
                enabled: !writing && (trigger != nil || intensity != nil),
                action: onSave
            )
            Button(action: onSkip) {
                Text(verbatim: SmokingStrings.triggerSkip)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
                    .frame(minHeight: SalusTouchTarget.min)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.bottom, SalusSpacing.xl)
    }

    private func caption(_ text: String) -> some View {
        Text(verbatim: text)
            .font(SalusTypography.bodySmall.font)
            .tracking(SalusTypography.bodySmall.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
    }
}

enum TriggerDefaults {
    static let intensities = 1 ... 5
}

extension CravingTrigger {
    /// `CravingTrigger.labelRes()`.
    var label: String {
        switch self {
        case .coffee: SmokingStrings.triggerCoffee
        case .stress: SmokingStrings.triggerStress
        case .alcohol: SmokingStrings.triggerAlcohol
        case .afterMeal: SmokingStrings.triggerAfterMeal
        case .social: SmokingStrings.triggerSocial
        case .boredom: SmokingStrings.triggerBoredom
        case .other: SmokingStrings.triggerOther
        }
    }

    /// `CravingTrigger.icon()`, as SF Symbols.
    var symbol: String {
        switch self {
        case .coffee: "cup.and.saucer"
        case .stress: "bolt"
        case .alcohol: "wineglass"
        case .afterMeal: "fork.knife"
        case .social: "person.3"
        case .boredom: "hourglass"
        case .other: "sparkles"
        }
    }
}

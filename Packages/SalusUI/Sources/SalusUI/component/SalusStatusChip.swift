// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusStatusChip.kt:34-71`.

import SalusDesignSystem
import SwiftUI

/// Small pill-shaped, non-interactive label — a status word, a reminder offset, an "encrypted"
/// marker. `accent` tints both the text and its 16 %-opacity fill; without one the chip is
/// Kotlin's `SalusStatus.Neutral`, tinted `onSurfaceVariant` (`SalusStatusChip.kt:45`).
public struct SalusStatusChip: View {
    private let label: String
    private let accent: FeatureAccent?

    @Environment(\.salusTheme) private var theme

    public init(label: String, accent: FeatureAccent? = nil) {
        self.label = label
        self.accent = accent
    }

    public var body: some View {
        Text(label)
            .font(SalusTypography.labelMedium.font)
            .tracking(SalusTypography.labelMedium.tracking)
            .foregroundStyle(tint)
            .padding(.horizontal, SalusSpacing.md)
            .padding(.vertical, SalusSpacing.xs)
            .background(SalusShapes.pill.fill(tint.opacity(Self.backgroundOpacity)))
    }

    private var tint: Color { accent?.accent ?? theme.colorScheme.onSurfaceVariant }

    /// `SalusStatusChip.kt:70` — `ChipBackgroundAlpha`.
    private static let backgroundOpacity = 0.16
}

#Preview("Status chips") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.surfaceContainerLow
        HStack(spacing: SalusSpacing.sm) {
            SalusStatusChip(label: "Tomorrow")
            SalusStatusChip(label: "1 hour before", accent: theme.extendedColors.appointments)
            SalusStatusChip(label: "Today", accent: theme.extendedColors.vitals)
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 120)
    .salusTheme(theme)
}

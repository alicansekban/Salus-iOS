// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusStatusChip.kt:34-71`.

import SalusDesignSystem
import SwiftUI

/// Small pill-shaped, non-interactive label — a status word, a reminder offset, an "encrypted"
/// marker. The tint colours both the text and its 16 %-opacity fill.
///
/// Two ways to ask for one, and they mean different things:
/// - `init(label:status:systemImage:)` is the Kotlin signature (`SalusStatusChip.kt:36-41`):
///   a **semantic** chip, tinted by what it states.
/// - `init(label:accent:)` is the iOS-M2 addition for chips that carry no verdict at all and
///   simply belong to a feature area — a reminder offset on an appointment card. Without an
///   accent it is Kotlin's `SalusStatus.Neutral` (`SalusStatusChip.kt:45`).
public struct SalusStatusChip: View {
    private let label: String
    private let systemImage: String?
    private let tintSource: TintSource

    @Environment(\.salusTheme) private var theme

    public init(label: String, accent: FeatureAccent? = nil) {
        self.label = label
        systemImage = nil
        // No accent is exactly Kotlin's `Neutral`, so it resolves through the same table
        // rather than repeating `onSurfaceVariant` here.
        tintSource = accent.map(TintSource.accent) ?? .status(.neutral)
    }

    /// - Parameter systemImage: SF Symbol name — the iOS twin of Kotlin's `icon: ImageVector`
    ///   (`SalusStatusChip.kt:40`), which leads the text when the chip states a condition the
    ///   word alone under-sells.
    public init(label: String, status: SalusStatus, systemImage: String? = nil) {
        self.label = label
        self.systemImage = systemImage
        tintSource = .status(status)
    }

    public var body: some View {
        // `Arrangement.spacedBy(SalusSpacing.xs)` (`SalusStatusChip.kt:56`).
        HStack(spacing: SalusSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: Self.iconSize))
                    // `contentDescription = null` (`SalusStatusChip.kt:60`): the label beside it
                    // already says what the icon says.
                    .accessibilityHidden(true)
            }
            Text(label)
                .font(SalusTypography.labelMedium.font)
                .tracking(SalusTypography.labelMedium.tracking)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, SalusSpacing.md)
        .padding(.vertical, SalusSpacing.xs)
        .background(SalusShapes.pill.fill(tint.opacity(Self.backgroundOpacity)))
    }

    /// What the chip was asked to tint itself by.
    private enum TintSource {
        case accent(FeatureAccent)
        case status(SalusStatus)
    }

    private var tint: Color {
        switch tintSource {
        case let .accent(accent): accent.accent
        case let .status(status): status.tint(in: theme)
        }
    }

    /// `SalusStatusChip.kt:70` — `ChipBackgroundAlpha`.
    private static let backgroundOpacity = 0.16
    /// `SalusStatusChip.kt:71` — `ChipIconSize`. A component dimension, not a design token;
    /// Android keeps it in `:core:ui` too, not in `:core:designsystem`.
    private static let iconSize: CGFloat = 16
}

#Preview("Status chips") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.surfaceContainerLow
        VStack(spacing: SalusSpacing.sm) {
            HStack(spacing: SalusSpacing.sm) {
                SalusStatusChip(label: "Taken", status: .success)
                SalusStatusChip(label: "Low stock", status: .warning)
                SalusStatusChip(label: "Missed", status: .error)
            }
            HStack(spacing: SalusSpacing.sm) {
                SalusStatusChip(label: "Reminders off", status: .neutral, systemImage: "bell.slash")
                SalusStatusChip(label: "Tomorrow")
                SalusStatusChip(label: "1 hour before", accent: theme.extendedColors.appointments)
            }
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 160)
    .salusTheme(theme)
}

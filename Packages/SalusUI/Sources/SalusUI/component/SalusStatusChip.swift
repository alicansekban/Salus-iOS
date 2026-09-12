// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusStatusChip.kt:34-99` in its M15 shape.

import SalusDesignSystem
import SwiftUI

/// Small pill-shaped status label ("Taken", "Due soon", "Missed"). The ground is the neutral
/// `surfaceContainerHigh` in every tone but `accent`; the status itself is carried by the
/// text colour, so a row of chips reads as one family rather than as four coloured blocks.
///
/// The M15 chip keeps the two ways to ask for one:
/// - `init(label:status:dot:systemImage:)` is the Kotlin signature (`SalusStatusChip.kt:46-52`):
///   a **semantic** chip, tinted by what it states. `dot: true` draws the quieter 6 pt disc in
///   the tone colour instead of an icon, for chips whose text already says everything.
/// - `init(label:accent:)` is the iOS-M2 addition for chips that carry no verdict at all and
///   simply belong to a feature area — a reminder offset on an appointment card. Without an
///   accent it is Kotlin's `SalusStatus.Neutral` (`SalusStatusChip.kt:57`).
public struct SalusStatusChip: View {
    private let label: String
    private let systemImage: String?
    private let dot: Bool
    private let tintSource: TintSource

    @Environment(\.salusTheme) private var theme

    public init(label: String, accent: FeatureAccent? = nil) {
        self.label = label
        systemImage = nil
        dot = false
        // No accent is exactly Kotlin's `Neutral`, so it resolves through the same table
        // rather than repeating `onSurfaceVariant` here.
        tintSource = accent.map(TintSource.accent) ?? .status(.neutral)
    }

    /// - Parameters:
    ///   - dot: draw the 6 pt dot in the tone colour instead of an icon (`SalusStatusChip.kt:71-76`).
    ///   - systemImage: SF Symbol name — the iOS twin of Kotlin's `icon: ImageVector`
    ///     (`SalusStatusChip.kt:50`), which leads the text when the chip states a condition the
    ///     word alone under-sells.
    public init(label: String, status: SalusStatus, dot: Bool = false, systemImage: String? = nil) {
        self.label = label
        self.systemImage = systemImage
        self.dot = dot
        tintSource = .status(status)
    }

    public var body: some View {
        // `Arrangement.spacedBy(SalusSpacing.xs)` (`SalusStatusChip.kt:69`).
        HStack(spacing: SalusSpacing.xs) {
            if dot {
                // `Box(size = DotSize).background(tint, shape = CircleShape)`
                // (`SalusStatusChip.kt:71-76`) — small enough to read as punctuation next to the
                // label rather than as a second element. Purely visual.
                Circle()
                    .fill(tint)
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .accessibilityHidden(true)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: Self.iconSize))
                    // `contentDescription = null` (`SalusStatusChip.kt:79-84`): the label beside it
                    // already says what the icon says.
                    .accessibilityHidden(true)
            }
            // `Text(verbatim:)` because `label` is already a resolved string — the plain
            // initializer would re-read it as a `LocalizedStringKey` against the main bundle (the
            // M7 `c726e22` finding).
            Text(verbatim: label)
                .font(SalusTypography.labelMedium.font)
                .tracking(SalusTypography.labelMedium.tracking)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, SalusSpacing.md)
        .padding(.vertical, SalusSpacing.xs)
        .background(SalusShapes.pill.fill(container))
    }

    /// `SalusStatusChip.kt:60-63` — the accent tone carries `primaryContainer`, every other
    /// tone the neutral `surfaceContainerHigh`. The status itself never tints the ground, which
    /// is what keeps a row of chips one family.
    private var container: Color {
        switch tintSource {
        case .accent: theme.colorScheme.primaryContainer
        case let .status(status) where status == .accent: theme.colorScheme.primaryContainer
        default: theme.colorScheme.surfaceContainerHigh
        }
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

    /// `SalusStatusChipDefaults` (`SalusStatusChip.kt:94-99`). Component dimensions, not design
    /// tokens — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
    private static let iconSize: CGFloat = 16
    /// `SalusStatusChipDefaults.DotSize` (`SalusStatusChip.kt:97-98`).
    private static let dotSize: CGFloat = 6
}

#Preview("Status chips") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    ZStack {
        theme.colorScheme.surfaceContainerLow
        VStack(spacing: SalusSpacing.sm) {
            HStack(spacing: SalusSpacing.sm) {
                SalusStatusChip(label: "Taken", status: .success, dot: true)
                SalusStatusChip(label: "Low stock", status: .warning, dot: true)
                SalusStatusChip(label: "Missed", status: .error)
            }
            HStack(spacing: SalusSpacing.sm) {
                SalusStatusChip(label: "Reminders off", status: .neutral, systemImage: "bell.slash")
                SalusStatusChip(label: "Premium", status: .accent)
                SalusStatusChip(label: "Tomorrow")
            }
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 160)
    .salusTheme(theme)
}

#Preview("Status chips — dark") {
    let theme = SalusTheme.resolve(systemIsDark: true)
    ZStack {
        theme.colorScheme.surfaceContainerLow
        VStack(spacing: SalusSpacing.sm) {
            HStack(spacing: SalusSpacing.sm) {
                SalusStatusChip(label: "Taken", status: .success, dot: true)
                SalusStatusChip(label: "Premium", status: .accent)
                SalusStatusChip(label: "Missed", status: .error)
            }
            HStack(spacing: SalusSpacing.sm) {
                SalusStatusChip(label: "1 hour before", accent: theme.extendedColors.appointments)
                SalusStatusChip(label: "Tomorrow")
            }
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 130)
    .salusTheme(theme)
}

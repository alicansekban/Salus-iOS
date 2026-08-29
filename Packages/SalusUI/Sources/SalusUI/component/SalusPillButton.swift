// Ported from `core/ui/.../component/SalusPillButton.kt:38-101`.
//
// Kotlin reaches for Material's `Button` / `FilledTonalButton` with `shape = CircleShape`; the
// SwiftUI twin of that pair is `.borderedProminent` / `.bordered` worn as a capsule. That mapping
// already exists twice, inlined at the two detail-screen action rows shipped in iOS-M4/M5
// (`AppointmentDetailScreen.swift:226-259`, `MedicationDetailSections.swift:275-292`); a third
// feature needs it in iOS-M6, so it is lifted here. Those two call sites keep their inlined copies
// on purpose — migrating them is deferred by the M6 plan's ruling 3, not forgotten.
//
// `.buttonBorderShape(.capsule)`, not `.clipShape(SalusShapes.pill)`: the bordered styles draw
// their own background and border, and clipping that to a capsule would cut the corners off a
// rounded rectangle rather than round the shape the style draws. `buttonBorderShape` is the
// modifier that makes the style *draw* the pill `design-tokens.md` §6 maps `CircleShape` onto, and
// it is what both existing call sites use.

import SalusDesignSystem
import SwiftUI

/// Fully rounded brand button. `tonal` switches from the filled primary style to the tonal
/// (container-tinted) style for secondary actions. Pass the feature's `FeatureAccent` to color the
/// button with that accent instead of the primary role (`SalusPillButton.kt:29-36`).
///
/// Width is the caller's: Kotlin takes a `Modifier`, so a full-width action row applies
/// `.frame(maxWidth: .infinity)` at the call site rather than the component deciding for every one.
public struct SalusPillButton: View {
    private let text: String
    private let enabled: Bool
    private let tonal: Bool
    private let accent: FeatureAccent?
    private let systemImage: String?
    private let action: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - systemImage: SF Symbol name for the leading icon, which labels the action and leads the
    ///     text (`SalusPillButton.kt:34-35`). Kotlin takes an `ImageVector` from `Icons`; the iOS
    ///     twin of that catalogue is SF Symbols, named rather than referenced.
    public init(
        text: String,
        enabled: Bool = true,
        tonal: Bool = false,
        accent: FeatureAccent? = nil,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.enabled = enabled
        self.tonal = tonal
        self.accent = accent
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        styledButton
            .tint(containerColor)
            // `shape = CircleShape` (`SalusPillButton.kt:73`, `:88`).
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            // Kotlin passes `enabled` to the button; SwiftUI's twin is the environment flag, which
            // dims the label the way Material's disabled colors do.
            .disabled(!enabled)
            // `heightIn(min = SalusTouchTarget.min)` (`SalusPillButton.kt:67`) — a floor, not a
            // height. `.controlSize(.large)` already draws taller than the floor at the default
            // text size; the floor is what holds the touch target at the smaller Dynamic Type
            // sizes, which is the only thing Kotlin's `heightIn(min =)` does either.
            .frame(minHeight: SalusTouchTarget.min)
    }

    @ViewBuilder
    private var styledButton: some View {
        if tonal {
            button.buttonStyle(.bordered)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: SalusSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: Self.iconSize))
                }
                Text(text)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
            }
            .foregroundStyle(contentColor)
        }
    }

    private var colors: SalusColorScheme { theme.colorScheme }

    /// Kotlin's `containerColor` (`SalusPillButton.kt:76`, `:91`), with `ButtonDefaults`' own
    /// values — `primary` filled, `secondaryContainer` tonal — standing in for the `accent == null`
    /// rows. SwiftUI paints `.borderedProminent` with the tint solidly, as `Button` does; it paints
    /// `.bordered` with a softened wash of it, which is its own rendering of the same tonal idea
    /// Material fills flat.
    private var containerColor: Color {
        guard let accent else { return tonal ? colors.secondaryContainer : colors.primary }
        return tonal ? accent.container : accent.accent
    }

    /// Kotlin's `contentColor` (`SalusPillButton.kt:77`, `:92`). Set on the label rather than left
    /// to the style, so the accent rows carry the `onAccent` / `onContainer` role Kotlin names
    /// instead of a color derived from the tint.
    private var contentColor: Color {
        guard let accent else { return tonal ? colors.onSecondaryContainer : colors.onPrimary }
        return tonal ? accent.onContainer : accent.onAccent
    }

    /// `private val ButtonIconSize = 18.dp` (`SalusPillButton.kt:101`) — a Material component
    /// dimension that lives in the Kotlin file, not a token `design-tokens.md` carries.
    private static let iconSize: CGFloat = 18
}

#Preview("Pill buttons") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.background
        VStack(spacing: SalusSpacing.sm) {
            // The two rows of `SalusPillButtonPreview` (`SalusPillButton.kt:104-115`).
            SalusPillButton(text: "Log period", systemImage: "plus", action: {})
            SalusPillButton(text: "View details", tonal: true, action: {})
            // The accent rows, which Kotlin's preview does not draw.
            SalusPillButton(text: "Log period", accent: theme.extendedColors.cycle, action: {})
            SalusPillButton(
                text: "View details",
                tonal: true,
                accent: theme.extendedColors.cycle,
                action: {}
            )
            SalusPillButton(text: "Log period", enabled: false, action: {})
        }
        .padding(SalusSpacing.lg)
    }
    .frame(height: 360)
    .salusTheme(theme)
}

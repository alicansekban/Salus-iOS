// Ported from `core/ui/.../component/SalusPillButton.kt:38-101`.
//
// The pill is hand-drawn — `.buttonStyle(.plain)` over a `SalusShapes.pill` background — rather
// than worn as one of SwiftUI's bordered button styles, and the reason is the touch target.
// Kotlin hangs `heightIn(min = SalusTouchTarget.min)` on the *container*
// (`SalusPillButton.kt:67`, passed as the button's own `Modifier` at `:71` and `:86`), so the drawn
// pill is 48 dp and its clickable surface is the same 48 dp. `.bordered` / `.borderedProminent`
// size their background to whatever label they are handed and pad around it, so the floor cannot
// sit on their container: put it on the label and the pill draws 48 plus twice the style's padding,
// well past the 48 that `design-tokens.md:382` asks for by name ("use 48 to stay identical to
// Android"). Drawing the capsule ourselves is the one placement that gets both axes right at once,
// and it is what `SalusEmptyState.swift:89-99` already does for this very Kotlin button.
//
// The bordered mapping this supersedes is inlined in three places, and all three keep their copies
// on purpose — migrating them is deferred by the M6 plan's ruling 3, not forgotten:
// `AppointmentDetailScreen.swift:226-259`, `MedicationDetailSections.swift:275-292`, and this
// package's own empty-state action (`SalusEmptyState.swift:87-99`, already hand-drawn).

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
            // `ButtonDefaults.ContentPadding`'s 24 dp horizontal, which Kotlin inherits without
            // naming it — the same `SalusSpacing.xl` the empty state's pill already uses.
            .padding(.horizontal, SalusSpacing.xl)
            // `heightIn(min = SalusTouchTarget.min)` (`SalusPillButton.kt:67`), on the container as
            // Kotlin has it: the pill *draws* 48 pt and is hittable across exactly that, rather
            // than drawing short and reserving dead space around itself.
            .frame(minHeight: SalusTouchTarget.min)
            .foregroundStyle(contentColor)
            // `shape = CircleShape` (`:73`, `:88`) filled with `containerColor` (`:76`, `:91`).
            .background(SalusShapes.pill.fill(containerColor))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Kotlin passes `enabled` to the button, which swaps in `ButtonDefaults`' disabled colors;
        // this draws those colors itself (below) and keeps the flag for everything else it governs
        // — the tap, VoiceOver's disabled trait, focus.
        .disabled(!enabled)
    }

    private var colors: SalusColorScheme { theme.colorScheme }

    /// Kotlin's `containerColor` (`SalusPillButton.kt:76`, `:91`), with `ButtonDefaults`' own
    /// values — `primary` filled, `secondaryContainer` tonal — standing in for the `accent == null`
    /// rows.
    private var containerColor: Color {
        guard enabled else { return colors.onSurface.opacity(Self.disabledContainerAlpha) }
        guard let accent else { return tonal ? colors.secondaryContainer : colors.primary }
        return tonal ? accent.container : accent.accent
    }

    /// Kotlin's `contentColor` (`SalusPillButton.kt:77`, `:92`), with `onPrimary` /
    /// `onSecondaryContainer` for the `accent == null` rows.
    private var contentColor: Color {
        guard enabled else { return colors.onSurface.opacity(Self.disabledContentAlpha) }
        guard let accent else { return tonal ? colors.onSecondaryContainer : colors.onPrimary }
        return tonal ? accent.onContainer : accent.onAccent
    }

    /// Material's disabled button alphas, laid over `onSurface`, which `ButtonDefaults`
    /// (`buttonColors()` / `filledTonalButtonColors()`) applies for every M3 button and Kotlin
    /// therefore never spells. A `.plain` button draws its own container, so they are spelled here.
    /// Material component values, not `design-tokens.md` tokens — the doc carries no disabled row.
    private static let disabledContainerAlpha = 0.12
    private static let disabledContentAlpha = 0.38

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
            // The accent and disabled rows, which Kotlin's preview does not draw.
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

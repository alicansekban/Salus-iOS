// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusCard.kt:25-161` in its M15 shape.
//
// The M15 card separates hierarchy from edges. The ground comes from a `tone` that walks the
// surface ladder (`standard` = `surfaceContainerLow`, `elevated` = `surfaceContainer`) or steps off
// it (`accent` = `primaryContainer`, `accentOutlined` = the `aiGradient` frame over the standard
// ground); the edge is decided by mode — a dark ground leans on a `cardBorder` line, a light one on
// the 2 dp shadow with the same line at half strength (`SalusCard.kt:41-44, 82-101`).
//
// `selected` turns a clickable card into a radio item: it swaps the button role for the radio one
// and carries a 1.5 pt `primary` edge while picked (`SalusCard.kt:49-54, 103-121`), the same
// selected treatment `SalusChoiceTile` draws. It is ignored without an `onTap`, since a card that
// cannot be picked has nothing to say (`SalusCard.kt:54`).

import SalusDesignSystem
import SwiftUI

/// The brand card: surface-ladder ground, a mode-dependent edge, 20pt corners. Feature screens
/// use this instead of a hand-rolled rounded rectangle so every card in the app shares one look
/// (`SalusCard.kt:20-24`).
public struct SalusCard<Content: View>: View {
    /// Which ground the card sits on (`SalusCardTone`, `SalusCard.kt:39`).
    public enum Tone {
        /// The default card — `surfaceContainerLow`.
        case standard
        /// One rung up the surface ladder — `surfaceContainer`. Heroes, detail headers.
        case elevated
        /// The tinted card that announces something ("report ready", the premium banner).
        case accent
        /// The standard ground framed by the AI gradient edge.
        case accentOutlined
    }

    private let onTap: (() -> Void)?
    private let selected: Bool?
    private let tone: Tone
    private let contentPadding: EdgeInsets
    private let content: Content

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - tone: the card's ground (`SalusCard.kt:60`).
    ///   - selected: `true` / `false` draws the card as a radio item in a one-of-several picker
    ///     (the paywall's plans); `nil` is the unselected plain card. Ignored without `onTap`
    ///     (`SalusCard.kt:54`).
    ///   - onTap: Kotlin's `onClick` (`SalusCard.kt:28`). `nil` is the non-interactive card.
    ///   - contentPadding: Kotlin takes `PaddingValues`, which can differ per edge; every call site
    ///     in the app passes one uniform value, so this takes a uniform `EdgeInsets`.
    public init(
        tone: Tone = .standard,
        selected: Bool? = nil,
        onTap: (() -> Void)? = nil,
        contentPadding: EdgeInsets = SalusCardDefaults.contentPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.selected = selected
        self.onTap = onTap
        self.contentPadding = contentPadding
        self.content = content()
    }

    public var body: some View {
        if let onTap {
            // `selected != nil` is the radio card; otherwise the plain clickable one
            // (`SalusCard.kt:103-134`). `.plain`, or the whole card would take the tint and
            // the pressed styling that Compose's `Card(onClick =)` does not apply either.
            Button(action: onTap) { surface }
                .buttonStyle(.plain)
                .accessibilityAddTraits(SalusCardAccessibility.traits(selected: selected, onTap: onTap))
        } else {
            surface
        }
    }

    private var colors: SalusColorScheme { theme.colorScheme }

    private var surface: some View {
        // `Column` with no `verticalArrangement` is zero spacing; the content brings its own.
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(contentPadding)
            .foregroundStyle(contentColor)
            .background(background)
    }

    /// Kotlin's `contentColor` (`SalusCard.kt:76-79`): an accent card's children are legible on
    /// `primaryContainer` without every call site restating the colour.
    private var contentColor: Color {
        switch tone {
        case .accent: colors.onPrimaryContainer
        case .accentOutlined, .elevated, .standard: colors.onSurface
        }
    }

    private var background: some View {
        SalusShapes.largeShape
            .fill(container)
            .overlay {
                if case .accentOutlined = tone {
                    // `BorderStroke(brush = Brush.linearGradient(…))` (`SalusCard.kt:88-91`): the
                    // AI frame, the `aiGradient` drawn edge-on so its two stops read as a ring.
                    SalusShapes.largeShape
                        .strokeBorder(
                            LinearGradient(
                                colors: [ext.accentGlow, theme.extendedColors.aiGradient.bottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: SalusCardDefaults.selectedBorderWidth
                        )
                } else if selected == true {
                    SalusShapes.largeShape
                        .strokeBorder(colors.primary, lineWidth: SalusCardDefaults.selectedBorderWidth)
                } else {
                    SalusShapes.largeShape
                        .strokeBorder(
                            SalusCardStyle.border(isDark: theme.isDark, theme: theme),
                            lineWidth: SalusCardDefaults.borderWidth
                        )
                }
            }
            .salusShadow(.card, isDark: theme.isDark)
    }

    /// The extended colors, named short for the view's own use.
    private var ext: SalusExtendedColors { theme.extendedColors }

    private var container: Color {
        switch tone {
        case .accentOutlined, .standard: colors.surfaceContainerLow
        case .elevated: colors.surfaceContainer
        case .accent: colors.primaryContainer
        }
    }
}

/// The `SalusCardDefaults` (`SalusCard.kt:150-161`). Component values, not design tokens — Android
/// keeps them in `:core:ui` too, not in `:core:designsystem`.
public enum SalusCardDefaults {
    /// Kotlin's default `PaddingValues(SalusSpacing.lg)` (`SalusCard.kt:53, 62`).
    public static let contentPadding = EdgeInsets(
        top: SalusSpacing.lg,
        leading: SalusSpacing.lg,
        bottom: SalusSpacing.lg,
        trailing: SalusSpacing.lg
    )

    /// `SalusCardDefaults.BorderWidth` (`SalusCard.kt:151`).
    public static let borderWidth: CGFloat = 1
    /// `SalusCardDefaults.SelectedBorderWidth` / `.AccentBorderWidth` (`SalusCard.kt:154-157`) —
    /// the picked and the AI frame are both half a step thicker than the plain edge.
    public static let selectedBorderWidth: CGFloat = 1.5
}

/// The decisions `SalusCard` makes, lifted out of the view so they can be tested without SwiftUI —
/// the arrangement `SalusSelectableRowStyle` sets.
enum SalusCardStyle {
    /// The mode-dependent edge for the plain card (`SalusCard.kt:93-100`): dark draws `cardBorder`
    /// at full strength, light at half (the shadow does most of the lifting).
    static func border(isDark: Bool, theme: SalusResolvedTheme) -> Color {
        let cardBorder = theme.extendedColors.cardBorder
        return isDark ? cardBorder : cardBorder.opacity(SalusCardBorderLightAlpha)
    }

    /// `SalusCardDefaults.LightBorderAlpha` (`SalusCard.kt:160`).
    private static let SalusCardBorderLightAlpha = 0.5
}

/// The accessibility traits a `SalusCard` publishes, derived from the two optional knobs together
/// (`SalusCard.kt:103-134`): a `selected` card is a radio item, a merely-clickable one a button.
/// Lifted out so the mapping can be tested without rendering a view.
enum SalusCardAccessibility {
    static func traits(selected: Bool?, onTap: (() -> Void)?) -> AccessibilityTraits {
        // A card with no `onTap` is non-interactive and publishes no role; the traits call only
        // ever happens on the Button branch, so the empty set is defensive.
        guard onTap != nil else { return [] }
        // `selected != nil` is the radio card (`Role.RadioButton`, `SalusCard.kt:117`); a `nil`
        // selected keeps the button role a clickable card always has (`SalusCard.kt:123-134`).
        return selected != nil ? [.isSelected] : [.isButton]
    }
}

#Preview("Cards") {
    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.lg) {
            SalusCard {
                Text(verbatim: "Standard card")
                    .font(SalusTypography.titleMedium.font)
            }
            SalusCard(tone: .elevated) {
                Text(verbatim: "Elevated card")
                    .font(SalusTypography.titleMedium.font)
            }
            SalusCard(tone: .accent) {
                Text(verbatim: "Accent card")
                    .font(SalusTypography.titleMedium.font)
            }
            SalusCard(
                selected: true,
                onTap: {},
                content: {
                    Text(verbatim: "Selected, tappable")
                        .font(SalusTypography.titleMedium.font)
                }
            )
        }
    }
}

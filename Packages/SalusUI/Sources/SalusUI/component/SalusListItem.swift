// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusListItem.kt:43-91` in its M15 shape, with the trailing chevron (`SalusListItemChevron.kt`,
// `SalusListItem.kt:93-101`) kept as the default trailing content.
//
// The M15 list row: a leading icon on a tinted 40 pt tile (`SalusIconBadge`, `shapes.small`), a
// title + optional subtitle, and an optional trailing slot — a chevron, a value, a
// `SalusStatusChip` or a `Switch` all fit. Pass the feature's `FeatureAccent` to tint the tile;
// defaults to the primary role.
//
// A clickable row carries the button role, so VoiceOver announces it as one (`SalusListItem.kt:62-65`).
// `titleColor` overrides the title's `onSurface` for the one case that needs it — a placeholder
// row ("Doktor adı ekle") that must read as an invitation rather than an entered value — without a
// nested theme or a second row component.

import SalusDesignSystem
import SwiftUI

/// Standard list row: leading icon on a tinted tile, title + optional subtitle, optional trailing
/// slot. A clickable row is the button; a non-clickable one is plain content (`SalusListItem.kt:43-91`).
public struct SalusListItem<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String?
    private let accent: FeatureAccent?
    private let titleColor: Color?
    private let onTap: (() -> Void)?
    private let trailing: Trailing

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - title: the row's name, in `titleMedium`.
    ///   - subtitle: an optional supporting line, in `bodySmall`.
    ///   - systemImage: SF Symbol name for the leading tile icon — the iOS twin of Kotlin's
    ///     `Vector` (`SalusListItem.kt:47`).
    ///   - accent: the feature accent that tints the leading tile, or nil for the primary role
    ///     (`SalusListItem.kt:49`).
    ///   - titleColor: overrides the title's `onSurface` (`SalusListItem.kt:52`).
    ///   - onTap: makes the row a button. `nil` is the read-only row (`SalusListItem.kt:54`).
    ///   - trailing: the row's trailing content (chevron, chip, toggle …). Defaults to
    ///     `SalusListItemChevron` in the convenience initializer below.
    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        accent: FeatureAccent? = nil,
        titleColor: Color? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.accent = accent
        self.titleColor = titleColor
        self.onTap = onTap
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: SalusSpacing.lg) {
            SalusIconBadge(systemImage: systemImage ?? "list.bullet", accent: accent, size: .medium)
            VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                Text(verbatim: title)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(titleColor ?? theme.colorScheme.onSurface)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(SalusTypography.bodySmall.font)
                        .tracking(SalusTypography.bodySmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // A spacer wider than the gap, so the trailing slot sits at the right edge
            // (`SalusListItem.kt:87-89`).
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.md)
        // A row with a short title and no subtitle would otherwise fall under the 48 pt target,
        // which is exactly the row an unsteady hand misses (`SalusListItem.kt:56-60`).
        .frame(maxWidth: .infinity, minHeight: SalusTouchTarget.min)
        .contentShape(.rect)
        .modifier(SalusListItemTap(onTap: onTap))
    }
}

extension SalusListItem where Trailing == SalusListItemChevron {
    /// The navigation-row form: trailing `>` by default (`SalusListItem.kt:93-101`).
    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        accent: FeatureAccent? = nil,
        titleColor: Color? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            accent: accent,
            titleColor: titleColor,
            onTap: onTap,
            trailing: { SalusListItemChevron() }
        )
    }
}

/// The row's tap: a `Button` when `onTap != nil`, otherwise plain content that still takes the
/// full touch target (`SalusListItem.kt:61-66`). Lifted into a modifier so the optional closure
/// doesn't force two copies of the row's layout.
private struct SalusListItemTap: ViewModifier {
    let onTap: (() -> Void)?

    func body(content: Content) -> some View {
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// The trailing chevron on a list row — the `>` that says "this opens something".
///
/// `chevron.right` is the SF Symbol that reads as a `>` in an LTR layout; it mirrors with the
/// layout direction automatically. `onSurfaceVariant` matches the muted look the Kotlin
/// `MaterialTheme.colorScheme.onSurfaceVariant` gives it (`SalusListItemChevron.kt`). Decoration,
/// not content: the row's title is the accessibility label, so reading the chevron aloud would
/// only repeat "disclosure" after it.
public struct SalusListItemChevron: View {
    @Environment(\.salusTheme) private var theme

    public init() {}

    public var body: some View {
        Image(systemName: "chevron.right")
            .font(SalusTypography.labelLarge.font)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .accessibilityHidden(true)
    }
}

#Preview("List items") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    ZStack {
        theme.colorScheme.background
        VStack(spacing: 0) {
            SalusListItem(
                title: "Blood pressure",
                subtitle: "120/80 · today 09:41",
                systemImage: "heart.fill",
                accent: theme.extendedColors.vitals,
                onTap: {}
            )
            SalusListItem(
                title: "Theme",
                subtitle: "System default",
                systemImage: "paintpalette",
                onTap: {}
            )
            SalusListItem(title: "No subtitle", systemImage: "list.bullet")
        }
    }
    .frame(height: 220)
    .salusTheme(theme)
}

#Preview("List items — dark") {
    let theme = SalusTheme.resolve(systemIsDark: true)
    ZStack {
        theme.colorScheme.background
        VStack(spacing: 0) {
            SalusListItem(
                title: "Blood pressure",
                subtitle: "120/80 · today 09:41",
                systemImage: "heart.fill",
                accent: theme.extendedColors.vitals,
                onTap: {}
            )
            SalusListItem(title: "No subtitle", systemImage: "list.bullet")
        }
    }
    .frame(height: 140)
    .salusTheme(theme)
}

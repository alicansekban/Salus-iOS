// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusSectionHeader.kt:24-49`.
//
// Kotlin's `contentPadding` parameter (`SalusSectionHeader.kt:27-30`) arrived on the day one
// needed it: `MoreScreen`'s scroll column applies the screen's horizontal inset itself, so its
// section labels pass ``SalusSectionHeaderDefaults/topOnly`` and stop being inset twice — the
// twin of Kotlin's `PaddingValues(top = SalusSpacing.sm)` (`MoreScreen.kt:363-366`). Compose's
// `PaddingValues` is spelled `EdgeInsets`; the default is Kotlin's default, so every existing
// caller draws exactly what it drew before.
//
// The trailing action is rendered inside a `SalusTouchTarget.min`-high frame, the twin of
// Kotlin's `defaultMinSize(minHeight = SalusTouchTarget.min)` (`SalusSectionHeader.kt:64`) —
// enforced at the component slot so every caller's "See all" meets the ≥44 pt tap-target
// binding, never at the call site.

import SalusDesignSystem
import SwiftUI

/// The header's two padding values, named rather than spelled at each call site — the shape
/// `SalusSelectableRow`'s component dimensions set.
public enum SalusSectionHeaderDefaults {
    /// Kotlin's `PaddingValues(horizontal = SalusSpacing.lg, vertical = SalusSpacing.sm)`
    /// (`SalusSectionHeader.kt:27-30`) — the header carries the screen inset itself.
    public static let contentPadding = EdgeInsets(
        top: SalusSpacing.sm,
        leading: SalusSpacing.lg,
        bottom: SalusSpacing.sm,
        trailing: SalusSpacing.lg
    )

    /// Kotlin's `PaddingValues(top = SalusSpacing.sm)` (`MoreScreen.kt:363-366`) — for a parent
    /// that already applies the screen's horizontal inset, so the label lines up with the cards
    /// below it instead of starting a second `lg` in.
    public static let topOnly = EdgeInsets(top: SalusSpacing.sm, leading: 0, bottom: 0, trailing: 0)
}

/// Section title above a group of cards or list rows, with an optional trailing action
/// (e.g. a "See all" button) (`SalusSectionHeader.kt:18-22`).
public struct SalusSectionHeader<Actions: View>: View {
    private let title: String
    private let contentPadding: EdgeInsets
    private let actions: Actions

    @Environment(\.salusTheme) private var theme

    /// - Parameter contentPadding: override it when the parent already applies the screen's
    ///   horizontal padding (`SalusSectionHeader.kt:20-21`) — ``SalusSectionHeaderDefaults/topOnly``
    ///   is that case.
    public init(
        title: String,
        contentPadding: EdgeInsets = SalusSectionHeaderDefaults.contentPadding,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.contentPadding = contentPadding
        self.actions = actions()
    }

    public var body: some View {
        // Zero, matching Compose's `Arrangement.Start` default — the same reasoning as
        // the shell's inline titles: the `minHeight` below sizes the touch target, and the
        // action slot's caller styles the label.
        HStack(spacing: 0) {
            // `Text(verbatim:)` because the caller hands over a resolved `String` — the plain
            // initializer would read it back as a `LocalizedStringKey` against the main bundle
            // (the M7 `c726e22` finding).
            Text(verbatim: title)
                .font(SalusTypography.labelSmall.font)
                .tracking(SalusTypography.labelSmall.tracking)
                .foregroundStyle(theme.extendedColors.overline)
                // `Modifier.weight(1f)` (`SalusSectionHeader.kt:43`).
                .frame(maxWidth: .infinity, alignment: .leading)
            actions
                // `Modifier.defaultMinSize(minHeight = SalusTouchTarget.min)`
                // (`SalusSectionHeader.kt:64`) — the trailing action meets the
                // `SalusTouchTarget.min` touch-target floor no matter what the caller puts in
                // the slot, so the "See all" button is never a bare text hit target.
                .frame(minHeight: SalusTouchTarget.min)
        }
        .frame(maxWidth: .infinity)
        // `Modifier.padding(contentPadding)` (`SalusSectionHeader.kt:35`).
        .padding(contentPadding)
    }
}

extension SalusSectionHeader where Actions == EmptyView {
    /// The header with no trailing action — Kotlin's `action: (…)? = null` default
    /// (`SalusSectionHeader.kt:31`).
    public init(title: String, contentPadding: EdgeInsets = SalusSectionHeaderDefaults.contentPadding) {
        self.init(title: title, contentPadding: contentPadding, actions: { EmptyView() })
    }
}

/// The samples the palette fan-out renders — a view of its own because the trailing action is
/// tinted `primary`, which every palette re-values.
private struct SalusSectionHeaderPreviewSamples: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            SalusSectionHeader(title: "Upcoming") {
                Button("See all") {}
                    .buttonStyle(.plain)
                    // `labelLarge` in `primary`, the twin's action label (`SalusSectionHeader.kt:70`),
                    // rendered inside the slot's `SalusTouchTarget.min`-high frame.
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
                    .foregroundStyle(theme.colorScheme.primary)
            }
            SalusSectionHeader(title: "Notes")
            // The parent-inset variant: no horizontal padding of its own, so it lines up with
            // whatever inset the column around it applies.
            SalusSectionHeader(title: "Flush", contentPadding: SalusSectionHeaderDefaults.topOnly)
        }
    }
}

#Preview("Section header") {
    SalusPreviewPalettes {
        SalusSectionHeaderPreviewSamples()
    }
}

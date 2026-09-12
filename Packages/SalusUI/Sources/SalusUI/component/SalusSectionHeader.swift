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
// The trailing action's slot is `SalusTouchTarget.min` high, the twin of Kotlin's
// `defaultMinSize(minHeight = SalusTouchTarget.min)` (`SalusSectionHeader.kt:64`). That frame
// sizes the ROW and nothing else: a `Button`'s hit area is its label's, so a bare-`Text` label
// inside the slot keeps its own ~20 pt shape however tall the box around it is — which is the
// finding the whole-branch review raised against three call sites.
//
// ``SalusSectionHeaderAction`` is where the hit shape actually lives — the `minHeight` frame and
// the `contentShape` INSIDE the `Button` — and it is what every caller puts in the slot, so the
// next one cannot miss it.

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
                // (`SalusSectionHeader.kt:64`) — the row is at least as tall as the touch-target
                // floor whatever the caller puts in the slot. The tappable shape is
                // ``SalusSectionHeaderAction``'s, for the reason this file's header records.
                .frame(minHeight: SalusTouchTarget.min)
        }
        .frame(maxWidth: .infinity)
        // `Modifier.padding(contentPadding)` (`SalusSectionHeader.kt:35`).
        .padding(contentPadding)
    }
}

/// The header's trailing text action: `labelLarge` in `primary`, on a hit shape that is the full
/// `SalusTouchTarget.min` (`SalusSectionHeader.kt:59-73` — Kotlin's `Box(clickable)` carries
/// `defaultMinSize(minHeight = SalusTouchTarget.min)` and `padding(horizontal = SalusSpacing.sm)`
/// around a `labelLarge`/`primary` `Text`).
///
/// The frame and the `contentShape` sit INSIDE the `Button`, which is the only place they buy a
/// 44 pt tap target: ``SalusSectionHeader``'s own slot frame sizes the row, not the label's hit
/// area. Every header action in the tree is this view rather than a `Button` styled at the call
/// site, so the shape is derived once.
public struct SalusSectionHeaderAction: View {
    private let title: String
    private let action: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - title: the already-resolved action label (`SalusSectionHeader.kt:69`).
    ///   - action: what the tap runs (`SalusSectionHeader.kt:63`).
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            // `Text(verbatim:)` because the caller hands over a resolved `String` — the plain
            // initializer would read it back as a `LocalizedStringKey` against the main bundle.
            Text(verbatim: title)
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
                .foregroundStyle(theme.colorScheme.primary)
                // `padding(horizontal = SalusSpacing.sm)` (`SalusSectionHeader.kt:65`).
                .padding(.horizontal, SalusSpacing.sm)
                .frame(minHeight: SalusTouchTarget.min)
                // Without this the hit area is the glyph box the text draws in, not the frame.
                .contentShape(.rect)
        }
        // `.plain`, or the label would take the system tint over the token colour above it.
        .buttonStyle(.plain)
    }
}

extension SalusSectionHeader where Actions == EmptyView {
    /// The header with no trailing action — Kotlin's `action: (…)? = null` default
    /// (`SalusSectionHeader.kt:31`).
    public init(title: String, contentPadding: EdgeInsets = SalusSectionHeaderDefaults.contentPadding) {
        self.init(title: title, contentPadding: contentPadding, actions: { EmptyView() })
    }
}

/// The samples the palette fan-out renders — a view of its own so each palette re-evaluates the
/// trailing action, which draws itself in that palette's `primary`.
private struct SalusSectionHeaderPreviewSamples: View {
    var body: some View {
        VStack(spacing: 0) {
            SalusSectionHeader(title: "Upcoming") {
                SalusSectionHeaderAction(title: "See all") {}
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

// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusSectionHeader.kt:24-49`.
//
// Kotlin's `contentPadding` parameter (`SalusSectionHeader.kt:27-30`) arrived on the day one
// needed it: `MoreScreen`'s scroll column applies the screen's horizontal inset itself, so its
// section labels pass ``SalusSectionHeaderDefaults/topOnly`` and stop being inset twice — the
// twin of Kotlin's `PaddingValues(top = SalusSpacing.sm)` (`MoreScreen.kt:363-366`). Compose's
// `PaddingValues` is spelled `EdgeInsets`; the default is Kotlin's default, so every existing
// caller draws exactly what it drew before.

import SalusDesignSystem
import SwiftUI

/// The header's two padding values, named rather than spelled at each call site — the shape
/// `SalusOptionRow`'s component dimensions set.
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
        // `SalusScreenHeader`: a trailing button carries its own touch-target padding.
        HStack(spacing: 0) {
            Text(title)
                .font(SalusTypography.titleLarge.font)
                .tracking(SalusTypography.titleLarge.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
                // `Modifier.weight(1f)` (`SalusSectionHeader.kt:43`).
                .frame(maxWidth: .infinity, alignment: .leading)
            actions
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

#Preview("Section header") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack(alignment: .top) {
        theme.colorScheme.background
        VStack(spacing: 0) {
            SalusSectionHeader(title: "Upcoming") {
                Button("See all") {}
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.colorScheme.primary)
            }
            SalusSectionHeader(title: "Notes")
            // The parent-inset variant: no horizontal padding of its own, so it lines up with
            // whatever inset the column around it applies.
            SalusSectionHeader(title: "Flush", contentPadding: SalusSectionHeaderDefaults.topOnly)
        }
    }
    .frame(height: 140)
    .salusTheme(theme)
}

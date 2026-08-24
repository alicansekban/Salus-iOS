// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusSectionHeader.kt:24-49`.
//
// Kotlin's `contentPadding` parameter is not ported: it exists so a parent that already applies the
// screen's horizontal padding can drop this one, and no iOS caller does that yet. It arrives the
// day one needs it, rather than as an unused knob.

import SalusDesignSystem
import SwiftUI

/// Section title above a group of cards or list rows, with an optional trailing action
/// (e.g. a "See all" button) (`SalusSectionHeader.kt:18-22`).
public struct SalusSectionHeader<Actions: View>: View {
    private let title: String
    private let actions: Actions

    @Environment(\.salusTheme) private var theme

    public init(title: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
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
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.sm)
    }
}

extension SalusSectionHeader where Actions == EmptyView {
    /// The header with no trailing action — Kotlin's `action: (…)? = null` default
    /// (`SalusSectionHeader.kt:31`).
    public init(title: String) {
        self.init(title: title, actions: { EmptyView() })
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
        }
    }
    .frame(height: 140)
    .salusTheme(theme)
}

// Ported from `core/ui/.../component/SalusListItemChevron.kt`.
//
// A trailing `>` on a list row: the SF Symbol `chevron.right` in `onSurfaceVariant`, sized to read
// as a hint rather than a control. `contentDescription = null` on the Kotlin side marks it as
// decoration — the row's own title already says where tapping goes, so an extra accessibility label
// would only repeat it — and the iOS twin hides it from VoiceOver for the same reason.
//
// A structural component rather than a styled `ChevronRight` built inline, because every list row in
// the More hub draws the same one and a second caller would otherwise copy-paste the four lines. The
// `SalusEmptyState` precedent: a small component whose whole value is "the four lines live in one
// place" (`SalusEmptyState.swift`'s header).

import SalusDesignSystem
import SwiftUI

/// The trailing chevron on a list row — the `>` that says "this opens something".
public struct SalusListItemChevron: View {
    @Environment(\.salusTheme) private var theme

    public init() {}

    public var body: some View {
        // `chevron.right` is the SF Symbol that reads as a `>` in an LTR layout; it mirrors with
        // the layout direction automatically. `onSurfaceVariant` matches the muted look the Kotlin
        // `MaterialTheme.colorScheme.onSurfaceVariant` gives it (`SalusListItemChevron.kt`).
        Image(systemName: "chevron.right")
            .font(SalusTypography.labelLarge.font)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            // Decoration, not content: the row's title is the accessibility label, so reading the
            // chevron aloud would only repeat "disclosure" after it.
            .accessibilityHidden(true)
    }
}

#Preview("List item chevron") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return HStack {
        Text(verbatim: "A row")
        Spacer()
        SalusListItemChevron()
    }
    .padding(SalusSpacing.lg)
    .salusTheme(theme)
}

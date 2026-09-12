// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusStatusChip.kt:28-33` — `enum class SalusStatus { Success, Warning, Error, Neutral, Accent }`
// — and the `when (status)` tint table at `:53-59`, which lives here rather than inside the chip so
// the mapping is testable without rendering a view.

import SalusDesignSystem
import SwiftUI

/// Semantic tint of a `SalusStatusChip`: what the chip *means*, not what colour it draws.
public enum SalusStatus: Sendable {
    /// Something recorded, done, in range — "taken".
    case success
    /// Something asking for attention but not wrong yet — "low stock", "due soon".
    case warning
    /// Something that did not happen — "missed".
    case error
    /// A plain statement with no verdict in it — "reminders off", "skipped".
    case neutral
    /// The brand tone — a chip that labels rather than warns ("Premium", "Today"), and the one
    /// that carries its own tinted ground (`SalusStatusChip.kt:29-32`, `:60-62`).
    case accent

    /// The tint this status resolves to in `theme` (`SalusStatusChip.kt:53-59`).
    ///
    /// `success` and `warning` are the two §3.3 extended status tokens; `error` stays on the
    /// Material role (there is no extended `error`); `neutral` is `onSurfaceVariant`; `accent` is
    /// the primary role, matching Android's `MaterialTheme.colorScheme.primary`.
    public func tint(in theme: SalusResolvedTheme) -> Color {
        switch self {
        case .success: theme.extendedColors.success
        case .warning: theme.extendedColors.warning
        case .error: theme.colorScheme.error
        case .neutral: theme.colorScheme.onSurfaceVariant
        case .accent: theme.colorScheme.primary
        }
    }
}

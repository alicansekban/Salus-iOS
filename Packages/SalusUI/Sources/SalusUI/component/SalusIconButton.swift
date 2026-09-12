// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusIconButton.kt:47-100`.
//
// Two deliberate differences from the Kotlin twin, both recorded in spec §3.3:
//
//   Tone names   → Kotlin's `Primary / Destructive / Neutral` (`SalusIconButton.kt:37`) become
//                  `.accent / .destructive / .standard`, and the quiet one is the **default**
//                  here where Kotlin defaults to `Primary`. Every iOS call site the M16 screens
//                  need — a sheet's close button, the stepper's − and + — is the quiet one; the
//                  tinted disc is the exception, so it is the one that has to be asked for.
//   Disc size    → 40 pt, not Kotlin's 36 dp (spec §3.3). The touch target is `SalusTouchTarget.min`
//                  in both, so the disc grew inside a box that did not.
//
// `enabled` is not ported: the one Kotlin caller that disables a button is its own stepper, whose
// iOS twin hands the bounds check to the caller's `onDecrement`/`onIncrement` instead (spec §3.3).
// An unused knob is a knob that drifts.

import SalusDesignSystem
import SwiftUI

/// Icon on a tinted circle that does something. The visible disc is
/// ``SalusIconButtonDefaults/circleSize`` but the tappable box is the full
/// `SalusTouchTarget.min`, so a row of these stays reachable without the icons crowding
/// each other.
///
/// `accessibilityLabel` is required rather than optional: an icon button carries no text, so
/// omitting it would leave the action nameless to VoiceOver (`SalusIconButton.kt:44-45`).
public struct SalusIconButton: View {
    /// Weight of the button (`SalusIconButton.kt:37`). ``Tone/destructive`` is reserved for
    /// actions that delete data; ``Tone/standard`` is the quiet one — a close button, a
    /// stepper's − and +.
    public enum Tone: Sendable {
        /// Kotlin's `Neutral`: `surfaceContainerHigh` disc, `onSurfaceVariant` glyph.
        case standard
        /// Kotlin's `Primary`: `primaryContainer` disc, `primary` glyph.
        case accent
        /// `errorContainer` disc, `error` glyph.
        case destructive
    }

    private let systemImage: String
    private let accessibilityLabel: String
    private let tone: Tone
    private let action: () -> Void

    @Environment(\.salusTheme) private var theme

    /// - Parameters:
    ///   - systemImage: SF Symbol name — the iOS twin of Kotlin's `ImageVector`.
    ///   - accessibilityLabel: what VoiceOver announces (`SalusIconButton.kt:50`).
    public init(
        systemImage: String,
        accessibilityLabel: String,
        tone: Tone = .standard,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.tone = tone
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            // `Box(size = CircleSize).background(container, CircleShape)`
            // (`SalusIconButton.kt:79-84`) inside a `size(SalusTouchTarget.min)` box
            // (`:70`) — the disc is what is seen, the box is what is hit.
            SalusShapes.pill
                .fill(container)
                .frame(width: SalusIconButtonDefaults.circleSize, height: SalusIconButtonDefaults.circleSize)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: SalusIconButtonDefaults.iconSize))
                        .foregroundStyle(content)
                }
                .frame(width: SalusTouchTarget.min, height: SalusTouchTarget.min)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // `verbatim:` because the caller hands us a resolved string — `Text(_:)` would re-read it
        // as a `LocalizedStringKey` against the main bundle (the M7 `c726e22` finding).
        .accessibilityLabel(Text(verbatim: accessibilityLabel))
    }

    /// `SalusIconButton.kt:56-60`.
    private var container: Color {
        switch tone {
        case .standard: theme.colorScheme.surfaceContainerHigh
        case .accent: theme.colorScheme.primaryContainer
        case .destructive: theme.colorScheme.errorContainer
        }
    }

    /// `SalusIconButton.kt:61-65`.
    private var content: Color {
        switch tone {
        case .standard: theme.colorScheme.onSurfaceVariant
        case .accent: theme.colorScheme.primary
        case .destructive: theme.colorScheme.error
        }
    }
}

/// `object SalusIconButtonDefaults` (`SalusIconButton.kt:95-100`). Component dimensions, not
/// design tokens — Android keeps them in `:core:ui` too, not in `:core:designsystem`.
public enum SalusIconButtonDefaults {
    /// The disc the user sees; the touch target around it is `SalusTouchTarget.min`. 40 pt per
    /// spec §3.3, where `SalusIconButtonDefaults.CircleSize` (`SalusIconButton.kt:97`) is 36 dp.
    public static let circleSize: CGFloat = 40
    /// `SalusIconButtonDefaults.IconSize` (`SalusIconButton.kt:98`).
    public static let iconSize: CGFloat = 20
}

#Preview("Icon buttons") {
    SalusPreviewPalettes {
        HStack(spacing: SalusSpacing.sm) {
            SalusIconButton(systemImage: "pencil", accessibilityLabel: "Edit", tone: .accent) {}
            SalusIconButton(systemImage: "trash", accessibilityLabel: "Delete", tone: .destructive) {}
            SalusIconButton(systemImage: "xmark", accessibilityLabel: "Close") {}
        }
    }
}

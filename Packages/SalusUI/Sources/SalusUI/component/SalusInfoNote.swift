// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusInfoNote.kt:38-96`.
//
// Kotlin's optional `title` (`SalusInfoNote.kt:44`) is not ported: spec §3.3 names the note as
// "leading icon + text", and the icon is required here where Kotlin defaults it to `Info` —
// SF Symbols has no one name that is right for all three tones, so the caller picks.

import SalusDesignSystem
import SwiftUI

/// Tinted note with a leading icon: an explanation attached to the thing it explains, not a
/// transient message. ``Tone/warning`` keeps its text on `onSurface` and carries the warning
/// colour in the icon and the ground only — a whole paragraph in the warning hue reads as an
/// error the user has to fix (`SalusInfoNote.kt:32-37`).
public struct SalusInfoNote: View {
    /// Semantic tint of the note (`SalusInfoNote.kt:30`).
    public enum Tone: Sendable {
        case info
        case warning
        case neutral
    }

    private let text: String
    private let systemImage: String
    private let tone: Tone

    @Environment(\.salusTheme) private var theme

    /// - Parameter systemImage: SF Symbol name — the iOS twin of Kotlin's `ImageVector`.
    public init(text: String, systemImage: String, tone: Tone = .info) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
    }

    public var body: some View {
        // `Arrangement.spacedBy(SalusSpacing.md)` (`SalusInfoNote.kt:66`).
        HStack(alignment: .top, spacing: SalusSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: SalusInfoNoteDefaults.iconSize))
                .foregroundStyle(iconTint)
                // `contentDescription = null` (`SalusInfoNote.kt:70`): the sentence beside it
                // already says what the icon says.
                .accessibilityHidden(true)
            // `Text(verbatim:)` because `text` is already a resolved string.
            Text(verbatim: text)
                .font(SalusTypography.bodySmall.font)
                .tracking(SalusTypography.bodySmall.tracking)
                .foregroundStyle(content)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SalusSpacing.md)
        .background(SalusShapes.mediumShape.fill(container))
    }

    /// `SalusInfoNote.kt:46-52`.
    private var container: Color {
        switch tone {
        case .info: theme.colorScheme.primaryContainer
        case .warning: theme.extendedColors.warning.opacity(SalusInfoNoteDefaults.warningGroundAlpha)
        case .neutral: theme.colorScheme.surfaceContainerHigh
        }
    }

    /// `SalusInfoNote.kt:53-56`.
    private var content: Color {
        switch tone {
        case .info: theme.colorScheme.onPrimaryContainer
        case .neutral, .warning: theme.colorScheme.onSurface
        }
    }

    /// `SalusInfoNote.kt:57-61`.
    private var iconTint: Color {
        switch tone {
        case .info: theme.colorScheme.onPrimaryContainer
        case .warning: theme.extendedColors.warning
        case .neutral: theme.colorScheme.onSurfaceVariant
        }
    }
}

/// `object SalusInfoNoteDefaults` (`SalusInfoNote.kt:91-96`). Component dimensions, not design
/// tokens — Android keeps them in `:core:ui` too.
public enum SalusInfoNoteDefaults {
    /// `SalusInfoNoteDefaults.IconSize` (`SalusInfoNote.kt:92`).
    public static let iconSize: CGFloat = 20
    /// The warning ground is the warning colour washed out; the text stays on `onSurface`
    /// (`SalusInfoNote.kt:95`).
    public static let warningGroundAlpha = 0.16
}

#Preview("Info notes") {
    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.md) {
            SalusInfoNote(text: "Your data never leaves this device.", systemImage: "info.circle")
            SalusInfoNote(
                text: "Predictions need at least three logged cycles.",
                systemImage: "exclamationmark.triangle",
                tone: .warning
            )
            SalusInfoNote(
                text: "Reminders are delivered by the system alarm clock.",
                systemImage: "bell",
                tone: .neutral
            )
        }
    }
}

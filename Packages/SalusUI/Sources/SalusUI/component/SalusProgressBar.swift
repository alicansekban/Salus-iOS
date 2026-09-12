// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusProgressBar.kt:38-89`.

import SalusDesignSystem
import SwiftUI

/// Slim rounded progress bar. `progress` is a fraction in `0 ... 1` and is coerced
/// (`SalusProgressBar.kt:52`), so a caller that divides by a count it has not validated cannot
/// draw past the track.
public struct SalusProgressBar: View {
    /// Fill colour of the bar (`SalusProgressBar.kt:32`); the track is `surfaceContainerHigh` in
    /// every tone.
    public enum Tone: Sendable {
        case primary
        /// The primary at reduced strength, for secondary or partial metrics.
        case primarySoft
        case rose
        case warning
    }

    private let progress: Double
    private let tone: Tone

    @Environment(\.salusTheme) private var theme

    public init(progress: Double, tone: Tone = .primary) {
        self.progress = progress
        self.tone = tone
    }

    public var body: some View {
        // A fractional width has to be measured, not guessed — Kotlin reads the track's own
        // width in a `layout` block (`SalusProgressBar.kt:70-78`); `GeometryReader` is the same
        // reading here, so the bar works inside any parent.
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                SalusShapes.pill.fill(theme.colorScheme.surfaceContainerHigh)
                SalusShapes.pill
                    .fill(fill)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: SalusProgressBarDefaults.height)
        .animation(.easeInOut(duration: SalusMotion.stateChangeDurationSeconds), value: clamped)
        // Kotlin draws two bare `Box`es, which TalkBack never focuses: the number beside the bar
        // is what states the metric, and a second unnamed stop would only slow the reader down.
        .accessibilityHidden(true)
    }

    /// `progress.coerceIn(0f, 1f)` (`SalusProgressBar.kt:52`).
    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    /// `SalusProgressBar.kt:44-51`.
    private var fill: Color {
        switch tone {
        case .primary: theme.colorScheme.primary
        case .primarySoft: theme.colorScheme.primary.opacity(SalusProgressBarDefaults.softAlpha)
        case .rose: theme.extendedColors.metricDown
        case .warning: theme.extendedColors.warning
        }
    }
}

/// `object SalusProgressBarDefaults` (`SalusProgressBar.kt:84-89`). Component dimensions, not
/// design tokens — Android keeps them in `:core:ui` too.
public enum SalusProgressBarDefaults {
    /// `SalusProgressBarDefaults.Height` (`SalusProgressBar.kt:85`).
    public static let height: CGFloat = 6
    /// `SalusProgressBarDefaults.SoftAlpha` (`SalusProgressBar.kt:88`).
    public static let softAlpha = 0.4
}

#Preview("Progress bars") {
    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.md) {
            SalusProgressBar(progress: 0)
            SalusProgressBar(progress: 0.65)
            SalusProgressBar(progress: 0.4, tone: .primarySoft)
            SalusProgressBar(progress: 0.8, tone: .rose)
            SalusProgressBar(progress: 1, tone: .warning)
        }
    }
}

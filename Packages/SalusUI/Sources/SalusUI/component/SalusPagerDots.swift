// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusPagerDots.kt:33-77`.

import SalusDesignSystem
import SwiftUI

/// Page indicator for onboarding and paywall carousels. The current page's dot stretches into a
/// pill instead of only changing colour, so the position reads at a glance and not only by hue —
/// the one cue that survives both a colour-blind user and a dimmed screen
/// (`SalusPagerDots.kt:28-32`).
public struct SalusPagerDots: View {
    private let count: Int
    private let index: Int

    @Environment(\.salusTheme) private var theme

    public init(count: Int, index: Int) {
        self.count = count
        self.index = index
    }

    /// Which dot is drawn as the active pill. Kotlin compares `page == currentPage` inside
    /// `repeat(pageCount)` (`SalusPagerDots.kt:44-45`), which quietly stretches nothing when the
    /// page is out of range; the iOS port indexes instead, so it has to say what out of range
    /// means — the nearest real page, because a carousel that has scrolled past its last page
    /// still has a current one. Pure, so the bounds are table-testable without rendering.
    static func clampedIndex(index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    public var body: some View {
        let active = Self.clampedIndex(index: index, count: count)
        // `Arrangement.spacedBy(SalusSpacing.sm)` (`SalusPagerDots.kt:42`).
        HStack(spacing: SalusSpacing.sm) {
            ForEach(0 ..< max(count, 0), id: \.self) { page in
                SalusShapes.pill
                    .fill(page == active ? theme.colorScheme.primary : inactive)
                    .frame(
                        width: page == active
                            ? SalusPagerDotsDefaults.activeWidth
                            : SalusPagerDotsDefaults.dotSize,
                        height: SalusPagerDotsDefaults.dotSize
                    )
            }
        }
        .animation(.easeInOut(duration: SalusMotion.feedbackDurationSeconds), value: active)
        // Kotlin draws bare `Spacer`s, which TalkBack never focuses: the page itself is what the
        // reader is on, and a row of unnamed dots between pages would only be noise.
        .accessibilityHidden(true)
    }

    /// `onSurfaceVariant.copy(alpha = InactiveAlpha)` (`SalusPagerDots.kt:63-64`).
    private var inactive: Color {
        theme.colorScheme.onSurfaceVariant.opacity(SalusPagerDotsDefaults.inactiveAlpha)
    }
}

/// `object SalusPagerDotsDefaults` (`SalusPagerDots.kt:73-77`). Component dimensions, not design
/// tokens — Android keeps them in `:core:ui` too.
public enum SalusPagerDotsDefaults {
    /// `SalusPagerDotsDefaults.DotSize` (`SalusPagerDots.kt:74`).
    public static let dotSize: CGFloat = 6
    /// `SalusPagerDotsDefaults.ActiveWidth` (`SalusPagerDots.kt:75`).
    public static let activeWidth: CGFloat = 18
    /// `SalusPagerDotsDefaults.InactiveAlpha` (`SalusPagerDots.kt:76`).
    public static let inactiveAlpha = 0.4
}

#Preview("Pager dots") {
    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.md) {
            SalusPagerDots(count: 4, index: 0)
            SalusPagerDots(count: 4, index: 2)
            SalusPagerDots(count: 4, index: 3)
        }
    }
}

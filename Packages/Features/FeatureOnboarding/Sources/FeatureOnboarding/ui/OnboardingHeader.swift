// Ported 1:1 from
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingHeader.kt:42-89` (M15/M16).
//
// The section title, the single 128 pt bar and the counter disc of the eight-step header are gone:
// M15 draws the flow's chrome as back, the position as an overline, and one bar segment per page.
// Segments rather than a single fraction, because three pages are few enough to be counted at a
// glance — the current page is filled, so the bar is read as "two of three done", not as a
// percentage (`OnboardingHeader.kt:32-40`).
//
// Material → SwiftUI:
//   `SalusIconButton(ArrowBack,       → `SalusIconButton(systemImage:accessibilityLabel:tone:action:)`,
//     tone = Neutral)`                  whose `.standard` tone is Kotlin's `Neutral`. The symbol is
//                                       `chevron.backward`, the back glyph the rest of the port uses.
//   `Spacer(size = TouchTarget.min)`  → a `Color.clear` frame of the same 48 pt, so the overline
//                                       keeps its place on page 1 (`OnboardingHeader.kt:64-65`).
//   `repeat(stepCount) {              → `ForEach(0 ..< stepCount, id: \.self)` over `SalusProgressBar`
//     SalusProgressBar(weight(1f)) }`   in an `HStack`, where Compose's `weight(1f)` is
//                                       `.frame(maxWidth: .infinity)` — the bar reads its own width
//                                       through a `GeometryReader`, so it fills whatever it is given.
//   `clearAndSetSemantics {}`         → `.accessibilityHidden(true)`. Kotlin's reasoning verbatim:
//                                       "the overline right above them already says the same thing
//                                       in words".
//
// The back button's `accessibilityLabel` is `onboarding_back`, the twin of the Kotlin
// `contentDescription` (`OnboardingHeader.kt:59`) — controller ruling H-8 (iOS-M8): divergence (d)
// drops a back label only for a *pushed* screen, and this gate is not one, so this is the only
// hand-made back button in the tree and nothing else would name it.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The flow's chrome: back where there is something to go back to, the position as an overline,
/// and one bar segment per page (`OnboardingHeader.kt:41-89`).
struct OnboardingHeader: View {
    let stepNumber: Int
    let stepCount: Int
    let canGoBack: Bool
    let onBack: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // `Arrangement.spacedBy(SalusSpacing.sm)` (`OnboardingHeader.kt:53`).
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            topRow
            segments
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.md)
    }

    /// `OnboardingHeader.kt:55-73`.
    private var topRow: some View {
        HStack(spacing: 0) {
            if canGoBack {
                SalusIconButton(
                    systemImage: "chevron.backward",
                    accessibilityLabel: OnboardingStrings.onboardingBack,
                    tone: .standard,
                    action: onBack
                )
            } else {
                // Page 1 has nowhere to go back to; the overline keeps its place all the same.
                Color.clear
                    .frame(width: SalusTouchTarget.min, height: SalusTouchTarget.min)
            }
            Text(verbatim: OnboardingStrings.onboardingStepOf(stepNumber, stepCount))
                .font(SalusTypography.labelSmall.font)
                .tracking(SalusTypography.labelSmall.tracking)
                .foregroundStyle(theme.extendedColors.overline)
                .padding(.leading, SalusSpacing.sm)
            Spacer(minLength: 0)
        }
    }

    /// `OnboardingHeader.kt:75-87` — one filled segment per page already reached.
    private var segments: some View {
        HStack(spacing: SalusSpacing.xs) {
            ForEach(0 ..< max(stepCount, 0), id: \.self) { index in
                SalusProgressBar(progress: index < stepNumber ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// `OnboardingHeaderPreview` (`OnboardingHeader.kt:91-102`).
#Preview("Onboarding header") {
    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.lg) {
            OnboardingHeader(stepNumber: 1, stepCount: 3, canGoBack: false) {}
            OnboardingHeader(stepNumber: 2, stepCount: 3, canGoBack: true) {}
            OnboardingHeader(stepNumber: 3, stepCount: 3, canGoBack: true) {}
        }
    }
}

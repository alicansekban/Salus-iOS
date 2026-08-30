// Ported 1:1 from
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingHeader.kt`.
//
// Material → SwiftUI:
//   `Box(height = 64).align(…)`      → a `.frame(maxWidth: .infinity, height: 64)` strip with two
//                                      `.overlay(alignment:)`s (leading back, trailing counter) over
//                                      a centred `VStack`. Compose's `Alignment.CenterStart` /
//                                      `CenterEnd` are `.leading` / `.trailing` on the overlay.
//   `IconButton { Icon(ArrowBack) }` → a `.plain` `Button` carrying a `SalusTouchTarget.min` frame,
//                                      which is the 48 dp `IconButton` draws by default and the one
//                                      thing a bare SF Symbol would lose.
//   `LinearProgressIndicator(        → `ProgressView(value:)` under a small `ProgressViewStyle`.
//     progress, color, trackColor,     THE STYLE IS NOT DECORATION: the system linear style paints
//     gapSize = 0.dp,                  its own track and cannot be told to use `outlineVariant`,
//     drawStopIndicator = {})`         and it draws the stop indicator + gap that Kotlin explicitly
//                                      turns off. Two capsules under `ProgressView` is the only
//                                      spelling that reproduces all four Kotlin arguments while
//                                      keeping the accessibility semantics of a progress element.
//   `semantics { contentDescription  → `.accessibilityLabel`, with the same
//     = positionDescription }`         `onboarding_progress` sentence.
//   `clearAndSetSemantics {}` on the → `.accessibilityHidden(true)`. Same reasoning, quoted from the
//    counter                           Kotlin: "the bar next to it already announces the position".
//                                      The M7 sparkline (ruling 7) is the precedent.
//
// NOT A DIVERGENCE, and it took a ruling to get there. The back button's `accessibilityLabel` is
// `onboarding_back` ("Geri"/"Back", `values/strings.xml:3`), the twin of the Kotlin `IconButton`'s
// `contentDescription` (`OnboardingHeader.kt:63`). iOS-M8 T2 first dropped that key on the
// `reminder_health_back` / `settings_back` precedent — "the shell's single `NavigationStack` draws
// the back button" — which is true of every *pushed* screen and NOT of this one: the onboarding
// gate is an overlay with no navigation container, so this file draws the only hand-made back
// button in the tree and nothing else would name it. **Controller ruling H-8 (iOS-M8)** restored
// the key for exactly this call site; the catalog is 46 keys and `OnboardingStringsTests` pins it.
//
// The four dimensions are the Kotlin file's own private vals (`OnboardingHeader.kt:111-114`).

import SalusDesignSystem
import SwiftUI

/// Section heading for every step except Welcome: back, the section title over a short progress
/// bar, and the position as a counter (`OnboardingHeader.kt:43-109`).
///
/// The bar tracks the whole flow rather than the current section — a bar that reset at each heading
/// would read as progress being taken away.
struct OnboardingHeader: View {
    let title: String
    let stepNumber: Int
    let stepCount: Int
    let progress: Float
    let onBack: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        centre
            .frame(maxWidth: .infinity)
            .frame(height: Dimensions.header)
            .overlay(alignment: .leading) { backButton }
            .overlay(alignment: .trailing) { counter }
    }

    /// `OnboardingHeader.kt:57-65`.
    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.backward")
                .font(.system(size: Dimensions.backIcon))
                .foregroundStyle(theme.colorScheme.onSurface)
                .frame(width: SalusTouchTarget.min, height: SalusTouchTarget.min)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: OnboardingStrings.onboardingBack))
    }

    /// `OnboardingHeader.kt:67-89` — the title over the bar.
    private var centre: some View {
        VStack(spacing: 0) {
            Text(verbatim: title)
                .font(SalusTypography.titleLarge.font)
                .tracking(SalusTypography.titleLarge.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
                .lineLimit(nil)
            ProgressView(value: Double(progress.clampedToUnitInterval))
                .progressViewStyle(
                    OnboardingProgressBarStyle(
                        fill: theme.colorScheme.primary,
                        track: theme.colorScheme.outlineVariant
                    )
                )
                .padding(.top, SalusSpacing.xs)
                .accessibilityLabel(
                    Text(verbatim: OnboardingStrings.onboardingProgress(stepNumber, stepCount))
                )
        }
    }

    /// `OnboardingHeader.kt:93-107` — the position as a filled circle, cleared from the
    /// accessibility tree because the bar beside it already announces the same fact.
    private var counter: some View {
        Text(verbatim: OnboardingStrings.onboardingStepCounter(stepNumber, stepCount))
            .font(SalusTypography.labelMedium.font)
            .tracking(SalusTypography.labelMedium.tracking)
            .foregroundStyle(theme.colorScheme.onPrimary)
            .frame(width: Dimensions.counter, height: Dimensions.counter)
            .background(theme.colorScheme.primary, in: Circle())
            .padding(.trailing, SalusSpacing.lg)
            .accessibilityHidden(true)
    }
}

/// Kotlin's four `LinearProgressIndicator` arguments, drawn rather than configured: `color` fills,
/// `trackColor` backs, `gapSize = 0.dp` and `drawStopIndicator = {}` are simply not drawn
/// (`OnboardingHeader.kt:76-88`). The width is fixed, so the fill needs no `GeometryReader`.
private struct OnboardingProgressBarStyle: ProgressViewStyle {
    let fill: Color
    let track: Color

    func makeBody(configuration: Configuration) -> some View {
        let fraction = CGFloat(configuration.fractionCompleted ?? 0)
        return Capsule()
            .fill(track)
            .frame(width: Dimensions.progressWidth, height: Dimensions.progressHeight)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(fill)
                    .frame(width: Dimensions.progressWidth * fraction)
            }
    }
}

extension Float {
    /// `progress` is derived from two counts, so it is already in range; clamping is the guard a
    /// shortened flow would otherwise need, and `ProgressView` renders out-of-range values oddly.
    fileprivate var clampedToUnitInterval: Float { min(max(self, 0), 1) }
}

/// `OnboardingHeader.kt:111-114`, plus the two icon dimensions Material supplies by default.
private enum Dimensions {
    static let header: CGFloat = 64
    static let progressWidth: CGFloat = 128
    static let progressHeight: CGFloat = 4
    static let counter: CGFloat = 32
    /// Material's `IconButton` draws a 24 dp icon; SF Symbols are sized by point size.
    static let backIcon: CGFloat = 24
}

// `OnboardingHeaderPreview` (`OnboardingHeader.kt:116-130`).
#Preview("Onboarding header") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.background
        OnboardingHeader(
            title: OnboardingStrings.onboardingSectionPersonal,
            stepNumber: 2,
            stepCount: 7,
            progress: 2.0 / 7.0
        ) {}
    }
    .frame(height: 120)
    .salusTheme(theme)
}

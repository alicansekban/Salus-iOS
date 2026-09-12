// The twin of `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/preview/SalusPreview.kt`
// and its `SalusPaletteProvider`, which Android reaches through
// `@PreviewParameter(SalusPaletteProvider::class)` + `@PreviewLightDark` — one annotation pair that
// renders every component across the four premium palettes in both modes.
//
// SwiftUI has no preview-parameter provider, so the fan-out is a view: one `#Preview` per
// component wraps its samples in `SalusPreviewPalettes`, and the canvas shows the same eight
// renders. It is what makes a palette regression visible at the component rather than only on a
// screen — a `primaryContainer` pill that vanishes in Sunset dark is invisible in a light Classic
// preview, which is the only one anybody would otherwise draw.

import SalusDesignSystem
import SalusModel
import SwiftUI

/// Renders `content` once per premium palette in both modes — four palettes × light and dark —
/// each wrapped in its own resolved theme.
///
/// ```swift
/// #Preview("Progress bars") {
///     SalusPreviewPalettes {
///         SalusProgressBar(progress: 0.65)
///     }
/// }
/// ```
public struct SalusPreviewPalettes<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(PremiumTheme.allCases, id: \.rawValue) { palette in
                    ForEach(SalusPreviewPalettesDefaults.modes, id: \.self) { isDark in
                        panel(palette: palette, isDark: isDark)
                    }
                }
            }
        }
    }

    private func panel(palette: PremiumTheme, isDark: Bool) -> some View {
        let theme = SalusTheme.resolve(premiumTheme: palette, systemIsDark: isDark)
        return VStack(alignment: .leading, spacing: SalusSpacing.md) {
            // Names the render, so a palette that goes wrong is identified without counting
            // panels — the label `@PreviewParameter` puts on Android's previews for free.
            Text(verbatim: "\(palette.rawValue) · \(isDark ? "DARK" : "LIGHT")")
                .font(SalusTypography.labelSmall.font)
                .tracking(SalusTypography.labelSmall.tracking)
                .foregroundStyle(theme.extendedColors.overline)
            content
        }
        .padding(SalusSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorScheme.background)
        .salusTheme(theme)
    }
}

/// Which renders the helper draws. Not design tokens — a preview arrangement.
enum SalusPreviewPalettesDefaults {
    /// Light first, then dark, for each palette — the order `@PreviewLightDark` uses.
    static let modes: [Bool] = [false, true]
}

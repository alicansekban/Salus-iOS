// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusDisclaimer.kt:24-36`.

import SalusDesignSystem
import SwiftUI

/// Centred caption for the medical and legal lines that close a screen ("Salus is not a medical
/// device"). Deliberately quiet: it has to be present and readable without competing with the
/// content it qualifies (`SalusDisclaimer.kt:20-23`).
public struct SalusDisclaimer: View {
    private let text: String

    @Environment(\.salusTheme) private var theme

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        // `Text(verbatim:)` because `text` is already a resolved string — the plain initializer
        // would re-read it as a `LocalizedStringKey` against the main bundle (the M7 `c726e22`
        // finding).
        Text(verbatim: text)
            .font(SalusTypography.bodySmall.font)
            .tracking(SalusTypography.bodySmall.tracking)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

#Preview("Disclaimers") {
    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.md) {
            SalusDisclaimer("Salus is not a medical device.")
            SalusDisclaimer(
                "Predictions are estimates based on your own logs and must never replace "
                    + "advice from a healthcare professional."
            )
        }
    }
}

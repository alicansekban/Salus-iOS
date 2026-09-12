// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusCheckRow.kt:35-84`.
//
// Kotlin's `checked` argument (`SalusCheckRow.kt:40`), which swaps the check for an empty outline
// circle, is not ported: spec §3.3 names the row as "read-only row with a check glyph and a
// trailing count/chip", and no M16 screen states what it leaves out. An unused knob is a knob
// that drifts; it arrives with the first caller that needs it.

import SalusDesignSystem
import SwiftUI

/// Read-only "this is included" row: a check glyph, a label and an optional trailing count. It is
/// not a control — nothing here is tappable, so it reserves no touch target
/// (`SalusCheckRow.kt:29-30`).
public struct SalusCheckRow: View {
    private let title: String
    private let trailing: String?

    @Environment(\.salusTheme) private var theme

    public init(title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        // `Arrangement.spacedBy(SalusSpacing.md)` (`SalusCheckRow.kt:45`).
        HStack(spacing: SalusSpacing.md) {
            Image(systemName: "checkmark")
                .font(.system(size: SalusCheckRowDefaults.glyphSize))
                .foregroundStyle(theme.colorScheme.primary)
                // `contentDescription = null` (`SalusCheckRow.kt:50`): the row's own text is what
                // says what is included, and "checkmark" repeated down a list says nothing.
                .accessibilityHidden(true)
            // `Text(verbatim:)` on both: the caller hands us resolved strings.
            Text(verbatim: title)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                Text(verbatim: trailing)
                    .font(SalusTypography.labelMedium.font)
                    .tracking(SalusTypography.labelMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// `object SalusCheckRowDefaults` (`SalusCheckRow.kt:81-84`). Component dimensions, not design
/// tokens — Android keeps them in `:core:ui` too.
public enum SalusCheckRowDefaults {
    /// `SalusCheckRowDefaults.GlyphSize` (`SalusCheckRow.kt:82`).
    public static let glyphSize: CGFloat = 20
}

#Preview("Check rows") {
    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.sm) {
            SalusCheckRow(title: "Medications", trailing: "12")
            SalusCheckRow(title: "Vitals")
            SalusCheckRow(title: "Appointments", trailing: "3")
        }
    }
}

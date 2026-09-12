// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusCheckRow.kt:35-84`.
//
// Kotlin's `checked` argument (`SalusCheckRow.kt:40`) swaps the check for an empty outline circle,
// which is how a list states what it leaves out without dropping the line entirely. It shipped with
// the doctor report's "RAPORA DAHİL EDİLENLER" list (`DoctorReportSections.kt:289,295`): a section
// with no records and a report without a narrative draw the empty outline.

import SalusDesignSystem
import SwiftUI

/// Read-only "this is included" row: a check glyph, a label and an optional trailing count. It is
/// not a control — nothing here is tappable, so it reserves no touch target
/// (`SalusCheckRow.kt:29-30`).
///
/// `checked` is `false` only when the caller means "included but empty" — the doctor report's zero-
/// count sections and missing narrative (`DoctorReportSections.kt:289,295`) — and draws the empty
/// outline circle instead of the check (`SalusCheckRow.kt:47-64,83`).
public struct SalusCheckRow: View {
    private let title: String
    private let trailing: String?
    private let checked: Bool

    @Environment(\.salusTheme) private var theme

    public init(title: String, trailing: String? = nil, checked: Bool = true) {
        self.title = title
        self.trailing = trailing
        self.checked = checked
    }

    public var body: some View {
        // `Arrangement.spacedBy(SalusSpacing.md)` (`SalusCheckRow.kt:45`).
        HStack(spacing: SalusSpacing.md) {
            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: SalusCheckRowDefaults.glyphSize))
                    .foregroundStyle(theme.colorScheme.primary)
                    // `contentDescription = null` (`SalusCheckRow.kt:50`): the row's own text is
                    // what says what is included, and "checkmark" repeated down a list says nothing.
                    .accessibilityHidden(true)
            } else {
                // `Box` with the empty outline circle (`SalusCheckRow.kt:55-63`): the same size as
                // the check, bordered, so the unchecked row still aligns with the checked ones around
                // it.
                Circle()
                    .strokeBorder(
                        theme.colorScheme.outline,
                        lineWidth: SalusCheckRowDefaults.emptyBorderWidth
                    )
                    .frame(width: SalusCheckRowDefaults.glyphSize, height: SalusCheckRowDefaults.glyphSize)
                    .accessibilityHidden(true)
            }
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
    /// `SalusCheckRowDefaults.EmptyBorderWidth` (`SalusCheckRow.kt:83`).
    public static let emptyBorderWidth: CGFloat = 1
}

#Preview("Check rows") {
    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.sm) {
            SalusCheckRow(title: "Medications", trailing: "12")
            SalusCheckRow(title: "Vitals")
            SalusCheckRow(title: "Cycle", trailing: "Not included", checked: false)
        }
    }
}

// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusHeroBand.kt:35-100`.
//
// Kotlin's `trailingOverline` slot (`SalusHeroBand.kt:40-41`) is not ported and a `subtitle` line
// takes its place, per the spec §3.3 contract ("date overline slot, greeting in `headlineMedium`,
// chip slot"). The `leading` slot **is** ported (M16 Task 10): the Profile hero leads with the
// avatar, exactly as Kotlin's `ProfileScreen` passes `leading = { SalusAvatar(name) }`
// (`ProfileScreen.kt:119`). `leading` is an optional `@ViewBuilder` so a band without one draws
// exactly as it did before — SwiftUI gives a generic slot no null, so the caller passes
// `{ EmptyView() }`. `chip` is a required `@ViewBuilder` rather than a nullable lambda: SwiftUI has
// no null, and a band without one passes `{ EmptyView() }`.

import SalusDesignSystem
import SwiftUI

/// The band a screen opens on: a small overline over a greeting, on the `hero` gradient. Home and
/// Profile use it; nothing else should, because a screen with two heroes has none
/// (`SalusHeroBand.kt:26-27`).
///
/// The two grounds are not the same picture, so the text colours are not either. In dark the
/// gradient rises out of the app background into `primaryContainer` and the band is part of the
/// page — `onSurface` title, `overline` label. In light the same token is the saturated brand
/// green, a painted panel, and the only legible content on it is `onPrimary`: reading the
/// `overline` token there would put emerald-800 on a dark green at about 1.2:1
/// (`SalusHeroBand.kt:29-34`).
public struct SalusHeroBand<Leading: View, Chip: View>: View {
    private let overline: String?
    private let title: String
    private let subtitle: String?
    private let leading: Leading
    private let chip: Chip

    @Environment(\.salusTheme) private var theme

    public init(
        overline: String?,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder chip: () -> Chip
    ) {
        self.overline = overline
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.chip = chip()
    }

    public var body: some View {
        // `Arrangement.spacedBy(SalusSpacing.sm)` (`SalusHeroBand.kt:61`).
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            if let overline {
                // `Text(overline, labelSmall, color = overlineColor)` (`SalusHeroBand.kt:69-74`).
                Text(verbatim: overline)
                    .font(SalusTypography.labelSmall.font)
                    .tracking(SalusTypography.labelSmall.tracking)
                    .foregroundStyle(overlineColor)
            }
            // `Row(spacedBy(SalusSpacing.md))` with the leading slot first, the title on
            // `weight(1f)` and the chip trailing (`SalusHeroBand.kt:85-98`).
            HStack(spacing: SalusSpacing.md) {
                leading
                Text(verbatim: title)
                    .font(SalusTypography.headlineMedium.font)
                    .tracking(SalusTypography.headlineMedium.tracking)
                    .foregroundStyle(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                chip
            }
            if let subtitle {
                Text(verbatim: subtitle)
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(overlineColor)
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        // `Brush.verticalGradient(listOf(hero.top, hero.bottom))` (`SalusHeroBand.kt:59`).
        .background(theme.extendedColors.hero.vertical)
    }

    /// `SalusHeroBand.kt:46-50`.
    private var titleColor: Color {
        theme.isDark ? theme.colorScheme.onSurface : theme.colorScheme.onPrimary
    }

    /// `SalusHeroBand.kt:51-55`.
    private var overlineColor: Color {
        theme.isDark ? theme.extendedColors.overline : theme.colorScheme.onPrimary
    }
}

#Preview("Hero bands") {
    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.md) {
            SalusHeroBand(overline: "SALUS HEALTH", title: "Günaydın, Alican") {
                SalusAvatar(name: "Alican Sekban")
            } chip: {
                SalusStatusChip(label: "11 EYL")
            }
            SalusHeroBand(overline: "HESAP", title: "Profil", subtitle: "Alican Sekban") {
                EmptyView()
            } chip: {
                EmptyView()
            }
        }
    }
}

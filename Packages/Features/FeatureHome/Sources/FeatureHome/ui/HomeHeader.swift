// Ported from `HomeScreen.kt:145-184` — the tinted greeting band.
//
// The Kotlin doc comment still says "full date, time-of-day greeting **and the settings gear**";
// the gear itself was removed by Android's M9 and only the now-unused `Icons.Outlined.Settings`,
// `IconButton` and `Icon` imports are left (`HomeScreen.kt:18-22`). Nothing is ported from them,
// and `home_title` / `home_settings` are absent from the catalog for the same reason
// (`HomeStrings.swift`).
//
// Material → SwiftUI:
//   `Row { Column(weight(1f)) { … } }` → a single leading-aligned `VStack`. Kotlin's `Row` had a
//                                        second child (the gear); with one child left, the `Row`
//                                        and the `weight(1f)` say nothing a greedy `frame` does
//                                        not, so the band is the column plus a full-width frame.
//   `Spacer(height = xs)`              → `VStack(spacing: SalusSpacing.xs)`.
//   `MaterialTheme.typography.*`       → `SalusTypography.*`, `.font` + `.tracking` in a pair.

import SalusDesignSystem
import SwiftUI

/// The band above the cards: today's date and the greeting, on `primaryContainer`
/// (`HomeScreen.kt:146-184`).
struct HomeHeader: View {
    let todayEpochDay: Int
    let greeting: HomeGreeting

    @Environment(\.salusTheme) private var theme
    /// `LocalLocale.current.platformLocale` (`HomeScreen.kt:151`).
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.xs) {
            // Pre-formatted, so `verbatim` — nothing here is a catalog key.
            Text(verbatim: HomeFormatting.fullDate(epochDay: todayEpochDay, locale: locale))
                .font(SalusTypography.headlineMedium.font)
                .tracking(SalusTypography.headlineMedium.tracking)
            Text(verbatim: HomeStrings.greeting(greeting))
                .font(SalusTypography.bodyLarge.font)
                .tracking(SalusTypography.bodyLarge.tracking)
        }
        .foregroundStyle(theme.colorScheme.onPrimaryContainer)
        // `fillMaxWidth().background(primaryContainer).padding(horizontal = lg, vertical = xl)`
        // (`HomeScreen.kt:162-165`) — the padding is inside the band, so the tint reaches the edges.
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.xl)
        .background(theme.colorScheme.primaryContainer)
    }
}

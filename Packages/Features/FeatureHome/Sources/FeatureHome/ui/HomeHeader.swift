// Ported from `HomeScreen.kt:155-235` — the hero band: a full-width vertical gradient with the
// personalised greeting, the date, the avatar and, when there are doses today, the dose-progress
// ring.
//
// Android's M9 removed the settings gear the old doc comment mentions, and the M12 refresh
// (`56ccb9b`) replaced the `primaryContainer` band with a hero gradient, added the avatar and the
// dose ring. Kotlin resolves the date through a `remember(locale)` `DateTimeFormatter`; iOS keeps
// `HomeFormatting.fullDate` as the standing twin of that formatter.
//
// Material → SwiftUI:
//   `Brush.verticalGradient(listOf(hero.top, hero.bottom))` → `theme.extendedColors.hero.vertical`
//                                                        (`SalusGradient.vertical`).
//   `Row(verticalAlignment = Top) { Column(weight(1f)) … SalusAvatar }`
//                                                   → the `HStack(alignment: .top)` below, with the
//                                                     text column greedy and the avatar trailing.
//   `Spacer(height = xs)`                            → `VStack(spacing: SalusSpacing.xs)`.
//   `Spacer(height = lg)` / `Spacer(width = md)`     → the `Spacer().frame(...)` gaps.
//   `Color.White` / `Color.White.copy(alpha = 0.9f)` → `.foregroundStyle(.white)` / `(.white.opacity(0.9))`
//  (`white` is Kotlin's own literal, so it is allowed by the no-hex rule.)
//   `MaterialTheme.typography.*`                     → `SalusTypography.*`, `.font` + `.tracking`.
//
// The greeting picks the formatted `%1$@` arm when a profile name exists and the `*_plain` arm
// otherwise — `greetingText(greeting, profileName)` (`HomeScreen.kt:221-235`) — through the two
// `HomeStrings.greeting` overloads. Kotlin's `profileName != null` gate is mirrored exactly: a
// non-nil (even blank) name takes the formatted arm.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The hero band above the cards (`HomeScreen.kt:159-219`).
struct HomeHeader: View {
    let todayEpochDay: Int
    let greeting: HomeGreeting
    let profileName: String?
    let doseProgress: (taken: Int, total: Int)?

    @Environment(\.salusTheme) private var theme
    /// `LocalLocale.current.platformLocale` (`HomeScreen.kt:166`).
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                    greetingText
                    // `LocalDate.ofEpochDay(todayEpochDay).format(dateFormatter)` (`HomeScreen.kt:191-196`),
                    // pre-formatted by `HomeFormatting.fullDate`, so `verbatim`.
                    Text(verbatim: HomeFormatting.fullDate(epochDay: todayEpochDay, locale: locale))
                        .font(SalusTypography.bodyLarge.font)
                        .tracking(SalusTypography.bodyLarge.tracking)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // `SalusAvatar(name = profileName, size = SalusAvatarDefaults.LargeSize)`
                // (`HomeScreen.kt:198-201`).
                SalusAvatar(name: profileName, size: SalusAvatarDefaults.largeSize)
            }
            // `doseProgress?.let { (taken, total) -> … }` (`HomeScreen.kt:203-217`).
            if let doseProgress {
                Spacer().frame(height: SalusSpacing.lg)
                doseProgressRow(doseProgress)
            }
        }
        .foregroundStyle(.white)
        // `fillMaxWidth().background(Brush.verticalGradient(hero.top, hero.bottom)).padding(horizontal = lg,
        // vertical = xl)` (`HomeScreen.kt:172-177`) — the padding is inside the band, so the
        // gradient reaches the edges.
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.xl)
        .background(theme.extendedColors.hero.vertical)
    }

    /// `greetingText(greeting, profileName)` (`HomeScreen.kt:221-235`) — `headlineMedium`, white.
    @ViewBuilder private var greetingText: some View {
        if let profileName {
            Text(verbatim: HomeStrings.greeting(greeting, name: profileName))
                .font(SalusTypography.headlineMedium.font)
                .tracking(SalusTypography.headlineMedium.tracking)
        } else {
            Text(verbatim: HomeStrings.greeting(greeting))
                .font(SalusTypography.headlineMedium.font)
                .tracking(SalusTypography.headlineMedium.tracking)
        }
    }

    /// The ring and its caption (`HomeScreen.kt:204-216`).
    private func doseProgressRow(_ progress: (taken: Int, total: Int)) -> some View {
        HStack(spacing: 0) {
            // `SalusProgressRing(progress = taken.toFloat() / total, label = "$taken/$total")`
            // (`HomeScreen.kt:206-209`).
            SalusProgressRing(
                progress: Float(progress.taken) / Float(progress.total),
                label: "\(progress.taken)/\(progress.total)"
            )
            Spacer().frame(width: SalusSpacing.md)
            // `stringResource(R.string.home_dose_progress, taken, total)` (`HomeScreen.kt:211-215`),
            // `bodySmall`, white-90%.
            Text(verbatim: HomeStrings.doseProgress(progress.taken, progress.total))
                .font(SalusTypography.bodySmall.font)
                .tracking(SalusTypography.bodySmall.tracking)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

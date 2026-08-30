// Ported 1:1 from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// ui/about/AboutScreen.kt`.
//
// Material → SwiftUI, per the mapping table `docs/ios-feature-template.md` records:
//   `TopAppBar` + `navigationIcon`  → `.navigationTitle(_:)`; the shell's one `NavigationStack`
//                                    draws the back button, so `onBack` is not a back-button
//                                    callback but the shell's `navigator.pop` — and no
//                                    `settings_back` key ships (recorded divergence (d), the same
//                                    one `ProfileScreen.swift` and `ReminderHealthScreen.swift`
//                                    record).
//   `Column` + `verticalScroll`     → `ScrollView` + `VStack(spacing:)`.
//   `Card`                          → `SalusCard` (`SalusUI`).
//   `Modifier.padding(16.dp)`        → `SalusSpacing.lg` (ruling 10, divergence (c) — the Android
//                                    file's hardcoded 16/12/8 dp become the `SalusSpacing` tokens,
//                                    the same conversion every other screen in the port makes; the
//                                    values are identical, `lg = 16`, `md = 12`, `sm = 8`).
//
// The app version deliberately lives on the More screen's About row only, so the number has a single
// home (`AboutScreen.kt:33-34`); see `docs/architecture/m9-plan.md` item 1. No version footer here.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the (empty) ViewModel and wires it to the shell (`AboutScreen.kt:27-31`).
///
/// The Kotlin `AboutRoute` calls `koinInject<Navigator>()` then passes `navigator::pop` as `onBack`;
/// iOS needs neither, because the shell's one `NavigationStack` draws the back button itself once a
/// `.navigationTitle` is set (divergence (d) — the same one `ProfileRoute` and `ReminderHealthRoute`
/// record). The back tap pops the stack without the feature reaching for a `Navigator`.
public struct AboutRoute: View {
    public init() {}

    public var body: some View {
        AboutScreen()
    }
}

/// The stateless About screen (`AboutScreen.kt:35-79`).
struct AboutScreen: View {
    @Environment(\.salusTheme) private var theme

    private var colors: SalusColorScheme { theme.colorScheme }

    var body: some View {
        // No `Scaffold` twin: the shell owns the one navigation stack and its insets, and draws the
        // back button (divergence (d)).
        ScrollView {
            VStack(spacing: SalusSpacing.md) {
                Text(verbatim: SettingsStrings.aboutAppName)
                    .font(SalusTypography.headlineMedium.font)
                    .tracking(SalusTypography.headlineMedium.tracking)
                    .foregroundStyle(colors.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(verbatim: SettingsStrings.aboutDescription)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // The privacy card (`AboutScreen.kt:65-77`).
                SalusCard(contentPadding: SalusSpacing.lg) {
                    VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                        Text(verbatim: SettingsStrings.aboutPrivacyTitle)
                            .font(SalusTypography.titleMedium.font)
                            .tracking(SalusTypography.titleMedium.tracking)
                            .foregroundStyle(colors.onSurface)
                        Text(verbatim: SettingsStrings.aboutPrivacyBody)
                            .font(SalusTypography.bodyMedium.font)
                            .tracking(SalusTypography.bodyMedium.tracking)
                            .foregroundStyle(colors.onSurface)
                    }
                }
            }
            .padding(SalusSpacing.lg)
        }
        .background(colors.background)
        .navigationTitle(SettingsStrings.aboutTitle)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview("About") {
    NavigationStack {
        AboutScreen()
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("About, dark") {
    NavigationStack {
        AboutScreen()
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: true))
    .preferredColorScheme(.dark)
}

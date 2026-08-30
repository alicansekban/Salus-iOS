// Ported 1:1 from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// ui/more/MoreScreen.kt`. Material → SwiftUI (the mapping `docs/ios-feature-template.md` records):
// `Column`+`verticalScroll` → `ScrollView`+`VStack(spacing:)`; tab-root `SalusScreenHeader` stays
// `SalusScreenHeader(title:)` (no `TopAppBar` — divergence (d)); `SalusSectionHeader(contentPadding
// = top(sm))` → `SalusSectionHeader(title:)` with no column horizontal padding (cards carry the
// inset — the cosmetic difference `ProfileScreen.swift` records); `Card(onClick)` → `SalusCard`;
// `Switch` → `Toggle`; `AlertDialog`+`RadioButton` → `confirmationDialog`; `Icons.Outlined.*` → SF
// Symbols (the Material→SF map is in the task brief — a recorded divergence, not byte-for-byte);
// `stringResource(R.string.…)` → `SettingsStrings.…` in `Text(verbatim:)`; `profileName.ifBlank` →
// `profileName.isEmpty ? … : profileName`.
//
// Six platform divergences from the Kotlin twin:
//   1. **`MoreRoute` owns the LAContext availability check** — the twin of
//      `BiometricManager.from(context).canAuthenticate(BIOMETRIC_WEAK or DEVICE_CREDENTIAL)`
//      (`MoreScreen.kt:94-98`); `.canEvaluatePolicy(.deviceOwnerAuthentication)` answers true with a
//      biometric enrolled or a passcode set.
//   2. **The enable-re-auth interception (ruling 4) is a shell-injected closure**, not a
//      `BiometricPrompt` the Route builds. The shell owns the `LAContext`; the Route calls
//      `appLockPrompt(…)` and forwards `SetAppLock(true)` only on a true answer.
//   3. **`UIApplication.openSettingsURLString` for the notification row** — the twin of
//      `Settings.ACTION_APP_NOTIFICATION_SETTINGS` (`MoreScreen.kt:144-149`). iOS exposes no
//      notification-only page, so the row opens the app's own Settings page.
//   4. **`CFBundleShortVersionString` for the version footer** — the twin of
//      `context.packageManager.getPackageInfo(…).versionName` (`MoreScreen.kt:120-124`).
//   5. **Effect consumption drains a queue, not a `Channel`** (MoreViewModel div. 4): a `.task`
//      re-runs `restartObservation()` (ruling 3) and drains `pendingEffects` on every appearance.
//   6. **`effectivePremiumTheme` is two-state** (the collapse `MoreViewModel` makes, div. 1):
//      `status == .entitled ? selected : .classic`, folding `GRACE_PERIOD` and `PREMIUM`.
//
// The three same-feature pushes (`ReminderHealthKey`/`AboutKey`/`ProfileKey`) the Kotlin Route makes
// through `koinInject<Navigator>()` (`MoreScreen.kt:139-141`) go through the `navigator` the
// `SettingsModule` exposes — the same way `ProfileViewModel` reaches it. The shell owns the stack.

import Foundation
import LocalAuthentication
import SalusDesignSystem
import SalusModel
import SalusNavigation
import SalusUI
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// Owns the ViewModel and wires it to the shell (`MoreScreen.kt:81-151`).
///
/// `onOpenCycle`/`onOpenDoctorReport`/`onOpenTrends` are the cross-feature hops (the shell owns the
/// keys, the feature cannot); `appLockPrompt` is the shell-owned biometric evaluation the
/// enable-re-auth interception calls (ruling 4 — the shell owns the `LAContext`).
public struct MoreRoute: View {
    @Environment(\.settingsModule) private var module
    @Environment(\.openURL) private var openURL

    @State private var viewModel: MoreViewModel?

    /// Whether the device can evaluate `.deviceOwnerAuthentication` (divergence 1), read once per
    /// Route — the same `remember(context)` the Kotlin `MoreRoute` carries (`MoreScreen.kt:94-98`).
    @State private var appLockAvailable = false

    /// `CFBundleShortVersionString` (`MoreScreen.kt:120-124`). `nil` renders by omitting the footer.
    @State private var versionName: String?

    let onOpenCycle: () -> Void
    let onOpenDoctorReport: () -> Void
    let onOpenTrends: () -> Void
    /// The shell-owned biometric prompt the enable-re-auth interception calls (ruling 4 / div. 2).
    /// `false` is the silence the Kotlin `onAuthenticationSucceeded`-only callback produces on
    /// cancel/failure (`MoreScreen.kt:452-472`).
    let appLockPrompt: @MainActor (String) async -> Bool

    public init(
        onOpenCycle: @escaping () -> Void,
        onOpenDoctorReport: @escaping () -> Void,
        onOpenTrends: @escaping () -> Void,
        appLockPrompt: @escaping @MainActor (String) async -> Bool
    ) {
        self.onOpenCycle = onOpenCycle
        self.onOpenDoctorReport = onOpenDoctorReport
        self.onOpenTrends = onOpenTrends
        self.appLockPrompt = appLockPrompt
    }

    public var body: some View {
        Group {
            if let viewModel {
                MoreScreen(
                    state: viewModel.state,
                    versionName: versionName ?? "",
                    appLockAvailable: appLockAvailable,
                    onEvent: { event in
                        // `MoreScreen.kt:130-137` — only the enable edge is intercepted; a disabling
                        // tap is forwarded straight through (div. 2 — the prompt is shell-owned).
                        if case let .setAppLock(enabled) = event, enabled {
                            Task { [appLockPrompt] in
                                if await appLockPrompt(SettingsStrings.settingsAppLockConfirmTitle) {
                                    viewModel.onEvent(event)
                                }
                            }
                        } else {
                            viewModel.onEvent(event)
                        }
                    },
                    onOpenCycle: onOpenCycle,
                    // `navigator.navigate(ReminderHealthKey/AboutKey/ProfileKey)`
                    // (`MoreScreen.kt:139-141`) — the shell owns the stack; a row pushes through the
                    // navigator rather than `backStacks.push`.
                    onOpenReminderHealth: { module?.navigator.navigate(ReminderHealthKey()) },
                    onOpenAbout: { module?.navigator.navigate(AboutKey()) },
                    onOpenProfile: { module?.navigator.navigate(ProfileKey()) },
                    onOpenNotificationSettings: openNotificationSettings
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeMoreViewModel()
            // `BiometricManager.from(context).canAuthenticate(…)` (divergence 1).
            appLockAvailable = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
            // `context.packageManager.getPackageInfo(…).versionName` (divergence 4).
            versionName = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        }
        // The buffered-effects drain (MoreViewModel div. 4/5): re-runs on every appearance,
        // re-capturing the profile stream (ruling 3) and draining any effect fired off-screen.
        .task {
            await drainEffects()
        }
    }

    /// Drains `viewModel.pendingEffects` in order — the twin of the Kotlin
    /// `LaunchedEffect { viewModel.effects.collect { … } }` (`MoreScreen.kt:103-116`).
    @MainActor
    private func drainEffects() async {
        guard let viewModel else { return }
        viewModel.restartObservation()
        // Drain until empty: a handler may append an effect, and a single pass would miss it — the
        // Kotlin `collect` is the same shape, it never returns.
        while !viewModel.pendingEffects.isEmpty {
            for effect in viewModel.consumeEffects() {
                switch effect {
                case let .openUrl(urlString):
                    #if canImport(UIKit)
                        guard let url = URL(string: urlString) else { continue }
                        // `runCatching { context.startActivity(Intent(…)) }` — a device without the
                        // App Store must not crash on a tap.
                        openURL(url)
                    #endif

                case .openDoctorReport:
                    onOpenDoctorReport()

                case .openTrends:
                    onOpenTrends()
                }
            }
        }
    }

    /// `Settings.ACTION_APP_NOTIFICATION_SETTINGS` → `UIApplication.openSettingsURLString`
    /// (divergence 3) — iOS exposes no notification-only page, so the row opens the app's Settings.
    private func openNotificationSettings() {
        #if canImport(UIKit)
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        #endif
    }
}

/// The stateless More hub (`MoreScreen.kt:153-358`).
struct MoreScreen: View {
    let state: MoreUiState
    let versionName: String
    let appLockAvailable: Bool
    let onEvent: (MoreEvent) -> Void
    let onOpenCycle: () -> Void
    let onOpenReminderHealth: () -> Void
    let onOpenAbout: () -> Void
    let onOpenProfile: () -> Void
    let onOpenNotificationSettings: () -> Void

    @Environment(\.salusTheme) private var theme

    private var colors: SalusColorScheme { theme.colorScheme }

    var body: some View {
        // No `Scaffold` twin and no inset modifiers: the shell owns the one `NavigationStack` and
        // its insets, and this is a tab root — `SalusScreenHeader` rather than a `TopAppBar`
        // (div. (d), `MoreScreen.kt:165-168`). The §1 draw order is `MoreScreen.kt:180-313`;
        // section labels carry no horizontal padding (each card carries the screen inset).
        VStack(spacing: 0) {
            SalusScreenHeader(title: SettingsStrings.moreTitle)
            ScrollView {
                VStack(spacing: SalusSpacing.md) {
                    // 1. Profile (`MoreScreen.kt:180-187`): blank name → onboarding skipped.
                    MoreCard(
                        icon: "person.fill",
                        title: SettingsStrings.moreProfile,
                        subtitle: state.profileName.isEmpty
                            ? SettingsStrings.moreProfileIncomplete
                            : state.profileName,
                        onClick: onOpenProfile
                    )

                    // 2. Premium (`MoreScreen.kt:191-202`): sits above every section.
                    MoreCard(
                        icon: "crown.fill",
                        title: SettingsStrings.settingsPremium,
                        subtitle: state.premiumStatus == .entitled
                            ? SettingsStrings.settingsPremiumActive
                            : SettingsStrings.settingsPremiumPromo,
                        onClick: { onEvent(.premiumClicked) }
                    )

                    // 3. Doctor report (`MoreScreen.kt:206-211`): the premium feature people leave
                    //    with.
                    MoreCard(
                        icon: "doc.text",
                        title: SettingsStrings.settingsDoctorReport,
                        subtitle: SettingsStrings.settingsDoctorReportDesc,
                        onClick: { onEvent(.doctorReportClicked) }
                    )

                    // 4. Trends (`MoreScreen.kt:215-220`): not gated — the screen shows its lock.
                    MoreCard(
                        icon: "chart.xyaxis.line",
                        title: SettingsStrings.moreTrends,
                        subtitle: SettingsStrings.moreTrendsSubtitle,
                        onClick: { onEvent(.trendsClicked) }
                    )

                    // 5. [if showCycle] Tracking + Cycle (`MoreScreen.kt:222-231`): hidden for male
                    //    profiles; the accent is the cycle one.
                    if state.showCycle {
                        SectionLabel(title: SettingsStrings.moreSectionTracking)
                        MoreCard(
                            icon: "drop.fill",
                            title: SettingsStrings.moreCycle,
                            subtitle: SettingsStrings.moreCycleSubtitle,
                            onClick: onOpenCycle,
                            accent: theme.extendedColors.cycle
                        )
                    }

                    // 6-8. Appearance: theme, color theme, language (`MoreScreen.kt:233-256`).
                    SectionLabel(title: SettingsStrings.settingsSectionAppearance)
                    MoreCard(
                        icon: "paintpalette.fill",
                        title: SettingsStrings.settingsTheme,
                        subtitle: SettingsStrings.theme(state.themeMode),
                        onClick: { onEvent(.dialogRequested(.theme)) }
                    )
                    MoreCard(
                        icon: "circle.hexagons.fill",
                        title: SettingsStrings.settingsColorTheme,
                        // `effectivePremiumTheme(status, selected)` (div. 6): the palette actually
                        // drawn, not the stored pick — a lapsed subscriber sees Classic here; the
                        // dialog still shows their stored choice as selected.
                        subtitle: SettingsStrings.colorTheme(effectivePremiumTheme(
                            state.premiumStatus,
                            state.premiumTheme
                        )),
                        onClick: { onEvent(.dialogRequested(.colorTheme)) }
                    )
                    MoreCard(
                        icon: "globe",
                        title: SettingsStrings.settingsLanguage,
                        subtitle: SettingsStrings.language(state.language),
                        onClick: { onEvent(.dialogRequested(.language)) }
                    )

                    // 9-10. Security: app lock + secure screen (`MoreScreen.kt:258-279`).
                    SectionLabel(title: SettingsStrings.settingsSectionSecurity)
                    MoreToggleCard(
                        icon: "lock.fill",
                        title: SettingsStrings.settingsAppLock,
                        subtitle: appLockAvailable
                            ? SettingsStrings.settingsAppLockDesc
                            : SettingsStrings.settingsAppLockUnavailable,
                        checked: state.appLockEnabled && appLockAvailable,
                        onCheckedChange: { onEvent(.setAppLock($0)) },
                        enabled: appLockAvailable
                    )
                    MoreToggleCard(
                        icon: "camera.viewfinder",
                        title: SettingsStrings.settingsSecureScreen,
                        subtitle: SettingsStrings.settingsSecureScreenDesc,
                        checked: state.secureScreenEnabled,
                        onCheckedChange: { onEvent(.setSecureScreen($0)) }
                    )

                    // 11-12. Notifications section (`MoreScreen.kt:281-293`).
                    SectionLabel(title: SettingsStrings.settingsSectionNotifications)
                    MoreCard(
                        icon: "bell.fill",
                        title: SettingsStrings.settingsNotifications,
                        subtitle: SettingsStrings.settingsNotificationsDesc,
                        onClick: onOpenNotificationSettings
                    )
                    MoreCard(
                        icon: "alarm.fill",
                        title: SettingsStrings.settingsReminders,
                        subtitle: SettingsStrings.settingsRemindersDesc,
                        onClick: onOpenReminderHealth
                    )

                    // 13. App section: about (`MoreScreen.kt:295-301`).
                    SectionLabel(title: SettingsStrings.settingsSectionApp)
                    MoreCard(
                        icon: "info.circle.fill",
                        title: SettingsStrings.settingsAbout,
                        subtitle: SettingsStrings.settingsAboutDesc,
                        onClick: onOpenAbout
                    )

                    // 14. Version footer (`MoreScreen.kt:303-313`).
                    if !versionName.isEmpty {
                        Text(verbatim: SettingsStrings.aboutVersion(versionName))
                            .font(SalusTypography.bodySmall.font)
                            .tracking(SalusTypography.bodySmall.tracking)
                            .foregroundStyle(colors.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, SalusSpacing.md)
                    }
                }
                .padding(.horizontal, SalusSpacing.lg)
                .padding(.bottom, SalusSpacing.xl)
            }
        }
        .background(colors.background)
        // The three selection dialogs (`MoreScreen.kt:317-357`), built on `activeDialog` rather than
        // three `@State` flags (matching Kotlin's `when (state.activeDialog)`). Each `isPresented`
        // binding reads/writes `activeDialog` so only one is open at a time.
        .confirmationDialog(
            SettingsStrings.themeTitle,
            isPresented: Binding(
                get: { state.activeDialog == .theme },
                set: { presented in
                    if !presented {
                        onEvent(.dialogDismissed)
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            ForEach(ThemeMode.allCases, id: \.self) { mode in
                Button {
                    onEvent(.selectTheme(mode))
                } label: {
                    Text(verbatim: SettingsStrings.theme(mode))
                }
            }
            Button(role: .cancel) {
                onEvent(.dialogDismissed)
            } label: {
                Text(verbatim: SettingsStrings.settingsCancel)
            }
        }
        .confirmationDialog(
            SettingsStrings.settingsColorTheme,
            isPresented: Binding(
                get: { state.activeDialog == .colorTheme },
                set: { presented in
                    if !presented {
                        onEvent(.dialogDismissed)
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            // Free users see the full list — the entitlement check runs in the ViewModel on tap, so
            // the palettes stay visible as something to subscribe for.
            ForEach(PremiumTheme.allCases, id: \.self) { premiumTheme in
                Button {
                    onEvent(.colorThemeSelected(premiumTheme))
                } label: {
                    Text(verbatim: SettingsStrings.colorTheme(premiumTheme))
                }
            }
            Button(role: .cancel) {
                onEvent(.dialogDismissed)
            } label: {
                Text(verbatim: SettingsStrings.settingsCancel)
            }
        }
        .confirmationDialog(
            SettingsStrings.languageTitle,
            isPresented: Binding(
                get: { state.activeDialog == .language },
                set: { presented in
                    if !presented {
                        onEvent(.dialogDismissed)
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            ForEach(AppLanguage.allCases, id: \.self) { language in
                Button {
                    onEvent(.selectLanguage(language))
                } label: {
                    Text(verbatim: SettingsStrings.language(language))
                }
            }
            Button(role: .cancel) {
                onEvent(.dialogDismissed)
            } label: {
                Text(verbatim: SettingsStrings.settingsCancel)
            }
        }
    }
}

// MARK: - Previews

#Preview("More, with cycle") {
    NavigationStack {
        MoreScreen(
            state: MoreUiState(
                isLoading: false,
                profileName: "Ada",
                showCycle: true,
                themeMode: .system,
                language: .turkish,
                appLockEnabled: true
            ),
            versionName: "1.0.0",
            appLockAvailable: true,
            onEvent: { _ in },
            onOpenCycle: {},
            onOpenReminderHealth: {},
            onOpenAbout: {},
            onOpenProfile: {},
            onOpenNotificationSettings: {}
        )
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("More, without cycle, premium") {
    NavigationStack {
        MoreScreen(
            state: MoreUiState(
                isLoading: false,
                showCycle: false,
                premiumTheme: .ocean,
                premiumStatus: .entitled
            ),
            versionName: "1.0.0",
            appLockAvailable: false,
            onEvent: { _ in },
            onOpenCycle: {},
            onOpenReminderHealth: {},
            onOpenAbout: {},
            onOpenProfile: {},
            onOpenNotificationSettings: {}
        )
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

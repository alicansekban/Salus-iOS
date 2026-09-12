// Ported 1:1 from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// ui/more/MoreScreen.kt`. Material → SwiftUI (the mapping `docs/ios-feature-template.md` records):
// `Column`+`verticalScroll` → `ScrollView`+`VStack(spacing:)`; the tab-root title is the shell's
// root toolbar plus this screen's `.navigationTitle` (iOS-M16 retired `SalusScreenHeader`, spec
// §2.2 — a native inline navigation bar, not a `TopAppBar`); `SalusSectionHeader(contentPadding
// = top(sm))` → `SalusSectionHeader(title:contentPadding: .topOnly)`, the scroll column carrying the
// screen's horizontal inset exactly as the Kotlin column does; `Card(onClick)` → `SalusCard`;
// `Switch` → `Toggle`; `AlertDialog`+`RadioButton` → the theme/language `.sheet`s (§2.3);
// `Icons.Outlined.*` → SF Symbols (a recorded divergence, not byte-for-byte);
// `stringResource(R.string.…)` → `SettingsStrings.…` in `Text(verbatim:)`.
//
// Eleven platform divergences from the Kotlin twin:
//   1. **`MoreRoute` owns the LAContext availability check** — the twin of
//      `.canEvaluatePolicy(.deviceOwnerAuthentication)` (`MoreScreen.kt:98-101`).
//   2. **The enable-re-auth interception (ruling 4) is a shell-injected closure**, not a
//      `BiometricPrompt`; the shell owns the `LAContext`, the Route calls `appLockPrompt(…)`.
//   3. **`UIApplication.openSettingsURLString` for the notification row** — iOS exposes no
//      notification-only page (`MoreScreen.kt:155-160`).
//   4. **`CFBundleShortVersionString` for the version footer** (`MoreScreen.kt:130-134`).
//   5. **Effect consumption drains a queue, not a `Channel`** (MoreViewModel div. 4) — the
//      collector is `.onChange(of: viewModel.pendingEffects)` (`AppointmentEditorScreen.swift:79`).
//   6. **`effectivePremiumTheme` reads the real three-state `PremiumStatus`** (`isEntitled`).
//   7. **The theme/language popups are `salusBottomSheet`s (`.medium`), not a `salusDialog`** —
//      `ThemeSheet`/`LanguageSheet` are their own files (plan ruling 1); `MoreSelectionDialog`
//      is retired (M16 Task 10).
//   8. **`SalusCard`'s content padding is uniform.** Kotlin's cards use
//      `horizontal = lg, vertical = md` (`MoreScreen.kt:404-412`); `SalusCard` takes one value by
//      house design, so every card here is `lg` on all four edges — the accepted limitation of the
//      shared component, not a new one.
//   9. **A language pick applies live through `SalusLocalization`**, the twin of appcompat's
//      `recreate()`: `RootView` re-identifies the tabs on the change, so this screen is rebuilt in
//      the new language while the stack and selection survive.
//   10. **The two setting sheets present from the `MoreScreen` body**, not on the `Route`: they are
//      tied to `state.isThemeSheetOpen` / `state.isLanguageSheetOpen`, which only the stateless
//      screen's environment knows. Kotlin's `MoreScreen` draws them the same way (`MoreScreen.kt`).
//   11. **The sex chip and PRO badge** (`MoreSections.kt:52-76`) live in the profile card, chipped
//      exactly as Kotlin draws them — the neutral sex chip + the accent PRO badge when entitled.

// The three same-feature pushes (`ReminderHealthKey`/`AboutKey`/`ProfileKey`) the Kotlin Route makes
// through `koinInject<Navigator>()` (`MoreScreen.kt:149-152`) go through the `navigator` the
// `SettingsModule` exposes — the same way `ProfileViewModel` reaches it. The shell owns the stack.

import Foundation
import LocalAuthentication
import SalusDesignSystem
import SalusModel
import SalusNavigation
import SalusPremium
import SalusUI
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// Owns the ViewModel and wires it to the shell (`MoreScreen.kt:86-162`).
///
/// `onOpenCycle`/`onOpenDoctorReport`/`onOpenTrends` are the cross-feature hops (the shell owns the
/// keys, the feature cannot); `appLockPrompt` is the shell-owned biometric evaluation the
/// enable-re-auth interception calls (ruling 4 — the shell owns the `LAContext`).
///
/// The three hops are parameters **here** rather than of `settingsDestinations()`, which the M8
/// plan named — recorded divergence (ruling H-7); `SettingsNavigation.swift`'s header says why.
public struct MoreRoute: View {
    @Environment(\.settingsModule) private var module
    @Environment(\.openURL) private var openURL

    @State private var viewModel: MoreViewModel?

    /// Whether the device can evaluate `.deviceOwnerAuthentication` (divergence 1), read once per
    /// Route — the same `remember(context)` the Kotlin `MoreRoute` carries (`MoreScreen.kt:98-101`).
    @State private var appLockAvailable = false

    /// `CFBundleShortVersionString` (`MoreScreen.kt:130-134`). `nil` renders by omitting the footer.
    @State private var versionName: String?

    let onOpenCycle: () -> Void
    let onOpenDoctorReport: () -> Void
    let onOpenTrends: () -> Void
    /// The shell-owned biometric prompt the enable-re-auth interception calls (ruling 4 / div. 2).
    /// `false` is the silence the Kotlin `onAuthenticationSucceeded`-only callback produces on
    /// cancel/failure (`MoreScreen.kt:477-497`).
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
                hub(driving: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let module else { return }
            guard viewModel == nil else {
                // A returning appearance re-captures the profile stream — the behavioural half of
                // Kotlin's `WhileSubscribed(5_000)` (ruling 3, MoreViewModel div. 5). A first
                // appearance needs no restart: `MoreViewModel.init` already started the
                // observation, which is why the call sits beside the creation rather than in a
                // second `.task` that would depend on this one having run first.
                viewModel?.restartObservation()
                return
            }
            viewModel = module.makeMoreViewModel()
            // `BiometricManager.from(context).canAuthenticate(…)` (divergence 1).
            appLockAvailable = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
            // `context.packageManager.getPackageInfo(…).versionName` (divergence 4).
            versionName = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        }
    }

    /// The screen plus its effect collector, compiled only where there is a ViewModel to drive them
    /// — the shape `AppointmentEditorScreen`'s `editor(driving:)` sets.
    private func hub(driving viewModel: MoreViewModel) -> some View {
        MoreScreen(
            state: viewModel.state,
            versionName: versionName ?? "",
            appLockAvailable: appLockAvailable,
            onEvent: { event in
                // `MoreScreen.kt:140-147` — only the enable edge is intercepted; a disabling
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
            // (`MoreScreen.kt:149-152`) — the shell owns the stack; a row pushes through the
            // navigator rather than `backStacks.push`.
            onOpenReminderHealth: { module?.navigator.navigate(ReminderHealthKey()) },
            onOpenAbout: { module?.navigator.navigate(AboutKey()) },
            onOpenProfile: { module?.navigator.navigate(ProfileKey()) },
            onOpenNotificationSettings: openNotificationSettings
        )
        // The collector for `Channel<MoreEffect>` (MoreViewModel div. 4), spelled for an
        // `@Observable`: the queue is a property, so `.onChange` is the twin of the Kotlin
        // `LaunchedEffect { viewModel.effects.collect { … } }` (`MoreScreen.kt:107-126`) — it fires
        // on every append, for as long as this view lives, which a `.task` on a tab root (created
        // once, never re-created) would not. `pendingEffects` is a queue rather than a single
        // effect because two rows can fire back-to-back, so the handler drains all of it.
        .onChange(of: viewModel.pendingEffects) { _, pending in
            // Fires on the drain's own write as well as on the append; the empty edge is dropped.
            guard !pending.isEmpty else { return }
            deliver(viewModel.consumeEffects())
        }
    }

    /// Performs the drained effects in order (`MoreScreen.kt:107-126`).
    @MainActor
    private func deliver(_ effects: [MoreEffect]) {
        for effect in effects {
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

    /// `Settings.ACTION_APP_NOTIFICATION_SETTINGS` → `UIApplication.openSettingsURLString`
    /// (divergence 3) — iOS exposes no notification-only page, so the row opens the app's Settings.
    private func openNotificationSettings() {
        #if canImport(UIKit)
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        #endif
    }
}

/// The stateless More hub (`MoreScreen.kt:165-383`).
///
/// The profile card and premium band are built by the private row helpers in `MoreScreenSections.swift`
/// (extracted so this file stays under the 500-line `file_length` gate — M16 Task 10 split). The two
/// setting sheets present from this body's `.salusBottomSheet` modifiers, tied to the state flags.
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
        // its insets, and this is a tab root — so the title is the system navigation bar's, drawn
        // by the shell's root toolbar. The §1 draw order is `MoreScreen.kt:193-339`; the scroll
        // column carries the screen's horizontal inset for everything in it.
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: SalusSpacing.md) {
                    // 1. Profile card (`MoreSections.kt:28-60`): avatar, name, sex + PRO chips →
                    //    Profile.
                    MoreProfileCard(state: state, onClick: onOpenProfile)

                    // 2. Premium band (`MoreSections.kt:63-88`): sells rather than settles.
                    MorePremiumBand(state: state, onEvent: onEvent)

                    // 3. The grouped rows (`MoreSections.kt:91-214`): health, tracking, appearance,
                    //    notifications, security, app.
                    MoreSections(
                        state: state,
                        appLockAvailable: appLockAvailable,
                        onEvent: onEvent,
                        onOpenCycle: onOpenCycle,
                        onOpenReminderHealth: onOpenReminderHealth,
                        onOpenAbout: onOpenAbout,
                        onOpenNotificationSettings: onOpenNotificationSettings
                    )

                    // 4. `SalusDisclaimer(more_footer)` (`MoreScreen.kt:328-338`).
                    SalusDisclaimer(SettingsStrings.moreFooter)
                        .padding(.bottom, SalusSpacing.lg)
                }
                .padding(.horizontal, SalusSpacing.lg)
                .padding(.bottom, SalusSpacing.xl)
            }
        }
        .background(colors.background)
        // The screen title. The shell's root toolbar draws it in the navigation bar's principal
        // slot; `.navigationTitle` is still what names the back button of everything this root
        // pushes — Profile, About, Reminder health, Cycle — and what VoiceOver reads.
        .navigationTitle(Text(verbatim: SettingsStrings.moreTitle))
        // The two setting sheets (plan ruling 1), driven by the state flags rather than two
        // `@State` values. ThemeSheet and LanguageSheet attach their own `salusBottomSheet`
        // (`.medium` detent); they sit in a zero-size background so neither presents over the
        // other, exactly as Kotlin's two independent `if (state.isThemeSheetOpen) { ThemeSheet() }`
        // blocks draw side by side.
        .background {
            ThemeSheet(state: state, onEvent: onEvent)
            LanguageSheet(state: state, onEvent: onEvent)
        }
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host. Last because SwiftFormat indents
        // whatever follows an `#endif` one level deeper.
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Previews

// The 8-palette fan-out: `SalusPreviewPalettes` renders `content` once per premium palette in both
// modes (spec §3, the iOS twin of Android's `@PreviewParameter(SalusPaletteProvider::class)`).
// A preview cannot show a live sheet — the presentation belongs to a window of its own — so the
// state flags are left closed here.
#Preview("More, 8 palettes") {
    SalusPreviewPalettes {
        MoreScreen(
            state: MoreUiState(
                isLoading: false,
                profileName: "Ada",
                profileSex: .female,
                showCycle: true,
                themeMode: .system,
                language: .turkish,
                premiumStatus: .premium,
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
}

// The system font scale is the one axis this list cannot control; a root has to survive it.
// `.dynamicTypeSize(.xxxLarge)` is the accessibility range floor (spec §5, QA rows).
#Preview("More, large dynamic type") {
    NavigationStack {
        MoreScreen(
            state: MoreUiState(
                isLoading: false,
                profileName: "Ada",
                profileSex: .female,
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
    .dynamicTypeSize(.xxxLarge)
}

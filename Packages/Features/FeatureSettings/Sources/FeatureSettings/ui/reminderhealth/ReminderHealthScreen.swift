// Ported from `feature/settings/src/main/kotlin/com/alicansekban/salus/feature/settings/
// ui/reminderhealth/ReminderHealthScreen.kt`.
//
// Material → SwiftUI, per the mapping table `docs/ios-feature-template.md` records:
//   `TopAppBar` + `navigationIcon`      → `.navigationTitle(_:)`; the shell's one `NavigationStack`
//                                         draws the back button, so no `onBack` parameter exists.
//   `Column` + `verticalScroll`         → `ScrollView` + `VStack(spacing:)`.
//   `Card`                              → `SalusCard` (`SalusUI`).
//   `FilledTonalButton`                 → `.buttonStyle(.borderedProminent)` tinted
//                                         `secondaryContainer`, which is what Material fills a
//                                         tonal button with.
//   `Icons.Filled.CheckCircle`/`Warning`→ SF Symbol names.
//   `Modifier.weight(1f)` in a `Row`    → `.frame(maxWidth: .infinity, alignment: .leading)`.
//   `LifecycleResumeEffect`             → `.onChange(of: scenePhase)`, `.active`.
//   `rememberLauncherForActivityResult` → no twin: the two prompts are `async` calls the ViewModel
//                                         makes itself, and only the Settings fall-through reaches
//                                         the view — as a URL to open.

import SalusDesignSystem
import SalusUI
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// Owns the ViewModel and wires it to the shell (`ReminderHealthScreen.kt:48-107`).
public struct ReminderHealthRoute: View {
    @Environment(\.settingsModule) private var module
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var viewModel: ReminderHealthViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                ReminderHealthScreen(state: viewModel.state, onEvent: viewModel.onEvent)
                    // `Channel.receiveAsFlow()` collected in a `LaunchedEffect`
                    // (`ReminderHealthScreen.kt:65-95`), spelled for an `@Observable`.
                    .onChange(of: viewModel.pendingEffect) { _, effect in
                        // Fires on the clear as well as on the set, so the nil edge is dropped
                        // before the queue is drained.
                        guard effect != nil, let pending = viewModel.consumeEffect() else { return }
                        open(pending)
                    }
                    // `LifecycleResumeEffect` (`ReminderHealthScreen.kt:98-101`): the user flips
                    // these switches in Settings, outside our process, so the only honest moment to
                    // re-read them is the one we come back in.
                    .onChange(of: scenePhase) { _, phase in
                        guard phase == .active else { return }
                        viewModel.onEvent(.refresh)
                    }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeReminderHealthViewModel()
        }
    }

    /// Both effects are a URL the system opens (`ReminderHealthScreen.kt:110-119` builds `Intent`s
    /// instead). `UIApplication` is the only place iOS spells these two addresses, so the whole
    /// function is UIKit-only; the macOS host `swift test` builds against has neither destination.
    private func open(_ effect: ReminderHealthEffect) {
        #if canImport(UIKit)
            let address = switch effect {
            case .openNotificationSettings: UIApplication.openNotificationSettingsURLString
            case .openAppSettings: UIApplication.openSettingsURLString
            }
            guard let url = URL(string: address) else { return }
            openURL(url)
        #endif
    }
}

/// The stateless screen (`ReminderHealthScreen.kt:121-215`).
struct ReminderHealthScreen: View {
    let state: ReminderHealthUiState
    let onEvent: (ReminderHealthEvent) -> Void

    @Environment(\.salusTheme) private var theme

    private var colors: SalusColorScheme { theme.colorScheme }

    var body: some View {
        // No `Scaffold` twin and no `NavigationStack` of its own: the shell owns the one stack and
        // its insets, and it is what draws the title and the back button.
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colors.background)
            .navigationTitle(SettingsStrings.reminderHealthTitle)
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host (CLAUDE.md's `.macOS(.v14)`
        // concession). Last because SwiftFormat indents whatever follows an `#endif` one level
        // deeper, which reads as if those modifiers were inside the guard
        // (`VitalsEditorChrome.swift`, `AppointmentDetailScreen.swift` set it the same way).
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            // `if (state.isLoading) return` (`ReminderHealthScreen.kt:141`). Android's reads are
            // synchronous and this frame is never seen; the iOS ones suspend, so it is.
            ProgressView()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: SalusSpacing.md) {
                    verdict
                    notificationsCard
                    if state.alarmKitSupported {
                        alarmKitCard
                    }
                    backgroundRefreshCard
                    lastSyncLine
                }
                .padding(SalusSpacing.lg)
            }
        }
    }

    /// `ReminderHealthScreen.kt:150-158`.
    private var verdict: some View {
        Text(verbatim: state.allHealthy ? SettingsStrings.reminderHealthAllOk : SettingsStrings.reminderHealthIntro)
            .font(SalusTypography.bodyMedium.font)
            .tracking(SalusTypography.bodyMedium.tracking)
            .foregroundStyle(colors.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `ReminderHealthScreen.kt:160-170` — notifications off is the one setting that stops a
    /// reminder from being shown at all, so it is an error rather than a warning.
    private var notificationsCard: some View {
        HealthCard(
            title: SettingsStrings.reminderHealthNotificationsTitle,
            description: state.notificationsEnabled
                ? SettingsStrings.reminderHealthNotificationsOk
                : SettingsStrings.reminderHealthNotificationsProblem,
            status: state.notificationsEnabled ? .success : .error,
            onFix: { onEvent(.fixNotifications) }
        )
    }

    /// `ReminderHealthScreen.kt:180-193` — drawn only where AlarmKit exists, exactly as Android
    /// draws its full-screen card only on API 34+ where the permission can be revoked. The dose
    /// still rings as a notification; only the full-screen alarm is lost, so a warning.
    private var alarmKitCard: some View {
        HealthCard(
            title: SettingsStrings.reminderHealthAlarmKitTitle,
            description: state.alarmKitAuthorized
                ? SettingsStrings.reminderHealthAlarmKitOk
                : SettingsStrings.reminderHealthAlarmKitProblem,
            status: state.alarmKitAuthorized ? .success : .warning,
            onFix: { onEvent(.requestAlarmKit) }
        )
    }

    /// The iOS replacement for the battery-optimization card (`ReminderHealthScreen.kt:195-206`).
    /// Only a delay is at stake, so it is a warning, never an error.
    private var backgroundRefreshCard: some View {
        HealthCard(
            title: SettingsStrings.reminderHealthBackgroundRefreshTitle,
            description: state.backgroundRefreshAvailable
                ? SettingsStrings.reminderHealthBackgroundRefreshOk
                : SettingsStrings.reminderHealthBackgroundRefreshProblem,
            status: state.backgroundRefreshAvailable ? .success : .warning,
            onFix: { onEvent(.fixBackgroundRefresh) }
        )
    }

    /// The honesty line, which Android has no twin for — see `ReminderHealthLastSync.line`, whose
    /// doc says what the stamp does and does not promise.
    private var lastSyncLine: some View {
        Text(verbatim: ReminderHealthLastSync.line(for: state.lastSyncAt, in: state.timeZone))
            .font(SalusTypography.bodySmall.font)
            .tracking(SalusTypography.bodySmall.tracking)
            .foregroundStyle(colors.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One row (`ReminderHealthScreen.kt:217-262`).
private struct HealthCard: View {
    let title: String
    let description: String
    /// The check's state: Success carries the ok chip; Warning / Error carry their own
    /// ``SalusStatus`` chip (`ReminderHealthScreen.kt:235-243`).
    let status: SalusStatus
    let onFix: () -> Void

    @Environment(\.salusTheme) private var theme

    private var colors: SalusColorScheme { theme.colorScheme }

    /// The Fix button only appears while the check is not healthy (`ReminderHealthScreen.kt:252-256`).
    private var needsFix: Bool {
        status != .success
    }

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                // `Row { Text(title).weight(1f); SalusStatusChip(status) }`
                // (`ReminderHealthScreen.kt:226-234`) — the chip heads the card, title left.
                HStack(spacing: SalusSpacing.sm) {
                    Text(verbatim: title)
                        .font(SalusTypography.titleMedium.font)
                        .tracking(SalusTypography.titleMedium.tracking)
                        .foregroundStyle(colors.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SalusStatusChip(label: label, status: status)
                }
                Text(verbatim: description)
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if needsFix {
                    // Material's `FilledTonalButton`: a `secondaryContainer` fill under an
                    // `onSecondaryContainer` label, which `.borderedProminent` draws once it is
                    // tinted with the container role (`ReminderHealthScreen.kt:264-270`).
                    fixButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `SalusStatus.labelRes()` (`ReminderHealthScreen.kt:272-280`): "Tamam" / "Sınırlı" / "Engelli".
    private var label: String {
        switch status {
        case .success: SettingsStrings.reminderHealthStatusOk
        case .warning: SettingsStrings.reminderHealthStatusWarning
        case .error: SettingsStrings.reminderHealthStatusError
        case .accent, .neutral: SettingsStrings.reminderHealthStatusOk
        }
    }

    /// Material's `FilledTonalButton`: a `secondaryContainer` fill under an `onSecondaryContainer`
    /// label, which `.borderedProminent` draws once it is tinted with the container role.
    private var fixButton: some View {
        Button(action: onFix) {
            Text(verbatim: SettingsStrings.reminderHealthFix)
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
                .foregroundStyle(colors.onSecondaryContainer)
        }
        .buttonStyle(.borderedProminent)
        .tint(colors.secondaryContainer)
    }
}

// The two states the screen has, previewed in both themes: everything healthy (one sentence, three
// green rows, a last-pass line) and everything broken (the intro sentence, three warning rows with
// their Fix buttons, and the never-ran line). These are the `#Preview` build check the testing
// standard asks of a view — behaviour lives in `ReminderHealthViewModel`, where it is asserted.

#Preview("Healthy") {
    NavigationStack {
        ReminderHealthScreen(
            state: ReminderHealthUiState(
                isLoading: false,
                notificationsEnabled: true,
                alarmKitSupported: true,
                alarmKitAuthorized: true,
                backgroundRefreshAvailable: true,
                lastSyncAt: Date(timeIntervalSince1970: 1_755_000_000),
                timeZone: .gmt
            ),
            onEvent: { _ in }
        )
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("Unhealthy") {
    NavigationStack {
        ReminderHealthScreen(
            state: ReminderHealthUiState(
                isLoading: false,
                notificationsEnabled: false,
                alarmKitSupported: true,
                alarmKitAuthorized: false,
                backgroundRefreshAvailable: false,
                lastSyncAt: nil,
                timeZone: .gmt
            ),
            onEvent: { _ in }
        )
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

#Preview("Unhealthy, dark") {
    NavigationStack {
        ReminderHealthScreen(
            state: ReminderHealthUiState(
                isLoading: false,
                notificationsEnabled: false,
                alarmKitSupported: true,
                alarmKitAuthorized: false,
                backgroundRefreshAvailable: false,
                lastSyncAt: nil,
                timeZone: .gmt
            ),
            onEvent: { _ in }
        )
    }
    .salusTheme(SalusTheme.resolve(systemIsDark: true))
    .preferredColorScheme(.dark)
}

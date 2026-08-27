// Ported from
// `feature/medications/src/test/kotlin/com/alicansekban/salus/feature/medications/
// FakeNavigator.kt`, which is itself byte-identical to `:feature:vitals`' copy — Android duplicates
// it per feature because `:core:testing` is a pure-JVM module and `:core:navigation` an Android one.
// The Swift file is therefore the same copy as `FeatureAppointmentsTests/FakeNavigator.swift`, and the
// feature template sanctions that duplicate: a test target cannot import another package's tests.
//
// One shape difference, and it is deliberate: `SalusNavigation.Navigator` is a concrete
// `final class`, not an interface, so there is nothing to implement. Kotlin needs the fake because
// it must satisfy the `Navigator` interface Koin hands ViewModels; here the *real* Navigator is
// already the test seam — it only publishes commands, and `commands` is the whole surface
// (`Navigator.swift:1-12` records that ruling). This type is therefore a recorder around a real
// Navigator rather than a stand-in for one, and no `Navigator` protocol is introduced for it.

import SalusNavigation

/// Records what a ViewModel asked for (`FakeNavigator.kt:15-28`).
///
/// Unused by `MedicationsViewModelTests` — the list ViewModel takes no navigator, its Route does.
/// It arrives with this slice because the detail and editor ViewModels (iOS-M5 Tasks 11 and 12) are
/// the ones Kotlin's `FakeNavigator.kt` exists for, and the file is their fixture.
///
/// The recorder drains `Navigator.commands` on the main actor, so `commandLog` lags a `navigate` /
/// `pop` by one hop — read it through `waitUntil`, exactly as the Kotlin test reads its log after
/// `advanceUntilIdle()`.
@MainActor
final class FakeNavigator {
    /// The instance under test. Handed to the ViewModel; nothing else touches it.
    let navigator = Navigator()

    /// `FakeNavigator.kt:17`.
    private(set) var commandLog: [NavCommand] = []

    private var drain: Task<Void, Never>?

    init() {
        // Subscribed here rather than on first read: `Navigator` hands a late subscriber the
        // backlog, but a ViewModel that navigates from its own `init` would then only be recorded
        // once someone thought to look.
        let commands = navigator.commands
        drain = Task { @MainActor [weak self] in
            for await command in commands {
                self?.commandLog.append(command)
            }
        }
    }

    /// Stops recording. Called from the test suite's teardown rather than from `deinit`, which
    /// cannot touch main-actor state.
    func stop() {
        drain?.cancel()
        drain = nil
    }
}

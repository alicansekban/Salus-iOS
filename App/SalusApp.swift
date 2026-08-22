import SwiftUI

/// The app entry point.
///
/// Deliberately thin: it owns the composition root, hands the window one view, and forwards the one
/// process-lifecycle event the graph cares about. Everything else — theming, navigation, features —
/// lives below `RootView`, so this file should stay roughly this size for the life of the port.
///
/// `@MainActor` on the struct, not only on `body`: `AppCompositionRoot` is a main-actor
/// `@Observable`, and the stored-property initializer below runs outside `body`'s isolation.
@main
@MainActor
struct SalusApp: App {
    /// The one composition root, created once and owned by the app.
    ///
    /// `@State` rather than a `let` because SwiftUI must keep it alive across the App value's
    /// re-creations; that is also what makes `.environment(_:)` below hand every view the same
    /// instance rather than a fresh one per update.
    @State private var compositionRoot = AppCompositionRoot()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(compositionRoot)
                // The twin of `MainActivity.onStop` (`MainActivity.kt:111-116`): undo windows do
                // not survive backgrounding, because a deletion the user confirmed must not linger
                // unresolved across a process death.
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .background else { return }
                    Task { await compositionRoot.commitPendingDeletes() }
                }
        }
    }
}

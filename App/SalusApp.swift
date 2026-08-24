import SwiftUI
import UIKit

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
    @State private var compositionRoot: AppCompositionRoot

    @Environment(\.scenePhase) private var scenePhase

    /// Built here rather than in the property's initializer for one reason: the reminder engine has
    /// to be installed before the app finishes launching. `BGTaskScheduler.register` must happen in
    /// this window or the first submitted request raises, and the notification-centre delegate must
    /// exist by then or a reminder tapped from a cold start is delivered to nobody.
    init() {
        let compositionRoot = AppCompositionRoot()
        _compositionRoot = State(initialValue: compositionRoot)
        compositionRoot.startReminderEngine()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(compositionRoot)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    // The foreground reconcile. Opening the app is the one trigger iOS never
                    // withholds, so it is also the engine's safety net for every background refresh
                    // the system chose not to run.
                    case .active: compositionRoot.reminderDidBecomeActive()
                    case .background: commitPendingDeletes()
                    default: break
                    }
                }
        }
    }

    /// The twin of `MainActivity.onStop` (`MainActivity.kt:111-116`): undo windows do not survive
    /// backgrounding, because a deletion the user confirmed must not linger unresolved across a
    /// process death.
    ///
    /// Android's `onStop` runs synchronously and the process stays alive around it; iOS suspends an
    /// app shortly after `.background` and will freeze a bare `Task` mid-commit, leaving the delete
    /// half-applied. `beginBackgroundTask` buys the seconds the commit needs — the expiration
    /// handler is not a fallback path but the OS taking the time back, and `endBackgroundTask` must
    /// be called on both exits or iOS terminates the app for overrunning.
    private func commitPendingDeletes() {
        let application = UIApplication.shared
        let token = BackgroundTaskToken()
        token.identifier = application.beginBackgroundTask(withName: "commit-pending-deletes") {
            token.end(on: application)
        }
        Task {
            await compositionRoot.commitPendingDeletes()
            token.end(on: application)
        }
    }
}

/// Holds one `UIBackgroundTaskIdentifier` so the expiration handler and the commit task can both
/// end it, and neither can end it twice — ending an already-ended identifier is a crash.
@MainActor
private final class BackgroundTaskToken {
    var identifier: UIBackgroundTaskIdentifier = .invalid

    func end(on application: UIApplication) {
        guard identifier != .invalid else { return }
        application.endBackgroundTask(identifier)
        identifier = .invalid
    }
}

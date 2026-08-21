import SwiftUI

/// The app entry point.
///
/// Deliberately thin: it owns the composition root and hands the window one view. Everything
/// else — theming, navigation, features — lives below `RootView`, so this file should stay
/// roughly this size for the life of the port.
@main
struct SalusApp: App {
    /// The one composition root, created once and owned by the app.
    ///
    /// `@State` rather than a `let` because SwiftUI must keep it alive across the App value's
    /// re-creations; that is also what makes `.environment(_:)` below hand every view the same
    /// instance rather than a fresh one per update.
    @State private var compositionRoot = AppCompositionRoot()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(compositionRoot)
        }
    }
}

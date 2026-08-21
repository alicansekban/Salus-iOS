import Observation

/// Where the object graph gets assembled — the iOS stand-in for Android's Hilt
/// `@HiltAndroidApp` application component.
///
/// Salus on iOS wires its dependencies by hand rather than pulling in a DI framework: the
/// third-party budget for this port is zero (spec §12), and a hand-written root is both
/// readable and trivially substitutable in tests. Concretely, this type is the single place
/// that knows how to build a real dependency, and the single place a test replaces to build
/// a fake one.
///
/// M0 has nothing to wire yet — the packages exist but are empty shells — so this is a stub
/// on purpose. It is created and injected now, rather than later, so that the seam is already
/// in place when M1 adds the first real dependency and nothing above it has to be restructured
/// to accept one. Expected first residents, in order:
///
/// - `SalusSettings` (M1): the theme mode and premium palette the shell currently defaults.
///   Once it lands, `RootView` reads the stored `ThemeMode` from here instead of relying on
///   `SalusTheme.resolve`'s default, and applies `mode.preferredColorScheme` at the window.
/// - `SalusDatabase` (M1): the store every feature repository is built on.
/// - Feature stores (M2+): one per tab, each handed only the dependencies it names.
///
/// Not annotated `@MainActor`: it holds no UI state today, and pinning it to an actor before
/// there is anything to protect would be a guess. The first stored dependency decides.
@Observable
final class AppCompositionRoot {
    init() {}
}

import Observation

/// The single gate to the paywall: any view model that hits a premium wall calls `show(_:)`
/// and is done — it never learns that the paywall is an overlay, or where it lives.
///
/// Same philosophy as `Navigator` in `:core:navigation`. As a Koin singleton it would outlive
/// any composition, so it holds no back stack and is not a navigation destination: it publishes
/// `request` and the app shell — the only thing that mounts UI — draws the overlay above
/// `NavDisplay`. That is also why this is state and not a one-shot event; a recomposing shell
/// re-reads the same open paywall instead of missing the signal.
///
/// `request` is also how the paywall learns which `PaywallSource` it was opened from: the
/// paywall's own view model collects it and turns the source into the sheet's headline, so a
/// caller never passes copy — it names the wall it hit and nothing else.
///
/// Ported 1:1 from `PaywallController.kt:35-51`. The `@Observable` macro makes `request`
/// observable to the shell's `PaywallHost`.
@MainActor
@Observable
public final class PaywallController {
    /// The paywall the shell should be showing, or `nil` while it is closed.
    public private(set) var request: PaywallRequest?

    public init() {}

    /// Opens the paywall for `source`. Called while one is already open, it replaces it.
    public func show(_ source: PaywallSource) {
        request = PaywallRequest(source: source)
    }

    /// Closes the paywall, whether the user bought or backed out.
    public func dismiss() {
        request = nil
    }
}

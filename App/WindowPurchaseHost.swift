import SalusPremium
import UIKit

/// The iOS implementation of ``PurchaseHost`` — divergence (c) from the Android twin.
///
/// Android passes the `Activity` the store sheet attaches to
/// (`ActivityPurchasesHost`, `RevenueCatPurchasesGateway.kt:23`); iOS passes a reference to the
/// key window instead. StoreKit's purchase sheet is system-presented, so the window reference is
/// deliberately minimal — the gateway only needs it (in the SDK's own configuration) and it is
/// otherwise unused. It lives in the `App` target, not in `SalusPremium`, because carrying a
/// `UIWindow` would drag UIKit into a core package that must stay UI-free.
public final class WindowPurchaseHost: PurchaseHost {
    public let window: UIWindow?

    public init(window: UIWindow?) {
        self.window = window
    }
}

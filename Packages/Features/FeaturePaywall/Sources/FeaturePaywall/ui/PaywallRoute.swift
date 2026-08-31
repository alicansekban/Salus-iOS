// The Route is the template's (`docs/ios-feature-template.md`): the module comes from the
// environment, the ViewModel is built once in `.task` and owned for the route's lifetime, and the
// stateless `PaywallSheet` gets `state`, `onEvent` and the two callbacks only the composition can
// supply — the purchase host and the policy-page open.
//
// `onPurchase` is the iOS twin of Android's `ActivityPurchasesHost` (`RevenueCatPurchasesGateway.kt:23`):
// the module's `makePurchaseHost` closure builds a `WindowPurchaseHost` over the key window, which
// lives in the app target. `onOpenUrl` is the twin of the Activity launch that opens a policy page.

import SalusPremium
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// The paywall, presented as a full-screen sheet by the shell's `PaywallHost`.
@MainActor
public struct PaywallRoute: View {
    @Environment(\.paywallModule) private var module
    @State private var viewModel: PaywallViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                PaywallSheet(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    onPurchase: {
                        guard let host = module?.makePurchaseHost() else { return }
                        viewModel.onEvent(.purchaseClicked(host))
                    },
                    onOpenUrl: { urlString in
                        guard let url = URL(string: urlString) else { return }
                        #if canImport(UIKit)
                            UIApplication.shared.open(url)
                        #endif
                    }
                )
            } else {
                // A dropped injection draws the spinner rather than a half-built graph — the
                // reason `paywallModule` is optional (`PaywallModule.swift`'s `@Entry` note).
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            // Built once: the ViewModel opens its own observation of the paywall source, and a
            // second one would be a second stream over the same controller.
            guard viewModel == nil, let module else { return }
            viewModel = module.makePaywallViewModel()
            // Sent every time the sheet opens: the ViewModel is retained by the shell, so it
            // outlives the sheet, and without this the failure of one open would still be on
            // screen at the next one.
            viewModel?.onEvent(.reload)
        }
    }
}

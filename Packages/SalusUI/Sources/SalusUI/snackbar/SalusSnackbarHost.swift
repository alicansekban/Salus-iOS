// The iOS twin of `SnackbarHost(snackbarHostState)` as the app shell mounts it
// (`app/src/main/kotlin/com/alicansekban/salus/ui/SalusApp.kt:106-136`).
//
// Android gets the view for free from Material; SwiftUI ships no snackbar, so this file is it.
// What it copies: one host for the whole app, sitting above every screen, drawn in the
// `inverseSurface` / `inverseOnSurface` pair `design-tokens.md` §2.1 names for snackbars, with a
// single text action on the trailing edge.
//
// One affordance Android does not have, added on purpose: tapping the snackbar body dismisses it.
// Material defaults an undo snackbar to `Indefinite` (`SnackbarHost.kt:104-105`), and on Android
// the collector suspends until that snackbar goes away — so without a way out, an iOS undo
// snackbar would sit there forever and block everything queued behind it. The duration table is
// ported unchanged; this is the escape hatch the platform does not otherwise provide.

import SalusDesignSystem
import SwiftUI

/// Mounted once by the shell, above the whole app.
public struct SalusSnackbarHost: View {
    private let controller: SalusSnackbarController

    @Environment(\.salusTheme) private var theme

    public init(controller: SalusSnackbarController) {
        self.controller = controller
    }

    public var body: some View {
        VStack {
            Spacer()
            if let request = controller.current {
                snackbar(request)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // §10 holds the app's only motion spec — Android's snackbar animates with Material's own
        // `FadeInFadeOutWithScale`, which names no Salus token. Reusing the push/pop curve keeps
        // the timing token-sourced rather than inventing a second duration the Android side has no
        // counterpart for.
        .animation(SalusMotion.pushPopAnimation, value: controller.current?.id)
        .padding(SalusSpacing.lg)
    }

    private var colors: SalusColorScheme { theme.colorScheme }

    private func snackbar(_ request: SnackbarRequest) -> some View {
        HStack(spacing: SalusSpacing.md) {
            Text(request.message)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(colors.inverseOnSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionLabel = request.actionLabel {
                Button(actionLabel) { controller.performAction() }
                    .buttonStyle(.plain)
                    .font(SalusTypography.labelLarge.font)
                    .foregroundStyle(colors.inversePrimary)
                    .frame(minHeight: SalusTouchTarget.min)
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.md)
        .background(background)
        .contentShape(SalusShapes.extraSmallShape)
        .onTapGesture { controller.dismiss() }
    }

    /// `inverseSurface`, per `design-tokens.md` §2.1's "Snackbar / tooltip" row, on Material's
    /// `extraSmall` snackbar corner and the `overlay` elevation step (§7).
    private var background: some View {
        SalusShapes.extraSmallShape
            .fill(colors.inverseSurface)
            .salusShadow(.overlay, isDark: theme.isDark)
    }
}

#Preview("Snackbar host") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    let controller = SalusSnackbarController()
    controller.show(
        SnackbarRequest(message: "Kilo kaydı silindi", actionLabel: SalusUIStrings.undo, onAction: {})
    )
    return ZStack {
        theme.colorScheme.background
        SalusSnackbarHost(controller: controller)
    }
    .frame(width: 380, height: 220)
    .salusTheme(theme)
}

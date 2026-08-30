// The iOS §6.2 secure screen, in one file: the app-switcher blur, the screenshot mask and the
// screen-capture hide.
//
// ANDROID HAS NO TWIN FOR THIS FILE. `MainActivity` adds `WindowManager.LayoutParams.FLAG_SECURE`
// when `secure_screen_enabled` is on and clears it when it is off (`MainActivity.kt:65-74`, read
// off `preferences.userSettings.map { it.secureScreenEnabled }`), and the platform does the rest:
// the recents preview goes blank, screenshots are refused, and a mirrored display shows nothing.
// UIKit has no such flag, so spec §6.2 splits the one Android switch into three iOS mechanisms
// (global constraints, ruling 2):
//
//   1. **The app-switcher blur is ALWAYS ON**, toggle or no toggle. iOS snapshots an app as it
//      leaves the foreground and shows that snapshot in the switcher; drawing this overlay while
//      `scenePhase != .active` is what the snapshot then captures. It is free, it costs the user
//      nothing, and health data in the switcher is the leak that needs no attacker at all.
//   2. **`secure_screen_enabled` adds the screenshot mask** — the secure-text-field layer below.
//   3. **`secure_screen_enabled` also hides content while the screen is captured** (AirPlay
//      mirroring, a screen recording, a QuickTime capture), which `UIScreen.isCaptured` reports.
//
// WORDING, and it is a rule rather than a preference (spec §6.2): this hides content. It does not
// *block* or *prevent* anything. The mask is an undocumented-but-stable UIKit behaviour, not a
// security guarantee — a photograph of the screen still works, and so does a jailbroken capture —
// and `settings_secure_screen_desc` promises exactly what is delivered: "hides screenshots and the
// recents preview". Never write "blocks" or "prevents" about this file.

import SalusDesignSystem
import SalusUI
import SwiftUI
import UIKit

// MARK: - The overlay

/// The privacy curtain: a heavy blur with the app's identity on it, drawn over the whole shell.
///
/// Deliberately *not* a black rectangle. A blank switcher card reads as a crashed app, and the
/// blur is also what the user recognises when they flick through the switcher looking for Salus.
struct PrivacyOverlay: View {
    /// Why the curtain is up — or that it is not. Drawn identically for both visible cases; the
    /// distinction exists because it is the thing manual QA verifies row by row, and because a
    /// future accessibility announcement would want to say which one it is.
    enum State: Equatable {
        /// Nothing is drawn — the app is frontmost and is not being captured.
        case hidden
        /// The app is leaving (or has left) the foreground: the always-on switcher blur.
        case switcher
        /// The screen is being mirrored or recorded and masking is on.
        case captured

        /// The whole visibility rule, as one pure function.
        ///
        /// This app target has no test bundle (user decision, iOS-M8), so this is where the rule is
        /// *stated* rather than *tested*: it takes three values and returns a case, it reads no
        /// clock and touches no window, and its table is verified by hand in
        /// `scripts/m8-manual-qa.md` §2.
        ///
        ///     scenePhase   isCaptured   maskingEnabled   result
        ///     .active      false        any              .hidden
        ///     .active      true         false            .hidden
        ///     .active      true         true             .captured
        ///     .inactive    any          any              .switcher
        ///     .background  any          any              .switcher
        ///
        /// Two things the table says out loud:
        ///
        ///  - **`.switcher` ignores `maskingEnabled`** — that is ruling 2's "always on". The
        ///    guard is written as "not `.active`" rather than as two named phases, so a `ScenePhase`
        ///    case iOS adds later falls on the safe side: it draws the curtain rather than the
        ///    user's blood pressure.
        ///  - **`.captured` is gated on the toggle.** Mirroring to a TV is something people do on
        ///    purpose; hiding the app for everyone who ever plugs in a cable would be a surprise,
        ///    not a protection. The user who wants it asks for it with the same switch that asks
        ///    for the screenshot mask.
        static func resolve(scenePhase: ScenePhase, isCaptured: Bool, maskingEnabled: Bool) -> State {
            guard scenePhase == .active else { return .switcher }
            return isCaptured && maskingEnabled ? .captured : .hidden
        }
    }

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ZStack {
            // The blur itself. `.ultraThickMaterial` rather than a lighter step because this is a
            // privacy surface first and a decoration second: the lighter materials leave large type
            // and chart shapes legible through them.
            Rectangle()
                .fill(.ultraThickMaterial)

            VStack(spacing: SalusSpacing.lg) {
                // The app's identity. `SalusIconBadge` stands in for the app icon, which the bundle
                // does not have yet — `project.yml` pins `ASSETCATALOG_COMPILER_APPICON_NAME: ""`
                // and the target links no asset catalog. When the real icon lands, this badge is
                // what it replaces; the layout around it does not change.
                SalusIconBadge(systemImage: "heart.text.square.fill", accent: theme.extendedColors.vitals)

                // `Text(verbatim:)` because this is a resolved value, not a catalog key: the plain
                // `Text(_:)` initializer takes a `LocalizedStringKey` and would look "Salus" up in
                // the main bundle's string table (the `c726e22` finding). The name comes from
                // `CFBundleDisplayName`, which is not localized — it is the same word in both
                // locales — so no catalog key is added for it.
                Text(verbatim: Self.appName)
                    .font(SalusTypography.titleMedium.font)
                    .foregroundStyle(theme.colorScheme.onSurface)
            }
        }
        // The curtain covers the status bar and the home indicator too; a blur that stops at the
        // safe area leaves two readable strips of the screen underneath it.
        .ignoresSafeArea()
        // One element, not two: a switcher card and a mirrored screen are not places to navigate,
        // and VoiceOver reading "Salus, image" adds nothing over the name itself.
        .accessibilityElement(children: .combine)
    }

    /// `CFBundleDisplayName`, falling back to `CFBundleName` and then to the literal.
    ///
    /// Read rather than hardcoded so a build that renames the product renames the curtain with it.
    private static var appName: String {
        let bundle = Bundle.main
        let names = ["CFBundleDisplayName", "CFBundleName"]
            .compactMap { bundle.object(forInfoDictionaryKey: $0) as? String }
        return names.first { !$0.isEmpty } ?? "Salus"
    }
}

// MARK: - The modifier the shell applies

extension View {
    /// Applies the §6.2 secure screen to everything below it.
    ///
    /// One line rather than three pieces spread through `RootView`, and it belongs **outside every
    /// other overlay** — outside the tab bar, outside every `NavigationStack`, and outside the
    /// onboarding and app-lock gates. A curtain a gate can draw over is not a curtain.
    ///
    /// The one modifier that stays *outside* this one is `.salusTheme(_:)`. An overlay's content
    /// reads the environment the modified view was handed, not the environment that view writes, so
    /// a curtain applied after `.salusTheme(_:)` would draw the default palette while the app behind
    /// it drew the resolved one. Theme outermost, curtain next, gates below it.
    ///
    /// - Parameter maskingEnabled: the stored `secure_screen_enabled`. It gates the screenshot mask
    ///   and the capture hide; the switcher blur is on either way.
    func secureScreen(maskingEnabled: Bool) -> some View {
        modifier(SecureScreenModifier(maskingEnabled: maskingEnabled))
    }
}

/// Owns the three moving parts: the phase, the capture flag, and the mask's lifetime.
///
/// `@MainActor` on the struct rather than only on `body`: `SecureScreenMask` is a main-actor class
/// and the stored-property initializer below runs outside `body`'s isolation — the same reason
/// `SalusApp` and `RootView` carry the attribute.
@MainActor
private struct SecureScreenModifier: ViewModifier {
    let maskingEnabled: Bool

    @Environment(\.scenePhase) private var scenePhase

    /// Whether *any* connected scene's screen is being mirrored or recorded.
    @State private var isCaptured = false

    /// The secure-text-field layer. Held here so it survives every body update and is installed and
    /// removed exactly once per toggle change.
    @State private var mask = SecureScreenMask()

    private var state: PrivacyOverlay.State {
        PrivacyOverlay.State.resolve(
            scenePhase: scenePhase,
            isCaptured: isCaptured,
            maskingEnabled: maskingEnabled
        )
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if state != .hidden {
                    PrivacyOverlay()
                }
            }
            // OBSERVATION CHOICE: the notification, not polling. `UIScreen.capturedDidChangeNotification`
            // is the documented event for exactly this flag, it fires on both edges, and it costs
            // nothing while nothing is happening — where a `CADisplayLink` or a timer would burn a
            // wake-up per frame (or per tick) for a property that changes a handful of times in an
            // app's life. The notification carries the screen that changed, but this re-reads every
            // connected scene instead: the app has one scene today (`UIApplicationSupportsMultipleScenes:
            // false`), and re-reading is correct if that ever stops being true.
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                isCaptured = SecureScreenMask.anyScreenIsCaptured()
            }
            // The seed. A screen that was already being mirrored when the app launched posts no
            // notification, so without this the first capture of a session is missed entirely.
            .onAppear { isCaptured = SecureScreenMask.anyScreenIsCaptured() }
            .onChange(of: maskingEnabled, initial: true) { _, enabled in
                mask.setEnabled(enabled)
            }
            // Re-assert the mask on every return to the foreground. It is idempotent — `apply()`
            // returns early while the mask is installed — so this costs a comparison, and it buys
            // the one failure mode that would be silent: a mask that never installed (no key window
            // yet at the moment the toggle was read) or one whose window iOS replaced after a scene
            // reconnect. `SecureScreenMask` holds its view weakly, so a replaced window reads as
            // "not applied" here and gets masked again.
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                mask.setEnabled(maskingEnabled)
            }
    }
}

// MARK: - The screenshot mask

/// The secure-text-field layer: a zero-size `UITextField` with `isSecureTextEntry = true` whose
/// content layer is made the parent of the app's own layer.
///
/// HOW IT WORKS, because the code below is otherwise unreadable. UIKit renders a secure text
/// field's content into a layer the render server excludes from screenshots, screen recordings and
/// the switcher snapshot — that exclusion is the entire mechanism behind "you cannot screenshot a
/// password field". Re-parenting the app's root layer *under* that content layer extends the same
/// exclusion to the whole app: on screen everything draws normally, and in a capture the subtree
/// comes out blank.
///
/// WHAT IT IS NOT. It is undocumented, and it is not a guarantee — see the wording note at the top
/// of this file. It is also the only technique iOS offers; there is no API for this.
///
/// The re-parenting is exactly reversible, and `setEnabled(false)` reverses it, because the toggle
/// is a setting the user flips both ways rather than a one-way door.
@MainActor
final class SecureScreenMask {
    /// The field itself. Never a first responder, never interactive, and never carrying text — only
    /// its `isSecureTextEntry` layer is wanted.
    private let field = UITextField()

    /// The view whose layer was re-parented, and the layer it was re-parented *from*. Weak: iOS owns
    /// both, and a mask that outlived its window must not be the reason they stay alive.
    private weak var maskedView: UIView?
    private weak var originalSuperlayer: CALayer?

    private var isApplied: Bool { maskedView != nil }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            apply()
        } else {
            remove()
        }
    }

    /// True if any connected scene's screen is being mirrored or recorded.
    ///
    /// `UIWindowScene.screen` rather than `UIScreen.main`, which is deprecated from iOS 16 and would
    /// spend a warning on the project's clean baseline.
    static func anyScreenIsCaptured() -> Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .contains { $0.screen.isCaptured }
    }

    private func apply() {
        guard !isApplied,
              let host = Self.hostView(),
              let superlayer = host.layer.superlayer
        else { return }

        field.isSecureTextEntry = true
        // The field is a mechanism, not a control: it must never take a touch, a tap or the
        // keyboard away from the app it is masking.
        field.isUserInteractionEnabled = false
        field.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(field)
        NSLayoutConstraint.activate([
            field.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            field.centerYAnchor.constraint(equalTo: host.centerYAnchor),
            field.widthAnchor.constraint(equalToConstant: 0),
            field.heightAnchor.constraint(equalToConstant: 0)
        ])
        // The content layer exists only once the field has been laid out inside a window.
        host.layoutIfNeeded()

        // Order matters. The field's layer goes where the host's layer was, so it is the host's
        // sibling; then the host's layer moves *inside* the field's content layer.
        superlayer.addSublayer(field.layer)
        guard let canvas = field.layer.sublayers?.last else {
            // The content layer is not there — a UIKit change, or a field iOS declined to lay out.
            // Undo the half that did happen and leave the app rendering normally: no mask is a
            // missing feature, a half-applied one is a broken screen.
            field.layer.removeFromSuperlayer()
            field.removeFromSuperview()
            return
        }
        // The field is zero-sized on purpose (it must not be visible), and a content layer that
        // clipped to its own bounds would then clip the entire app to nothing. UIKit does not set
        // this today; pinning it is what makes the zero size safe rather than lucky.
        canvas.masksToBounds = false
        canvas.addSublayer(host.layer)

        maskedView = host
        originalSuperlayer = superlayer
    }

    private func remove() {
        guard isApplied else { return }
        // Put the app's layer back before taking the field apart: `addSublayer` moves a layer out of
        // whatever holds it, so this both restores the hierarchy and empties the content layer.
        if let host = maskedView, let superlayer = originalSuperlayer {
            superlayer.addSublayer(host.layer)
        }
        field.layer.removeFromSuperlayer()
        field.removeFromSuperview()
        maskedView = nil
        originalSuperlayer = nil
    }

    /// The root view of the app's key window — the one view whose layer is the whole UI.
    ///
    /// The window's own layer is not usable here: a `UIWindow`'s layer is a root layer with no
    /// superlayer, and the technique needs somewhere to put the field's layer.
    private static func hostView() -> UIView? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState != .unattached }?
            .windows
            .first { $0.isKeyWindow }?
            .rootViewController?
            .view
    }
}

#Preview("Privacy overlay") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    return ZStack {
        theme.colorScheme.surface
        VStack(spacing: SalusSpacing.sm) {
            Text(verbatim: "120/80 mmHg")
            Text(verbatim: "5.6 mmol/L")
        }
        PrivacyOverlay()
    }
    .salusTheme(theme)
}

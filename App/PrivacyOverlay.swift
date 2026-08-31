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
//   2. **`secure_screen_enabled` adds the screenshot mask** — the secure-text-field layer below
//      (invisible, not zero-sized; see the geometry note on `SecureScreenMask`).
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

    /// The secure-text-field layer. Held here so it survives every body update; it is installed and
    /// removed by the two `.onChange` handlers below and is idempotent under both.
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
            // VoiceOver reads what the curtain covers unless it is told not to. It matters in the
            // `.captured` state, where the app is foreground and someone could otherwise walk the
            // measurements the screen is busy hiding.
            .accessibilityHidden(state != .hidden)
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
            .onChange(of: maskingEnabled, initial: true) { _, enabled in
                mask.setEnabled(enabled)
            }
            // Everything that has to be re-read on the way back to the foreground.
            //
            // `isCaptured` first, and it is not optional: `capturedDidChangeNotification` is not
            // delivered to a suspended app, so a mirror or a recording started while Salus was in
            // the background would otherwise leave the flag `false` and draw the user's data
            // straight onto the mirrored display — the exact case QA §2.6 promises to cover.
            //
            // Then the mask, re-asserted. It is idempotent — `apply()` returns early while the mask
            // is installed — so this costs a comparison, and it buys the failure that would
            // otherwise be silent: a window iOS replaced after a scene reconnect. `SecureScreenMask`
            // holds its view weakly, so a replaced window reads as "not applied" and gets masked
            // again. `initial: true` because the launch phase is already `.active`: without it the
            // first pass through this handler would wait for a background round trip.
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active else { return }
                isCaptured = SecureScreenMask.anyScreenIsCaptured()
                mask.setEnabled(maskingEnabled)
            }
    }
}

// MARK: - The screenshot mask

/// The secure-text-field layer: an invisible `UITextField` with `isSecureTextEntry = true` whose
/// content layer is made the parent of the app's own layer.
///
/// HOW IT WORKS, because the code below is otherwise unreadable. UIKit renders a secure text
/// field's content into a layer the render server excludes from screenshots, screen recordings and
/// the switcher snapshot — that exclusion is the entire mechanism behind "you cannot screenshot a
/// password field". Re-parenting the app's root layer *under* that content layer extends the same
/// exclusion to the whole app: on screen everything draws normally, and in a capture the subtree
/// comes out blank.
///
/// GEOMETRY, and it is the half that bites. Re-parenting a layer does not move it by itself, but it
/// does change whose bounds space its `position` is read in. The circulated form of this trick pins
/// the field **0×0 at the host's centre**, which puts the content layer's origin at the middle of
/// the screen — the app, re-parented under it, then renders from the centre outward with three
/// quarters of it off-screen, while touches keep landing at the original coordinates because
/// hit-testing walks the *view* tree, not the layer tree. So the field is pinned to the window's
/// **edges** instead: its layer's frame is the window's, the two coordinate spaces coincide, and
/// nothing moves. A full-size field is still invisible — no text, no placeholder, no border, a clear
/// background, never a first responder. "Zero-size" in the brief means "invisible", and this is the
/// spelling of that which does not displace the app.
///
/// WHAT IT IS NOT. It is undocumented, and it is not a guarantee — see the wording note at the top
/// of this file. It is also the only technique iOS offers; there is no API for this.
///
/// The re-parenting is exactly reversible, and `setEnabled(false)` reverses it, because the toggle
/// is a setting the user flips both ways rather than a one-way door.
@MainActor
private final class SecureScreenMask {
    /// The field itself. Never a first responder, never interactive, and never carrying text — only
    /// its `isSecureTextEntry` layer is wanted.
    ///
    /// `lazy` so that constructing a `SecureScreenMask` costs nothing: SwiftUI re-runs a view's
    /// stored-property initializers on every update and throws the extra instances away, and a
    /// `UITextField` allocated per body pass is a real cost for an object that is usually discarded.
    private lazy var field = UITextField()

    /// The view whose layer was re-parented, and the layer it was re-parented *from*. Weak: iOS owns
    /// both, and a mask that outlived its window must not be the reason they stay alive.
    private weak var maskedView: UIView?
    private weak var originalSuperlayer: CALayer?

    /// What the setting currently says, so the deferred retry below cannot install a mask the user
    /// turned off while it was waiting its turn.
    private var wantsMask = false

    private var isApplied: Bool { maskedView != nil }

    func setEnabled(_ enabled: Bool) {
        wantsMask = enabled
        guard enabled else {
            remove()
            return
        }
        guard !apply() else { return }
        // One retry, on the next main-actor turn. The one way `apply()` can fail at launch is that
        // the scene has no key window yet, and it has one a turn later; without this the mask would
        // stay off for the whole session unless the user happened to background and come back. A
        // single retry rather than a loop — a second failure is a real one, and the `.active`
        // re-assert in `SecureScreenModifier` picks it up at the next foregrounding.
        Task { @MainActor [weak self] in
            guard let self, wantsMask else { return }
            apply()
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

    /// - Returns: whether the mask is installed when this returns — `true` also when it already was.
    @discardableResult
    private func apply() -> Bool {
        guard !isApplied else { return true }
        guard let window = Self.keyWindow(),
              let host = window.rootViewController?.view,
              let superlayer = host.layer.superlayer
        else { return false }

        field.isSecureTextEntry = true
        // A mechanism, not a control: it must never take a touch, a tap or the keyboard away from
        // the app it is masking, and it must draw nothing of its own.
        field.isUserInteractionEnabled = false
        // …and it must not exist for VoiceOver either. This field is full-screen (the C-1 fix), and
        // an accessibility element that size sits over the whole app: VoiceOver would offer "secure
        // text field, double-tap to edit" and touch exploration would land on it instead of on the
        // content underneath, for as long as masking is on. `isUserInteractionEnabled = false` does
        // not cover this — the accessibility tree is walked separately from the touch hierarchy.
        field.isAccessibilityElement = false
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.translatesAutoresizingMaskIntoConstraints = false
        // Hosted by the WINDOW, and deliberately not by the view whose layer it is about to adopt. A
        // field parented to `host` would be a subview of a view whose layer becomes a descendant of
        // the field's own layer, and any UIKit path that re-syncs sublayer order to subview order
        // would then be asked to build a cycle. As a sibling the worst case is that the mask quietly
        // comes undone — which `remove()` and the `.active` re-assert both survive.
        window.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            field.topAnchor.constraint(equalTo: window.topAnchor),
            field.bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])
        // The content layer exists only once the field has been laid out inside a window.
        window.layoutIfNeeded()

        // Exactly one sublayer, or nothing at all. Picking by position (`.first`, `.last`) is a
        // guess, and a wrong guess is the worst outcome available here: the app's layer would hang
        // under a *non-secure* layer, the mask would do nothing, and `isApplied` would still report
        // success. A count that is not 1 means UIKit's private view tree changed shape, so this
        // fails safely — no mask, and QA §2.4 is the detector — rather than half-applying.
        guard let sublayers = field.layer.sublayers, sublayers.count == 1, let canvas = sublayers.first
        else {
            // Silent-and-safe in every build: a UIKit shape change (e.g. a simulator iOS version
            // whose secure field layers differently) is a thing to discover via QA §2.4, not a
            // reason to trap the app. The `assertionFailure` that was here crashed Debug builds
            // on launch when the simulator's `UITextField` did not produce exactly one sublayer.
            field.removeFromSuperview()
            return false
        }
        // The last of the geometry. `masksToBounds` stays off so a content layer shorter than the
        // field — UIKit centres a single line of text inside it — cannot clip the app; the bounds
        // origin then cancels whatever inset that centring gave the canvas, so the app's layer lands
        // on the window exactly. Setting `bounds.origin` survives layout: a view's `frame` setter
        // writes `bounds.size` and `position` and never the bounds origin. It is computed once, and
        // the field's own size cannot change while it is installed (pinned to the window, in a
        // portrait-only app), so there is nothing to recompute.
        canvas.masksToBounds = false
        canvas.bounds.origin = canvas.frame.origin
        canvas.addSublayer(host.layer)

        maskedView = host
        originalSuperlayer = superlayer
        return true
    }

    private func remove() {
        guard isApplied else { return }
        // Put the app's layer back before taking the field apart: `addSublayer` moves a layer out of
        // whatever holds it, so this both restores the hierarchy and empties the content layer.
        if let host = maskedView, let superlayer = originalSuperlayer {
            superlayer.addSublayer(host.layer)
        }
        field.removeFromSuperview()
        maskedView = nil
        originalSuperlayer = nil
    }

    /// The app's key window — the view the field is planted in and the owner of the layer the app's
    /// root view hangs from.
    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState != .unattached }?
            .windows
            .first { $0.isKeyWindow }
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

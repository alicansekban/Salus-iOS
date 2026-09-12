// Ported from `core/ui/.../component/SalusConfirmDialog.kt:17-39`.
//
// Two shape differences, both deliberate:
//
//   * Kotlin's is a composable a screen renders conditionally
//     (`if (state.pendingDeleteId != null) { SalusConfirmDialog(...) }`, `VitalsScreen.kt:154-163`),
//     because Compose's `AlertDialog` IS a composable. SwiftUI's alert is a modifier driven by a
//     `Binding<Bool>`, so the iOS twin is a modifier and the `if` becomes the binding.
//   * Each button arrives as a label + handler pair rather than as two loose parameters. That is
//     what Kotlin's `confirmButton = { TextButton(onClick = onConfirm) { Text(confirmLabel) } }`
//     already is; keeping the pair together is also what stops a call site from lining up four
//     strings and closures in the wrong order.
//
// Same contract otherwise: all copy is passed in, so the component carries no strings of its own
// and each site can name what it is about to delete (`SalusConfirmDialog.kt:11-15`).

import SwiftUI

/// One button of a `salusConfirmDialog` — what it says and what it does.
public struct SalusDialogAction {
    public let label: String
    public let action: () -> Void

    public init(label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }
}

extension View {
    /// The one confirmation dialog — before a destructive action, and before any other answer
    /// worth stopping for.
    ///
    /// - Parameters:
    ///   - isPresented: the twin of the Kotlin `if`. The system clears it for either button, which
    ///     is what `onDismissRequest` means there.
    ///   - confirm: the button that goes through with it (`SalusConfirmDialog.kt:29-34`).
    ///   - dismiss: the way out (`SalusConfirmDialog.kt:35-37`).
    ///   - confirmIsDestructive: whether the confirm button is drawn as destructive. Defaults to
    ///     `true`, because nearly every site here confirms a deletion; a site whose confirm button
    ///     *does* something — steering the user onwards rather than removing data — passes `false`
    ///     and gets the plain button (`SalusConfirmDialog.kt:22-27`, the same default and the same
    ///     reason).
    ///
    /// A destructive confirm carries the `.destructive` role, the platform twin of Kotlin tinting
    /// it `colorScheme.error` — "destructive actions are tinted, never the default primary"
    /// (`SalusConfirmDialog.kt:31`). Alerts are drawn by the system on both platforms, so this is
    /// the one component whose chrome is not painted from Salus tokens.
    public func salusConfirmDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirm: SalusDialogAction,
        dismiss: SalusDialogAction,
        confirmIsDestructive: Bool = true
    ) -> some View {
        alert(title, isPresented: isPresented) {
            // `role:` takes an optional, so the non-destructive case is the absent role rather than
            // a second `Button` line — one button, one place its action is wired.
            Button(confirm.label, role: confirmIsDestructive ? .destructive : nil, action: confirm.action)
            Button(dismiss.label, role: .cancel, action: dismiss.action)
        } message: {
            // `Text(verbatim:)`: `message` is already a resolved `String` from the call site's
            // typed `Strings` enum — the plain initializer would read it back as a
            // `LocalizedStringKey` against the main bundle (the M7 `c726e22` finding).
            Text(verbatim: message)
        }
    }
}

private struct SalusConfirmDialogPreview: View {
    @State private var isPresented = true

    let title: String
    let message: String
    let confirmLabel: String
    let dismissLabel: String
    let confirmIsDestructive: Bool

    var body: some View {
        // `verbatim:` on purpose: the other `Text(_:)` overload takes a `LocalizedStringKey`, and
        // Xcode's string extraction writes every one it finds in this package into
        // `Localizable.xcstrings` — which is how a stray "Host" key (and an empty one) turned up in
        // the catalog during the M2 simulator pass and broke `SalusUIStringsTests`. Preview copy is
        // never localised, so it must never look like a key.
        Text(verbatim: "Host")
            .salusConfirmDialog(
                isPresented: $isPresented,
                title: title,
                message: message,
                confirm: SalusDialogAction(label: confirmLabel, action: {}),
                dismiss: SalusDialogAction(label: dismissLabel, action: {}),
                confirmIsDestructive: confirmIsDestructive
            )
    }
}

#Preview("Confirm dialog") {
    // The alert itself is the system's and is drawn outside the panels, so the palettes below show
    // the host row rather than eight dialogs. Kept in the fan-out shape all the same: what this
    // preview is for is that the host and its ground stay legible in every palette.
    SalusPreviewPalettes {
        SalusConfirmDialogPreview(
            title: "Kilo kaydı silinsin mi?",
            message: "Bu kayıt kalıcı olarak silinir.",
            confirmLabel: SalusUIStrings.delete,
            dismissLabel: SalusUIStrings.cancel,
            confirmIsDestructive: true
        )
    }
}

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
    /// The one confirmation shown before every destructive action.
    ///
    /// - Parameters:
    ///   - isPresented: the twin of the Kotlin `if`. The system clears it for either button, which
    ///     is what `onDismissRequest` means there.
    ///   - confirm: the destructive button (`SalusConfirmDialog.kt:29-34`).
    ///   - dismiss: the way out (`SalusConfirmDialog.kt:35-37`).
    ///
    /// The confirm button carries the `.destructive` role, the platform twin of Kotlin tinting it
    /// `colorScheme.error` — "destructive actions are tinted, never the default primary"
    /// (`SalusConfirmDialog.kt:31`). Alerts are drawn by the system on both platforms, so this is
    /// the one component whose chrome is not painted from Salus tokens.
    public func salusConfirmDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirm: SalusDialogAction,
        dismiss: SalusDialogAction
    ) -> some View {
        alert(title, isPresented: isPresented) {
            Button(confirm.label, role: .destructive, action: confirm.action)
            Button(dismiss.label, role: .cancel, action: dismiss.action)
        } message: {
            Text(message)
        }
    }
}

private struct SalusConfirmDialogPreview: View {
    @State private var isPresented = true

    var body: some View {
        // `verbatim:` on purpose: the other `Text(_:)` overload takes a `LocalizedStringKey`, and
        // Xcode's string extraction writes every one it finds in this package into
        // `Localizable.xcstrings` — which is how a stray "Host" key (and an empty one) turned up in
        // the catalog during the M2 simulator pass and broke `SalusUIStringsTests`. Preview copy is
        // never localised, so it must never look like a key.
        Text(verbatim: "Host")
            .salusConfirmDialog(
                isPresented: $isPresented,
                title: "Kilo kaydı silinsin mi?",
                message: "Bu kayıt kalıcı olarak silinir.",
                confirm: SalusDialogAction(label: SalusUIStrings.delete, action: {}),
                dismiss: SalusDialogAction(label: SalusUIStrings.cancel, action: {})
            )
    }
}

#Preview("Confirm dialog") {
    SalusConfirmDialogPreview()
}

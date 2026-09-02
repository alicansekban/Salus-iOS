// The house popup — the iOS twin of Material's `AlertDialog(text = { … })` when the body is more
// than plain buttons (`MoreScreen.kt:487-522` is the first caller: a radio list).
//
// SwiftUI's `alert` holds buttons only and its `sheet` slides up from the bottom edge, so neither is
// the centred, scrimmed card Android draws. This modifier presents one: a `fullScreenCover` whose
// presentation background is clear (iOS 16.4+), carrying a scrim and a centred card. The cover is
// what puts the popup above the tab bar — an `.overlay` on a screen would stop at the shell's tab
// bar, where Android's dialog window covers the navigation bar too.
//
// The cover's own slide transition is disabled (`Transaction.disablesAnimations`) and replaced by
// the host's fade + scale, so the card grows out of the centre exactly as Material's dialog does.
// The exit is a cut, not a fade, on purpose: a pick can close this dialog and open the shell's
// paywall cover (`PaywallHost.swift`) in the same event, and a cover still fading out while another
// presents is exactly the overlap SwiftUI resolves by dropping one of them.
//
// Chrome from `design-tokens.md`: `surfaceContainerHigh` on `shapes.extraLarge` (28pt) with the
// `xl` inset Material gives a dialog, under a `scrim` at 32% — the M3 `AlertDialog` defaults.
// `salusConfirmDialog` stays the system alert: two buttons need nothing this draws.

import SalusDesignSystem
import SwiftUI

extension View {
    /// A centred, scrimmed popup over the whole window (tab bar included).
    ///
    /// - Parameters:
    ///   - isPresented: the twin of Kotlin's `if (state.activeDialog != null)`. A tap on the scrim
    ///     sets it `false` — `onDismissRequest` — and the caller's `dialog` decides everything else.
    ///   - dialog: the card's content. It brings its own padding; the host paints the surface.
    public func salusDialog(
        isPresented: Binding<Bool>,
        @ViewBuilder dialog: @escaping () -> some View
    ) -> some View {
        modifier(SalusDialogModifier(isPresented: isPresented, dialog: dialog))
    }
}

/// How long the dialog takes to fade — in and out alike.
enum SalusDialogDefaults {
    static let transitionSeconds: TimeInterval = 0.18
    /// Material's `AlertDialog` scrim: `scrim` at 32%.
    static let scrimOpacity = 0.32
    /// Material's dialog width band, `AlertDialogDefaults` (280–560dp).
    static let minWidth: CGFloat = 280
    static let maxWidth: CGFloat = 560
    /// The card starts slightly smaller than life and settles into place.
    static let enterScale: CGFloat = 0.92
}

private struct SalusDialogModifier<Dialog: View>: ViewModifier {
    @Binding var isPresented: Bool
    let dialog: () -> Dialog

    /// Drives the cover. Mirrors `isPresented`, one update behind, so the entrance can animate.
    @State private var isCoverPresented = false
    /// Drives the scrim's opacity and the card's scale — the animated half of the presentation.
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented, initial: true) { _, presented in
                if presented {
                    present()
                } else {
                    dismiss()
                }
            }
            .salusDialogCover(isPresented: $isCoverPresented) {
                SalusDialogHost(
                    isVisible: isVisible,
                    onAppear: {
                        withAnimation(.easeOut(duration: SalusDialogDefaults.transitionSeconds)) { isVisible = true }
                    },
                    onScrimTap: { isPresented = false },
                    content: dialog
                )
            }
    }

    private func present() {
        guard !isCoverPresented else { return }
        // The cover's slide is not this dialog's entrance — the host fades in instead.
        withTransaction(Self.noAnimation) { isCoverPresented = true }
    }

    private func dismiss() {
        guard isCoverPresented else { return }
        // Torn down in the same update that flipped the binding, so whatever the caller presents
        // next (the paywall, a push) never races a cover on its way out.
        withTransaction(Self.noAnimation) {
            isVisible = false
            isCoverPresented = false
        }
    }

    private static var noAnimation: Transaction {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        return transaction
    }
}

extension View {
    /// The window-covering presentation behind the popup. `fullScreenCover` with a clear
    /// presentation background is what lets the scrim dim the tab bar too.
    @ViewBuilder
    fileprivate func salusDialogCover(
        isPresented: Binding<Bool>,
        @ViewBuilder host: @escaping () -> some View
    ) -> some View {
        #if os(iOS)
            fullScreenCover(isPresented: isPresented) {
                host().presentationBackground(.clear)
            }
        #else
            // The macOS test host has no `fullScreenCover`; nothing on macOS ever presents this.
            sheet(isPresented: isPresented, content: host)
        #endif
    }
}

/// Scrim plus centred card. Painted from tokens; the content only brings its inset.
private struct SalusDialogHost<Content: View>: View {
    let isVisible: Bool
    let onAppear: () -> Void
    let onScrimTap: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ZStack {
            // `onDismissRequest` — a tap outside the card closes it, as on Android. Hidden from
            // assistive tech: the card's own cancel action is the announced way out.
            theme.colorScheme.scrim
                .opacity(isVisible ? SalusDialogDefaults.scrimOpacity : 0)
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture(perform: onScrimTap)
                .accessibilityHidden(true)

            content()
                .frame(
                    minWidth: SalusDialogDefaults.minWidth,
                    maxWidth: SalusDialogDefaults.maxWidth
                )
                .background(
                    SalusShapes.extraLargeShape
                        .fill(theme.colorScheme.surfaceContainerHigh)
                        .salusShadow(.card, isDark: theme.isDark)
                )
                .padding(.horizontal, SalusSpacing.xl)
                .scaleEffect(isVisible ? 1 : SalusDialogDefaults.enterScale)
                .opacity(isVisible ? 1 : 0)
        }
        .onAppear(perform: onAppear)
    }
}

private struct SalusDialogPreview: View {
    @State private var isPresented = true

    var body: some View {
        // `verbatim:` on purpose — preview copy must never look like a localisation key.
        Text(verbatim: "Host")
            .salusDialog(isPresented: $isPresented) {
                VStack(alignment: .leading, spacing: SalusSpacing.lg) {
                    Text(verbatim: "Tema")
                        .font(SalusTypography.headlineSmall.font)
                    SalusOptionRow(systemImage: "paintpalette", label: "Açık", isSelected: true, onSelected: {})
                    SalusOptionRow(systemImage: "paintpalette", label: "Koyu", isSelected: false, onSelected: {})
                    SalusPillButton(text: "İptal", tonal: true) { isPresented = false }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(SalusSpacing.xl)
            }
    }
}

#Preview("Dialog") {
    SalusDialogPreview()
        .salusTheme(SalusTheme.resolve(systemIsDark: false))
}

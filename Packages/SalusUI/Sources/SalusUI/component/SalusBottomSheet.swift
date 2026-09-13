// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusBottomSheet.kt:47-112`.
//
// **Recorded divergence (d), spec §9: this is a modifier, not a view.** Kotlin's
// `ModalBottomSheet` is a composable the caller places inside an `if (show)`; SwiftUI's sheet is a
// *presentation* attached to the view that owns the flag, so the twin of `SalusBottomSheet(...)`
// is `someView.salusBottomSheet(isPresented:)`. Everything Kotlin sets by argument is set by a
// presentation modifier here: `presentationDetents` for the height, `presentationDragIndicator`
// for the handle, `presentationCornerRadius` for the `extraLarge` top corners and
// `presentationBackground` for the `surfaceContainer` ground.
//
// **The height is the one thing SwiftUI has no twin for, and ``SalusSheetSizing/fitted`` is how it
// is answered (owner QA round 2, C2).** A `ModalBottomSheet` wraps its content: three rows make a
// sheet three rows tall. A SwiftUI sheet only rests at the detents it is given, so the language
// picker at `[.medium]` opened at half the screen with a large empty area under its three rows. A
// fitting sheet measures the height its own body wants — a hidden copy of the header and the
// caller's content, laid out at the sheet's width and at its natural height — and presents at
// `.height(measured)`. The measurement is deliberately taken from a copy that is laid out with
// `fixedSize(horizontal: false, vertical: true)` rather than from the sheet on screen: a height
// read off the presented body would be the height the *detent* gave it, and feeding that back into
// the detent is a layout loop. The copy is only ever proposed the sheet's width, which no detent
// changes.
//
// Two Kotlin concerns fall away with the modifier. `sheetState.hide()` before `onDismiss`
// (`SalusBottomSheet.kt:99-105`) existed because a close button wired straight to the callback
// would make the sheet vanish while a swipe or a scrim tap slid away; SwiftUI animates the
// dismissal from the binding itself, so all three exits look the same by construction. And
// `tonalElevation = none` (`:69`) has no iOS equivalent at all (divergence (e)).
//
// The theme is re-applied inside the sheet: a sheet is presented from a new window scene, and
// nothing about that guarantees the caller's `@Environment(\.salusTheme)` travels with it.

import SalusDesignSystem
import SwiftUI

/// How tall a ``SwiftUI/View/salusBottomSheet(isPresented:title:subtitle:sizing:content:)`` rests
/// (spec §9 (d)).
///
/// One value rather than a `detents:` set plus a `fitsContent:` flag, because the two answers are
/// exclusive: a sheet either takes the height its content asks for or the heights the caller names,
/// and a call site that said both would have to be read to find out which one won.
public enum SalusSheetSizing: Equatable {
    /// The sheet is exactly as tall as its own body — header, content and the sheet's bottom inset
    /// — which is what Compose's `ModalBottomSheet` does by construction. The twin of Android
    /// wrapping its content, and the right answer for a short sheet: the language picker's three
    /// rows, the onboarding privacy paragraph.
    ///
    /// A body taller than the screen is capped by the system, which never places a sheet above its
    /// container's full height, and the body's `ScrollView` is what keeps the rest reachable — so
    /// fitting is never the reason something cannot be read.
    case fitted

    /// The heights the sheet may rest at. `[.medium]` is the plain half sheet; a sheet whose
    /// content is taller than a medium sheet passes `[.medium, .large]` so it can be dragged up,
    /// as the theme picker does (final-review I4). Either way the body scrolls, so a detent is
    /// never the reason something is unreachable.
    case detents(Set<PresentationDetent>)
}

extension View {
    /// The app's one modal sheet: drag handle, a title/subtitle header with a close button, and
    /// the caller's content on a `surfaceContainer` ground with `extraLarge` top corners
    /// (`SalusBottomSheet.kt:33-35`).
    ///
    /// The close button is there for the users who never learn the swipe — the sheet is still
    /// dismissible by dragging and by the scrim, and `isPresented` is the one exit all three take
    /// (`SalusBottomSheet.kt:37-38`).
    ///
    /// - Parameter sizing: ``SalusSheetSizing/fitted`` for a sheet that hugs its content, the
    ///   twin of `ModalBottomSheet`'s own behaviour; `.detents(…)` for the fixed heights a taller
    ///   sheet is dragged between. The default is the plain half sheet.
    public func salusBottomSheet(
        isPresented: Binding<Bool>,
        title: String,
        subtitle: String? = nil,
        sizing: SalusSheetSizing = .detents([.medium]),
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        modifier(
            SalusBottomSheetModifier(
                isPresented: isPresented,
                title: title,
                subtitle: subtitle,
                sizing: sizing,
                sheetContent: content
            )
        )
    }
}

/// The presentation behind ``SwiftUI/View/salusBottomSheet(isPresented:title:subtitle:sizing:content:)``.
private struct SalusBottomSheetModifier<C: View>: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let subtitle: String?
    let sizing: SalusSheetSizing
    @ViewBuilder let sheetContent: () -> C

    @Environment(\.salusTheme) private var theme
    /// The height a fitting body reported, or `nil` until the first layout pass has produced one.
    /// It rides here rather than inside the body because `presentationDetents` is applied to the
    /// sheet's root — the one place it is known to take — and a preference is how a measurement
    /// travels the other way.
    @State private var fittedHeight: CGFloat?

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            SalusBottomSheetBody(
                title: title,
                subtitle: subtitle,
                isFitting: sizing == .fitted,
                onClose: { isPresented = false },
                content: sheetContent
            )
            .onPreferenceChange(SalusSheetFittedHeightKey.self) { height in
                // Zero is "nothing has been laid out yet", not "the body is empty", so it leaves
                // the fallback detent in place rather than collapsing the sheet to a line.
                fittedHeight = height > 0 ? height : nil
            }
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            // `shapes.extraLarge` on the top corners only — the bottom edge is off-screen
            // (`SalusBottomSheet.kt:61-65`). `presentationCornerRadius` rounds exactly those two.
            .presentationCornerRadius(SalusShapes.extraLarge)
            // `containerColor = surfaceContainer` (`SalusBottomSheet.kt:66`).
            .presentationBackground(theme.colorScheme.surfaceContainer)
            .salusTheme(theme)
        }
    }

    /// What the sheet rests at. A fitting sheet waits at the half sheet for one layout pass and
    /// then takes its body's own height; a caller's fixed detents are passed straight through.
    private var detents: Set<PresentationDetent> {
        switch sizing {
        case let .detents(detents):
            detents
        case .fitted:
            if let fittedHeight {
                [.height(fittedHeight)]
            } else {
                [.medium]
            }
        }
    }
}

/// The sheet's own content: the header Kotlin draws (`SalusBottomSheet.kt:71-109`) over the
/// caller's.
private struct SalusBottomSheetBody<C: View>: View {
    let title: String
    let subtitle: String?
    /// Whether to measure and report the height this body wants (``SalusSheetSizing/fitted``).
    let isFitting: Bool
    let onClose: () -> Void
    @ViewBuilder let content: () -> C

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            // The caller's content scrolls, the header does not. Compose's `ModalBottomSheet`
            // column is scrollable by construction; a SwiftUI sheet clips instead, so content
            // taller than the detent it opened at — the theme sheet's mode tiles plus four
            // palette rows at a large Dynamic Type, say — was simply unreachable. The
            // `ScrollView` bounces on content that already fits, and the detent still sizes the
            // sheet, so nothing that fitted before moves.
            ScrollView {
                content()
            }
            // The content decides the sheet's height up to the detent; without this a `ScrollView`
            // greedily takes the whole sheet and a short body's ground stretches under it.
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .top) { fittingMeasurement }
    }

    /// A second, hidden copy of the body, laid out at its natural height — where a fitting sheet's
    /// detent comes from. Nothing at all for a sheet with fixed detents.
    ///
    /// A background rather than a wrapper, so it is proposed exactly the sheet's width and a
    /// paragraph wraps to the same number of lines it will really take; `fixedSize(vertical:)` is
    /// what makes it answer with its ideal height instead of the height the sheet was given, which
    /// is the whole reason this is a copy and not a reading of the body on screen. `hidden()` keeps
    /// it out of the drawing and the two lines under it keep it out of VoiceOver and hit testing,
    /// so the only thing the copy contributes is its size.
    ///
    /// The outer reader adds the sheet's bottom safe-area inset to that height: a detent names the
    /// sheet's frame, and the body inside it is then inset clear of the home indicator, so a sheet
    /// asked for exactly the content height would leave the last row's own clearance to scroll for.
    @ViewBuilder private var fittingMeasurement: some View {
        if isFitting {
            GeometryReader { sheet in
                VStack(alignment: .leading, spacing: 0) {
                    header
                    content()
                }
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { measured in
                        Color.clear.preference(
                            key: SalusSheetFittedHeightKey.self,
                            value: measured.size.height + sheet.safeAreaInsets.bottom
                        )
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .hidden()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }

    /// `Row(start = lg, end = sm, bottom = md)` with the titles on `weight(1f)` and the close
    /// button trailing them (`SalusBottomSheet.kt:72-108`). The top inset is the iOS half: the
    /// drag indicator sits above it, where Compose's sheet keeps its own handle padding.
    private var header: some View {
        HStack(spacing: SalusSpacing.sm) {
            VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                // `Text(verbatim:)` on both: the caller hands us resolved strings.
                Text(verbatim: title)
                    .font(SalusTypography.titleLarge.font)
                    .tracking(SalusTypography.titleLarge.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(SalusTypography.bodySmall.font)
                        .tracking(SalusTypography.bodySmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SalusIconButton(
                systemImage: "xmark",
                accessibilityLabel: SalusUIStrings.sheetClose,
                action: onClose
            )
        }
        .padding(.leading, SalusSpacing.lg)
        .padding(.trailing, SalusSpacing.sm)
        .padding(.top, SalusSpacing.lg)
        .padding(.bottom, SalusSpacing.md)
    }
}

/// The height a fitting body wants, carried from the hidden copy to the detent. `reduce` keeps the
/// maximum for the same reason ``SalusBottomSheetBody`` only ever plants one reporter: a second
/// value can only come from a second layout of the same copy, and the taller reading is the one
/// that shows every row.
private struct SalusSheetFittedHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("Bottom sheet header") {
    // The sheet itself is a presentation and does not render in a preview, so the preview shows
    // the header the sheet draws, on the sheet's own ground — exactly what Kotlin's preview does
    // (`SalusBottomSheet.kt:119-120`).
    SalusPreviewPalettes {
        SalusBottomSheetBody(
            title: "Tema",
            subtitle: "Uygulamanın rengini seç",
            isFitting: false,
            onClose: {},
            content: { SalusSelectableRow(title: "Classic", isSelected: true) {} }
        )
    }
}

#Preview("Fitting sheet body — three rows") {
    // The fitting body at the size it reports: header + three rows and nothing under them, which
    // is what the language sheet's detent is measured from (owner QA round 2, C2). The measuring
    // copy is hidden, so what is on screen here is the body itself at its natural height.
    SalusPreviewPalettes {
        SalusBottomSheetBody(
            title: "Uygulama dili",
            subtitle: "Seçim anında uygulanır",
            isFitting: true,
            onClose: {},
            content: {
                VStack(spacing: 0) {
                    SalusSelectableRow(title: "Sistem dili", systemImage: "globe", isSelected: true) {}
                    SalusSelectableRow(title: "Türkçe", systemImage: "globe", isSelected: false) {}
                    SalusSelectableRow(title: "English", systemImage: "globe", isSelected: false) {}
                }
            }
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

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
// Two Kotlin concerns fall away with it. `sheetState.hide()` before `onDismiss`
// (`SalusBottomSheet.kt:99-105`) existed because a close button wired straight to the callback
// would make the sheet vanish while a swipe or a scrim tap slid away; SwiftUI animates the
// dismissal from the binding itself, so all three exits look the same by construction. And
// `tonalElevation = none` (`:69`) has no iOS equivalent at all (divergence (e)).
//
// The theme is re-applied inside the sheet: a sheet is presented from a new window scene, and
// nothing about that guarantees the caller's `@Environment(\.salusTheme)` travels with it.

import SalusDesignSystem
import SwiftUI

extension View {
    /// The app's one modal sheet: drag handle, a title/subtitle header with a close button, and
    /// the caller's content on a `surfaceContainer` ground with `extraLarge` top corners
    /// (`SalusBottomSheet.kt:33-35`).
    ///
    /// The close button is there for the users who never learn the swipe — the sheet is still
    /// dismissible by dragging and by the scrim, and `isPresented` is the one exit all three take
    /// (`SalusBottomSheet.kt:37-38`).
    ///
    /// - Parameter detents: the heights the sheet may rest at; `.medium` is what the theme and
    ///   language pickers use (spec §9 (d)).
    public func salusBottomSheet(
        isPresented: Binding<Bool>,
        title: String,
        subtitle: String? = nil,
        detents: Set<PresentationDetent> = [.medium],
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        modifier(
            SalusBottomSheetModifier(
                isPresented: isPresented,
                title: title,
                subtitle: subtitle,
                detents: detents,
                sheetContent: content
            )
        )
    }
}

/// The presentation behind ``SwiftUI/View/salusBottomSheet(isPresented:title:subtitle:detents:content:)``.
private struct SalusBottomSheetModifier<C: View>: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let subtitle: String?
    let detents: Set<PresentationDetent>
    @ViewBuilder let sheetContent: () -> C

    @Environment(\.salusTheme) private var theme

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            SalusBottomSheetBody(
                title: title,
                subtitle: subtitle,
                onClose: { isPresented = false },
                content: sheetContent
            )
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
}

/// The sheet's own content: the header Kotlin draws (`SalusBottomSheet.kt:71-109`) over the
/// caller's.
private struct SalusBottomSheetBody<C: View>: View {
    let title: String
    let subtitle: String?
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

#Preview("Bottom sheet header") {
    // The sheet itself is a presentation and does not render in a preview, so the preview shows
    // the header the sheet draws, on the sheet's own ground — exactly what Kotlin's preview does
    // (`SalusBottomSheet.kt:119-120`).
    SalusPreviewPalettes {
        SalusBottomSheetBody(
            title: "Tema",
            subtitle: "Uygulamanın rengini seç",
            onClose: {},
            content: { SalusSelectableRow(title: "Classic", isSelected: true) {} }
        )
    }
}

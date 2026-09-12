// The tab roots' one toolbar — the twin of
// `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/SalusTopBar.kt:96-189`
// (`SalusTopBar.Home`), which Android's shell draws over the five top-level destinations
// (`app/src/main/kotlin/com/alicansekban/salus/ui/SalusApp.kt:281-287`).
//
// Where Kotlin builds a `Row` and floats it over the Scaffold, this fills the SYSTEM navigation
// bar (spec §2.2, decision Q2): leading brand tile, principal title, trailing bell and avatar.
// That is the whole iOS divergence (a) in one file — no custom bar, no `Clearance` constant for a
// root to reserve, because the native bar lives in the safe area and the content below it starts
// where the system says.
//
// **The shell applies this, never a feature** (`App/RootNavigationStack.swift`). A tab root is the
// one screen that has no back button, so it is the one screen where three leading/trailing slots
// are free; a pushed screen gets `.navigationTitle` + its own `ToolbarItem` actions instead, and
// the two never combine (spec §10, first risk). The bell and the avatar both land in
// `FeatureSettings`, which no feature may import, so their destinations arrive as closures the
// shell fills — the cross-feature rule the feature template records.
//
// **`.navigationBarTitleDisplayMode(.inline)` is here as well as on every pushed screen.** The
// modifier describes the view it is applied to, not the stack, so a root setting it says nothing
// about what the root pushes: T6–T13 set it on their own screens, and the template says so.

import SalusDesignSystem
import SwiftUI

extension View {
    /// The root toolbar every tab root wears: brand tile, title, bell, avatar.
    ///
    /// - Parameters:
    ///   - title: the tab's label, already resolved (`SalusApp.kt:283` passes the same).
    ///   - onBell: opens Reminder health (`SalusTopBar.kt:164`).
    ///   - onAvatar: opens Profile (`SalusTopBar.kt:171`).
    public func salusRootToolbar(
        title: String,
        onBell: @escaping () -> Void,
        onAvatar: @escaping () -> Void
    ) -> some View {
        modifier(SalusRootToolbar(title: title, onBell: onBell, onAvatar: onAvatar))
    }
}

/// The modifier behind ``SwiftUI/View/salusRootToolbar(title:onBell:onAvatar:)``.
///
/// A `ViewModifier` rather than a chain of `.toolbar` calls at the call site so the three slots,
/// the inline mode and the title stay one decision — five roots wearing five hand-written
/// toolbars is how two of them end up with a different bell.
private struct SalusRootToolbar: ViewModifier {
    let title: String
    let onBell: () -> Void
    let onAvatar: () -> Void

    @Environment(\.salusTheme) private var theme

    func body(content: Content) -> some View {
        // `.navigationBarTitleDisplayMode` and the two `topBar*` placements are iOS-only API, and
        // this package also builds for the macOS host so `swift test` can run (CLAUDE.md, the
        // `.macOS(.v14)` concession). macOS has no navigation bar to fill and ships nothing, so
        // there the modifier is a pass-through rather than a second, wrong toolbar.
        #if os(iOS)
            content
                // The back button of anything this root pushes reads the title, so it is set as
                // well as drawn: `.principal` replaces what the bar SHOWS, not what it is called.
                .navigationTitle(Text(verbatim: title))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { brandTile }
                    ToolbarItem(placement: .principal) { titleText }
                    ToolbarItem(placement: .topBarTrailing) { bell }
                    ToolbarItem(placement: .topBarTrailing) { avatar }
                }
        #else
            content
        #endif
    }

    /// `SalusTopBar.kt:134-150` — a `primaryContainer` mark with the heart glyph on it, decorative
    /// (`contentDescription = null` at `:146`).
    ///
    /// A circle rather than Kotlin's `shapes.small` rounded square: the shared `SalusIconBadge` is
    /// what draws a tinted glyph everywhere else in the app, and a second brand-only shape would be
    /// a component nobody else could reuse. Recorded with divergence (a).
    private var brandTile: some View {
        SalusIconBadge(systemImage: "heart.fill", size: .small)
    }

    /// `SalusTopBar.kt:151-160`. `titleMedium` rather than Kotlin's `titleLarge` (spec §2.2): the
    /// system bar is shorter than Android's 56 dp row, and the same weight the native inline title
    /// draws is what `SalusBarAppearance.navigationBar(for:)` puts on pushed screens — so a root
    /// and the screen it pushes read as one bar.
    private var titleText: some View {
        // `verbatim:` because `title` is an already-resolved `AppStrings` value; the plain
        // initializer would read it back as a `LocalizedStringKey` (the M7 `c726e22` finding).
        Text(verbatim: title)
            .font(SalusTypography.titleMedium.font)
            .tracking(SalusTypography.titleMedium.tracking)
            .foregroundStyle(theme.colorScheme.onSurface)
            .lineLimit(1)
    }

    /// `SalusTopBar.kt:161-166` — the quiet tone, which is Kotlin's `Neutral`.
    private var bell: some View {
        SalusIconButton(
            systemImage: "bell",
            accessibilityLabel: SalusUIStrings.topBarBell,
            action: onBell
        )
    }

    /// `SalusTopBar.kt:167-187`. The glyph, not initials: Kotlin's note at `:112-113` is that the
    /// bar must have no data dependency, so the shell can draw it without loading a profile.
    ///
    /// `SalusAvatar` is `accessibilityHidden`, so the name belongs to the button around it — which
    /// is also where Kotlin puts it, on the clickable `Box` rather than on the disc.
    private var avatar: some View {
        Button(action: onAvatar) {
            SalusAvatar(name: nil, size: SalusAvatarDefaults.toolbar)
                .frame(width: SalusTouchTarget.min, height: SalusTouchTarget.min)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: SalusUIStrings.topBarProfile))
    }
}

#Preview("Root toolbar") {
    SalusPreviewPalettes {
        // Not a `NavigationStack` — `SalusUI` may not declare one (the shell rule), and a toolbar
        // has nothing to attach to outside one anyway. What the eight panels show is the three
        // slots side by side, which is what a palette can get wrong.
        HStack(spacing: SalusSpacing.sm) {
            SalusIconBadge(systemImage: "heart.fill", size: .small)
            Text(verbatim: "Ana Sayfa")
                .font(SalusTypography.titleMedium.font)
                .frame(maxWidth: .infinity)
            SalusIconButton(systemImage: "bell", accessibilityLabel: "Hatırlatıcı sağlığı") {}
            SalusAvatar(name: nil, size: SalusAvatarDefaults.toolbar)
        }
    }
}

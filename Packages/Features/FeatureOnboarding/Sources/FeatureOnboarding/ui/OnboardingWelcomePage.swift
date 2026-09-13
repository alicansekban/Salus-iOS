// Ported 1:1 from `WelcomePage` and its `TrustChips` table in
// `feature/onboarding/src/main/kotlin/com/alicansekban/salus/feature/onboarding/ui/
// OnboardingPages.kt:74-122` and `:366-371`.
//
// Android keeps all three pages in one Kotlin file; iOS splits them into one file each, because
// SwiftLint caps a file at 500 lines and three pages with their previews do not fit under it. Each
// file cites the line range of `OnboardingPages.kt` it carries.
//
// The cover: what the app is, what it will not do with the data, and one way in. The privacy link
// opens the statement in a sheet rather than navigating — leaving the gate to read it would mean
// coming back to a flow that has to be restarted (`OnboardingPages.kt:69-73`).
//
// Material → SwiftUI:
//   `FlowRow(spacedBy(sm,             → `ViewThatFits(in: .horizontal)` over a centred `HStack` and
//     CenterHorizontally))`             a centred `VStack`. SwiftUI has no flow layout before
//                                       iOS 18's `Layout`-built ones, and the three chips either
//                                       fit on one line or (at the larger type sizes) do not — so
//                                       the two arrangements are the only two a flow row would ever
//                                       produce here.
//   `SalusStatusChip(status =         → `SalusStatusChip(label:status:systemImage:)` with
//     Neutral, icon = …)`               `.neutral`. Kotlin's chips are the plain neutral pill, not
//                                       the selectable `SalusChoiceChip`: nothing here is a choice,
//                                       and a chip that looks pressable invites a tap that does
//                                       nothing.
//   `SalusBottomSheet(onDismiss,      → the `salusBottomSheet(isPresented:title:subtitle:sizing:content:)`
//     title) { Text(body) }`            modifier (§9 (d): the sheet is a modifier on this side, not
//                                       a view), driven by the same `rememberSaveable` boolean,
//                                       which is `@State` here.
//   `TextButton { Text(link) }`       → a `.plain` `Button` over `SalusTypography.labelLarge` in the
//                                       primary role, which is what a Material `TextButton` draws.
//                                       `SalusUI` has no text-button component to reach for, and
//                                       the link is not an action the page is built around.
//
// The three glyphs: `Smartphone` → `iphone`, `NoAccounts` → `person.crop.circle.badge.xmark`,
// `Block` → `nosign`; `Shield` → `shield`, the symbol the port already used for this page.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// Page 1 of 3 — the cover (`OnboardingPages.kt:76-122`).
struct OnboardingWelcomePage: View {
    let onEvent: (OnboardingEvent) -> Void

    @Environment(\.salusTheme) private var theme
    /// `var privacyShown by rememberSaveable { mutableStateOf(false) }` (`OnboardingPages.kt:80`).
    @State private var isPrivacyShown = false

    var body: some View {
        // `PageColumn` (`OnboardingPages.kt:307-319`) — full width, one gap, room to breathe at
        // both ends. Three lines rather than a shared helper: SwiftUI has no `ColumnScope`, so a
        // wrapper would cost a generic view per page to save nothing.
        VStack(spacing: SalusSpacing.lg) {
            OnboardingHero(
                systemImage: "shield",
                title: OnboardingStrings.onboardingWelcomeTitle,
                message: OnboardingStrings.onboardingWelcomeBody
            )
            trustChips
            SalusButton(OnboardingStrings.onboardingStart, variant: .primary, size: .large) {
                onEvent(.nextClicked)
            }
            privacyLink
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SalusSpacing.xl)
        // `SalusBottomSheet` (`OnboardingPages.kt:110-121`). Fitting rather than a fixed detent:
        // the statement is one paragraph, so the sheet is as tall as the paragraph — a half sheet
        // opened on its first two lines and a `.large` one left empty space under a short
        // translation. At the largest text sizes the paragraph outgrows the screen; the sheet is
        // capped at the container's height there and the body's own `ScrollView` reaches the rest
        // (owner QA round 2, C2).
        .salusBottomSheet(
            isPresented: $isPrivacyShown,
            title: OnboardingStrings.onboardingPrivacyTitle,
            sizing: .fitted
        ) {
            Text(verbatim: OnboardingStrings.onboardingPrivacyBody)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .lineLimit(nil)
                // The sheet body pads its header only, because every other caller's content is
                // rows that carry their own inset (`SalusSelectableRow`). A bare paragraph has
                // none, so it applies the screen inset itself rather than the body gaining a
                // default every row would then have to undo.
                .padding(.horizontal, SalusSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `FlowRow { TrustChips.forEach { … } }` (`OnboardingPages.kt:87-99`) — the promises the cover
    /// makes, in the order they answer "what is the catch?" (`:366-367`).
    private var trustChips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SalusSpacing.sm) { chips }
            VStack(spacing: SalusSpacing.sm) { chips }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var chips: some View {
        SalusStatusChip(
            label: OnboardingStrings.onboardingTrustLocal,
            status: .neutral,
            systemImage: "iphone"
        )
        SalusStatusChip(
            label: OnboardingStrings.onboardingTrustNoAccount,
            status: .neutral,
            systemImage: "person.crop.circle.badge.xmark"
        )
        SalusStatusChip(
            label: OnboardingStrings.onboardingTrustNoAds,
            status: .neutral,
            systemImage: "nosign"
        )
    }

    /// `PageTextButton(onboarding_privacy_link)` (`OnboardingPages.kt:104-107`, `:353-364`) — the
    /// quiet way out of a page, always under the primary action, never beside it.
    private var privacyLink: some View {
        Button { isPrivacyShown = true } label: {
            Text(verbatim: OnboardingStrings.onboardingPrivacyLink)
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
                .foregroundStyle(theme.colorScheme.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: SalusTouchTarget.min)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// `WelcomePagePreview` (`OnboardingPages.kt:394-400`) — the four palettes in both modes, which is
// what `@PreviewParameter(SalusPaletteProvider::class)` + `@PreviewLightDark` renders on Android.
#Preview("Welcome page · palettes") {
    SalusPreviewPalettes {
        OnboardingWelcomePage { _ in }
    }
}

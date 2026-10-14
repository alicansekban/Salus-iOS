// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/ui/
// HomeSmokingCards.kt` (Android branch `feature/m17-smoking-cessation`) — `HomeSmokingSection`
// and its three states (design screen `01`).
//
// The card sits **between the dose pager and the AI card** (spec §3), never as a pager page: it is
// its own static card in the column. Which state shows is `HomeUiState.smokingCard`, and nil draws
// nothing.
//
//   * **Discovery** — one slim line that opens the setup, with an (x) that closes it for good.
//   * **QUIT** — the day count in the smoking accent, the ring to the next stage, the money kept
//     and a full-width "Canım çekti" button that opens the craving flow.
//   * **REDUCE** — "Bugün 6 / 10", a bar and a "+1". Over the limit the excess is a neutral second
//     lap of the bar plus a neutral "+n" chip: going over is information, so neither the bar nor
//     the chip takes a warning colour (design review R2), and there is no "Dün durumu" row (R12).
//
// **Why the QUIT and REDUCE cards are not `SalusCard(onTap:)`.** Both hold a button, and a button
// inside a button is decoration to SwiftUI — the outer one swallows the tap. So the card is
// non-interactive, the block that opens the main screen carries `homeOpensCard`, and the button is
// its **sibling** (`HomeDashboardCard`'s note). The discovery row holds the (x) for the same reason.
//
// **Accessibility.** The figures are live, so each block that holds them is one VoiceOver element
// reading one sentence (`home_smoking_*_spoken`); the buttons stay separate elements a screen
// reader can act on. At the accessibility sizes the day count and the ring stack instead of
// sharing a row.

import SalusDesignSystem
import SalusUI
import SwiftUI

/// The smoking card under the dose pager (`HomeSmokingSection`, `HomeSmokingCards.kt`).
struct HomeSmokingSection: View {
    let card: HomeSmokingCard
    let onEvent: (HomeEvent) -> Void
    let onOpenSmoking: () -> Void
    let onOpenSmokingSetup: () -> Void
    let onOpenCraving: () -> Void

    var body: some View {
        switch card {
        case .discovery:
            SmokingDiscoveryRow(
                onOpenSetup: onOpenSmokingSetup,
                onDismiss: { onEvent(.smokingDiscoveryDismissed) }
            )

        case let .quit(quit):
            SmokingQuitCard(
                quit: quit,
                onOpenSmoking: onOpenSmoking,
                onOpenCraving: onOpenCraving
            )

        case let .reduce(today, limit, overflow):
            SmokingReduceCard(
                today: today,
                limit: limit,
                overflow: overflow,
                onOpenSmoking: onOpenSmoking,
                onPlusOne: { onEvent(.smokingPlusOne) }
            )
        }
    }
}

/// A slim line, not a card's worth of content: the (x) closes it for good.
private struct SmokingDiscoveryRow: View {
    let onOpenSetup: () -> Void
    let onDismiss: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(
            contentPadding: EdgeInsets(
                top: SalusSpacing.sm,
                leading: SalusSpacing.md,
                bottom: SalusSpacing.sm,
                trailing: SalusSpacing.md
            )
        ) {
            HStack(spacing: SalusSpacing.md) {
                HStack(spacing: SalusSpacing.md) {
                    SalusIconBadge(systemImage: "smoke", accent: theme.extendedColors.smoking)
                    Text(verbatim: HomeStrings.smokingDiscovery)
                        .font(SalusTypography.bodyLarge.font)
                        .tracking(SalusTypography.bodyLarge.tracking)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SalusListItemChevron()
                }
                .homeOpensCard(onOpenSetup)
                SalusIconButton(
                    systemImage: "xmark",
                    accessibilityLabel: HomeStrings.smokingDiscoveryDismiss,
                    action: onDismiss
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SalusSpacing.lg)
    }
}

private struct SmokingQuitCard: View {
    let quit: HomeSmokingQuit
    let onOpenSmoking: () -> Void
    let onOpenCraving: () -> Void

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accent: FeatureAccent {
        theme.extendedColors.smoking
    }

    private var daysText: String {
        HomeStrings.smokingDays(quit.days)
    }

    private var savedText: String {
        HomeSmokingFormatting.wholeMoney(minor: quit.savedMinor, currencyCode: quit.currency, locale: locale)
    }

    /// "3 gün" and its siblings; nil once every stage is done.
    private var nextStageText: String? {
        quit.nextStageRemainingMs.map { HomeSmokingFormatting.nextStageText(remainingMs: $0) }
    }

    private var spoken: String {
        let base = HomeStrings.smokingQuitSpoken(daysText, savedText)
        guard let nextStageText else { return base }
        return base + " " + HomeStrings.smokingNextStage(nextStageText)
    }

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                VStack(alignment: .leading, spacing: SalusSpacing.md) {
                    SmokingCardHeader()
                    figures
                    Text(verbatim: HomeStrings.smokingSaved(savedText))
                        .font(SalusTypography.bodyLarge.font)
                        .tracking(SalusTypography.bodyLarge.tracking)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .homeOpensCard(onOpenSmoking)
                .accessibilityLabel(Text(verbatim: spoken))

                SalusButton(HomeStrings.smokingCraving, accent: accent, action: onOpenCraving)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SalusSpacing.lg)
    }

    /// The day count beside the ring; stacked at the accessibility sizes, where the two would not
    /// fit a row.
    @ViewBuilder private var figures: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SalusSpacing.md))
            : AnyLayout(HStackLayout(spacing: SalusSpacing.md))
        layout {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: daysText)
                    .font(SalusTypography.displaySmall.font)
                    .tracking(SalusTypography.displaySmall.tracking)
                    .foregroundStyle(accent.accent)
                Text(verbatim: HomeStrings.smokingQuitCaption)
                    .font(SalusTypography.bodyMedium.font)
                    .tracking(SalusTypography.bodyMedium.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let nextStagePermille = quit.nextStagePermille, let nextStageText {
                VStack(spacing: SalusSpacing.xs) {
                    SalusProgressRing(
                        progress: Float(nextStagePermille) / 1000,
                        label: HomeSmokingFormatting.percent(permille: nextStagePermille, locale: locale),
                        accent: accent.accent
                    )
                    Text(verbatim: HomeStrings.smokingNextStage(nextStageText))
                        .font(SalusTypography.labelSmall.font)
                        .tracking(SalusTypography.labelSmall.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

private struct SmokingReduceCard: View {
    let today: Int
    let limit: Int
    let overflow: Int
    let onOpenSmoking: () -> Void
    let onPlusOne: () -> Void

    @Environment(\.salusTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accent: FeatureAccent {
        theme.extendedColors.smoking
    }

    private var isOver: Bool {
        overflow > 0
    }

    private var spoken: String {
        isOver
            ? HomeStrings.smokingReduceOverSpoken(today, limit, overflow)
            : HomeStrings.smokingReduceSpoken(today, limit)
    }

    /// The share of the track that is under the limit, 0 ... 1; the bar clamps what it is given.
    private var progress: Double {
        limit > 0 ? Double(today) / Double(limit) : 0
    }

    /// The excess in permille of the track, so 12 of 10 is a 200 permille second lap.
    private var overflowPermille: Int {
        isOver && limit > 0 ? overflow * 1000 / limit : 0
    }

    var body: some View {
        SalusCard {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: SalusSpacing.md))
                : AnyLayout(HStackLayout(spacing: SalusSpacing.md))
            layout {
                VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                    SmokingCardHeader()
                    HStack(spacing: SalusSpacing.sm) {
                        Text(verbatim: HomeStrings.smokingToday(today, limit))
                            .font(SalusTypography.headlineSmall.font)
                            .tracking(SalusTypography.headlineSmall.tracking)
                        // The excess is a neutral segment plus this chip: going over is
                        // information, so neither the bar nor the chip turns a warning colour.
                        if isOver {
                            SalusStatusChip(label: HomeStrings.smokingOverChip(overflow), status: .neutral)
                        }
                    }
                    SalusProgressBar(progress: progress, accent: accent.accent, overflowPermille: overflowPermille)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .homeOpensCard(onOpenSmoking)
                .accessibilityLabel(Text(verbatim: spoken))

                SalusButton(HomeStrings.smokingPlusOne, size: .medium, accent: accent, action: onPlusOne)
                    .accessibilityLabel(Text(verbatim: HomeStrings.smokingPlusOneDescription))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SalusSpacing.lg)
    }
}

/// The badge and the overline both cards open with.
private struct SmokingCardHeader: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        HStack(spacing: SalusSpacing.sm) {
            SalusIconBadge(systemImage: "smoke", accent: theme.extendedColors.smoking)
            Text(verbatim: HomeStrings.smokingOverline)
                .font(SalusTypography.labelMedium.font)
                .tracking(SalusTypography.labelMedium.tracking)
                .foregroundStyle(theme.extendedColors.smoking.accent)
        }
    }
}

// MARK: - Previews

private enum SmokingPreviewData {
    static let quit = HomeSmokingCard.quit(HomeSmokingQuit(
        days: 42,
        savedMinor: 315_000,
        currency: "TRY",
        nextStagePermille: 700,
        nextStageRemainingMs: 3 * 86_400_000
    ))
    static let reduce = HomeSmokingCard.reduce(today: 6, limit: 10, overflow: 0)
    static let reduceOver = HomeSmokingCard.reduce(today: 12, limit: 10, overflow: 2)
}

private struct SmokingPreview: View {
    let card: HomeSmokingCard

    var body: some View {
        HomeSmokingSection(
            card: card,
            onEvent: { _ in },
            onOpenSmoking: {},
            onOpenSmokingSetup: {},
            onOpenCraving: {}
        )
        .padding(.vertical, SalusSpacing.lg)
    }
}

// Each state in the eight-palette fan-out (light and dark), then the largest accessibility size.
#Preview("Smoking card — discovery") {
    SalusPreviewPalettes { SmokingPreview(card: .discovery) }
}

#Preview("Smoking card — quit") {
    SalusPreviewPalettes { SmokingPreview(card: SmokingPreviewData.quit) }
}

#Preview("Smoking card — reduce") {
    SalusPreviewPalettes { SmokingPreview(card: SmokingPreviewData.reduce) }
}

#Preview("Smoking card — reduce over the limit") {
    SalusPreviewPalettes { SmokingPreview(card: SmokingPreviewData.reduceOver) }
}

#Preview("Smoking card — accessibility3") {
    ScrollView {
        VStack {
            SmokingPreview(card: .discovery)
            SmokingPreview(card: SmokingPreviewData.quit)
            SmokingPreview(card: SmokingPreviewData.reduceOver)
        }
    }
    .dynamicTypeSize(.accessibility3)
}

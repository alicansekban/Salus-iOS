// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/setup/
// SmokingSetupSteps.kt`.
//
// The four pages of the setup wizard. Each is a column of content only: the title, the segments
// and the pinned button belong to `SmokingSetupScreen`, so the pages stay plain and previewable.
//
// Compose → SwiftUI, beyond the shared mapping table:
//   `SalusChoiceTile(icon, label, subtitle, accent)` → `SalusChoiceTile(…subtitle:accent:)`, the
//                           two knobs iOS-M17 ported into `SalusUI`.
//   `SalusInfoNote(icon: Lock)`  → `SalusInfoNote(systemImage: "lock")`.
//   `FlowRow` of chips           → `ChipFlowLayout`.
//   `SalusStepperField(range:)`  → the iOS field owns no range: the helpers below clamp every
//                           report into `1…SetupDefaults.maxUnits` and answer it, the caller
//                           contract in `SalusStepperField.swift`.
//   `SalusListItem` + `AlertDialog` → `SalusListItem(onTap:)` + the `quitDateSheet` modifier.

import Foundation
import SalusCommon
import SalusDesignSystem
import SalusModel
import SalusSmoking
import SalusUI
import SwiftUI

/// The page's lead: an accent badge, a headline and one calm sentence under it.
private struct StepHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.sm) {
            SalusIconBadge(systemImage: systemImage, accent: theme.extendedColors.smoking, size: .large)
            Text(verbatim: title)
                .font(SalusTypography.headlineSmall.font)
                .tracking(SalusTypography.headlineSmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurface)
                .multilineTextAlignment(.center)
            Text(verbatim: subtitle)
                .font(SalusTypography.bodyMedium.font)
                .tracking(SalusTypography.bodyMedium.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 1 — mode

struct ModeStep: View {
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.md) {
            StepHeader(
                systemImage: "timer",
                title: SmokingStrings.setupModeTitle,
                subtitle: SmokingStrings.setupModeSubtitle
            )
            SalusChoiceTile(
                label: SmokingStrings.setupModeQuit,
                systemImage: "timer",
                isSelected: state.mode == .quit,
                subtitle: SmokingStrings.setupModeQuitDesc,
                accent: theme.extendedColors.smoking
            ) { onEvent(.modeSelected(.quit)) }
            SalusChoiceTile(
                label: SmokingStrings.setupModeReduce,
                systemImage: "chart.line.downtrend.xyaxis",
                isSelected: state.mode == .reduce,
                subtitle: SmokingStrings.setupModeReduceDesc,
                accent: theme.extendedColors.smoking
            ) { onEvent(.modeSelected(.reduce)) }
            SalusInfoNote(text: SmokingStrings.setupPrivacy, systemImage: "lock", tone: .neutral)
        }
    }
}

// MARK: - 2 — product

struct ProductStep: View {
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.md) {
            StepHeader(
                systemImage: "smoke",
                title: SmokingStrings.setupProductTitle,
                subtitle: SmokingStrings.setupProductSubtitle
            )
            // Two tiles a row, as Android lays them out.
            ForEach(Array(ProductType.allCases.chunked(into: 2).enumerated()), id: \.offset) { _, pair in
                HStack(alignment: .top, spacing: SalusSpacing.md) {
                    ForEach(pair, id: \.rawValue) { product in
                        SalusChoiceTile(
                            label: product.label,
                            systemImage: product.systemImage,
                            isSelected: state.product == product,
                            subtitle: product.caption,
                            accent: theme.extendedColors.smoking
                        ) { onEvent(.productSelected(product)) }
                    }
                }
            }
            SalusInfoNote(text: SmokingStrings.setupProductHelper, systemImage: "info.circle", tone: .neutral)
        }
    }
}

extension ProductType {
    fileprivate var systemImage: String {
        switch self {
        case .cigarette: "smoke"
        case .rolled: "leaf"
        case .heated: "flame"
        case .vape: "cloud"
        }
    }

    fileprivate var label: String {
        switch self {
        case .cigarette: SmokingStrings.setupProductCigarette
        case .rolled: SmokingStrings.setupProductRolled
        case .heated: SmokingStrings.setupProductHeated
        case .vape: SmokingStrings.setupProductVape
        }
    }

    fileprivate var caption: String {
        switch self {
        case .cigarette: SmokingStrings.setupProductCigaretteDesc
        case .rolled: SmokingStrings.setupProductRolledDesc
        case .heated: SmokingStrings.setupProductHeatedDesc
        case .vape: SmokingStrings.setupProductVapeDesc
        }
    }
}

extension Array {
    fileprivate func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0 ..< Swift.min($0 + size, count)]) }
    }
}

// MARK: - 3 — amount

struct AmountStep: View {
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void

    var body: some View {
        VStack(spacing: SalusSpacing.md) {
            StepHeader(
                systemImage: "smoke",
                title: SmokingStrings.setupAmountTitle,
                subtitle: state.isVape ? SmokingStrings.setupAmountSubtitleVape : SmokingStrings.setupAmountSubtitle
            )
            if state.isVape {
                VapeAmount(state: state, onEvent: onEvent)
            } else {
                PackAmount(state: state, onEvent: onEvent)
            }
            if let summary = state.summary {
                SummaryCard(summary: summary, state: state)
            }
        }
    }
}

private struct PackAmount: View {
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void

    var body: some View {
        let rolled = state.product == .rolled
        SalusCard {
            SetupIntStepper(
                label: SmokingStrings.setupUnitsPerDay,
                value: state.unitsPerDay,
                unit: SmokingStrings.setupUnitsPerDayUnit
            ) { onEvent(.unitsPerDayChanged($0)) }
        }
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                PriceField(
                    label: rolled ? SmokingStrings.setupPouchPrice : SmokingStrings.setupPackPrice,
                    state: state,
                    onEvent: onEvent
                )
                CurrencyChoice(state: state, onEvent: onEvent)
            }
        }
        SalusCard {
            SetupIntStepper(
                label: rolled ? SmokingStrings.setupUnitsPerPouch : SmokingStrings.setupUnitsPerPack,
                value: state.unitsPerPack,
                unit: SmokingStrings.setupUnitsPerPackUnit
            ) { onEvent(.unitsPerPackChanged($0)) }
        }
    }
}

private struct VapeAmount: View {
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: SalusSpacing.sm) {
            SalusStatusChip(label: SmokingStrings.setupVapeSelected, status: .neutral, dot: true)
            // Draws `primary` by inheritance (the shell tints the whole tab view), as Android's
            // `TextButton` does; amber text on a light surface would be a contrast risk.
            Button(SmokingStrings.setupChangeProduct) { onEvent(.changeProductClicked) }
            Spacer(minLength: 0)
        }
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                PriceField(label: SmokingStrings.setupWeeklySpend, state: state, onEvent: onEvent)
                QuickAddChips(symbol: currencySymbol(of: state.currencyCode, locale: locale), onEvent: onEvent)
                CurrencyChoice(state: state, onEvent: onEvent)
            }
        }
    }
}

private struct PriceField: View {
    let label: String
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        SalusTextField(
            text: Binding(get: { state.priceText }, set: { onEvent(.priceChanged($0)) }),
            label: label,
            // A digit, not copy: it is the empty field's ghost value.
            placeholder: "0",
            suffix: currencySymbol(of: state.currencyCode, locale: locale),
            keyboard: .decimal
        )
    }
}

private struct QuickAddChips: View {
    let symbol: String
    let onEvent: (SmokingSetupEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ChipFlowLayout(spacing: SalusSpacing.sm) {
            Text(verbatim: SmokingStrings.setupQuickAddLabel)
                .font(SalusTypography.bodySmall.font)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            ForEach(SetupDefaults.quickAddAmounts, id: \.self) { amount in
                SalusChoiceChip(
                    label: SmokingStrings.setupQuickAdd(symbol, amount),
                    isSelected: false
                ) { onEvent(.priceQuickAdded(wholeUnits: amount)) }
            }
        }
    }
}

private struct CurrencyChoice: View {
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            Text(verbatim: SmokingStrings.setupCurrency)
                .font(SalusTypography.labelSmall.font)
                .tracking(SalusTypography.labelSmall.tracking)
                .foregroundStyle(theme.extendedColors.overline)
            ChipFlowLayout(spacing: SalusSpacing.sm) {
                ForEach(currencyChoices(selected: state.currencyCode), id: \.self) { code in
                    SalusChoiceChip(label: code, isSelected: code == state.currencyCode) {
                        onEvent(.currencySelected(code))
                    }
                }
            }
        }
    }
}

/// The locale's own currency first when it is not one of the common ones, then the common ones.
func currencyChoices(selected: String) -> [String] {
    SetupDefaults.commonCurrencies.contains(selected)
        ? SetupDefaults.commonCurrencies
        : [selected] + SetupDefaults.commonCurrencies
}

private struct SummaryCard: View {
    let summary: SetupSummary
    let state: SmokingSetupUiState

    @Environment(\.locale) private var locale
    @Environment(\.salusTheme) private var theme

    private func money(_ minor: Int64) -> String {
        formatMoney(minor: minor, currencyCode: state.currencyCode, locale: locale, showFraction: false)
    }

    private var headline: String {
        switch summary {
        case let .daily(daily, yearly):
            SmokingStrings.setupSummaryDaily(money(daily), money(yearly))
        case let .weekly(weekly, yearly):
            SmokingStrings.setupSummaryWeekly(money(weekly), money(yearly))
        }
    }

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                Text(verbatim: headline)
                    .font(SalusTypography.titleMedium.font)
                    .tracking(SalusTypography.titleMedium.tracking)
                    .foregroundStyle(theme.extendedColors.smoking.accent)
                Text(verbatim: state.mode == .quit ? SmokingStrings.setupSummaryQuit : SmokingStrings
                    .setupSummaryReduce)
                    .font(SalusTypography.bodySmall.font)
                    .tracking(SalusTypography.bodySmall.tracking)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 4 — quit date and reason, or the daily limit

struct DetailsStep: View {
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void
    let clock: any SalusClock

    var body: some View {
        if state.mode == .quit {
            QuitDetails(state: state, onEvent: onEvent, clock: clock)
        } else {
            ReduceDetails(state: state, onEvent: onEvent)
        }
    }
}

private struct QuitDetails: View {
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void
    let clock: any SalusClock

    @State private var showSheet = false
    @Environment(\.locale) private var locale
    @Environment(\.salusTheme) private var theme

    private var shown: String {
        let zone = TimeZone(identifier: state.zoneId) ?? clock.timeZone()
        if localEpochDay(of: state.quitAtMs, in: zone) == state.todayEpochDay {
            return SmokingStrings.setupQuitToday(formatClockTime(epochMs: state.quitAtMs, zone: zone, locale: locale))
        }
        return formatDateTime(epochMs: state.quitAtMs, zone: zone, locale: locale)
    }

    var body: some View {
        VStack(spacing: SalusSpacing.md) {
            StepHeader(
                systemImage: "timer",
                title: SmokingStrings.setupQuitTitle,
                subtitle: SmokingStrings.setupQuitSubtitle
            )
            SalusCard {
                VStack(alignment: .leading, spacing: SalusSpacing.sm) {
                    HStack {
                        Text(verbatim: SmokingStrings.setupQuitWhen)
                            .font(SalusTypography.labelSmall.font)
                            .tracking(SalusTypography.labelSmall.tracking)
                            .foregroundStyle(theme.extendedColors.overline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        SalusChoiceChip(label: SmokingStrings.setupQuitNow, isSelected: !state.quitAtEdited) {
                            onEvent(.quitNowClicked)
                        }
                    }
                    SalusListItem(
                        title: shown,
                        subtitle: SmokingStrings.setupQuitEdit,
                        systemImage: "clock",
                        accent: theme.extendedColors.smoking,
                        onTap: { showSheet = true }
                    )
                }
            }
            SalusTextField(
                text: Binding(get: { state.reason }, set: { onEvent(.reasonChanged($0)) }),
                label: SmokingStrings.setupReasonLabel,
                placeholder: SmokingStrings.setupReasonPlaceholder,
                supportingText: SmokingStrings.setupReasonHint,
                isSingleLine: false,
                capitalization: .sentences
            )
        }
        .quitDateSheet(isPresented: $showSheet, initialMs: state.quitAtMs, clock: clock) { ms in
            onEvent(.quitAtChanged(ms))
        }
    }
}

private struct ReduceDetails: View {
    let state: SmokingSetupUiState
    let onEvent: (SmokingSetupEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.md) {
            StepHeader(
                systemImage: "chart.line.downtrend.xyaxis",
                title: SmokingStrings.setupReduceTitle,
                subtitle: SmokingStrings.setupReduceSubtitle
            )
            SalusCard {
                VStack(spacing: SalusSpacing.md) {
                    SetupIntStepper(
                        label: SmokingStrings.setupDailyLimit,
                        value: state.dailyLimit,
                        unit: SmokingStrings.setupDailyLimitUnit,
                        // Until the person picks one, the number is the suggestion and says so.
                        isSuggestion: state.dailyLimitOverride == nil
                    ) { onEvent(.dailyLimitChanged($0)) }
                    // A vape counts sessions with a baseline of one, so "currently n" would say nothing.
                    if !state.isVape {
                        Text(verbatim: SmokingStrings.setupLimitSuggestion(state.unitsPerDay))
                            .font(SalusTypography.bodySmall.font)
                            .tracking(SalusTypography.bodySmall.tracking)
                            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Whole-number stepper

/// A stepper over a whole number in `1…SetupDefaults.maxUnits`. The iOS field owns no range, so
/// every report it makes is clamped here and answered — the caller contract that comes with it.
/// Internal since the slip sheet counts cigarettes over the same range (Android's slip sheet uses
/// the same `1..200` as the setup).
struct SetupIntStepper: View {
    let label: String
    let value: Int
    let unit: String
    var isSuggestion = false
    let onChange: (Int) -> Void

    private var bounds: ClosedRange<Int> {
        1 ... SetupDefaults.maxUnits
    }

    var body: some View {
        SalusStepperField(
            label: label,
            value: String(value),
            placeholder: isSuggestion,
            rangeHint: unit,
            keyboard: .decimal,
            parse: { Int($0.trimmingCharacters(in: .whitespaces)) != nil },
            onValueChange: { typed in
                guard let number = Int(typed.trimmingCharacters(in: .whitespaces)) else { return }
                onChange(min(bounds.upperBound, max(bounds.lowerBound, number)))
            },
            onDecrement: { onChange(max(bounds.lowerBound, value - 1)) },
            onIncrement: { onChange(min(bounds.upperBound, value + 1)) }
        )
    }
}

extension SetupDefaults {
    static let commonCurrencies = ["TRY", "EUR", "USD", "GBP", "CHF"]
    static let quickAddAmounts = [50, 100]
}

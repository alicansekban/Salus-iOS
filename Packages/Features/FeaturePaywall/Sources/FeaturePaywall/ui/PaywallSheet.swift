// Ported 1:1 from `feature/paywall/src/main/kotlin/com/alicansekban/salus/feature/paywall/
// ui/PaywallSheet.kt` (482 lines).
//
// The paywall is a full-screen sheet rather than a destination, which is why it applies its own
// safe-area padding — it is drawn above the shell's tab bar, outside its insets. The Android
// `Surface` becomes a `Color` background; the `IconButton` becomes a plain `Button` over an SF
// Symbol; the `RadioButton` selection is a hand-drawn ring, the same shape `SalusOptionRow` uses.
//
// `onPurchase` is separate from `onEvent` because only the composition can reach the window the
// store sheet attaches to; this file never learns what a purchase host is. `onOpenUrl` is separate
// for the same reason: opening a policy page is an app launch.

import SalusDesignSystem
import SalusPremium
import SalusUI
import SwiftUI

/// The order plans are sold in: the one we want bought sits on top.
private let planDisplayOrder: [PlanPeriod] = [.annual, .sixMonth, .monthly]

// swiftlint:disable identifier_name
/// What the subscription actually buys, in the order it is sold.
///
/// `internal` (the default access level) so `PaywallFeatureListTests` can read the shipped list
/// rather than a copy of it: every row here is a promise made before payment, so it may only name
/// a feature that exists. The SF Symbols are the iOS twins of Android's `Icons.Outlined` catalogue
/// — `AutoAwesome`, `Description`, `Insights`, `Palette`.
///
/// The name is `FeatureRows` (capitalised) because the test reads the declaration by name, exactly
/// as Android's `PaywallFeatureListTest` reads `internal val FeatureRows` out of the Kotlin source.
let FeatureRows: [(icon: String, labelKey: String)] = [
    ("sparkles", "paywall_feature_ai_summary"),
    ("doc.text", "paywall_feature_doctor_report"),
    ("chart.xyaxis.line", "paywall_feature_trends"),
    ("paintpalette", "paywall_feature_themes")
]
// swiftlint:enable identifier_name

/// The paywall itself: stateless, so every decision it makes is visible in `state`.
struct PaywallSheet: View {
    let state: PaywallUiState
    let onEvent: (PaywallEvent) -> Void
    let onPurchase: () -> Void
    let onOpenUrl: (String) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ZStack {
            theme.colorScheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                closeButton
                if state.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    if state.plans.isEmpty {
                        // Nothing to sell is not a dead end: the body says so, and the actions
                        // below still offer a retry and a restore — someone reinstalling on a
                        // flaky connection has to be able to get their subscription back.
                        Spacer()
                        Text(verbatim: PaywallStrings.errorOffering)
                            .font(SalusTypography.bodyLarge.font)
                            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SalusSpacing.xl)
                        Spacer()
                    } else {
                        PaywallContent(state: state, onEvent: onEvent)
                    }
                    PaywallActions(
                        state: state,
                        onEvent: onEvent,
                        onPurchase: onPurchase,
                        onOpenUrl: onOpenUrl
                    )
                }
            }
            .padding(.top, SalusSpacing.sm)
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                onEvent(.dismissClicked)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(theme.colorScheme.onSurface)
                    .frame(width: SalusTouchTarget.min, height: SalusTouchTarget.min)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PaywallStrings.close)
        }
        .padding(.horizontal, SalusSpacing.sm)
    }
}

/// Everything that scrolls: the pitch, the feature list and the plan cards.
private struct PaywallContent: View {
    let state: PaywallUiState
    let onEvent: (PaywallEvent) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Named after the wall the user hit, so the sheet answers the tap that opened it.
                Text(verbatim: PaywallStrings.resolve(headlineKey(for: state.source)))
                    .font(SalusTypography.headlineMedium.font)
                    .foregroundStyle(theme.colorScheme.onSurface)
                Spacer().frame(height: SalusSpacing.sm)
                Text(verbatim: PaywallStrings.subtitle)
                    .font(SalusTypography.bodyMedium.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)

                Spacer().frame(height: SalusSpacing.xl)
                ForEach(FeatureRows, id: \.labelKey) { row in
                    FeatureRow(icon: row.icon, label: PaywallStrings.resolve(row.labelKey))
                }

                Spacer().frame(height: SalusSpacing.xl)
                // Store order is the store's business; the sheet always sells annual first.
                let ordered = state.plans.sorted { lhs, rhs in
                    planDisplayOrder.firstIndex(of: lhs.period) ?? .max
                        < planDisplayOrder.firstIndex(of: rhs.period) ?? .max
                }
                ForEach(ordered, id: \.packageId) { plan in
                    PlanCard(
                        plan: plan,
                        selected: plan.packageId == state.selectedPackageId,
                        onClick: { onEvent(.planSelected(plan.packageId)) }
                    )
                    Spacer().frame(height: SalusSpacing.md)
                }
            }
            .padding(.horizontal, SalusSpacing.xl)
        }
    }
}

/// The pinned bottom block: the failure line, the CTA, restore, the renewal note and the
/// policy links.
private struct PaywallActions: View {
    let state: PaywallUiState
    let onEvent: (PaywallEvent) -> Void
    let onPurchase: () -> Void
    let onOpenUrl: (String) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let selected = state.plans.first { $0.packageId == state.selectedPackageId }
        VStack(spacing: 0) {
            // OFFERING_UNAVAILABLE is already spelled out in the body above; only the failures
            // that leave the sheet usable get a line here.
            let errorText: String? = switch state.error {
            case .purchaseFailed: PaywallStrings.errorPurchase
            case .restoreNoEntitlement: PaywallStrings.errorRestore
            case nil, .offeringUnavailable: nil
            }
            if let errorText {
                Text(verbatim: errorText)
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.error)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: SalusSpacing.sm)
            }

            // The store sheet and the restore call are both "busy": one signal disables every
            // button here, so nothing can be fired twice.
            if state.plans.isEmpty {
                SalusPillButton(
                    text: PaywallStrings.retry,
                    enabled: !state.isPurchasing,
                    tonal: true,
                    fillsWidth: true,
                    action: { onEvent(.reload) }
                )
            } else {
                SalusPillButton(
                    text: selected?.hasFreeTrial == true
                        ? PaywallStrings.ctaTrial
                        : PaywallStrings.ctaSubscribe,
                    enabled: !state.isPurchasing,
                    fillsWidth: true,
                    action: onPurchase
                )
            }

            Button {
                onEvent(.restoreClicked)
            } label: {
                Text(verbatim: PaywallStrings.restore)
                    .font(SalusTypography.labelLarge.font)
                    .foregroundStyle(theme.colorScheme.primary)
                    .frame(minHeight: SalusTouchTarget.min)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(state.isPurchasing)

            if !state.plans.isEmpty {
                Text(verbatim: PaywallStrings.renewalNote)
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            PolicyLinks(onOpenUrl: onOpenUrl)
        }
        .padding(.horizontal, SalusSpacing.xl)
        .padding(.vertical, SalusSpacing.md)
    }
}

/// The subscription terms and privacy policy links Play requires next to a subscription offer.
///
/// The addresses are string resources rather than constants so they can be published (and
/// localized) without touching Kotlin. Until one is filled in there is nothing to open, and a
/// link to nowhere is worse than no link — so a blank address hides its own row.
private struct PolicyLinks: View {
    let onOpenUrl: (String) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let termsUrl = PaywallStrings.termsURL
        let privacyUrl = PaywallStrings.privacyURL
        let showTerms = !Self.isBlank(termsUrl)
        let showPrivacy = !Self.isBlank(privacyUrl)
        if showTerms || showPrivacy {
            HStack(spacing: SalusSpacing.lg) {
                if showTerms {
                    PolicyLink(label: PaywallStrings.terms) { onOpenUrl(termsUrl) }
                }
                if showPrivacy {
                    PolicyLink(label: PaywallStrings.privacy) { onOpenUrl(privacyUrl) }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Kotlin's `isBlank()` — "empty, or every character is whitespace".
    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct PolicyLink: View {
    let label: String
    let action: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(verbatim: label)
                .font(SalusTypography.bodySmall.font)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .frame(minHeight: SalusTouchTarget.min)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct FeatureRow: View {
    let icon: String
    let label: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        HStack(spacing: SalusSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: Self.iconSize))
                .foregroundStyle(theme.colorScheme.primary)
                .frame(width: Self.iconSize, height: Self.iconSize)
                // `contentDescription = null` (`PaywallSheet.kt:337`): the label beside it already
                // says what the feature is.
                .accessibilityHidden(true)
            Text(verbatim: label)
                .font(SalusTypography.bodyLarge.font)
                .foregroundStyle(theme.colorScheme.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SalusSpacing.sm)
    }

    /// `private val FeatureIconSize = 22.dp` (`PaywallSheet.kt:439`).
    private static let iconSize: CGFloat = 22
}

private struct PlanCard: View {
    let plan: PremiumPlan
    let selected: Bool
    let onClick: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let colors = theme.colorScheme
        Button(action: onClick) {
            HStack(spacing: SalusSpacing.md) {
                // The card is the click target; the ring only mirrors the selection.
                radioIndicator
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: SalusSpacing.sm) {
                        Text(verbatim: planName)
                            .font(SalusTypography.titleMedium.font)
                            .foregroundStyle(colors.onSurface)
                        if plan.period == .annual {
                            BestValueBadge()
                        }
                    }
                    if let monthlyEquivalent = plan.monthlyEquivalent {
                        Text(verbatim: PaywallStrings.monthlyEquivalent(monthlyEquivalent))
                            .font(SalusTypography.bodySmall.font)
                            .foregroundStyle(
                                selected ? colors.onPrimaryContainer : colors.onSurfaceVariant
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: plan.priceFormatted)
                    .font(SalusTypography.titleMedium.font)
                    .foregroundStyle(colors.onSurface)
            }
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.md)
            .frame(maxWidth: .infinity, minHeight: SalusTouchTarget.min)
            .background(
                SalusShapes.largeShape.fill(
                    selected ? colors.primaryContainer : colors.surfaceContainerLow
                )
            )
            .overlay {
                SalusShapes.largeShape.stroke(
                    selected ? colors.primary : colors.outlineVariant,
                    lineWidth: selected ? Self.selectedBorderWidth : Self.unselectedBorderWidth
                )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // `Modifier.selectable(role = Role.RadioButton)` (`PaywallSheet.kt:369`): a plan is a
        // radio choice, and only this reports "selected" to a screen reader.
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var planName: String {
        switch plan.period {
        case .monthly: PaywallStrings.planMonthly
        case .sixMonth: PaywallStrings.planSixMonth
        case .annual: PaywallStrings.planAnnual
        }
    }

    /// The radio mark, drawn rather than composed so it stays purely visual — the same shape
    /// `SalusOptionRow`'s indicator uses.
    private var radioIndicator: some View {
        let colors = theme.colorScheme
        return SalusShapes.pill
            .stroke(selected ? colors.primary : colors.outlineVariant, lineWidth: Self.indicatorBorder)
            .frame(width: Self.indicatorSize, height: Self.indicatorSize)
            .overlay {
                if selected {
                    SalusShapes.pill
                        .fill(colors.primary)
                        .frame(width: Self.indicatorDotSize, height: Self.indicatorDotSize)
                }
            }
            .accessibilityHidden(true)
    }

    /// `SelectedBorderWidth = 2.dp` / `UnselectedBorderWidth = 1.dp` (`PaywallSheet.kt:440-441`).
    private static let selectedBorderWidth: CGFloat = 2
    private static let unselectedBorderWidth: CGFloat = 1
    /// The radio ring, matching `SalusOptionRow`'s indicator dimensions.
    private static let indicatorSize: CGFloat = 24
    private static let indicatorBorder: CGFloat = 2
    private static let indicatorDotSize: CGFloat = 12
}

private struct BestValueBadge: View {
    @Environment(\.salusTheme) private var theme

    var body: some View {
        Text(verbatim: PaywallStrings.badgeBestValue)
            .font(SalusTypography.labelSmall.font)
            .foregroundStyle(theme.colorScheme.onPrimary)
            .padding(.horizontal, SalusSpacing.sm)
            .padding(.vertical, SalusSpacing.xs)
            .background(SalusShapes.pill.fill(theme.colorScheme.primary))
    }
}

// MARK: - Previews

/// The three plans the Android preview hardcodes (`PaywallSheet.kt:443-447`).
private func previewPlans() -> [PremiumPlan] {
    [
        PremiumPlan(
            packageId: "annual",
            period: .annual,
            priceFormatted: "₺499,99",
            monthlyEquivalent: "₺41,67",
            hasFreeTrial: true
        ),
        PremiumPlan(
            packageId: "six_month",
            period: .sixMonth,
            priceFormatted: "₺299,99",
            monthlyEquivalent: "₺50,00",
            hasFreeTrial: false
        ),
        PremiumPlan(
            packageId: "monthly",
            period: .monthly,
            priceFormatted: "₺59,99",
            monthlyEquivalent: nil,
            hasFreeTrial: false
        )
    ]
}

#Preview("Paywall sheet") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    var state = PaywallUiState()
    state.isLoading = false
    state.plans = previewPlans()
    state.selectedPackageId = "annual"
    state.source = .themes
    return PaywallSheet(
        state: state,
        onEvent: { _ in },
        onPurchase: {},
        onOpenUrl: { _ in }
    )
    .salusTheme(theme)
}

#Preview("Paywall sheet, offering unavailable") {
    let theme = SalusTheme.resolve(systemIsDark: false)
    var state = PaywallUiState()
    state.isLoading = false
    state.error = .offeringUnavailable
    return PaywallSheet(
        state: state,
        onEvent: { _ in },
        onPurchase: {},
        onOpenUrl: { _ in }
    )
    .salusTheme(theme)
}

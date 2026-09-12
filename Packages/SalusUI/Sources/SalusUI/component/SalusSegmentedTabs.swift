// Ported from `core/ui/src/main/kotlin/com/alicansekban/salus/core/ui/component/
// SalusSegmentedTabs.kt:72-216`.
//
// **Recorded divergence (b), spec §9**, and it reverses the earlier M14 ruling: this is a custom
// SwiftUI control, not `Picker(.segmented)`. The native segmented control paints itself from
// `UISegmentedControl`'s appearance proxy, which is process-wide; the M15 selection is a
// **per-palette** `primaryContainer` pill, so four palettes × two modes cannot be expressed
// through it, and a pill that cannot follow the theme is not the M15 control.
//
// Kotlin measures the track and offsets one `Box` by `(segmentWidth + gap) * indicatorIndex`
// (`SalusSegmentedTabs.kt:92-146`). SwiftUI has that measurement for free:
// `matchedGeometryEffect` in a shared `@Namespace` interpolates one pill's frame between the
// segment it left and the segment it arrived at, so the port needs no `onSizeChanged` and no
// density arithmetic. The curve is the same one — `SalusMotion.segmentedSlideDurationSeconds`
// (§1.5), which is Android's `tween(Normal, FastOutSlowInEasing)`.
//
// No haptics and no ripple (`SalusSegmentedTabs.kt:186-187`): the sliding pill is the whole
// feedback for a tap here.

import SalusDesignSystem
import SwiftUI

/// Pill segment control over `options`. The selection is a single `primaryContainer` pill drawn
/// behind the labels that **slides** from the old segment to the new one. Fading a separate fill
/// in on each segment made the selection appear where it was tapped instead of moving there, which
/// reads as a teleport and hides which segment it came from (`SalusSegmentedTabs.kt:52-57`).
///
/// `enabled` false is a real disabled state rather than a control that quietly ignores touches:
/// the segments stop being selectable and everything is drawn at
/// ``SalusSegmentedTabsDefaults/disabledAlpha``, while the control stays in the accessibility tree
/// so VoiceOver announces it as unavailable instead of reading tabs that answer nothing
/// (`SalusSegmentedTabs.kt:65-70`).
public struct SalusSegmentedTabs<T: Hashable>: View {
    private let options: [T]
    private let selected: T
    private let enabled: Bool
    private let label: (T) -> String
    private let onSelected: (T) -> Void

    @Environment(\.salusTheme) private var theme
    @Namespace private var pill

    /// - Parameter label: resolves an option's text. Kotlin's is `@Composable` so a caller can
    ///   read a `stringResource`; the tabs themselves never know what an option means
    ///   (`SalusSegmentedTabs.kt:62-63`).
    public init(
        options: [T],
        selected: T,
        enabled: Bool = true,
        label: @escaping (T) -> String,
        onSelected: @escaping (T) -> Void
    ) {
        self.options = options
        self.selected = selected
        self.enabled = enabled
        self.label = label
        self.onSelected = onSelected
    }

    /// Which segment the pill parks on, or `nil` for no pill at all.
    ///
    /// `options.indexOf(selected)` guarded by `selectedIndex >= 0`
    /// (`SalusSegmentedTabs.kt:81`, `:106`). A caller can hand us a `selected` that is not in
    /// `options` — a filter cleared, a list swapped a frame before the selection follows — and
    /// then **nothing** is drawn, rather than a pill parked on the first segment claiming a
    /// selection that is not there (`SalusSegmentedTabs.kt:103-105`). Pure, so the rule is
    /// table-testable without rendering the control.
    static func indicatorIndex(options: [T], selected: T) -> Int? {
        options.firstIndex(of: selected)
    }

    public var body: some View {
        let indicator = Self.indicatorIndex(options: options, selected: selected)
        // `Arrangement.spacedBy(TrackPadding)` inside a track padded by the same
        // (`SalusSegmentedTabs.kt:115`, `:150`).
        HStack(spacing: SalusSegmentedTabsDefaults.trackPadding) {
            ForEach(Array(options.enumerated()), id: \.offset) { offset, option in
                segment(option, isSelected: offset == indicator)
            }
        }
        .padding(SalusSegmentedTabsDefaults.trackPadding)
        .background(SalusShapes.pill.fill(theme.colorScheme.surfaceContainerHigh))
        // `alpha(if (enabled) 1f else DisabledAlpha)` on the pill and the segments
        // (`SalusSegmentedTabs.kt:143`, `:184`) — one layer here, same result.
        .opacity(enabled ? 1 : SalusSegmentedTabsDefaults.disabledAlpha)
        .disabled(!enabled)
        // The twin of `Modifier.semantics { disabled() }` (`SalusSegmentedTabs.kt:121`): the
        // control is *unavailable*, never absent. Said out loud because `.disabled(true)` and
        // "hidden from VoiceOver" are one keystroke apart and only one of them is the contract.
        .accessibilityHidden(false)
        .animation(
            .easeInOut(duration: SalusMotion.segmentedSlideDurationSeconds),
            value: indicator
        )
    }

    /// `RowScope.Segment` (`SalusSegmentedTabs.kt:164-205`).
    private func segment(_ option: T, isSelected: Bool) -> some View {
        Button {
            onSelected(option)
        } label: {
            // `Text(verbatim:)` because `label` returns a resolved string.
            Text(verbatim: label(option))
                .font(SalusTypography.labelLarge.font)
                .tracking(SalusTypography.labelLarge.tracking)
                .lineLimit(1)
                .foregroundStyle(isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)
                .padding(.horizontal, SalusSpacing.sm)
                .padding(.vertical, SalusSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: SalusSegmentedTabsDefaults.segmentHeight)
                .background {
                    if isSelected {
                        // One pill for the whole control: the `matchedGeometryEffect` id is
                        // shared, so SwiftUI interpolates its frame from the segment it left.
                        SalusShapes.pill
                            .fill(theme.colorScheme.primaryContainer)
                            .matchedGeometryEffect(id: Self.pillID, in: pill)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // `Role.Tab` with `selected` (`SalusSegmentedTabs.kt:189-191`).
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The one geometry identity the sliding pill travels under.
    private static var pillID: String { "salusSegmentedTabsIndicator" }
}

/// `object SalusSegmentedTabsDefaults` (`SalusSegmentedTabs.kt:207-216`). Component dimensions,
/// not design tokens — Android keeps them in `:core:ui` too.
public enum SalusSegmentedTabsDefaults {
    /// Inset of the segments inside the track, and the gap between them
    /// (`SalusSegmentedTabs.kt:209`).
    public static let trackPadding: CGFloat = SalusSpacing.xs
    /// Segment height; the whole control stays above the minimum touch target
    /// (`SalusSegmentedTabs.kt:212`).
    public static let segmentHeight: CGFloat = SalusTouchTarget.min
    /// Material's disabled-content opacity, applied when `enabled` is false
    /// (`SalusSegmentedTabs.kt:215`).
    public static let disabledAlpha = 0.38
}

#Preview("Segmented tabs") {
    @Previewable @State var selected = "Month"

    SalusPreviewPalettes {
        VStack(spacing: SalusSpacing.md) {
            SalusSegmentedTabs(
                options: ["Week", "Month", "Year"],
                selected: selected,
                label: { $0 },
                onSelected: { selected = $0 }
            )
            // Disabled — the locked Trends screen, visible but inert.
            SalusSegmentedTabs(
                options: ["Week", "Month", "Year"],
                selected: "Week",
                enabled: false,
                label: { $0 },
                onSelected: { _ in }
            )
            // A selection the options do not carry: no pill at all.
            SalusSegmentedTabs(
                options: ["Week", "Month", "Year"],
                selected: "Decade",
                label: { $0 },
                onSelected: { _ in }
            )
        }
    }
}

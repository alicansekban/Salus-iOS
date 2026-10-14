// Ported from `feature/smoking/src/main/kotlin/com/alicansekban/salus/feature/smoking/ui/timeline/
// StageDetailSheet.kt`.
//
// One stage in full: its ring, its sentence, where the sentence comes from and the fixed
// disclaimer. Nothing else: no bullets, no share (review R4).
//
// Compose → SwiftUI:
//   `SalusBottomSheet(onDismiss:, title:)` → `.salusBottomSheet(isPresented:)`, applied by the
//                           `stageDetailSheet(…)` modifier below; ``StageDetailContent`` is the
//                           sheet's body, so a preview can draw it.
//   `FlowRow`                              → `ChipFlowLayout`.
//   `clearAndSetSemantics { contentDescription }` → `.accessibilityElement(children: .ignore)` +
//                           a label.

import SalusDesignSystem
import SalusSmoking
import SalusUI
import SwiftUI

/// The body of the stage sheet (`StageDetailSheet.kt`'s `StageDetailContent`).
struct StageDetailContent: View {
    let row: StageRow

    @Environment(\.salusTheme) private var theme

    var body: some View {
        let accent = theme.extendedColors.smoking
        let percent = SmokingStrings.stageCardPercent(row.permille / TimelineDefaults.permillePerPercent)
        let spoken = "\(row.state.label), \(percent)"

        VStack(spacing: SalusSpacing.md) {
            SalusProgressRing(
                progress: row.progress,
                label: percent,
                accent: accent.accent
            )
            // The ring is a figure of elapsed time; spoken once with its state, not as a bare number.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: spoken))
            if row.state == .inProgress {
                Text(verbatim: StageRemaining(remainingMs: row.remainingMs).text)
                    .font(SalusTypography.labelLarge.font)
                    .tracking(SalusTypography.labelLarge.tracking)
                    .foregroundStyle(accent.accent)
            }
            if let statement = StageCopy.statement(of: row.stageId) {
                Text(verbatim: statement)
                    .font(SalusTypography.bodyLarge.font)
                    .tracking(SalusTypography.bodyLarge.tracking)
                    .foregroundStyle(theme.colorScheme.onSurface)
                    .multilineTextAlignment(.center)
            }
            StageNotes(row: row, centered: true)
            Text(verbatim: StageCopy.attribution(of: row.source))
                .font(SalusTypography.bodySmall.font)
                .tracking(SalusTypography.bodySmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
            SalusDisclaimer(SmokingStrings.timelineDisclaimer)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.bottom, SalusSpacing.xl)
    }
}

/// The small labels a stage can carry: counting again after a slip, and the product note. Two
/// short chips at most; they share a line when they fit and stack on a narrow screen.
struct StageNotes: View {
    let row: StageRow
    var centered = false

    var body: some View {
        if row.countingAgain || row.combustionNote {
            ChipFlowLayout(spacing: SalusSpacing.xs) {
                if row.countingAgain {
                    SalusStatusChip(
                        label: SmokingStrings.timelineCountingAgain,
                        status: .neutral,
                        systemImage: TimelineSymbols.countingAgain
                    )
                }
                if row.combustionNote {
                    SalusStatusChip(label: SmokingStrings.timelineCombustionOnly, status: .neutral)
                }
            }
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        }
    }
}

extension StageRow {
    /// The ring's and the bar's fill, 0...1.
    var progress: Float {
        Float(permille) / TimelineDefaults.permille
    }
}

extension StageState {
    /// The state as a person says it: the row's spoken state, never a bare glyph.
    var label: String {
        switch self {
        case .done: SmokingStrings.timelineStateDone
        case .inProgress: SmokingStrings.timelineStateInProgress
        case .pending: SmokingStrings.timelineStatePending
        }
    }
}

enum TimelineSymbols {
    static let done = "checkmark"
    static let locked = "lock"
    static let countingAgain = "arrow.clockwise"
}

enum TimelineDefaults {
    static let permille: Float = 1000
    static let permillePerPercent = 10
    /// How far the highlighted card swells before it settles back; small enough to stay inside the
    /// gutter.
    static let pulseScale: CGFloat = 1.03
}

private struct StageDetailSheetModifier: ViewModifier {
    let row: StageRow?
    let onDismiss: () -> Void

    /// The row last shown. While the sheet slides away `row` is already `nil`; drawing the last
    /// content through the animation keeps it from emptying out first.
    @State private var shown: StageRow?

    func body(content: Content) -> some View {
        content
            .salusBottomSheet(
                isPresented: Binding(
                    get: { row != nil },
                    set: { presented in
                        if !presented {
                            onDismiss()
                        }
                    }
                ),
                title: StageCopy.title(of: (row ?? shown)?.stageId ?? "") ?? "",
                sizing: .fitted
            ) {
                if let current = row ?? shown {
                    StageDetailContent(row: current)
                }
            }
            .onChange(of: row, initial: true) { _, new in
                if let new {
                    shown = new
                }
            }
    }
}

extension View {
    /// Presents the stage sheet while `row` is non-nil; every dismissal route (close button, swipe,
    /// scrim) reports `onDismiss`.
    func stageDetailSheet(row: StageRow?, onDismiss: @escaping () -> Void) -> some View {
        modifier(StageDetailSheetModifier(row: row, onDismiss: onDismiss))
    }
}

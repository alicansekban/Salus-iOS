// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/list/MedicationsScreen.kt:184-235` — `MedicationsHeader` and `MedicationsMetrics`.
//
// Its own file rather than two more members of `MedicationsScreen.swift`: the screen file stays the
// screen's shape, which is what `MedicationCard.swift` was split out for. Kotlin can keep all three
// in one file because a `private @Composable` is invisible outside it; Swift has no per-file privacy
// for a `View` used from another file, so these are internal types. Nothing outside this package can
// name them — the package exports the Route and nothing else.
//
// **THE COUNT CHIP LEFT THE TOOLBAR HERE.** Until this task the medications count sat in a
// `ToolbarItem`, the place the retired `SalusScreenHeader` left it (iOS-M16 Task 5). M15 spends the
// count on the first of three metric tiles instead (`MedicationsScreen.kt:217-221`), so the toolbar
// item is gone and the root draws nothing of its own beside the shell's brand tile, bell and avatar.
//
// Material → SwiftUI:
//   `DateTimeFormatter.ofPattern("d MMMM", locale)` → `LocalDate.formatted(pattern:locale:)`, which
//                                                     renders through a fixed-GMT `DateFormatter`
//                                                     over six numbers — no `Calendar` (CLAUDE.md).
//   `Row(spacedBy(md)) { tile.weight(1f) × 3 }`      → `HStack(spacing: md)` with each tile framed
//                                                     `maxWidth: .infinity`.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// The date overline, the screen title and the three metric tiles
/// (`MedicationsScreen.kt:184-205`).
struct MedicationsHeader: View {
    let state: MedicationsUiState

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        // `Column(verticalArrangement = spacedBy(SalusSpacing.lg))` (`MedicationsScreen.kt:187`).
        VStack(alignment: .leading, spacing: SalusSpacing.lg) {
            // `Column { overline; Spacer(xs); headline }` (`MedicationsScreen.kt:188-202`).
            VStack(alignment: .leading, spacing: SalusSpacing.xs) {
                Text(verbatim: MedicationsStrings.overlineToday(date: headerDate))
                    .font(SalusTypography.labelSmall.font)
                    .tracking(SalusTypography.labelSmall.tracking)
                    .foregroundStyle(theme.extendedColors.overline)
                Text(verbatim: MedicationsStrings.titleRoutine)
                    .font(SalusTypography.headlineMedium.font)
                    .foregroundStyle(theme.colorScheme.onSurface)
            }
            MedicationsMetrics(state: state)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `LocalDate.ofEpochDay(state.todayEpochDay).format(ofPattern("d MMMM", locale))`
    /// (`MedicationsScreen.kt:186`, `:192`). The day comes from the view model's clock — a screen
    /// never asks the machine what day it is (`MedicationsUiState.kt:34-38`).
    private var headerDate: String {
        LocalDate(epochDay: state.todayEpochDay)
            .formatted(pattern: MedicationsHeaderDefaults.datePattern, locale: locale)
    }
}

/// Active count, recorded-dose share and the next dose (`MedicationsScreen.kt:208-235`).
struct MedicationsMetrics: View {
    let state: MedicationsUiState

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .top, spacing: SalusSpacing.md) {
            SalusMetricTile(
                overline: MedicationsStrings.metricActive,
                value: String(state.medications.count)
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            SalusMetricTile(
                overline: MedicationsStrings.metricRecorded,
                value: recorded.map(String.init) ?? MedicationsStrings.metricNone,
                unit: recorded.map { _ in "%" },
                progress: recorded.map { Double($0) / MedicationsHeaderDefaults.percentMax }
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            SalusMetricTile(
                overline: MedicationsStrings.metricNext,
                value: state.nextDoseMinuteOfDay
                    .map { formatTime(minuteOfDay: $0, locale: locale) }
                    ?? MedicationsStrings.metricNone
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `shares.average().toInt()` over the non-nil per-medication shares
    /// (`MedicationsScreen.kt:212-213`).
    ///
    /// The list-level share exists only while at least one medication has something recorded — the
    /// same "never 0 % for silence" rule the cards follow, because an absent record is not a dose
    /// somebody did not take.
    private var recorded: Int? {
        let shares = state.medications.compactMap(\.recordedDosePercent)
        guard !shares.isEmpty else { return nil }
        // Kotlin's `average()` is a `Double` and `toInt()` truncates toward zero; a share is never
        // negative, so `Int(_:)`'s truncation is the same number. It traps only on a NaN or an
        // infinite value, and the `guard` above makes the divisor at least 1, so neither is reachable.
        return Int(Double(shares.reduce(0, +)) / Double(shares.count))
    }
}

/// Layout values this header owns. Not design tokens — a pattern and a percentage base.
enum MedicationsHeaderDefaults {
    /// `DateTimeFormatter.ofPattern("d MMMM", locale)` (`MedicationsScreen.kt:186`).
    static let datePattern = "d MMMM"

    /// `MedicationsScreen.kt:350`.
    static let percentMax = 100.0
}

// Ported from `feature/medications/src/main/kotlin/com/alicansekban/salus/feature/medications/
// ui/detail/MedicationDetailSections.kt:224-342` — `MedicationHistoryCard`, `RhythmRow` and the two
// glyph/tint tables under them.
//
// Its own file rather than a fifth section in `MedicationDetailSections.swift`, for that file's
// reason: five sections in one file would run past the 500-line lint gate.
//
// Read-only: a row is a record, written from Home's dose list, this screen's "record now" or a
// notification action. There is no dose-editing affordance here on either platform.
//
// Material → SwiftUI:
//   `DateTimeFormatter.ofPattern("d MMM")`   → `LocalDate.formatted(pattern:locale:)`.
//   `DateTimeFormatter.ofPattern("EEEEE")`   → `SalusWeekdaySymbols.narrowMondayFirst(locale:)`
//                                              indexed by `LocalDate.mondayBasedWeekdayIndex`.
//                                              Foundation has no `DayOfWeek.getDisplayName`, and
//                                              that helper is the tree's one sanctioned reader of
//                                              localized weekday symbols (`CLAUDE.md`).
//   `Icons.Filled.Check / Close / Remove`    → `checkmark` / `xmark` / `minus`.
//   `Icons.Outlined.Circle`                  → `circle`.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// "Son 30 gün": the seven-day rhythm row over the recorded doses under it
/// (`MedicationDetailSections.kt:224-271`).
struct MedicationHistoryCard: View {
    let history: [IntakeHistoryItem]
    let todayEpochDay: Int

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        SalusCard {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                Text(verbatim: MedicationsStrings.detailHistory)
                    .font(SalusTypography.titleLarge.font)
                    .foregroundStyle(theme.colorScheme.onSurface)

                RhythmRow(history: history, todayEpochDay: todayEpochDay)

                if history.isEmpty {
                    Text(verbatim: MedicationsStrings.detailHistoryEmpty)
                        .font(SalusTypography.bodyMedium.font)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Position is the identity, not the value. Two schedules of one medication can
                    // share a minute — the editor seeds 08:00 and the add button re-adds that seed
                    // — so when both doses are recorded the two rows are *equal*
                    // `IntakeHistoryItem`s, and `id: \.self` would hand SwiftUI one id for two rows.
                    // The offset into the already-sorted list cannot collide.
                    ForEach(Array(history.enumerated()), id: \.offset) { indexed in
                        row(indexed.element)
                    }
                }
            }
        }
    }

    /// `MedicationDetailSections.kt:251-269`.
    private func row(_ item: IntakeHistoryItem) -> some View {
        HStack(alignment: .center, spacing: SalusSpacing.sm) {
            Text(verbatim: when(item))
                .font(SalusTypography.bodyMedium.font)
                .foregroundStyle(theme.colorScheme.onSurface)
                // `Modifier.weight(1f)` (`MedicationDetailSections.kt:260`).
                .frame(maxWidth: .infinity, alignment: .leading)
            SalusStatusChip(label: item.status.label, status: item.status.chipStatus, dot: true)
        }
        // The date, the time and the verdict are one fact; VoiceOver reads them as one row.
        .accessibilityElement(children: .combine)
    }

    /// `LocalDate.ofEpochDay(epochDay).format(ofPattern("d MMM", locale)) + " · " +
    /// formatTime(minuteOfDay, locale)` (`MedicationDetailSections.kt:256-258`).
    private func when(_ item: IntakeHistoryItem) -> String {
        let day = LocalDate(epochDay: item.epochDay)
            .formatted(pattern: MedicationHistoryCardDefaults.datePattern, locale: locale)
        return "\(day) · \(formatTime(minuteOfDay: item.minuteOfDay, locale: locale))"
    }
}

/// One glyph per day of the last week (`MedicationDetailSections.kt:273-327`).
///
/// A check for a dose that was taken, a cross for one that was missed, a dash for one that was
/// skipped and an empty ring for a day with no record at all — the shape says what happened without
/// the colour having to carry it alone.
struct RhythmRow: View {
    let history: [IntakeHistoryItem]
    let todayEpochDay: Int

    @Environment(\.salusTheme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: SalusSpacing.sm) {
            Text(verbatim: MedicationsStrings.detailRhythm)
                .font(SalusTypography.labelSmall.font)
                .tracking(SalusTypography.labelSmall.tracking)
                .foregroundStyle(theme.extendedColors.overline)

            // `Arrangement.SpaceBetween` (`MedicationDetailSections.kt:296`).
            HStack(alignment: .top, spacing: 0) {
                ForEach(days, id: \.self) { day in
                    dayColumn(day)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `MedicationDetailSections.kt:299-325`.
    private func dayColumn(_ day: Int) -> some View {
        let date = LocalDate(epochDay: day)
        // History is newest first, so the first match is the latest dose of that day.
        let status = history.first { $0.epochDay == day }?.status
        return VStack(spacing: SalusSpacing.xs) {
            Text(verbatim: weekdaySymbols[safe: date.mondayBasedWeekdayIndex] ?? "")
                .font(SalusTypography.labelSmall.font)
                .tracking(SalusTypography.labelSmall.tracking)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            Image(systemName: status.rhythmGlyph)
                .font(.system(size: SalusIconBadgeDefaults.small))
                .foregroundStyle(status.rhythmTint(in: theme))
        }
        // `clearAndSetSemantics { contentDescription = "$day: $statusLabel" }`
        // (`MedicationDetailSections.kt:306-308`): the letter and the glyph are one announcement.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(verbatim: "\(fullDate(date)): \(status?.label ?? MedicationsStrings.detailRhythmNone)")
        )
    }

    /// `(todayEpochDay - (RHYTHM_WINDOW_DAYS - 1))..todayEpochDay`
    /// (`MedicationDetailSections.kt:298-299`).
    private var days: [Int] {
        Array((todayEpochDay - (rhythmWindowDays - 1)) ... todayEpochDay)
    }

    /// `DateTimeFormatter.ofPattern("EEEEE", locale)` (`MedicationDetailSections.kt:285`).
    private var weekdaySymbols: [String] {
        SalusWeekdaySymbols.narrowMondayFirst(locale: locale)
    }

    /// `DateTimeFormatter.ofPattern("d MMMM", locale)` (`MedicationDetailSections.kt:284`) — the
    /// spoken date, which is longer than the letter on screen.
    private func fullDate(_ date: LocalDate) -> String {
        date.formatted(pattern: MedicationHistoryCardDefaults.spokenDatePattern, locale: locale)
    }
}

extension IntakeStatus? {
    /// `IntakeStatus?.rhythmGlyph()` (`MedicationDetailSections.kt:329-334`).
    fileprivate var rhythmGlyph: String {
        switch self {
        case .missed: "xmark"
        case .skipped: "minus"
        case .taken: "checkmark"
        case .none, .pending: "circle"
        }
    }

    /// `IntakeStatus?.rhythmTint()` (`MedicationDetailSections.kt:336-342`).
    fileprivate func rhythmTint(in theme: SalusResolvedTheme) -> Color {
        switch self {
        case .missed: theme.extendedColors.metricDown
        case .skipped: theme.extendedColors.warning
        case .taken: theme.colorScheme.primary
        case .none, .pending: theme.colorScheme.outline
        }
    }
}

extension [String] {
    /// The weekday table is always seven long, so this only ever returns a symbol — but
    /// `SalusWeekdaySymbols` documents that it hands back Foundation's own array unrotated if that
    /// were ever not seven, and a production subscript must not be the place that finds out.
    fileprivate subscript(safe index: Int) -> String? {
        indices.contains(index) ? self[index] : nil
    }
}

/// The two date patterns this card renders with. Not design tokens — format strings.
enum MedicationHistoryCardDefaults {
    /// `MedicationDetailSections.kt:231`.
    static let datePattern = "d MMM"

    /// `MedicationDetailSections.kt:284`.
    static let spokenDatePattern = "d MMMM"
}

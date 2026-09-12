// Ported from `feature/vitals/src/main/kotlin/com/alicansekban/salus/feature/vitals/
// ui/list/VitalsRow.kt` — one recorded measurement: the direction it moved, its value and delta,
// when it was taken and the two actions on it.
//
// Its own file on both platforms since M15; on this side it also keeps `VitalsListSections.swift`
// clear of the 500-line limit now that the chart card has grown a header and a stats row.
//
// **Why this is not `SalusCard(onTap:)` with the two buttons inside it.** That is what Compose
// does — `SalusCard(onClick = onClick)` with `SalusIconButton`s in its content — and it works there
// because Compose dispatches a tap to the innermost clickable. `SalusCard(onTap:)` on iOS is
// `Button(action: onTap) { surface }` (`SalusCard.swift:33-34`), so a button inside it would sit
// **inside another Button's label**, where SwiftUI's default styles treat it as decoration and
// route the tap to the outer button: the row would open the editor and `deleteRequested` would
// never fire.
//
// So the outer `Button` is gone. The card is the plain, non-interactive `SalusCard`, "open" is a
// tap gesture on the text column, and the two icon buttons are real `Button`s — and the tap targets
// are **disjoint by layout**, not merely ordered by dispatch rules: the column is a sibling of the
// buttons in the `HStack`, so no tap can reach both. The gesture route costs the row its automatic
// button semantics, so they are added back by hand below.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// One row of the list (`VitalsRow.kt:40-112`).
struct VitalsRow: View {
    let entry: VitalsListItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.salusTheme) private var theme
    /// The in-app language pick (`RootView+Locale.swift`) — the date and the value are both written
    /// in it, and `Locale.current` does not follow it on iOS.
    @Environment(\.locale) private var locale

    var body: some View {
        SalusCard(contentPadding: EdgeInsets(
            top: SalusSpacing.md,
            leading: SalusSpacing.md,
            bottom: SalusSpacing.md,
            trailing: SalusSpacing.sm
        )) {
            HStack(alignment: .center, spacing: 0) {
                // `SalusIconBadge(icon = entry.trend.glyph(), accent = trendAccent(entry.trend))`
                // (`VitalsRow.kt:59-63`). The badge repeats what the row's first line already says,
                // so both platforms hide it from the accessibility tree.
                SalusIconBadge(systemImage: Self.glyph(entry.trend), accent: trendAccent)
                Spacer().frame(width: SalusSpacing.md)

                details
                    // The column already fills every point the buttons do not, and `contentShape`
                    // makes the empty space beside a short value tappable too.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onEdit)
                    // A tap gesture is invisible to VoiceOver, where Compose's `Card(onClick =)` is
                    // announced as a button. `.combine` reads the row's lines as one element, the
                    // trait announces it as activatable, and the action is what a double tap runs.
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(.default, onEdit)

                // Siblings of the column, not descendants of any Button: this is the whole fix.
                SalusIconButton(
                    systemImage: "pencil",
                    accessibilityLabel: VitalsStrings.edit,
                    tone: .accent,
                    action: onEdit
                )
                SalusIconButton(
                    systemImage: "trash",
                    accessibilityLabel: VitalsStrings.delete,
                    tone: .destructive,
                    action: onDelete
                )
            }
        }
    }

    /// `VitalsRow.kt:65-97`.
    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: SalusSpacing.sm) {
                Text(verbatim: entry.headline(locale: locale))
                    .font(SalusTypography.titleMedium.font)
                    .foregroundStyle(theme.colorScheme.onSurface)
                if let delta = entry.deltaText(locale: locale) {
                    Text(verbatim: delta)
                        .font(SalusTypography.bodySmall.font)
                        .foregroundStyle(tint)
                }
            }
            Text(verbatim: entry.metaLine(locale: locale))
                .font(SalusTypography.bodySmall.font)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            if let note = entry.note {
                Text(verbatim: note)
                    .font(SalusTypography.bodySmall.font)
                    .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    .lineLimit(2)
            }
        }
    }

    /// The glyph says which way the number moved and nothing else. A rise in weight or in glucose
    /// is not "bad" and a fall is not "good", so the row never carries a verdict — the tint follows
    /// the direction alone and no classification is drawn anywhere on this screen
    /// (`VitalsRow.kt:114-123`).
    ///
    /// `ArrowUpward` / `ArrowDownward` / `Remove` are `arrow.up` / `arrow.down` / `minus`.
    private static func glyph(_ trend: Trend?) -> String {
        switch trend {
        case .rising: "arrow.up"
        case .falling: "arrow.down"
        case nil, .stable: "minus"
        }
    }

    /// `VitalsRow.kt:125-130`.
    private var tint: Color {
        switch entry.trend {
        case .rising: theme.extendedColors.metricUp
        case .falling: theme.extendedColors.metricDown
        case nil, .stable: theme.colorScheme.onSurfaceVariant
        }
    }

    /// A direction tint shaped as a `FeatureAccent` so the shared `SalusIconBadge` can carry it
    /// (`VitalsRow.kt:132-147`).
    ///
    /// This is not a feature accent and never replaces `extendedColors.vitals`, which still tints
    /// the chart, the FAB and the empty state: the badge ground stays neutral and only the glyph
    /// takes the direction's colour.
    private var trendAccent: FeatureAccent {
        FeatureAccent(
            accent: tint,
            onAccent: theme.colorScheme.surface,
            container: theme.colorScheme.surfaceContainerHigh,
            onContainer: tint
        )
    }
}

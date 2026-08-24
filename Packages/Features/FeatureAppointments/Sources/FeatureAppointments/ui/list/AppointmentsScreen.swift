// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/list/AppointmentsScreen.kt`.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `LazyColumn` + `contentPadding`      → `ScrollView` + `LazyVStack` + `.padding`.
//   `stickyHeader`                       → `LazyVStack(pinnedViews: .sectionHeaders)` + `Section`.
//   `CircularProgressIndicator`          → `ProgressView()`.
//   `Icons.Filled.*`                     → SF Symbol names.
//   `Modifier.weight(1f)` in a `Row`     → `.frame(maxWidth: .infinity, alignment: .leading)`.
//   `DateTimeFormatter.ofPattern(p, l)`  → `LocalDateTime.formatted(pattern:locale:)`, which owns
//                                          the fixed-pattern `DateFormatter`. Never a `Calendar`.
//
// One reuse the Kotlin does not have: the past block's title row is Android's hand-rolled
// `Row { Text(titleLarge); TextButton }` (`AppointmentsScreen.kt:163-186`), which is exactly what
// `SalusSectionHeader(title:actions:)` already draws — same style, same trailing action. Using the
// shared component instead of repeating the row costs one padding difference, recorded at the call
// site below.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`AppointmentsScreen.kt:60-75`).
///
/// No callback parameters, where `VitalsRoute` takes one: every destination this screen reaches is
/// this feature's own, so there is no cross-feature move for the shell to fill in.
public struct AppointmentsRoute: View {
    @Environment(\.appointmentsModule) private var module
    @State private var viewModel: AppointmentsViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let viewModel {
                AppointmentsScreen(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    onAddAppointment: { navigate(AppointmentEditorKey(id: nil)) },
                    // Rows open the detail screen; editing is an action on it, not the row's job
                    // (`AppointmentsScreen.kt:72`).
                    onOpenAppointment: { id in navigate(AppointmentDetailKey(id: id)) }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            // Built once and owned for the lifetime of the route. Unlike `VitalsRoute` there is
            // nothing to restart on a later appearance: the agenda's two windows are open-ended
            // (`>= now`, `< now`), so an appointment saved after the ViewModel was built still
            // falls inside one of them and arrives on the next repository emission.
            guard viewModel == nil, let module else { return }
            viewModel = module.makeAppointmentsViewModel()
        }
    }

    private func navigate(_ key: some Hashable & Sendable) {
        module?.navigator.navigate(key)
    }
}

/// The stateless agenda (`AppointmentsScreen.kt:77-123`).
struct AppointmentsScreen: View {
    let state: AppointmentsUiState
    let onEvent: (AppointmentsEvent) -> Void
    let onAddAppointment: () -> Void
    let onOpenAppointment: (String) -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                SalusScreenHeader(title: AppointmentsStrings.title)
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // `AppointmentsScreen.kt:112-120`.
            SalusFab(systemImage: "plus", contentDescription: AppointmentsStrings.add, action: onAddAppointment)
                .padding(SalusSpacing.lg)
        }
        .background(theme.colorScheme.background)
    }

    /// `AppointmentsScreen.kt:82-110`.
    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.hasNothing {
            SalusEmptyState(
                systemImage: "calendar",
                title: AppointmentsStrings.empty,
                accent: theme.extendedColors.appointments,
                actionLabel: AppointmentsStrings.add,
                onAction: onAddAppointment
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            agenda
        }
    }

    /// `AppointmentsScreen.kt:125-201`.
    private var agenda: some View {
        ScrollView {
            // `pinnedViews: .sectionHeaders` is `stickyHeader`: the day a card belongs to stays
            // visible while that day scrolls past.
            LazyVStack(alignment: .leading, spacing: SalusSpacing.sm, pinnedViews: .sectionHeaders) {
                if state.upcoming.isEmpty {
                    // `AppointmentsScreen.kt:134-142`.
                    Text(AppointmentsStrings.noUpcoming)
                        .font(SalusTypography.titleMedium.font)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .padding(.horizontal, SalusSpacing.lg)
                }

                ForEach(state.upcoming) { section in
                    Section {
                        ForEach(section.items) { item in
                            AppointmentCard(item: item, onTap: { onOpenAppointment(item.id) })
                        }
                    } header: {
                        DayHeader(epochDay: section.epochDay, todayEpochDay: state.todayEpochDay)
                    }
                }

                if !state.past.isEmpty {
                    pastSection
                }
            }
            // Keeps the last card scrollable above the floating action button
            // (`AppointmentsScreen.kt:130`, `:265`).
            .padding(.bottom, fabClearance)
        }
    }

    /// `AppointmentsScreen.kt:161-199`.
    ///
    /// `SalusSectionHeader` pads `sm` vertically where Kotlin's hand-rolled row pads `lg` on top
    /// only; the shared component is worth the two points, and the `LazyVStack`'s own `sm` spacing
    /// already separates the block from the day above it.
    @ViewBuilder
    private var pastSection: some View {
        SalusSectionHeader(title: AppointmentsStrings.pastHeader(count: state.past.count)) {
            Button(state.isPastExpanded ? AppointmentsStrings.pastHide : AppointmentsStrings.pastShow) {
                onEvent(.togglePastSection)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.colorScheme.primary)
        }

        if state.isPastExpanded {
            ForEach(state.past) { item in
                AppointmentCard(item: item, onTap: { onOpenAppointment(item.id) })
            }
        }
    }
}

/// The pinned day label (`AppointmentsScreen.kt:203-224`).
private struct DayHeader: View {
    let epochDay: Int
    let todayEpochDay: Int

    @Environment(\.salusTheme) private var theme

    var body: some View {
        Text(label)
            .font(SalusTypography.titleSmall.font)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.sm)
            // Opaque, or the cards would show through the pinned header as they scroll under it
            // (`AppointmentsScreen.kt:219`).
            .background(theme.colorScheme.background)
    }

    /// `AppointmentsScreen.kt:206-211`.
    private var label: String {
        switch epochDay {
        case todayEpochDay: AppointmentsStrings.dayToday
        case todayEpochDay + 1: AppointmentsStrings.dayTomorrow
        default: LocalDate(epochDay: epochDay).formatted(pattern: dayHeaderPattern)
        }
    }
}

/// Time on the left, what and where on the right (`AppointmentsScreen.kt:226-256`).
private struct AppointmentCard: View {
    let item: AppointmentListItem
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        SalusCard(onTap: onTap) {
            HStack(alignment: .top, spacing: 0) {
                Text(item.startsAt.formatted(pattern: timePattern))
                    .font(SalusTypography.titleMedium.font)
                    .foregroundStyle(theme.extendedColors.appointments.accent)
                    .frame(width: timeColumnWidth, alignment: .leading)

                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title)
                        .font(SalusTypography.titleMedium.font)
                        .foregroundStyle(theme.colorScheme.onSurface)
                    if let doctorName = item.doctorName {
                        DetailRow(systemImage: "person", text: doctorName)
                    }
                    if let location = item.location {
                        DetailRow(systemImage: "mappin.and.ellipse", text: location)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
    }
}

/// `AppointmentsScreen.kt:258-278`.
private struct DetailRow: View {
    let systemImage: String
    let text: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        HStack(spacing: SalusSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: detailIconSize))
                // Decoration: the text beside it already says what this is
                // (`contentDescription = null`).
                .accessibilityHidden(true)
            Text(text)
                .font(SalusTypography.bodyMedium.font)
        }
        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
        .padding(.top, SalusSpacing.xs)
    }
}

/// `AppointmentsScreen.kt:205`.
private let dayHeaderPattern = "EEEE, d MMMM"
/// `AppointmentsScreen.kt:232`.
private let timePattern = "HH:mm"
/// `AppointmentsScreen.kt:262`.
private let detailIconSize: CGFloat = 16
/// `AppointmentsScreen.kt:263`.
private let timeColumnWidth: CGFloat = 64
/// `AppointmentsScreen.kt:265`.
private let fabClearance: CGFloat = 88

// MARK: - Previews

/// The fixture the three previews share (`AppointmentsScreen.kt:280-324`, which needs only one
/// preview because Compose renders light and dark from a single `@PreviewLightDark`).
///
/// A namespace rather than loose file-scope constants: everything preview-only is then one
/// `private enum` a reader can skip, and nothing here can be mistaken for screen state.
private enum PreviewData {
    /// Kotlin's `todayEpochDay = 20_684`.
    static let today = 20684

    static let upcoming = [
        AppointmentDaySection(
            epochDay: today,
            items: [
                item(
                    id: "a1",
                    title: "Annual check-up",
                    doctorName: "Dr. Lee",
                    location: "City Clinic, Room 204",
                    epochDay: today,
                    minuteOfDay: 10 * 60
                )
            ]
        ),
        AppointmentDaySection(
            epochDay: today + 15,
            items: [
                item(
                    id: "a2",
                    title: "Dental cleaning",
                    doctorName: nil,
                    location: "Smile Dental",
                    epochDay: today + 15,
                    minuteOfDay: 14 * 60 + 30
                )
            ]
        )
    ]

    /// Kotlin's preview passes an empty past list; one row is carried here so the third preview has
    /// something to expand.
    static let past = [
        item(
            id: "p1",
            title: "Blood test",
            doctorName: "Dr. Yılmaz",
            location: nil,
            epochDay: today - 9,
            minuteOfDay: 8 * 60 + 15
        )
    ]

    static func item(
        id: String,
        title: String,
        doctorName: String?,
        location: String?,
        epochDay: Int,
        minuteOfDay: Int
    ) -> AppointmentListItem {
        AppointmentListItem(
            id: id,
            title: title,
            doctorName: doctorName,
            location: location,
            startsAt: LocalDateTime(date: LocalDate(epochDay: epochDay), minuteOfDay: minuteOfDay)
        )
    }
}

#Preview("Appointments agenda") {
    AppointmentsScreen(
        state: AppointmentsUiState(
            isLoading: false,
            upcoming: PreviewData.upcoming,
            past: PreviewData.past,
            todayEpochDay: PreviewData.today
        ),
        onEvent: { _ in },
        onAddAppointment: {},
        onOpenAppointment: { _ in }
    )
}

#Preview("Appointments agenda — past expanded") {
    AppointmentsScreen(
        state: AppointmentsUiState(
            isLoading: false,
            upcoming: PreviewData.upcoming,
            past: PreviewData.past,
            isPastExpanded: true,
            todayEpochDay: PreviewData.today
        ),
        onEvent: { _ in },
        onAddAppointment: {},
        onOpenAppointment: { _ in }
    )
}

#Preview("Appointments agenda — empty") {
    AppointmentsScreen(
        state: AppointmentsUiState(isLoading: false, todayEpochDay: PreviewData.today),
        onEvent: { _ in },
        onAddAppointment: {},
        onOpenAppointment: { _ in }
    )
}

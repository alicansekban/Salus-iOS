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
// One shape the Kotlin does not need: the row's trash icon. `SalusCard(onTap:)` is a `Button`, so
// a second `Button` inside its label is treated as decoration and the outer button swallows the
// tap — `VitalsRow` (`VitalsScreen.swift:258-307`) settled this, and this row copies its answer: a
// plain, non-interactive `SalusCard`, "open" as a tap gesture on the text column with the button
// semantics added back by hand, and the trash as a real `Button` that is the column's **sibling**,
// so the two targets are disjoint by layout rather than merely ordered by dispatch rules.
//
// One reuse the Kotlin does not have: the past block's title row is Android's hand-rolled
// `Row { Text(titleLarge); TextButton }` (`AppointmentsScreen.kt:181-205`), which is exactly what
// `SalusSectionHeader(title:actions:)` already draws — same style, same trailing action. Using the
// shared component instead of repeating the row costs one padding difference, recorded at the call
// site below.
//
// The row itself lives in `AppointmentCard.swift`: this file is the screen's own shape — header,
// the three content states, the agenda and the confirmation — and splitting the rows out is what M4
// did for Medications once its screen passed 500 lines.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`AppointmentsScreen.kt:64-76`).
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
                    // (`AppointmentsScreen.kt:74`).
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

/// The stateless agenda (`AppointmentsScreen.kt:79-137`).
struct AppointmentsScreen: View {
    let state: AppointmentsUiState
    let onEvent: (AppointmentsEvent) -> Void
    let onAddAppointment: () -> Void
    let onOpenAppointment: (String) -> Void

    @Environment(\.salusTheme) private var theme

    /// §10: reduce motion keeps the fade and drops the move, on both platforms.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // `AppointmentsScreen.kt:116-124`.
            SalusFab(systemImage: "plus", contentDescription: AppointmentsStrings.add, action: onAddAppointment)
                .padding(SalusSpacing.lg)
        }
        .background(theme.colorScheme.background)
        // The screen title. The shell's root toolbar draws it in the navigation bar's principal
        // slot; `.navigationTitle` is still what names the back button of everything this root
        // pushes, and what VoiceOver reads for the screen.
        .navigationTitle(Text(verbatim: AppointmentsStrings.title))
        // `AppointmentsScreen.kt:126-136`.
        .salusConfirmDialog(
            isPresented: isDeleteConfirmPresented,
            title: AppointmentsStrings.deleteTitle(state.pendingDelete?.title ?? ""),
            message: AppointmentsStrings.deleteMessage,
            confirm: SalusDialogAction(label: SalusUIStrings.delete) { onEvent(.deleteConfirmed) },
            dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.deleteDismissed) }
        )
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host (CLAUDE.md's `.macOS(.v14)`
        // concession). Last because SwiftFormat indents whatever follows an `#endif` one level
        // deeper, which reads as if those modifiers were inside the guard — the shape
        // `AboutScreen` has carried since M8.
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// Kotlin writes `state.pendingDelete?.let { … }` — the dialog exists only while there is
    /// something to ask about. SwiftUI's alert takes a `Binding<Bool>` instead, so the optional is
    /// read as "is there one" and the setter reports the system-driven dismissals (a swipe, the
    /// hardware back gesture) back as `deleteDismissed`, which is the same shape
    /// `AppointmentDetailScreen` uses.
    private var isDeleteConfirmPresented: Binding<Bool> {
        Binding(
            get: { state.pendingDelete != nil },
            set: { isPresented in
                guard !isPresented else { return }
                onEvent(.deleteDismissed)
            }
        )
    }

    /// `AppointmentsScreen.kt:86-114`.
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

    /// `AppointmentsScreen.kt:140-218`.
    private var agenda: some View {
        ScrollView {
            // `pinnedViews: .sectionHeaders` is `stickyHeader`: the day a card belongs to stays
            // visible while that day scrolls past.
            LazyVStack(alignment: .leading, spacing: SalusSpacing.sm, pinnedViews: .sectionHeaders) {
                if state.upcoming.isEmpty {
                    // `AppointmentsScreen.kt:152-160`.
                    Text(verbatim: AppointmentsStrings.noUpcoming)
                        .font(SalusTypography.titleMedium.font)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                        .padding(.horizontal, SalusSpacing.lg)
                }

                ForEach(state.upcoming) { section in
                    Section {
                        ForEach(section.items) { item in
                            AppointmentCard(
                                item: item,
                                onTap: { onOpenAppointment(item.id) },
                                onDelete: { onEvent(.deleteRequested(item.id)) }
                            )
                            // §10 list mutation: fade + vertical move on add, remove and undo's
                            // return. Reduce motion keeps the fade and drops the move
                            // (`AppointmentsScreen.kt:181-186`).
                            .transition(
                                reduceMotion
                                    ? SalusMotion.listMutationReducedMotionTransition
                                    : SalusMotion.listMutationTransition
                            )
                        }
                    } header: {
                        DayHeader(epochDay: section.epochDay, todayEpochDay: state.todayEpochDay)
                    }
                    // Every mutation path — delete confirmed, undo's return, an editor save
                    // landing — arrives as a state change the section observes, so the animation
                    // rides with it wherever it came from. The header is not a row and carries no
                    // transition, so it stays put while the cards around it move.
                    .animation(
                        reduceMotion
                            ? SalusMotion.listMutationReducedMotionAnimation
                            : SalusMotion.listMutationAnimation,
                        value: state.upcoming
                    )
                }

                if !state.past.isEmpty {
                    pastSection
                }
            }
            // Keeps the last card scrollable above the floating action button
            // (`AppointmentsScreen.kt:148`, `:304`).
            .padding(.bottom, fabClearance)
        }
    }

    /// `AppointmentsScreen.kt:180-216`.
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
                AppointmentCard(
                    item: item,
                    onTap: { onOpenAppointment(item.id) },
                    onDelete: { onEvent(.deleteRequested(item.id)) }
                )
                // §10 list mutation: fade + vertical move on add, remove and undo's
                // return. Reduce motion keeps the fade and drops the move
                // (`AppointmentsScreen.kt:223-228`).
                .transition(
                    reduceMotion
                        ? SalusMotion.listMutationReducedMotionTransition
                        : SalusMotion.listMutationTransition
                )
            }
            // Every mutation path — delete confirmed, undo's return, an editor save landing —
            // arrives as a state change the block observes, so the animation rides with it
            // wherever it came from. The section header above is not a row and carries no
            // transition, so it stays put while the cards below it move.
            .animation(
                reduceMotion
                    ? SalusMotion.listMutationReducedMotionAnimation
                    : SalusMotion.listMutationAnimation,
                value: state.past
            )
        }
    }
}

/// The pinned day label (`AppointmentsScreen.kt:221-238`).
private struct DayHeader: View {
    let epochDay: Int
    let todayEpochDay: Int

    @Environment(\.salusTheme) private var theme
    /// The in-app language pick, which `Locale.current` does not follow on iOS — see the free
    /// function below.
    @Environment(\.locale) private var locale

    var body: some View {
        Text(verbatim: label)
            .font(SalusTypography.titleSmall.font)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.sm)
            // Opaque, or the cards would show through the pinned header as they scroll under it
            // (`AppointmentsScreen.kt:235`).
            .background(theme.colorScheme.background)
    }

    private var label: String {
        appointmentsDayHeaderLabel(epochDay: epochDay, todayEpochDay: todayEpochDay, locale: locale)
    }
}

/// `AppointmentsScreen.kt:224-228`.
///
/// `locale` is the **environment** locale — the twin of Android's `Locale.getDefault()` here, since
/// `setApplicationLocales` moves that one and nothing moves iOS's `Locale.current`. The shell puts
/// the in-app pick into `\.locale` (`RootView+Locale.swift`), so the default would silently write
/// the day in the device's language while the rest of the app spoke the picked one.
///
/// A free function rather than a computed property on the view, so what it writes can be asserted
/// in a test without rendering anything.
func appointmentsDayHeaderLabel(epochDay: Int, todayEpochDay: Int, locale: Locale) -> String {
    switch epochDay {
    case todayEpochDay: AppointmentsStrings.dayToday
    case todayEpochDay + 1: AppointmentsStrings.dayTomorrow
    default: LocalDate(epochDay: epochDay).formatted(pattern: dayHeaderPattern, locale: locale)
    }
}

/// `AppointmentsScreen.kt:223`.
private let dayHeaderPattern = "EEEE, d MMMM"
/// `AppointmentsScreen.kt:304`.
private let fabClearance: CGFloat = 88

// MARK: - Previews

/// The fixture the three previews share (`AppointmentsScreen.kt:306-349`, which needs only one
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

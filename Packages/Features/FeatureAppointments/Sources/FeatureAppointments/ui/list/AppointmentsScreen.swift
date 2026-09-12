// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/list/AppointmentsScreen.kt`.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `LazyColumn` + `contentPadding`      → `ScrollView` + `LazyVStack` + `.padding`.
//   `CircularProgressIndicator`          → `ProgressView()`.
//   `Icons.Filled.*`                     → SF Symbol names.
//   `DateTimeFormatter.ofPattern(p, l)`  → `LocalDateTime.formatted(pattern:locale:)`, which owns
//                                          the fixed-pattern `DateFormatter`. Never a `Calendar`.
//   `item(key: …)` in a LazyColumn       → `ForEach` over `state.upcoming` / `state.past`.
//   `SalusSegmentedTabs`                 → one for one, the segmented tabs with the two halves.
//   `SalusSectionHeader` (day labels)    → one for one; the "TODAY"/"TOMORROW" overlines stay
//                                          upper-case resources, other days the locale's spelling.
//   `SalusExtendedFab`                   → one for one (M15); the icon-only FAB left the list.
//   `SalusEmptyState`                    → one for one, per tab.
//
// One shape the Kotlin does not need: the row's trash icon. `SalusCard(onTap:)` is a `Button`, so
// a second `Button` inside its label is treated as decoration and the outer button swallows the
// tap — `AppointmentCard.swift` records that answer in full.
//
// The row itself lives in `AppointmentCard.swift`: this file is the screen's own shape — the tabs,
// the three content states, the per-tab agenda and the confirmation — and splitting the rows out is
// what M4 did for Medications once its screen passed 500 lines.

import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`AppointmentsScreen.kt:56-69`).
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
                    // (`AppointmentsScreen.kt:67`).
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

/// The stateless agenda (`AppointmentsScreen.kt:71-146`).
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
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // `AppointmentsScreen.kt:125-133`: the extended FAB is the list's one action, floated
            // above the bottom bar.
            SalusExtendedFab(
                label: AppointmentsStrings.new,
                systemImage: "plus",
                action: onAddAppointment
            )
            .padding(SalusSpacing.lg)
        }
        .background(theme.colorScheme.background)
        // The screen title. The shell's root toolbar draws it in the navigation bar's principal
        // slot; `.navigationTitle` is still what names the back button of everything this root
        // pushes, and what VoiceOver reads for the screen.
        .navigationTitle(Text(verbatim: AppointmentsStrings.title))
        // `AppointmentsScreen.kt:136-145`.
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

    /// `AppointmentsScreen.kt:86-123`.
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
                actionLabel: AppointmentsStrings.new,
                onAction: onAddAppointment
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            tabs
        }
    }

    /// The segmented tabs and the list they select between (`AppointmentsScreen.kt:105-121`).
    private var tabs: some View {
        VStack(spacing: 0) {
            SalusSegmentedTabs(
                options: AppointmentsTab.allCases,
                selected: state.selectedTab,
                label: { tabLabel($0) },
                onSelected: { onEvent(.tabSelected($0)) }
            )
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.sm)

            Agenda(
                state: state,
                onOpenAppointment: onOpenAppointment,
                onEvent: onEvent,
                theme: theme
            )
        }
    }

    /// `AppointmentsTab.label` (`AppointmentsScreen.kt:148-162`) — the count each tab carries is
    /// the number of appointments behind it, not of day headers.
    private func tabLabel(_ tab: AppointmentsTab) -> String {
        switch tab {
        case .upcoming: AppointmentsStrings.tabUpcoming(count: state.upcomingCount)
        case .past: AppointmentsStrings.tabPast(count: state.pastCount)
        }
    }
}

/// The per-tab list (`AppointmentsScreen.kt:164-253`).
///
/// A small struct rather than a `@ViewBuilder` property so the tab-switch animation can attach to
/// the whole list without forcing a separate `state`-value comparison; the agenda below it reads
/// `state.selectedTab` and is what `state` changes drive.
private struct Agenda: View {
    let state: AppointmentsUiState
    let onOpenAppointment: (String) -> Void
    let onEvent: (AppointmentsEvent) -> Void
    let theme: SalusResolvedTheme

    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SalusSpacing.sm) {
                switch state.selectedTab {
                case .upcoming:
                    if state.upcoming.isEmpty {
                        emptyUpcoming
                    } else {
                        ForEach(state.upcoming) { section in
                            Section {
                                ForEach(section.items) { item in
                                    AppointmentCard(
                                        item: item,
                                        onTap: { onOpenAppointment(item.id) },
                                        onDelete: { onEvent(.deleteRequested(item.id)) }
                                    )
                                    .transition(SalusMotion.listMutationTransition)
                                }
                            } header: {
                                SalusSectionHeader(
                                    title: appointmentsDayHeaderLabel(
                                        epochDay: section.epochDay,
                                        todayEpochDay: state.todayEpochDay,
                                        locale: locale
                                    )
                                )
                            }
                            .animation(
                                SalusMotion.listMutationAnimation,
                                value: state.upcoming
                            )
                        }
                    }

                case .past:
                    if state.past.isEmpty {
                        emptyPast
                    } else {
                        ForEach(state.past) { item in
                            AppointmentCard(
                                item: item,
                                onTap: { onOpenAppointment(item.id) },
                                onDelete: { onEvent(.deleteRequested(item.id)) }
                            )
                            .transition(SalusMotion.listMutationTransition)
                        }
                        .animation(SalusMotion.listMutationAnimation, value: state.past)
                    }
                }
            }
            // Keeps the last card scrollable above the floating action button
            // (`AppointmentsScreen.kt:176-182`).
            .padding(.bottom, fabClearance)
        }
        .animation(.default, value: state.selectedTab)
    }

    /// `AppointmentsScreen.kt:185-192`, per tab.
    private var emptyUpcoming: some View {
        SalusEmptyState(
            systemImage: "calendar",
            title: AppointmentsStrings.noUpcoming,
            accent: theme.extendedColors.appointments
        )
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    /// `AppointmentsScreen.kt:214-221`, per tab.
    private var emptyPast: some View {
        SalusEmptyState(
            systemImage: "calendar",
            title: AppointmentsStrings.noPast,
            accent: theme.extendedColors.appointments
        )
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}

/// `AppointmentsScreen.kt:259-267`.
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

/// `AppointmentsScreen.kt:260`.
private let dayHeaderPattern = "EEEE, d MMMM"
/// Room for the extended FAB (`AppointmentsScreen.kt:177-181`).
private let fabClearance: CGFloat = 88

/// The fixture the previews share (`AppointmentsScreen.kt:269-311`).
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

#Preview("Appointments — upcoming") {
    SalusPreviewPalettes {
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
}

#Preview("Appointments — past") {
    SalusPreviewPalettes {
        AppointmentsScreen(
            state: AppointmentsUiState(
                isLoading: false,
                upcoming: PreviewData.upcoming,
                past: PreviewData.past,
                selectedTab: .past,
                todayEpochDay: PreviewData.today
            ),
            onEvent: { _ in },
            onAddAppointment: {},
            onOpenAppointment: { _ in }
        )
    }
}

#Preview("Appointments — empty") {
    SalusPreviewPalettes {
        AppointmentsScreen(
            state: AppointmentsUiState(isLoading: false, todayEpochDay: PreviewData.today),
            onEvent: { _ in },
            onAddAppointment: {},
            onOpenAppointment: { _ in }
        )
    }
}

#Preview("Appointments — large type") {
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
    .dynamicTypeSize(.xxxLarge)
}

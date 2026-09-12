// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/detail/AppointmentDetailScreen.kt`.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `TopAppBar`                 → `.navigationTitle(_:)` + trailing "Düzenle" on the shell's stack;
//                                 the back arrow is the stack's own, which pops the very path
//                                 `Navigator.pop()` mutates (`WeightEditorScreen.swift` records the
//                                 ruling), and the edit action is a `TextButton` in the toolbar.
//   `Column(verticalScroll)`    → `ScrollView` + `VStack`.
//   `SalusIconBadge(large)`     → `.large` (48 pt); the M15 hero's centred visual.
//   `SalusStatusChip(accent)`   → the relative-day chip ("Bugün"/"Yarın"/"N gün sonra"/"Geçti").
//   `SalusListItem`             → the "DETAYLAR" rows, with a chevron on the location row and a
//                                 time chip trailing the date row.
//   `SalusInfoNote`             → the profile's health notes, "what to tell the doctor".
//   `SalusButton`               → the "Takvime Ekle" (.primary) and "Sil" (.destructive) pills.
//   `Intent(ACTION_INSERT)`     → a `.sheet` over `CalendarEventEditSheet` — divergence (e).
//   `Intent(ACTION_VIEW, geo:)` → `openURL(mapsURL(for:))` — divergence (a), see `MapsLink.swift`.
//
// M15 made this a FULL-SCREEN detail rather than the M4 card: the hero sits on the background
// with no `SalusCard`, which is why the list and detail now look as M15 drew them. The status chip
// (`appointment_status_*`) retired with it — Android deleted the three status keys in M15 — and
// the old `appointment_detail_time`/`_location`/`_health_notes` keys were re-valued or replaced
// by the "DETAYLAR"/"NOTLAR" and placeholder shape. The `relativeDay` comes from the ViewModel, per
// emission (A62).

import SalusCommon
import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`AppointmentDetailScreen.kt:74-90`).
public struct AppointmentDetailRoute: View {
    private let appointmentId: String

    @Environment(\.appointmentsModule) private var module
    @State private var viewModel: AppointmentDetailViewModel?

    public init(appointmentId: String) {
        self.appointmentId = appointmentId
    }

    public var body: some View {
        Group {
            if let viewModel {
                AppointmentDetailScreen(
                    state: viewModel.state,
                    onEvent: viewModel.onEvent,
                    // `AppointmentDetailScreen.kt:88` — editing is an action on the detail, and the
                    // key it pushes is this feature's own, so no shell callback is involved.
                    onEdit: { module?.navigator.navigate(AppointmentEditorKey(id: appointmentId)) }
                )
            } else {
                // Only until `.task` has run, or if the shell forgot to inject the module.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard viewModel == nil, let module else { return }
            viewModel = module.makeAppointmentDetailViewModel(appointmentId)
        }
    }
}

/// The stateless detail (`AppointmentDetailScreen.kt:92-187`).
struct AppointmentDetailScreen: View {
    let state: AppointmentDetailUiState
    let onEvent: (AppointmentDetailEvent) -> Void
    let onEdit: () -> Void

    @Environment(\.salusTheme) private var theme
    /// The in-app language pick (`RootView+Locale.swift`). `Locale.current` is the device's on
    /// iOS and does not follow the in-app setting, so every date below is written through this.
    @Environment(\.locale) private var locale
    /// Presentation state, not screen state: the sheet is a view of the same `state.appointment`,
    /// so a ViewModel event for it would be a second copy of a boolean SwiftUI already owns.
    @State private var isAddingToCalendar = false

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colorScheme.background)
            // The inline title; the trailing "Düzenle" is a text action, exactly Android's
            // `TextButton` in the pushed top bar (`AppointmentDetailScreen.kt:105-116`).
            .navigationTitle(AppointmentsStrings.detailTitle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onEdit) {
                        Text(verbatim: AppointmentsStrings.detailEdit)
                    }
                }
            }
            .salusConfirmDialog(
                isPresented: isDeleteConfirmPresented,
                title: AppointmentsStrings.deleteTitle(state.appointment?.title ?? ""),
                message: AppointmentsStrings.deleteMessage,
                confirm: SalusDialogAction(label: SalusUIStrings.delete) { onEvent(.deleteConfirmed) },
                dismiss: SalusDialogAction(label: SalusUIStrings.cancel) { onEvent(.deleteDismissed) }
            )
        #if canImport(EventKitUI)
            .sheet(isPresented: $isAddingToCalendar) { calendarSheet }
        #endif
        // LAST in the chain, and `#if os(iOS)` because the modifier is iOS-only API while every
        // feature package also builds for the macOS test host (CLAUDE.md's `.macOS(.v14)`
        // concession). Last because SwiftFormat indents whatever follows an `#endif` one level
        // deeper, which reads as if those modifiers were inside the guard
        // (`VitalsEditorChrome.swift` sets it the same way).
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// `AppointmentDetailScreen.kt:119-129`.
    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let appointment = state.appointment {
            detail(of: appointment)
        } else {
            Text(verbatim: AppointmentsStrings.detailMissing)
                .font(SalusTypography.bodyLarge.font)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(SalusSpacing.xl)
        }
    }

    /// `AppointmentDetailScreen.kt:131-172` — the sections, in the Kotlin order.
    private func detail(of appointment: Appointment) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Hero(appointment: appointment, relativeDay: state.relativeDay, locale: locale)

                SalusSectionHeader(title: AppointmentsStrings.detailSectionDetails)
                DetailRows(appointment: appointment, locale: locale, onEdit: onEdit)

                SalusSectionHeader(title: AppointmentsStrings.detailNotes)
                Notes(notes: appointment.notes, onEdit: onEdit)

                if let healthNotes = state.healthNotes {
                    SalusInfoNote(
                        text: healthNotes,
                        systemImage: "info.circle",
                        tone: .neutral
                    )
                    .padding(.horizontal, SalusSpacing.lg)
                    .padding(.vertical, SalusSpacing.md)
                }

                Actions(
                    calendarEnabled: state.startEpochMs > 0,
                    onAddToCalendar: { isAddingToCalendar = true },
                    onDelete: { onEvent(.deleteClicked) }
                )
            }
            .padding(.bottom, SalusSpacing.xl)
        }
    }

    /// `AppointmentDetailScreen.kt:176-186`.
    private var isDeleteConfirmPresented: Binding<Bool> {
        Binding(
            get: { state.showDeleteConfirm && state.appointment != nil },
            set: { isPresented in
                guard !isPresented else { return }
                onEvent(.deleteDismissed)
            }
        )
    }

    #if canImport(EventKitUI)
        /// The payload the system's event editor is prefilled with
        /// (`AppointmentDetailScreen.kt:410-422`).
        private var calendarDraft: CalendarEventDraft? {
            guard let appointment = state.appointment, state.startEpochMs > 0 else { return nil }
            return .forDetail(
                appointment: appointment,
                start: Date(epochMilliseconds: state.startEpochMs),
                end: Date(epochMilliseconds: state.endEpochMs)
            )
        }

        @ViewBuilder
        private var calendarSheet: some View {
            if let calendarDraft {
                CalendarEventEditSheet(draft: calendarDraft, onDismiss: dismissCalendarSheet)
                    .ignoresSafeArea()
            }
        }

        /// The binding is captured rather than `self`, so the callback is `@Sendable` and the
        /// coordinator's main-actor hop is a compiler fact instead of a promise in a comment.
        private var dismissCalendarSheet: @MainActor @Sendable () -> Void {
            let isPresented = $isAddingToCalendar
            return { isPresented.wrappedValue = false }
        }
    #endif
}

/// The centred hero — this appointment's own title block, on the background with no card
/// (`AppointmentDetailScreen.kt:202-239`).
private struct Hero: View {
    let appointment: Appointment
    let relativeDay: RelativeDay?
    let locale: Locale

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.sm) {
            SalusIconBadge(
                systemImage: "calendar",
                accent: theme.extendedColors.appointments,
                size: .large
            )
            Text(verbatim: appointment.title)
                .font(SalusTypography.headlineMedium.font)
                .multilineTextAlignment(.center)
            Text(verbatim: appointment.startsAt.formatted(pattern: fullDatePattern, locale: locale))
                .font(SalusTypography.bodyMedium.font)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
            if let relativeDay {
                SalusStatusChip(label: relativeDayLabel(relativeDay), status: .accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SalusSpacing.lg)
    }

    /// `RelativeDay.label` (`AppointmentDetailScreen.kt:391-401`).
    private func relativeDayLabel(_ day: RelativeDay) -> String {
        switch day {
        case .today: AppointmentsStrings.relativeToday
        case .tomorrow: AppointmentsStrings.relativeTomorrow
        case .past: AppointmentsStrings.relativePast
        case let .inDays(days): AppointmentsStrings.relativeInDays(days)
        }
    }
}

/// The "DETAYLAR" rows: date, doctor, location, reminders — all four always present, an empty one
/// drawn as the row that fills it (`AppointmentDetailScreen.kt:241-322`).
private struct DetailRows: View {
    let appointment: Appointment
    let locale: Locale
    let onEdit: () -> Void

    @Environment(\.salusTheme) private var theme

    private var accent: FeatureAccent { theme.extendedColors.appointments }

    var body: some View {
        VStack(spacing: 0) {
            dateRow
            doctorRow
            locationRow
            remindersRow
        }
    }

    /// `AppointmentDetailScreen.kt:255-262` — the date with a time chip trailing.
    private var dateRow: some View {
        SalusListItem(
            title: appointment.startsAt.formatted(pattern: fullDatePattern, locale: locale),
            systemImage: "clock",
            accent: accent,
            trailing: {
                SalusStatusChip(
                    label: appointment.startsAt.formatted(pattern: timePattern, locale: locale),
                    status: .accent
                )
            }
        )
    }

    /// `AppointmentDetailScreen.kt:264-278` — the doctor row or its "Doktor ekle" placeholder.
    @ViewBuilder
    private var doctorRow: some View {
        if let doctor = nonBlank(appointment.doctorName) {
            SalusListItem(
                title: doctor,
                subtitle: nonBlank(appointment.specialty),
                systemImage: "person",
                accent: accent
            )
        } else {
            AddRow(systemImage: "person", text: AppointmentsStrings.addDoctor, onTap: onEdit)
        }
    }

    /// `AppointmentDetailScreen.kt:280-304` — the location row (subtitle "Haritalarda aç" + chevron
    /// when the location is non-empty; else "Konum ekle"). Divergence (a): iOS Maps is never
    /// removable, so the row always opens when the location is non-blank.
    @ViewBuilder
    private var locationRow: some View {
        if let location = nonBlank(appointment.location) {
            SalusListItem(
                title: location,
                subtitle: AppointmentsStrings.detailOpenMaps,
                systemImage: "mappin.and.ellipse",
                accent: accent,
                onTap: { openMaps(location) },
                trailing: { SalusListItemChevron() }
            )
        } else {
            AddRow(systemImage: "mappin.and.ellipse", text: AppointmentsStrings.addLocation, onTap: onEdit)
        }
    }

    /// `AppointmentDetailScreen.kt:306-321` — the reminders row or its "Hatırlatıcı ekle".
    @ViewBuilder
    private var remindersRow: some View {
        let reminders = appointment.reminderOffsetsMinutes.sorted()
        if reminders.isEmpty {
            AddRow(systemImage: "bell", text: AppointmentsStrings.addReminder, onTap: onEdit)
        } else {
            SalusListItem(
                title: reminders.map { offsetLabel($0) }.joined(separator: " · "),
                systemImage: "bell",
                accent: accent
            )
        }
    }

    /// `runCatching { startActivity(intent) }` (`AppointmentDetailScreen.kt:302`): no map app is a
    /// legal state on both platforms, and `openURL` reports it through its completion.
    private func openMaps(_ location: String) {
        guard let url = mapsURL(for: location) else { return }
        openURL(url)
    }

    @Environment(\.openURL) private var openURL
}

/// An empty field drawn as the row that fills it; the title is dimmed to `onSurfaceVariant` so the
/// invitation reads as a placeholder rather than a value someone already entered
/// (`AppointmentDetailScreen.kt:344-358`).
private struct AddRow: View {
    let systemImage: String
    let text: String
    let onTap: () -> Void

    @Environment(\.salusTheme) private var theme
    private var accent: FeatureAccent { theme.extendedColors.appointments }

    var body: some View {
        // `accent = appointments`, `titleColor = onSurfaceVariant`
        // (`AppointmentDetailScreen.kt:351-356`).
        SalusListItem(
            title: text,
            systemImage: systemImage,
            accent: accent,
            titleColor: onSurfaceVariant,
            onTap: onTap
        )
    }

    private var onSurfaceVariant: Color { theme.colorScheme.onSurfaceVariant }
}

/// The "NOTLAR" section — either the saved note in a card, or a "Not ekle" row
/// (`AppointmentDetailScreen.kt:324-342`).
private struct Notes: View {
    let notes: String?
    let onEdit: () -> Void

    var body: some View {
        if let text = nonBlank(notes) {
            SalusCard {
                Text(verbatim: text)
                    .font(SalusTypography.bodyMedium.font)
            }
            .padding(.horizontal, SalusSpacing.lg)
            .padding(.vertical, SalusSpacing.xs)
        } else {
            AddRow(systemImage: "doc.text", text: AppointmentsStrings.addNote, onTap: onEdit)
        }
    }
}

/// The two things done from here, in the order they are reached for (`AppointmentDetailScreen.kt:360-389`).
///
/// Editing lives in the top bar's text action alone — a second "Düzenle" down here read as a
/// different action (`AppointmentDetailScreen.kt:360-363`).
private struct Actions: View {
    let calendarEnabled: Bool
    let onAddToCalendar: () -> Void
    let onDelete: () -> Void

    @Environment(\.salusTheme) private var theme

    var body: some View {
        VStack(spacing: SalusSpacing.md) {
            SalusButton(
                AppointmentsStrings.addToCalendar,
                systemImage: "calendar",
                accent: theme.extendedColors.appointments,
                enabled: calendarEnabled,
                action: onAddToCalendar
            )
            SalusButton(
                AppointmentsStrings.detailDelete,
                variant: .destructive,
                action: onDelete
            )
        }
        .padding(.horizontal, SalusSpacing.lg)
        .padding(.vertical, SalusSpacing.md)
    }
}

/// `AppointmentDetailScreen.kt:423-424`.
private let fullDatePattern = "EEEE, d MMMM yyyy"
/// `AppointmentDetailScreen.kt:424`.
private let timePattern = "HH:mm"

// MARK: - Previews

/// `AppointmentDetailScreen.kt:427-446`.
private let previewAppointment = Appointment(
    id: "a1",
    title: "Annual check-up",
    doctorName: "Dr. Lee",
    specialty: "Cardiology",
    location: "City Clinic, Room 204",
    notes: "Bring the last blood test results.",
    startsAt: LocalDateTime(date: LocalDate(year: 2026, month: 8, day: 18), minuteOfDay: 10 * 60),
    timeZone: TimeZone(identifier: "Europe/Istanbul") ?? .gmt,
    durationMinutes: 30,
    status: .scheduled,
    reminderOffsetsMinutes: [1440, 60]
)

#Preview("Appointment detail") {
    NavigationStack {
        AppointmentDetailScreen(
            state: AppointmentDetailUiState(
                isLoading: false,
                appointment: previewAppointment,
                healthNotes: "Pollen allergy",
                relativeDay: .inDays(17),
                startEpochMs: 1_776_000_000_000,
                endEpochMs: 1_776_001_800_000
            ),
            onEvent: { _ in },
            onEdit: {}
        )
    }
}

#Preview("Appointment detail — minimal") {
    NavigationStack {
        AppointmentDetailScreen(
            state: AppointmentDetailUiState(
                isLoading: false,
                appointment: Appointment(
                    id: "a2",
                    title: "Dental cleaning",
                    doctorName: nil,
                    specialty: nil,
                    location: nil,
                    notes: nil,
                    startsAt: LocalDateTime(date: LocalDate(year: 2026, month: 9, day: 2), minuteOfDay: 14 * 60 + 30),
                    timeZone: TimeZone(identifier: "Europe/Istanbul") ?? .gmt,
                    durationMinutes: 45,
                    status: .scheduled,
                    reminderOffsetsMinutes: []
                ),
                relativeDay: .tomorrow
            ),
            onEvent: { _ in },
            onEdit: {}
        )
    }
}

#Preview("Appointment detail — missing") {
    NavigationStack {
        AppointmentDetailScreen(state: AppointmentDetailUiState(isLoading: false), onEvent: { _ in }, onEdit: {})
    }
}

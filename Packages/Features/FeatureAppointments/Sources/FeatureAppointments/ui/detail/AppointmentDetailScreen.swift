// Ported from `feature/appointments/src/main/kotlin/com/alicansekban/salus/feature/appointments/
// ui/detail/AppointmentDetailScreen.kt`.
//
// Material → SwiftUI, per the mapping table in `docs/ios-feature-template.md`:
//   `TopAppBar`                 → `.navigationTitle(_:)` on the shell's stack; the back arrow is
//                                 the stack's own, which pops the very path `Navigator.pop()`
//                                 mutates (`WeightEditorScreen.swift` records the ruling).
//   `Column(verticalScroll)`    → `ScrollView` + `VStack`.
//   `FlowRow`                   → `SalusUI.ChipFlowLayout`; SwiftUI ships no flow stack.
//   `SalusPillButton`           → `SalusUI.SalusPillButton`, one for one, since iOS-M7: `tonal:`
//                                 for Kotlin's `tonal`, `fillsWidth:` for its `fillMaxWidth()`,
//                                 `enabled:` for its `enabled`. The `.borderedProminent` /
//                                 `.bordered` stand-in this file carried is gone.
//   `Icons.Filled.*`            → SF Symbol names.
//   `AlertDialog`               → `.salusConfirmDialog(isPresented:…)`.
//   `Intent(ACTION_INSERT)`     → a `.sheet` over `CalendarEventEditSheet` — divergence (e).
//   `Intent(ACTION_VIEW, geo:)` → `openURL(mapsURL(for:))` — divergence (a), see `MapsLink.swift`.
//
// One layout difference from the Kotlin, the same one the list screen already recorded: Compose
// pads the whole scrolling column horizontally and passes each `SalusSectionHeader` a
// `contentPadding` with no horizontal component, while `SalusUI.SalusSectionHeader` pads itself
// (and deliberately does not port that parameter). So here the cards carry the `lg` inset and the
// headers keep their own — the drawn result is the same inset, reached from the other side.

import SalusCommon
import SalusDesignSystem
import SalusModel
import SalusUI
import SwiftUI

/// Owns the ViewModel and wires it to the shell (`AppointmentDetailScreen.kt:69-85`).
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
                    // `AppointmentDetailScreen.kt:83` — editing is an action on the detail, and the
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

/// The stateless detail (`AppointmentDetailScreen.kt:87-165`).
struct AppointmentDetailScreen: View {
    let state: AppointmentDetailUiState
    let onEvent: (AppointmentDetailEvent) -> Void
    let onEdit: () -> Void

    @Environment(\.salusTheme) private var theme
    /// Presentation state, not screen state: the sheet is a view of the same `state.appointment`,
    /// so a ViewModel event for it would be a second copy of a boolean SwiftUI already owns.
    @State private var isAddingToCalendar = false

    var body: some View {
        // No `Scaffold` twin here: the app shell owns the one navigation stack and its insets.
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colorScheme.background)
            .navigationTitle(AppointmentsStrings.detailTitle)
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
    }

    /// `AppointmentDetailScreen.kt:113-149`.
    @ViewBuilder
    private var content: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let appointment = state.appointment {
            detail(of: appointment)
        } else {
            Text(AppointmentsStrings.detailMissing)
                .font(SalusTypography.bodyLarge.font)
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(SalusSpacing.xl)
        }
    }

    /// `AppointmentDetailScreen.kt:126-147` — the sections, in the Kotlin order.
    private func detail(of appointment: Appointment) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SalusSpacing.md) {
                header(of: appointment)
                if let location = nonBlank(appointment.location) {
                    locationSection(location)
                }
                notesSection(notes: appointment.notes)
                if !appointment.reminderOffsetsMinutes.isEmpty {
                    remindersSection(appointment.reminderOffsetsMinutes)
                }
                actions
            }
            // `AppointmentDetailScreen.kt:146` — the trailing spacer.
            .padding(.bottom, SalusSpacing.lg)
        }
    }

    /// `AppointmentDetailScreen.kt:181-231`.
    private func header(of appointment: Appointment) -> some View {
        SalusCard {
            Text(appointment.title)
                .font(SalusTypography.headlineSmall.font)
            Spacer()
                .frame(height: SalusSpacing.sm)
            Text(appointment.startsAt.formatted(pattern: headerDatePattern))
                .font(SalusTypography.bodyLarge.font)
                .foregroundStyle(theme.extendedColors.appointments.accent)
            Text(
                AppointmentsStrings.detailTime(
                    time: appointment.startsAt.formatted(pattern: timePattern),
                    durationMinutes: appointment.durationMinutes
                )
            )
            .font(SalusTypography.bodyMedium.font)
            .foregroundStyle(theme.colorScheme.onSurfaceVariant)

            // `AppointmentDetailScreen.kt:215-222`.
            let who = [appointment.doctorName, appointment.specialty]
                .compactMap(nonBlank)
                .joined(separator: " · ")
            if !who.isEmpty {
                Spacer()
                    .frame(height: SalusSpacing.sm)
                IconRow(systemImage: "person", text: who)
            }

            if appointment.status != .scheduled {
                Spacer()
                    .frame(height: SalusSpacing.sm)
                SalusStatusChip(label: Self.statusLabel(appointment.status))
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
    }

    /// `AppointmentDetailScreen.kt:233-254`. The maps button is **always** offered here where
    /// Kotlin offers it only when something resolves `geo:` — divergence (a), see `MapsLink.swift`.
    @ViewBuilder
    private func locationSection(_ location: String) -> some View {
        SalusSectionHeader(title: AppointmentsStrings.detailLocation)
        SalusCard {
            IconRow(systemImage: "mappin.and.ellipse", text: location)
            Spacer()
                .frame(height: SalusSpacing.sm)
            OpenMapsButton(location: location)
        }
        .padding(.horizontal, SalusSpacing.lg)
    }

    /// `AppointmentDetailScreen.kt:256-280` — hidden when the appointment has no notes and the
    /// profile has no health notes.
    @ViewBuilder
    private func notesSection(notes: String?) -> some View {
        let appointmentNotes = nonBlank(notes)
        if appointmentNotes != nil || state.healthNotes != nil {
            SalusSectionHeader(title: AppointmentsStrings.detailNotes)
            SalusCard {
                if let appointmentNotes {
                    Text(appointmentNotes)
                        .font(SalusTypography.bodyLarge.font)
                }
                if let healthNotes = state.healthNotes {
                    if appointmentNotes != nil {
                        Spacer()
                            .frame(height: SalusSpacing.md)
                    }
                    Text(AppointmentsStrings.detailHealthNotes)
                        .font(SalusTypography.labelMedium.font)
                        .tracking(SalusTypography.labelMedium.tracking)
                        .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                    Text(healthNotes)
                        .font(SalusTypography.bodyMedium.font)
                }
            }
            .padding(.horizontal, SalusSpacing.lg)
        }
    }

    /// `AppointmentDetailScreen.kt:282-300`.
    @ViewBuilder
    private func remindersSection(_ offsets: [Int]) -> some View {
        SalusSectionHeader(title: AppointmentsStrings.remindersLabel)
        SalusCard {
            ChipFlowLayout(spacing: SalusSpacing.sm) {
                ForEach(offsets.sorted(), id: \.self) { offset in
                    SalusStatusChip(label: offsetLabel(offset))
                }
            }
        }
        .padding(.horizontal, SalusSpacing.lg)
    }

    /// `AppointmentDetailScreen.kt:291-318` — three full-width pills. Compose emits them as
    /// children of the screen's own `Column(spacedBy = md)`, so they are spaced `md` here too.
    ///
    /// `fillsWidth: true` is Kotlin's `Modifier.fillMaxWidth()` on each of the three
    /// (`:302`, `:310`, `:316`); an outer `.frame(maxWidth: .infinity)` would only centre a
    /// text-width capsule in a full-width slot (`SalusPillButton.swift:35-39`).
    private var actions: some View {
        VStack(spacing: SalusSpacing.md) {
            SalusPillButton(
                text: AppointmentsStrings.detailEdit,
                fillsWidth: true,
                action: onEdit
            )

            // Only where a calendar editor exists to present. On any other platform this is the
            // empty view the brief calls for, rather than a button that opens nothing.
            #if canImport(EventKitUI)
                SalusPillButton(
                    text: AppointmentsStrings.addToCalendar,
                    // `canAddToCalendar = state.startEpochMs > 0L` (`:144`), passed straight
                    // through as `enabled` (`:307`) — nothing to propose until the bounds are
                    // derived.
                    enabled: state.startEpochMs > 0,
                    tonal: true,
                    systemImage: "calendar",
                    fillsWidth: true
                ) {
                    isAddingToCalendar = true
                }
            #endif

            SalusPillButton(
                text: AppointmentsStrings.detailDelete,
                tonal: true,
                fillsWidth: true
            ) {
                onEvent(.deleteClicked)
            }
        }
        // `Spacer(height = sm)` before the block (`AppointmentDetailScreen.kt:298`): the actions
        // sit one step further from the section above them than the sections sit from each other.
        .padding(.top, SalusSpacing.sm)
        .padding(.horizontal, SalusSpacing.lg)
    }

    /// `AppointmentDetailScreen.kt:151-164` — the dialog is shown for the appointment being
    /// deleted, so it disappears with it rather than naming a title that is no longer there.
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
        /// (`AppointmentDetailScreen.kt:377-388`).
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

    /// `AppointmentDetailScreen.kt:390-394`.
    private static func statusLabel(_ status: AppointmentStatus) -> String {
        switch status {
        case .cancelled: AppointmentsStrings.statusCancelled
        case .completed: AppointmentsStrings.statusCompleted
        case .scheduled: AppointmentsStrings.statusScheduled
        }
    }
}

/// `AppointmentDetailScreen.kt:352-367`.
private struct IconRow: View {
    let systemImage: String
    let text: String

    @Environment(\.salusTheme) private var theme

    var body: some View {
        HStack(spacing: SalusSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize))
                .foregroundStyle(theme.colorScheme.onSurfaceVariant)
                // Decoration: the text beside it already says what this is
                // (`contentDescription = null`).
                .accessibilityHidden(true)
            Text(text)
                .font(SalusTypography.bodyLarge.font)
        }
    }
}

/// `AppointmentDetailScreen.kt:235-243` — the `appointment_detail_open_maps` button.
///
/// Its own view so the `openURL` environment value is read where it is used; a `Button` whose
/// action reaches for an environment value of the enclosing screen would work, but this keeps the
/// one link the screen opens in one place.
private struct OpenMapsButton: View {
    let location: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        // `SalusPillButton(tonal = true, icon = Icons.Filled.Map)`
        // (`AppointmentDetailScreen.kt:237-242`) — content width, since Kotlin passes it no
        // `Modifier.fillMaxWidth()` unlike the three in the action block.
        SalusPillButton(
            text: AppointmentsStrings.detailOpenMaps,
            tonal: true,
            systemImage: "map"
        ) {
            guard let url = mapsURL(for: location) else { return }
            // `runCatching { startActivity(intent) }` (`AppointmentDetailScreen.kt:239`): no map
            // app is a legal state on both platforms, and the completion is what says so here.
            openURL(url) { _ in }
        }
    }
}

/// `AppointmentDetailScreen.kt:186-188`.
private let headerDatePattern = "EEEE, d MMMM yyyy"
/// `AppointmentDetailScreen.kt:189`.
private let timePattern = "HH:mm"
/// `AppointmentDetailScreen.kt:396`.
private let iconSize: CGFloat = 18

// MARK: - Previews

/// `AppointmentDetailScreen.kt:400-437`.
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
                startEpochMs: 1_776_000_000_000,
                endEpochMs: 1_776_001_800_000
            ),
            onEvent: { _ in },
            onEdit: {}
        )
    }
}

#Preview("Appointment detail — cancelled, no location") {
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
                    status: .cancelled,
                    reminderOffsetsMinutes: []
                ),
                startEpochMs: 1_777_000_000_000,
                endEpochMs: 1_777_002_700_000
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

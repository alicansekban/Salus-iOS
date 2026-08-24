// Ported from `feature/appointments/src/test/kotlin/com/alicansekban/salus/feature/appointments/
// ui/list/AppointmentsViewModelTest.kt` — all four cases, by name.
//
// Two mechanical differences from the Kotlin, both already settled elsewhere in this port:
// Turbine's `state.test { awaitItem() }` becomes reading `viewModel.state` after `waitUntil`,
// because the iOS state is an `@Observable` property rather than a `StateFlow`; and
// `MainDispatcherRule` has no twin — `@MainActor` on the suite is the whole mechanism.

import Foundation
import SalusCommon
import SalusModel
import SalusTesting
import Testing

@testable import FeatureAppointments

@Suite("AppointmentsViewModel")
@MainActor
struct AppointmentsViewModelTests {
    /// `AppointmentsViewModelTest.kt:34-36` — the same instant and zone.
    private static let now = Date(timeIntervalSince1970: 1_755_000_000)
    private static let zone = FixedSalusClock.defaultZone

    private let clock = FixedSalusClock(now: AppointmentsViewModelTests.now, timeZone: AppointmentsViewModelTests.zone)
    private let repository = FakeAppointmentsRepository(zone: AppointmentsViewModelTests.zone)
    private let deletes = TestDeletes()

    /// `AppointmentsViewModelTest.kt:58`.
    private func viewModel() -> AppointmentsViewModel {
        AppointmentsViewModel(repository: repository, pendingDeletes: deletes.controller, clock: clock)
    }

    /// `AppointmentsViewModelTest.kt:40-54`. Kotlin's `Duration` argument becomes seconds, which is
    /// what `Date.addingTimeInterval` takes; `toLocalDateTime(zone)` is `Date.wallClock(in:)`.
    private func appointment(_ id: String, startsIn seconds: TimeInterval) -> Appointment {
        Appointment(
            id: id,
            title: "Checkup \(id)",
            doctorName: nil,
            specialty: nil,
            location: nil,
            notes: nil,
            startsAt: Self.now.addingTimeInterval(seconds).wallClock(in: Self.zone),
            timeZone: Self.zone,
            durationMinutes: 60,
            status: .scheduled,
            reminderOffsetsMinutes: []
        )
    }

    /// `AppointmentsViewModelTest.kt:56-79`.
    @Test("upcoming sorted soonest first and past collapsed by default")
    func upcomingSortedSoonestFirstAndPastCollapsedByDefault() async {
        repository.setAppointments(
            appointment("late", startsIn: 7 * .day),
            appointment("soon", startsIn: 1 * .day),
            appointment("past", startsIn: -3 * .day)
        )
        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let loaded = viewModel.state

        #expect(loaded.upcoming.flatMap { section in section.items.map(\.id) } == ["soon", "late"])
        #expect(loaded.past.map(\.id) == ["past"])
        #expect(loaded.isPastExpanded == false)
    }

    /// `AppointmentsViewModelTest.kt:81-98`.
    @Test("toggle event expands and collapses the past section")
    func toggleEventExpandsAndCollapsesThePastSection() async {
        repository.setAppointments(appointment("past", startsIn: -1 * .day))
        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        #expect(viewModel.state.isPastExpanded == false)

        viewModel.onEvent(.togglePastSection)
        #expect(viewModel.state.isPastExpanded == true)

        viewModel.onEvent(.togglePastSection)
        #expect(viewModel.state.isPastExpanded == false)
    }

    /// `AppointmentsViewModelTest.kt:100-121`.
    @Test("upcoming is grouped into one section per calendar day")
    func upcomingIsGroupedIntoOneSectionPerCalendarDay() async {
        repository.setAppointments(
            appointment("morning", startsIn: 1 * .day),
            appointment("evening", startsIn: 1 * .day + 6 * .hour),
            appointment("next-week", startsIn: 7 * .day)
        )
        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let loaded = viewModel.state

        #expect(loaded.upcoming.count == 2)
        #expect(loaded.upcoming[0].items.map(\.id) == ["morning", "evening"])
        #expect(loaded.upcoming[1].items.map(\.id) == ["next-week"])
        #expect(loaded.upcoming[0].epochDay == loaded.todayEpochDay + 1)
    }

    /// `AppointmentsViewModelTest.kt:123-136`.
    @Test("empty repository yields empty sections")
    func emptyRepositoryYieldsEmptySections() async {
        let viewModel = viewModel()

        await waitUntil("the first emission") { !viewModel.state.isLoading }
        let loaded = viewModel.state

        #expect(loaded.upcoming.isEmpty)
        #expect(loaded.past.isEmpty)
    }
}

/// Kotlin's `1.days` / `6.hours` (`kotlin.time.Duration.Companion`), as the seconds a
/// `TimeInterval` counts. Exact 24-hour days, not calendar ones — the same arithmetic the Kotlin
/// test does.
extension TimeInterval {
    fileprivate static let day: TimeInterval = 86400
    fileprivate static let hour: TimeInterval = 3600
}

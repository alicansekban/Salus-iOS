// Ported from `feature/smoking/src/test/kotlin/com/alicansekban/salus/feature/smoking/ui/history/
// SmokingHistoryViewModelTest.kt` (the editing and delete regions; the state and attempt regions are
// in `SmokingHistoryViewModelTests.swift`).
//
// The ViewModel is exercised over the real calculator and the real `EditEvent` / `DeleteEvent`;
// only the store is fake. `advanceUntilIdle()` becomes `waitUntil`, and the Turbine
// `effects.test { awaitItem() }` becomes `consumeEffects()` after the write has landed.

import Foundation
import SalusSmoking
import SalusTesting
import Testing

@testable import FeatureSmoking

@MainActor
@Suite("SmokingHistoryViewModel editing", .timeLimit(.minutes(1)))
struct SmokingHistoryEditingTests {
    // MARK: Editing

    @Test("tapping a row opens its editor and an unknown id opens nothing")
    func tapOpensTheEditor() async {
        let fx = HistoryHarness()
        let vm = await HistoryHarness(events: [fx.smoked("a", at: "2026-03-10T09:15")]).loadedViewModel()

        vm.onEvent(.rowTapped("ghost"))
        #expect(vm.state.editing == nil)

        vm.onEvent(.rowTapped("a"))
        #expect(vm.state.editing?.id == "a")

        vm.onEvent(.editDismissed)
        #expect(vm.state.editing == nil)
    }

    @Test("editing the time of a slip to before the attempt moves it out of the attempt")
    func editingTheTimeMovesASlipOut() async throws {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("slip", at: "2026-02-20T10:00")])
        let vm = await harness.loadedViewModel()
        #expect(vm.state.attempts.first?.slipCount == 1)
        vm.onEvent(.rowTapped("slip"))

        // 42 days before 2026-03-10 12:00 is 2026-01-27 12:00: this lands a day earlier.
        vm.onEvent(.editSaved(EventEdit(
            eventId: "slip",
            atMs: fx.ms("2026-01-26T10:00"),
            units: 1,
            trigger: nil,
            intensity: nil
        )))
        await waitUntil("the editor to close") { vm.state.editing == nil && !vm.state.writing }

        let stored = try #require(harness.store.input.events.first)
        #expect(stored.occurredAtMs == fx.ms("2026-01-26T10:00"))
        // The re-derivation detaches it from the attempt.
        #expect(stored.attemptId == nil)
        await waitUntil("the attempt card to drop the slip") { vm.state.attempts.first?.slipCount == 0 }
        #expect(vm.state.editingId == nil)
    }

    @Test("an edit changes units, trigger and intensity")
    func editChangesUnitsTriggerAndIntensity() async throws {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("a", at: "2026-03-10T09:15")])
        let vm = await harness.loadedViewModel()
        vm.onEvent(.rowTapped("a"))

        vm.onEvent(
            .editSaved(EventEdit(
                eventId: "a",
                atMs: fx.ms("2026-03-10T09:30"),
                units: 3,
                trigger: .coffee,
                intensity: 5
            ))
        )
        await waitUntil("the write") { vm.state.editing == nil }

        let stored = try #require(harness.store.input.events.first)
        #expect(stored.units == 3)
        #expect(stored.trigger == .coffee)
        #expect(stored.intensity == 5)
        #expect(stored.occurredAtMs == fx.ms("2026-03-10T09:30"))
    }

    @Test("a time in the future is refused and nothing is written")
    func futureTimeIsRefused() async {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("a", at: "2026-03-10T09:15")])
        let vm = await harness.loadedViewModel()
        vm.onEvent(.rowTapped("a"))

        vm.onEvent(.editSaved(EventEdit(eventId: "a", atMs: fx.nowMs + hourMs, units: 1, trigger: nil, intensity: nil)))

        #expect(vm.consumeEffects() == [.showError(.future)])
        #expect(harness.store.commits == 0)
        // The editor stays open so the time can be corrected.
        #expect(vm.state.editing?.id == "a")
        #expect(!vm.state.writing)
    }

    @Test("a refused edit leaves the state as it was and says so")
    func refusedEditSaysSo() async {
        // A marker cannot move onto a day that already has an entry (contract 8.10).
        let fx = HistoryHarness()
        let harness = HistoryHarness(
            events: [
                fx.smoked("marker", at: "2026-03-09T09:00", units: 0),
                fx.smoked("entry", at: "2026-03-10T09:00", units: 2)
            ]
        )
        let vm = await harness.loadedViewModel()
        vm.onEvent(.rowTapped("marker"))

        vm.onEvent(.editSaved(EventEdit(
            eventId: "marker",
            atMs: fx.ms("2026-03-10T10:00"),
            units: 0,
            trigger: nil,
            intensity: nil
        )))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.invalid)])
        #expect(harness.store.input.events.first { $0.id == "marker" }?.occurredAtMs == fx.ms("2026-03-09T09:00"))
        #expect(vm.state.editing?.id == "marker")
        #expect(!vm.state.writing)
    }

    @Test("a storage fault is reported generically and the editor stays")
    func storageFaultIsGeneric() async {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("a", at: "2026-03-10T09:15")])
        let vm = await harness.loadedViewModel()
        vm.onEvent(.rowTapped("a"))
        harness.store.failure = FakeStorageFault()

        vm.onEvent(.editSaved(EventEdit(
            eventId: "a",
            atMs: fx.ms("2026-03-10T09:30"),
            units: 1,
            trigger: nil,
            intensity: nil
        )))
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.generic)])
        #expect(vm.state.editing?.id == "a")
        #expect(!vm.state.writing)
    }

    @Test("the none-today marker can become a real entry")
    func markerBecomesARealEntry() async throws {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("marker", at: "2026-03-10T09:00", units: 0)])
        let vm = await harness.loadedViewModel()
        vm.onEvent(.rowTapped("marker"))

        vm.onEvent(.editSaved(EventEdit(
            eventId: "marker",
            atMs: fx.ms("2026-03-10T09:00"),
            units: 2,
            trigger: nil,
            intensity: nil
        )))
        await waitUntil("the write") { vm.state.editing == nil }

        let stored = try #require(harness.store.input.events.first)
        #expect(stored.id == "marker")
        #expect(stored.units == 2)
    }

    @Test("a double tap on save writes once")
    func doubleTapOnSaveWritesOnce() async throws {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("a", at: "2026-03-10T09:15")])
        let vm = await harness.loadedViewModel()
        let gate = WriteGate()
        harness.store.gate = gate
        vm.onEvent(.rowTapped("a"))
        let callsBefore = harness.store.calls

        vm.onEvent(.editSaved(EventEdit(
            eventId: "a",
            atMs: fx.ms("2026-03-10T09:30"),
            units: 1,
            trigger: nil,
            intensity: nil
        )))
        vm.onEvent(.editSaved(EventEdit(
            eventId: "a",
            atMs: fx.ms("2026-03-10T09:45"),
            units: 1,
            trigger: nil,
            intensity: nil
        )))
        gate.open()
        await waitUntil("the write") { vm.state.editing == nil }

        #expect(harness.store.calls - callsBefore == 1)
        #expect(try #require(harness.store.input.events.first).occurredAtMs == fx.ms("2026-03-10T09:30"))
    }

    // MARK: Delete

    @Test("delete asks first and writes nothing until it is confirmed")
    func deleteAsksFirst() async {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("a", at: "2026-03-10T09:15")])
        let vm = await harness.loadedViewModel()
        vm.onEvent(.rowTapped("a"))

        vm.onEvent(.deleteTapped)
        #expect(vm.state.deleteConfirm)
        #expect(harness.store.commits == 0)

        vm.onEvent(.deleteDismissed)
        #expect(!vm.state.deleteConfirm)
        // The editor is still open behind the dialog.
        #expect(vm.state.editing?.id == "a")
        #expect(harness.store.input.events.count == 1)
    }

    @Test("a confirm that was never asked for deletes nothing")
    func unaskedConfirmDeletesNothing() async {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("a", at: "2026-03-10T09:15")])
        let vm = await harness.loadedViewModel()
        vm.onEvent(.rowTapped("a"))

        vm.onEvent(.deleteConfirmed)

        // `writing` flips synchronously with the tap, so a write that was wrongly started is seen
        // here and not only after the task has run.
        #expect(!vm.state.writing)
        #expect(harness.store.calls == 0)
        #expect(harness.store.input.events.count == 1)
    }

    @Test("a confirmed delete removes exactly that entry by its id")
    func confirmedDeleteRemovesThatEntry() async {
        let fx = HistoryHarness()
        let harness = HistoryHarness(
            events: [fx.smoked("early", at: "2026-03-09T09:15"), fx.smoked("late", at: "2026-03-10T11:00")]
        )
        let vm = await harness.loadedViewModel()
        vm.onEvent(.rowTapped("early"))
        vm.onEvent(.deleteTapped)

        vm.onEvent(.deleteConfirmed)
        await waitUntil("the delete") { vm.state.editing == nil && !vm.state.writing }

        // The later entry survives; delete is by id, not "the latest".
        #expect(harness.store.input.events.map(\.id) == ["late"])
        #expect(!vm.state.deleteConfirm)
        await waitUntil("the log to follow") { vm.state.days.flatMap(\.rows).map(\.id) == ["late"] }
    }

    @Test("deleting an entry that is already gone still succeeds")
    func deletingAGoneEntrySucceeds() async {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("a", at: "2026-03-10T09:15")])
        let vm = await harness.loadedViewModel()
        vm.onEvent(.rowTapped("a"))
        vm.onEvent(.deleteTapped)

        vm.onEvent(.deleteConfirmed)
        vm.onEvent(.deleteConfirmed)
        await waitUntil("the delete") { vm.state.editing == nil && !vm.state.writing }

        #expect(vm.pendingEffects.isEmpty)
        #expect(harness.store.input.events.isEmpty)
    }

    @Test("a double tap on confirm deletes once")
    func doubleTapOnConfirmDeletesOnce() async {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("a", at: "2026-03-10T09:15")])
        let vm = await harness.loadedViewModel()
        let gate = WriteGate()
        harness.store.gate = gate
        vm.onEvent(.rowTapped("a"))
        vm.onEvent(.deleteTapped)
        let callsBefore = harness.store.calls

        vm.onEvent(.deleteConfirmed)
        vm.onEvent(.deleteConfirmed)
        gate.open()
        await waitUntil("the delete") { vm.state.editing == nil }

        #expect(harness.store.calls - callsBefore == 1)
    }

    @Test("a refused delete drops the dialog, keeps the editor and says so")
    func failedDeleteKeepsTheEditor() async {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("a", at: "2026-03-10T09:15")])
        let vm = await harness.loadedViewModel()
        vm.onEvent(.rowTapped("a"))
        vm.onEvent(.deleteTapped)
        harness.store.failure = FakeStorageFault()

        vm.onEvent(.deleteConfirmed)
        await waitUntil("the error") { !vm.pendingEffects.isEmpty }

        #expect(vm.consumeEffects() == [.showError(.generic)])
        #expect(!vm.state.deleteConfirm)
        #expect(vm.state.editing?.id == "a")
        #expect(!vm.state.writing)
    }

    @Test("an editor whose entry vanished closes itself")
    func vanishedEntryClosesTheEditor() async throws {
        let fx = HistoryHarness()
        let harness = HistoryHarness(events: [fx.smoked("a", at: "2026-03-10T09:15")])
        let vm = await harness.loadedViewModel()
        vm.onEvent(.rowTapped("a"))
        vm.onEvent(.deleteTapped)

        // Deleted somewhere else (undo on the main screen) while the sheet and its dialog were open.
        try await DeleteEvent(store: harness.store)(eventId: "a")
        await waitUntil("the editor to close") { vm.state.editing == nil && vm.state.days.isEmpty }

        // No stale id is kept to reopen on the next snapshot, and the dialog goes with the sheet.
        #expect(vm.state.editingId == nil)
        #expect(!vm.state.deleteConfirm)
    }
}

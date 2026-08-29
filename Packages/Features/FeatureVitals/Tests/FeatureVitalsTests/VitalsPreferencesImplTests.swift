// Covers `data/VitalsPreferencesImpl.swift`.
//
// There is no `VitalsPreferencesImplTest.kt` to port — Android's implementation is a `map` +
// `distinctUntilChanged` over DataStore and is covered through the ViewModels — so every case here
// is iOS-only, the shape `CycleReminderSettingsImplTests` set. What they pin is the wiring: that
// the stream reads the Android-verbatim `glucose_unit` key and nobody else's, that it starts from
// the Android default, that the setter writes through, and that equal consecutive units are
// dropped (the `distinctUntilChanged` the cycle twin deliberately does not have).
//
// Each test gets its own throwaway `UserDefaults` suite, the shape `SalusSettingsTests`'
// `TestUserDefaults` set: Swift Testing runs suites in parallel, so a shared domain would let one
// test read another's writes.

import Foundation
import SalusModel
import SalusSettings
import Testing

@testable import FeatureVitals

@Suite("VitalsPreferencesImpl")
struct VitalsPreferencesImplTests {
    /// `Settings.kt:23` — `GlucoseUnit.MG_DL`, restated here so a silent change to the default
    /// fails a vitals test too.
    @Test("glucoseUnit starts from the Android default", .timeLimit(.minutes(1)))
    func glucoseUnitStartsFromTheAndroidDefault() async throws {
        let fixture = try Fixture()

        #expect(await fixture.preferences.glucoseUnit.firstValue() == .mgDl)
    }

    /// `VitalsPreferencesImpl.kt:17-19` — the setter is the *app-wide* toggle, since the glucose
    /// editor's segmented control is the only place the unit is chosen.
    @Test("setGlucoseUnit writes the unit through", .timeLimit(.minutes(1)))
    func setGlucoseUnitWritesTheUnitThrough() async throws {
        let fixture = try Fixture()

        fixture.preferences.setGlucoseUnit(.mmolL)

        #expect(await fixture.preferences.glucoseUnit.firstValue() == .mmolL)
    }

    /// The key is Android-verbatim (`SettingsKeys.swift`), and the stream reads exactly it: a value
    /// written straight into the suite under that name comes back out, so nothing in between is
    /// inventing its own spelling — and the stored form is the Kotlin constant name.
    @Test("glucoseUnit reads the Android-verbatim glucose_unit key", .timeLimit(.minutes(1)))
    func glucoseUnitReadsTheAndroidVerbatimKey() async throws {
        let fixture = try Fixture()
        fixture.defaults.set("MMOL_L", forKey: "glucose_unit")

        #expect(await fixture.preferences.glucoseUnit.firstValue() == .mmolL)
    }

    /// `VitalsPreferencesImpl.kt:14-15` — the `distinctUntilChanged` that `CycleReminderSettings`
    /// deliberately does not have. `DefaultsValueStream` is distinct over the *whole*
    /// `UserSettings`, so changing the theme emits a new settings value whose glucose unit is the
    /// one before it; without the narrowing's own dedupe every unrelated setting change would
    /// re-run the glucose branch of the vitals screen.
    @Test("equal consecutive units are dropped", .timeLimit(.minutes(1)))
    @MainActor
    func equalConsecutiveUnitsAreDropped() async throws {
        let fixture = try Fixture()
        let collector = UnitCollector()
        let units = fixture.preferences.glucoseUnit
        let task = Task { @MainActor in
            for await unit in units {
                collector.append(unit)
            }
        }
        defer { task.cancel() }
        await waitUntil("the stored unit") { collector.values.count == 1 }

        // A change to another setting: a new `UserSettings`, the same glucose unit.
        fixture.dataSource.setThemeMode(.dark)
        await drain()

        #expect(collector.values == [.mgDl])

        // The stream is still live — only *equal* consecutive units are dropped.
        fixture.preferences.setGlucoseUnit(.mmolL)
        await waitUntil("the changed unit") { collector.values.count == 2 }

        #expect(collector.values == [.mgDl, .mmolL])
    }

    /// Hands the cooperative pool to everything already runnable, so a value the stream *would*
    /// have delivered has arrived by the time the expectation is checked. `waitUntil` cannot be
    /// used for an absence: it records a failure when its condition never holds.
    @MainActor
    private func drain() async {
        for _ in 0 ..< 200 {
            await Task.yield()
        }
    }

    /// A throwaway suite plus the preferences over it. A class rather than a struct because
    /// `deinit` is the only teardown hook that fires whether the test passed, failed or threw —
    /// `TestUserDefaults`' reason.
    private final class Fixture {
        let suiteName: String
        let defaults: UserDefaults
        let dataSource: SalusPreferencesDataSource
        let preferences: VitalsPreferencesImpl

        init() throws {
            let suiteName = "salus-vitals-test-\(UUID().uuidString)"
            self.suiteName = suiteName
            defaults = try #require(
                UserDefaults(suiteName: suiteName),
                "UserDefaults refused the suite name \(suiteName)"
            )
            dataSource = SalusPreferencesDataSource(
                defaults: defaults,
                appLockFlagStore: InMemoryAppLockFlagStore()
            )
            preferences = VitalsPreferencesImpl(dataSource: dataSource)
        }

        deinit {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}

/// Every unit the stream delivered, in order. On the main actor because the collecting task and
/// the expectations both run there, which is what makes the sequence an observation rather than a
/// race.
@MainActor
private final class UnitCollector {
    private(set) var values: [GlucoseUnit] = []

    func append(_ unit: GlucoseUnit) {
        values.append(unit)
    }
}

extension AsyncStream {
    /// The stream's current value — the twin of Kotlin's `flow.first()`. `glucoseUnit` emits the
    /// stored unit as soon as a collector arrives, so this awaits a real element instead of
    /// sleeping.
    fileprivate func firstValue() async -> Element? {
        for await value in self {
            return value
        }
        return nil
    }
}

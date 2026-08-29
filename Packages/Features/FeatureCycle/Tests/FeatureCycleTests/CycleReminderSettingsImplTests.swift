// Covers `data/CycleReminderSettingsImpl.swift`.
//
// There is no `CycleReminderSettingsImplTest.kt` to port — Android's implementation is a `map` over
// DataStore and is covered through the ViewModel — so every case here is iOS-only. What they pin is
// the wiring: that `config` reads the three Android-verbatim keys and nobody else's, that it starts
// from the Android defaults, that each setter writes the key it names, and that a live collector
// sees a change rather than a stale trio.
//
// Each test gets its own throwaway `UserDefaults` suite, the shape `SalusSettingsTests`'
// `TestUserDefaults` set: Swift Testing runs suites in parallel, so a shared domain would let one
// test read another's writes.

import Foundation
import SalusModel
import SalusSettings
import Testing

@testable import FeatureCycle

/// One setter row: what to call, and the `CycleReminderConfig` the store must read back.
///
/// Every field of the expectation is spelled out, so a setter that wrote a second key — or the
/// wrong key — fails the comparison rather than passing on the field it did touch.
struct CycleReminderSetterRow: Sendable, CustomStringConvertible {
    let name: String
    let apply: @Sendable (CycleReminderSettingsImpl) -> Void
    let expected: CycleReminderConfig

    var description: String { name }
}

/// The three setters of `CycleReminderSettingsImpl.kt:21-31`, in declaration order.
let cycleReminderSetterRows: [CycleReminderSetterRow] = [
    CycleReminderSetterRow(
        name: "setEnabled",
        apply: { $0.setEnabled(true) },
        expected: CycleReminderConfig(enabled: true, leadDays: 1, minuteOfDay: 540)
    ),
    CycleReminderSetterRow(
        name: "setLeadDays",
        apply: { $0.setLeadDays(3) },
        expected: CycleReminderConfig(enabled: false, leadDays: 3, minuteOfDay: 540)
    ),
    CycleReminderSetterRow(
        name: "setMinuteOfDay",
        apply: { $0.setMinuteOfDay(21 * 60) },
        expected: CycleReminderConfig(enabled: false, leadDays: 1, minuteOfDay: 21 * 60)
    )
]

@Suite("CycleReminderSettingsImpl")
struct CycleReminderSettingsImplTests {
    /// `Settings.kt:18-33`, restated here so a silent change to a default fails a cycle test too:
    /// reminders off, one day ahead, 09:00 local.
    @Test("config starts from the Android defaults", .timeLimit(.minutes(1)))
    func configStartsFromTheAndroidDefaults() async throws {
        let fixture = try Fixture()

        let config = await fixture.settings.config.firstValue()

        #expect(config == CycleReminderConfig(enabled: false, leadDays: 1, minuteOfDay: 540))
    }

    @Test("each setter writes its own key through", .timeLimit(.minutes(1)), arguments: cycleReminderSetterRows)
    func eachSetterWritesItsOwnKeyThrough(_ row: CycleReminderSetterRow) async throws {
        let fixture = try Fixture()

        row.apply(fixture.settings)

        #expect(await fixture.settings.config.firstValue() == row.expected)
    }

    /// The three keys are Android-verbatim (`SettingsKeys.swift:25-27`), and `config` reads exactly
    /// them: a value written straight into the suite under those names comes back out of the
    /// stream, so nothing in between is inventing its own spelling.
    @Test("config reads the three Android-verbatim keys", .timeLimit(.minutes(1)))
    func configReadsTheThreeAndroidVerbatimKeys() async throws {
        let fixture = try Fixture()
        fixture.defaults.set(true, forKey: "cycle_reminder_enabled")
        fixture.defaults.set(4, forKey: "cycle_reminder_lead_days")
        fixture.defaults.set(7 * 60 + 30, forKey: "cycle_reminder_minute_of_day")

        let config = await fixture.settings.config.firstValue()

        #expect(config == CycleReminderConfig(enabled: true, leadDays: 4, minuteOfDay: 7 * 60 + 30))
    }

    /// A collector already on the stream is handed the new trio, which is what keeps the reminder
    /// scheduler from re-running against the options as they were when the screen opened.
    @Test("a live collector sees a setter's change", .timeLimit(.minutes(1)))
    func aLiveCollectorSeesASettersChange() async throws {
        let fixture = try Fixture()
        var iterator = fixture.settings.config.makeAsyncIterator()
        #expect(await iterator.next() == CycleReminderConfig(enabled: false, leadDays: 1, minuteOfDay: 540))

        fixture.settings.setLeadDays(2)

        #expect(await iterator.next() == CycleReminderConfig(enabled: false, leadDays: 2, minuteOfDay: 540))
    }

    /// A throwaway suite plus the settings impl over it. A class rather than a struct because
    /// `deinit` is the only teardown hook that fires whether the test passed, failed or threw —
    /// `TestUserDefaults`' reason.
    private final class Fixture {
        let suiteName: String
        let defaults: UserDefaults
        let settings: CycleReminderSettingsImpl

        init() throws {
            let suiteName = "salus-cycle-test-\(UUID().uuidString)"
            self.suiteName = suiteName
            defaults = try #require(
                UserDefaults(suiteName: suiteName),
                "UserDefaults refused the suite name \(suiteName)"
            )
            settings = CycleReminderSettingsImpl(
                dataSource: SalusPreferencesDataSource(
                    defaults: defaults,
                    appLockFlagStore: InMemoryAppLockFlagStore()
                )
            )
        }

        deinit {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}

extension AsyncStream {
    /// The stream's current value — the twin of Kotlin's `flow.first()`. `config` emits the stored
    /// trio as soon as a collector arrives, so this awaits a real element instead of sleeping.
    fileprivate func firstValue() async -> Element? {
        for await value in self {
            return value
        }
        return nil
    }
}

// The twin of Android's `feature/settings/src/test/kotlin/.../data/AppCompatLocaleControllerTest.kt`,
// which has no test class of its own on Android either: the Kotlin controller is a thin wrapper
// around `AppCompatDelegate`, and the read/write round-trip is exercised end-to-end on device.
// The iOS controller carries its own mapping — `AppleLanguages` array ↔ `AppLanguage` — so each
// arm of that mapping gets a test here.
//
// The scratch `UserDefaults` is the same UUID-named-suite shape
// `SettingsPreferencesImplTests.ScratchUserDefaults` uses.

import Foundation
import Testing

@testable import FeatureSettings

@Suite("UserDefaultsAppLocaleController")
struct UserDefaultsAppLocaleControllerTests {
    /// A fresh controller on a throwaway suite.
    private func makeController() throws -> (UserDefaultsAppLocaleController, ScratchUserDefaultsSuite) {
        let env = try ScratchUserDefaultsSuite()
        let controller = UserDefaultsAppLocaleController(defaults: env.defaults)
        return (controller, env)
    }

    @Test("an untouched store reports .system")
    func untouchedStoreReportsSystem() throws {
        let (controller, _) = try makeController()

        #expect(controller.current() == .system)
    }

    @Test("apply(.turkish) stores ['tr'] and current() reports .turkish")
    func applyTurkishStoresAndReports() throws {
        let (controller, env) = try makeController()

        controller.apply(.turkish)

        // `persistentDomain` reads only what this suite wrote — the global `AppleLanguages` does
        // not bleed through, the way it does for `object(forKey:)`.
        let suiteKeys = env.defaults.persistentDomain(forName: env.suiteName) ?? [:]
        #expect(suiteKeys["AppleLanguages"] as? [String] == ["tr"])
        #expect(controller.current() == .turkish)
    }

    @Test("apply(.english) stores ['en'] and current() reports .english")
    func applyEnglishStoresAndReports() throws {
        let (controller, env) = try makeController()

        controller.apply(.english)

        let suiteKeys = env.defaults.persistentDomain(forName: env.suiteName) ?? [:]
        #expect(suiteKeys["AppleLanguages"] as? [String] == ["en"])
        #expect(controller.current() == .english)
    }

    @Test("apply(.system) removes the key and current() reports .system")
    func applySystemRemovesKeyAndReportsSystem() throws {
        let (controller, env) = try makeController()
        // Start from a non-system state so the removal is observable.
        env.defaults.set(["tr"], forKey: "AppleLanguages")
        #expect(controller.current() == .turkish)

        controller.apply(.system)

        // `object(forKey:)` searches the suite domain then the *global* domain, and
        // `AppleLanguages` is a key the system populates globally — so after removal the global
        // value bleeds through and `object(forKey:)` is non-nil. The suite's own persistent
        // domain is the honest "we removed what we wrote" check, and it is what `current()`
        // reads against in production too (`.standard` has no suite to inherit from a test).
        let suiteKeys = env.defaults.persistentDomain(forName: env.suiteName) ?? [:]
        #expect(suiteKeys["AppleLanguages"] == nil)
        // `["en-TR", "tr-TR"]` from the global domain does not match `"tr"` or `"en"` exactly, so
        // `current()` falls through to `.system` — the observable contract.
        #expect(controller.current() == .system)
    }

    @Test("an unknown entry falls back to .system")
    func unknownEntryFallsBackToSystem() throws {
        let (controller, env) = try makeController()
        env.defaults.set(["fr"], forKey: "AppleLanguages")

        #expect(controller.current() == .system)
    }

    @Test("an untouched suite reports .system")
    func untouchedStoreReportsSystem2() throws {
        let (controller, _) = try makeController()
        #expect(controller.current() == .system)
    }
}

/// One throwaway `UserDefaults` suite per test — the twin of
/// `SettingsPreferencesImplTests.ScratchUserDefaults`, restated so each suite is self-contained.
final class ScratchUserDefaultsSuite {
    let suiteName: String
    let defaults: UserDefaults

    init() throws {
        let suiteName = "salus-locale-test-\(UUID().uuidString)"
        self.suiteName = suiteName
        defaults = try #require(
            UserDefaults(suiteName: suiteName),
            "UserDefaults refused the suite name \(suiteName)"
        )
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

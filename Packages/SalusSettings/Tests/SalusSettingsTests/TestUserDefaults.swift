import Foundation
import Testing

/// A throwaway `UserDefaults` suite, one per test, wiped when the test's instance goes away.
///
/// The Android tests get their isolation from JUnit's `TemporaryFolder`
/// (`AiUsageDataSourceTest.kt:28-29`); a named suite is the `UserDefaults` twin. The name carries
/// a fresh UUID so tests running in parallel — Swift Testing's default — cannot see each other's
/// writes, and `removePersistentDomain` in `deinit` keeps the plist off the developer's machine.
///
/// A class rather than a struct on purpose: `deinit` is the only teardown hook a value type has
/// no equivalent for, and it fires whether the test passed, failed or threw.
final class TestUserDefaults {
    let suiteName: String
    let defaults: UserDefaults

    init() throws {
        let suiteName = "salus-test-\(UUID().uuidString)"
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

extension AsyncStream {
    /// The stream's current value — the twin of Kotlin's `flow.first()`
    /// (`AiUsageDataSourceTest.kt:166`).
    ///
    /// Both data sources emit the stored value as soon as a consumer arrives, so this awaits a
    /// real element instead of sleeping; leaving the loop terminates the stream, exactly as
    /// `first()` cancels its collector.
    func firstValue() async -> Element? {
        for await value in self {
            return value
        }
        return nil
    }
}

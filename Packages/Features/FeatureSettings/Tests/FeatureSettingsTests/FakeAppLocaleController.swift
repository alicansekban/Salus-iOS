// A ``AppLocaleController`` whose current value a test sets, for `MoreViewModelTests` (T4).
//
// No Android twin — the Kotlin `MoreViewModelTest` mocks the controller with a fake Kotlin would
// generate from the interface; on iOS the fake is hand-written here, the same shape
// `FakeSettingsPreferences.swift` uses.

import Foundation

@testable import FeatureSettings

/// An ``AppLocaleController`` whose `current()` answer and `apply(_:)` record a test drives.
final class FakeAppLocaleController: AppLocaleController, @unchecked Sendable {
    private let lock = NSLock()

    private var currentLanguage: AppLanguage
    private(set) var applied: [AppLanguage] = []

    init(current: AppLanguage = .system) {
        currentLanguage = current
    }

    func current() -> AppLanguage {
        lock.lock()
        defer { lock.unlock() }
        return currentLanguage
    }

    func apply(_ language: AppLanguage) {
        lock.lock()
        currentLanguage = language
        applied.append(language)
        lock.unlock()
    }
}

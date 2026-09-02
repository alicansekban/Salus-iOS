// The live per-app language switch — the iOS twin of what appcompat does for Android when
// `AppCompatDelegate.setApplicationLocales` recreates the activity: every string the app draws
// resolves in the newly picked language, right now, without a relaunch.
//
// Why this exists. `String(localized:bundle:)` against `Bundle.module` picks the `.lproj` from the
// process's launch-time language list (`AppleLanguages`), and that choice is fixed for the life of
// the process. Writing the key changes the *next* launch only — which is what the Settings screen
// used to say in a footnote, and what the release QA pass called a bad experience. The fix is to
// stop asking the process: every `…Strings` helper routes its lookup through ``string(_:bundle:)``,
// which resolves against the picked language's own `.lproj` sub-bundle instead. `AppleLanguages`
// is still written (`UserDefaultsAppLocaleController`) so the next launch — and the system's own
// UI, alerts and share sheets — agree with the pick.
//
// Two halves, because two audiences read the language:
//
//   * ``SalusLocalization`` — the lookup. A process-wide value behind a lock, readable from any
//     isolation, because `…Strings` accessors are static and are called from wherever a string is
//     needed (a ViewModel, a notification scheduler). Process-wide on purpose: Android's
//     `Resources` configuration is process-wide too, and 13 static enums cannot be injected into.
//   * ``SalusLocaleState`` — the observation. A main-actor `@Observable` mirror the shell reads in
//     `RootView.body`, so a change re-renders the tree that draws the strings. It is the `recreate()`.
//
// `nil` means "follow the device". That is resolved here too, rather than left to the bundle:
// the bundle would answer with the launch-time language, and a user switching *back* to "System"
// would see nothing happen until the next launch — the same bug in a smaller coat.

import Foundation
import Observation

/// Process-wide per-app language override, and the string lookup that honours it.
public enum SalusLocalization {
    /// The language every string resolves in: a BCP-47 code the catalogs carry (`"tr"`, `"en"`),
    /// or `nil` to follow the device.
    public static var languageCode: String? {
        storage.read { $0.languageCode }
    }

    /// Applies a language to the running process. Call from the one place that owns the pick
    /// (`AppLocaleController.apply`); everything that draws strings follows on its next render.
    public static func setLanguageCode(_ code: String?) {
        storage.write {
            $0.languageCode = code
            $0.bundles.removeAll()
        }
        if Thread.isMainThread {
            MainActor.assumeIsolated { SalusLocaleState.shared.languageCode = code }
        } else {
            Task { @MainActor in SalusLocaleState.shared.languageCode = code }
        }
    }

    /// `String(localized:bundle:)`, resolved in ``languageCode`` rather than the process language.
    ///
    /// Falls back to `bundle` itself when it carries no `.lproj` for the picked language — which is
    /// also what happens under `swift test`, where the catalog is copied verbatim and no table
    /// exists: the lookup returns the key, exactly as before.
    public static func string(_ key: String, bundle: Bundle) -> String {
        String(localized: String.LocalizationValue(key), bundle: localizedBundle(bundle))
    }

    /// `bundle`'s sub-bundle for ``languageCode`` (or, for `nil`, for the device's first preferred
    /// language the bundle supports). Cached per bundle until the language changes.
    public static func localizedBundle(_ bundle: Bundle) -> Bundle {
        storage.write { state in
            if let cached = state.bundles[bundle.bundlePath] {
                return cached
            }
            let resolved = resolve(bundle, code: state.languageCode)
            state.bundles[bundle.bundlePath] = resolved
            return resolved
        }
    }

    private static func resolve(_ bundle: Bundle, code: String?) -> Bundle {
        let wanted = code ?? Bundle.preferredLocalizations(
            from: bundle.localizations,
            forPreferences: Locale.preferredLanguages
        ).first
        guard let wanted,
              let path = bundle.path(forResource: wanted, ofType: "lproj"),
              let localized = Bundle(path: path)
        else {
            return bundle
        }
        return localized
    }

    private struct State {
        var languageCode: String?
        var bundles: [String: Bundle] = [:]
    }

    /// The one mutable value, behind its lock. A class rather than a `nonisolated(unsafe)` static
    /// so the unsafety is confined to the two accessors that take the lock.
    private final class Storage: @unchecked Sendable {
        private let lock = NSLock()
        private var state = State()

        func read<T>(_ body: (State) -> T) -> T {
            lock.withLock { body(state) }
        }

        func write<T>(_ body: (inout State) -> T) -> T {
            lock.withLock { body(&state) }
        }
    }

    private static let storage = Storage()
}

/// The main-actor mirror of ``SalusLocalization/languageCode`` the shell observes to re-render.
@MainActor
@Observable
public final class SalusLocaleState {
    public static let shared = SalusLocaleState()

    /// Kept in step by ``SalusLocalization/setLanguageCode(_:)``; `nil` follows the device.
    public internal(set) var languageCode: String?

    /// The `Locale` the shell puts in the environment for date and number formatting, or `nil` to
    /// leave the system value in place.
    public var locale: Locale? {
        languageCode.map { Locale(identifier: $0) }
    }

    private init() {}
}

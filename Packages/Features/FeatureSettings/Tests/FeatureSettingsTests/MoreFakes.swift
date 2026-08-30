// The two T4 fakes the `MoreViewModelTest` needs that are not T3 fakes: a `ProfileRepository` whose
// profile a test sets and re-emits, and a `PaywallRequester` that records the sources it was asked
// to show. The T3 fakes — `FakeSettingsPreferences`, `FakeAppLocaleController`,
// `FakeMorePremiumStatus` — are reused and extended where the 20 cases need push propagation.
//
// No Android twin — the Kotlin `MoreViewModelTest` declares its `FakeProfileRepository`,
// `FakePremiumRepository` and `FakePaywallController` inline; the iOS fakes live in their own files
// so the M9 `PaywallController` swap and any later test can reuse them.

import Foundation
import SalusModel
import SalusProfile

@testable import FeatureSettings

/// A ``ProfileRepository`` whose profile a test sets and re-emits on every write — the twin of the
/// Kotlin `MoreViewModelTest`'s `FakeProfileRepository(profiles: MutableStateFlow<Profile?>)` and
/// of `ProfileViewModelTest`'s, which adds the `saved` list (`ProfileViewModelTest.kt:23-35`).
///
/// `@unchecked Sendable` over a lock for the same reason `FakeSettingsPreferences.swift` is: the
/// protocol's stream is not `@MainActor`-isolated. Push-capable so the "changing sex updates
/// visibility without recreating the view model" case can flip the profile after the ViewModel has
/// subscribed and see the new value propagate — the same shape `FakeMorePremiumStatus` uses.
final class FakeProfileRepository: ProfileRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var profileValue: Profile?
    private var savedProfiles: [Profile] = []
    private var continuations: [UUID: AsyncThrowingStream<Profile?, any Error>.Continuation] = [:]

    /// Every profile `saveProfile` was handed, in order — `ProfileViewModelTest.kt:25` (`saved`).
    /// A write the ViewModel was supposed to refuse shows up here as an extra element, which is
    /// what the three "writes nothing" cases assert against.
    var saved: [Profile] {
        lock.lock()
        defer { lock.unlock() }
        return savedProfiles
    }

    init(profile: Profile? = nil) {
        profileValue = profile
    }

    func observeProfile() -> AsyncThrowingStream<Profile?, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let current = profileValue
            lock.unlock()

            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
        }
    }

    func getProfile() async throws -> Profile? {
        getProfileSync()
    }

    /// The synchronous helper keeps `NSLock` out of an asynchronous context, which Swift 6
    /// disallows — the same constraint `FakeSettingsPreferences`'s setters satisfy.
    private func getProfileSync() -> Profile? {
        lock.lock()
        defer { lock.unlock() }
        return profileValue
    }

    func saveProfile(_ profile: Profile) async throws {
        recordSave(profile)
        setProfile(profile)
    }

    /// Split out for the same reason `getProfileSync` is: `NSLock` may not be held across a
    /// suspension point under Swift 6.
    private func recordSave(_ profile: Profile) {
        lock.lock()
        savedProfiles.append(profile)
        lock.unlock()
    }

    /// The twin of `FakeProfileRepository.profiles.value = …` — flips the profile and pushes it to
    /// every open stream.
    func setProfile(_ profile: Profile?) {
        lock.lock()
        profileValue = profile
        let pending = Array(continuations.values)
        lock.unlock()
        for continuation in pending {
            continuation.yield(profile)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}

/// A ``PaywallRequester`` that records every `source` it was asked to show — the twin of the
/// Kotlin `MoreViewModelTest`'s `PaywallController`, whose `request` `StateFlow` the test reads.
///
/// `@MainActor` because every `MoreViewModel` event handler that calls `show(_:)` runs on the main
/// actor, and the recorder is read from the same actor in the test — no cross-actor hop, no lock.
@MainActor
final class FakePaywallRequester: PaywallRequester {
    /// The sources `show(_:)` was called with, in order. The Kotlin test reads
    /// `paywallController.request.value?.source` (the latest); the iOS test reads `last` for the
    /// same answer and `sources` when it wants the whole trail.
    private(set) var sources: [PaywallSource] = []

    func show(_ source: PaywallSource) {
        sources.append(source)
    }

    /// The most recent source, or nil if `show` was never called — the twin of
    /// `paywallController.request.value?.source`.
    var last: PaywallSource? {
        sources.last
    }
}

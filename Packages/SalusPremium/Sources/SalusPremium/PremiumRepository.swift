import Foundation
import Observation

/// The app's single source of truth for whether premium features are unlocked.
///
/// The ported twin of Android's `PremiumRepository` (`PremiumRepository.kt:9-21`), whose
/// `StateFlow<PremiumStatus>` becomes an `AsyncStream<PremiumStatus>`: it yields the current
/// status on subscription, then once per change, and never finishes.
public protocol PremiumRepository: Sendable {
    /// Emits the current status on subscription, then once per change.
    var status: AsyncStream<PremiumStatus> { get }

    /// Re-reads the entitlement from the store, e.g. after a purchase or a restore.
    ///
    /// A store that does not answer leaves the status untouched — offline, the last known
    /// entitlement stands.
    func refresh() async
}

/// Keeps ``currentStatus`` in step with the store by collecting ``PurchasesGateway/customerUpdates``
/// for the life of the instance.
///
/// The status starts ``PremiumStatus/free``: until the store answers, the user is not entitled,
/// so a slow or unconfigured SDK can never hand out premium features. Ported 1:1 from
/// `PremiumRepository.kt:23-53` — the Android `CoroutineScope` that drives the collection maps to
/// a `Task` owned by the instance, and the `MutableStateFlow` becomes ``currentStatus``, read
/// directly by tests just as Android reads `status.value`. The ``status`` stream is for consumers
/// (a ViewModel or a view).
@MainActor
@Observable
public final class PremiumRepositoryImpl: PremiumRepository {
    /// The latest status — the twin of Android's `_status.value`, read directly by tests.
    public private(set) var currentStatus: PremiumStatus = .free

    private let gateway: any PurchasesGateway
    // swiftlint:disable:next modifier_order
    private nonisolated let currentStatusStream: CurrentValueStream<PremiumStatus>

    public init(gateway: any PurchasesGateway) {
        self.gateway = gateway
        currentStatusStream = CurrentValueStream(.free)

        // The twin of `scope.launch { gateway.customerUpdates.collect { _status.value = ... } }`.
        Task { [weak self] in
            guard let self else { return }
            for await snapshot in gateway.customerUpdates {
                apply(snapshot)
            }
        }
    }

    // swiftlint:disable modifier_order
    /// The ported twin of `StateFlow`: yields the current value on subscription, then once per
    /// change (`PremiumRepositoryImplTest` reads ``currentStatus`` directly, the Android test reads
    /// `status.value`; this stream serves consumers). `nonisolated` because the backer is itself
    /// thread-safe and the protocol requires it outside the main actor.
    public nonisolated var status: AsyncStream<PremiumStatus> {
        currentStatusStream.stream
    }
    // swiftlint:enable modifier_order

    public func refresh() async {
        // A nil answer means the store was unreachable, not that the user is free: dropping a
        // paying user to FREE on a flaky network would take away what they bought.
        guard let snapshot = await gateway.currentCustomer() else { return }
        apply(snapshot)
    }

    private func apply(_ snapshot: CustomerSnapshot) {
        currentStatus = premiumStatusOf(
            entitlementActive: snapshot.entitlementActive,
            hasBillingIssue: snapshot.hasBillingIssue
        )
        currentStatusStream.send(currentStatus)
    }
}

/// Emits the current value on subscription, then once per `send(_:)`, and never finishes — the
/// same contract `MutableStateFlow` keeps (and the shape `CurrentValueStream` keeps in
/// `MoreViewModel.swift`). `@unchecked Sendable` over a lock because the value is mutable state
/// shared between the main-actor repository and the consumers who iterate the stream.
private final class CurrentValueStream<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]

    /// The stream, built fresh per call so a re-subscribe re-seeds from the current value.
    var stream: AsyncStream<Value> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let current = value
            lock.unlock()

            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
        }
    }

    init(_ value: Value) {
        self.value = value
    }

    /// Updates the value and pushes it to every open stream — the twin of `MutableStateFlow.value =`.
    func send(_ newValue: Value) {
        lock.lock()
        value = newValue
        let continuations = Array(continuations.values)
        lock.unlock()
        for continuation in continuations {
            continuation.yield(newValue)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        continuations[id] = nil
    }
}

// Ported from `core/ui/.../snackbar/SalusSnackbarController.kt:12-40` — plus the parts of the
// Android behaviour that live in Material rather than in Salus, because iOS has no Material.
//
// On Android the controller is a `Channel` and the state machine belongs to
// `SnackbarHostState`/`SnackbarHost`: one snackbar at a time, the rest queued behind it, a timeout
// per duration, and the action callback fired only on `SnackbarResult.ActionPerformed`
// (`SalusApp.kt:113-122`). SwiftUI ships no snackbar, so that machine is here and its Android
// source is cited line by line below.
//
// Two departures from the Kotlin, both forced and both recorded in the iOS-M2 plan:
//
//   * `SnackbarRequest` carries **resolved strings, not `@StringRes` ids**. Kotlin can pass an id
//     because every id resolves against one `Context`; on iOS a feature's strings live in its own
//     `Bundle.module` and the host is mounted in the shell, which cannot reach them. So the caller
//     resolves — the feature knows its bundle, the shell only draws.
//   * The Kotlin `interface` + `Impl` pair collapses into one `@Observable` class. SwiftUI observes
//     a concrete type, and the interface bought Kotlin a test seam this class does not need: it has
//     no dependencies to fake beyond the injected sleep.

import Foundation
import Observation

/// How long a snackbar stays up. The twin of `androidx.compose.material3.SnackbarDuration`
/// (`SnackbarHost.kt:286-307`), whose numbers the Salus app inherits unchanged.
public enum SnackbarDuration: Sendable, Equatable {
    case short
    case long
    case indefinite

    /// `SnackbarDuration.toMillis` (`SnackbarHost.kt:302-307`). `nil` is Kotlin's `Long.MAX_VALUE`,
    /// which is "never" written as a number.
    public var milliseconds: Int? {
        switch self {
        case .short: 4000
        case .long: 10000
        case .indefinite: nil
        }
    }

    /// What `SnackbarHostState.showSnackbar` picks when the caller names no duration
    /// (`SnackbarHost.kt:104-105`) — and `SalusApp.kt:116-119` is exactly that call.
    public static func `default`(hasActionLabel: Bool) -> SnackbarDuration {
        hasActionLabel ? .indefinite : .short
    }
}

/// One snackbar to show (`SalusSnackbarController.kt:12-16`).
public struct SnackbarRequest: Identifiable {
    public let id = UUID()
    public let message: String
    public let actionLabel: String?
    public let onAction: (() -> Void)?
    public let duration: SnackbarDuration

    /// - Parameter duration: `nil` reproduces Material's own default rule — short without an
    ///   action label, indefinite with one.
    public init(
        message: String,
        actionLabel: String? = nil,
        onAction: (() -> Void)? = nil,
        duration: SnackbarDuration? = nil
    ) {
        self.message = message
        self.actionLabel = actionLabel
        self.onAction = onAction
        self.duration = duration ?? .default(hasActionLabel: actionLabel != nil)
    }
}

/// Publishes snackbars for the single `SalusSnackbarHost` in the app shell.
///
/// A screen cannot host its own: deleting from a detail screen pops it, and the snackbar has to
/// appear on the list underneath. This mirrors the Navigator — the feature publishes, the shell
/// performs (`SalusSnackbarController.kt:18-24`).
@MainActor
@Observable
public final class SalusSnackbarController {
    /// The snackbar on screen, or `nil`. The twin of `SnackbarHostState.currentSnackbarData`.
    public private(set) var current: SnackbarRequest?

    /// Requests waiting their turn. Kotlin's `Channel(Channel.BUFFERED)` plus a collector that
    /// suspends inside `showSnackbar` until the current snackbar goes away
    /// (`SalusSnackbarController.kt:33-35`, `SalusApp.kt:115-122`).
    private var queue: [SnackbarRequest] = []
    private var timeout: Task<Void, Never>?
    private let sleep: @Sendable (Duration) async throws -> Void

    /// - Parameter sleep: how the auto-dismiss waits. Injected for the same reason
    ///   `PendingDeleteController` injects it — Swift Testing has no virtual clock, so the wait is
    ///   the seam. Production has no reason to pass anything but the default.
    public init(
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.sleep = sleep
    }

    /// Queues a snackbar, or shows it straight away when nothing is up
    /// (`SalusSnackbarController.kt:37-39`).
    public func show(_ request: SnackbarRequest) {
        guard current == nil else {
            queue.append(request)
            return
        }
        present(request)
    }

    /// The action button was tapped: run the callback, then take the snackbar away. Kotlin runs the
    /// callback only for `SnackbarResult.ActionPerformed` (`SalusApp.kt:121`), and `showSnackbar`
    /// has returned by then — the snackbar is already gone.
    public func performAction() {
        let action = current?.onAction
        dismiss()
        action?()
    }

    /// Takes the current snackbar away and brings up the next, if any. Both the timeout and the
    /// host's dismissal land here.
    public func dismiss() {
        timeout?.cancel()
        timeout = nil
        current = nil
        guard !queue.isEmpty else { return }
        present(queue.removeFirst())
    }

    /// The task that will auto-dismiss the current snackbar, for this package's tests to await
    /// instead of waiting on wall-clock time. Internal on purpose: the app never needs it. The
    /// shape is `PendingDeleteController.windowTask(id:)`'s.
    var timeoutTask: Task<Void, Never>? { timeout }

    private func present(_ request: SnackbarRequest) {
        current = request
        // `SnackbarHost.kt:224-232`: the host delays for the duration and then dismisses. An
        // indefinite snackbar starts no timer at all — Kotlin's `delay(Long.MAX_VALUE)` with the
        // waiting spelled honestly.
        guard let millis = request.duration.milliseconds else {
            timeout = nil
            return
        }
        timeout = Task { [weak self] in
            guard let self else { return }
            do {
                try await sleep(.milliseconds(millis))
            } catch {
                // What the host's `LaunchedEffect` does when it is cancelled: stop, dismiss nothing.
                return
            }
            // An injected sleep is under no obligation to throw on cancellation, so the timer asks
            // once more before dismissing. `Task.sleep` has already thrown by this point.
            guard !Task.isCancelled, current?.id == request.id else { return }
            dismiss()
        }
    }
}

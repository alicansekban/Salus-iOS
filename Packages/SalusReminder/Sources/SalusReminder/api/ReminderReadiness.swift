// Ported 1:1 from Android
// `core/reminder/src/main/kotlin/com/alicansekban/salus/core/reminder/api/ReminderReadiness.kt`,
// with the problem list re-read for iOS: Android's exact-alarm, background-restriction,
// battery-optimization and full-screen-intent questions have no iOS twin, and what replaces
// them is AlarmKit's authorization and the background refresh switch (see
// ``ReminderEnvironment``).
//
// PURE SWIFT, like the contracts it sits beside: the classification is a fold over three
// booleans, so nothing here imports UserNotifications, AlarmKit, SwiftUI or UIKit.

/// How much of the reminder pipeline still works, worst state last.
public enum ReminderReadiness: Sendable, Equatable {
    /// Every reminder fires as designed.
    case ok

    /// Reminders still reach the user, but later or less reliably than designed.
    case degraded

    /// At least one reminder cannot reach the user at all.
    case broken
}

/// One thing that is wrong with the reminder pipeline, in worst-first declaration order — which
/// is also the order ``ReminderReadinessReport/problems`` reports them in.
public enum ReminderProblem: Sendable, Equatable, CaseIterable {
    /// Notifications are not authorized: nothing the engine schedules is ever seen.
    case notificationsOff

    /// AlarmKit is not authorized on a system that has it, so a medication dose cannot take
    /// over the screen. Never reported below iOS 26, where AlarmKit does not exist.
    case alarmKitDenied

    /// Background refresh is off: the alarm window is only refilled while the app is open.
    case backgroundRefreshOff

    /// Whether this problem stops a reminder outright, as opposed to weakening it. A hard
    /// problem makes the whole report ``ReminderReadiness/broken``.
    public var isHard: Bool {
        switch self {
        case .alarmKitDenied, .notificationsOff: true
        case .backgroundRefreshOff: false
        }
    }
}

/// The classification plus the problems behind it, so a caller can both branch on the level and
/// tell the user what to fix.
public struct ReminderReadinessReport: Sendable, Equatable {
    public let readiness: ReminderReadiness

    /// The problems found, in ``ReminderProblem`` declaration order. Empty exactly when
    /// ``readiness`` is ``ReminderReadiness/ok``.
    public let problems: [ReminderProblem]

    public init(readiness: ReminderReadiness, problems: [ReminderProblem]) {
        self.readiness = readiness
        self.problems = problems
    }

    /// Only the problems that stop a reminder outright — what a "reminders will not work"
    /// warning names.
    public var hardProblems: [ReminderProblem] {
        problems.filter(\.isHard)
    }

    /// The healthy report, so a caller never has to spell the empty case out.
    public static let ok = ReminderReadinessReport(readiness: .ok, problems: [])
}

extension ReminderEnvironment {
    /// Classifies the device state this environment reports.
    ///
    /// The twin of Kotlin's parameterless `ReminderEnvironment.readiness()`; iOS needs
    /// `alarmKitSupported` because AlarmKit exists only from iOS 26, and asking an environment
    /// that has no AlarmKit whether it is authorized would report a denial the user cannot fix.
    /// The caller — never this function — decides availability, so the classification stays pure.
    ///
    /// - Parameter alarmKitSupported: whether the running system has AlarmKit at all.
    /// - Returns: ``ReminderReadiness/broken`` if any hard problem is present,
    ///   ``ReminderReadiness/degraded`` if only soft ones are, ``ReminderReadinessReport/ok``
    ///   otherwise.
    public func readiness(alarmKitSupported: Bool) async -> ReminderReadinessReport {
        var problems: [ReminderProblem] = []

        let notificationsOn = await notificationsAuthorized()
        if !notificationsOn {
            problems.append(.notificationsOff)
        }
        // Asked only where AlarmKit exists: below iOS 26 the environment can only answer false,
        // and that is not a denial the user could act on.
        if alarmKitSupported {
            let alarmKitOn = await alarmKitAuthorized()
            if !alarmKitOn {
                problems.append(.alarmKitDenied)
            }
        }
        if !backgroundRefreshAvailable() {
            problems.append(.backgroundRefreshOff)
        }

        guard !problems.isEmpty else { return .ok }

        return ReminderReadinessReport(
            readiness: problems.contains(where: \.isHard) ? .broken : .degraded,
            problems: problems
        )
    }
}

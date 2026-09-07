// Ported 1:1 from Android
// `core/reminder/src/main/kotlin/com/alicansekban/salus/core/reminder/api/ReminderReadiness.kt`,
// with the problem list re-read for iOS: Android's exact-alarm, background-restriction and
// battery-optimization questions have no iOS twin, and what replaces them is AlarmKit's
// authorization and the background refresh switch (see ``ReminderEnvironment``).
//
// **On iOS exactly one problem is hard, and it is ``ReminderProblem/notificationsOff``.**
// Everything else weakens a reminder without stopping it, because the notification is the
// fallback for all of them: an unauthorized AlarmKit still leaves the dose posting
// time-sensitive with the alarm sound (`ReminderContracts.swift`, `alarmKitAuthorized()`), and
// a disabled background refresh still refills the window whenever the app is opened. That
// makes ``ReminderProblem/alarmKitDenied`` the twin of Android's soft `FULL_SCREEN_DENIED`,
// not of its hard `EXACT_ALARMS_DENIED`. Only a denied notification silences the pipeline
// outright, so only it can make a report ``ReminderReadiness/broken``.
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
    /// over the screen — it still posts, time-sensitive and with the alarm sound. Soft for
    /// exactly that reason, the twin of Android's `FULL_SCREEN_DENIED`. Never reported below
    /// iOS 26, where AlarmKit does not exist.
    case alarmKitDenied

    /// Background refresh is off: the alarm window is only refilled while the app is open.
    case backgroundRefreshOff

    /// Whether this problem stops a reminder outright, as opposed to weakening it. A hard
    /// problem makes the whole report ``ReminderReadiness/broken``.
    ///
    /// True for ``notificationsOff`` alone: every other problem degrades to the plain
    /// notification, which a denied notification authorization is precisely the absence of.
    public var isHard: Bool {
        switch self {
        case .notificationsOff: true
        case .alarmKitDenied, .backgroundRefreshOff: false
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

    /// Derives ``readiness`` from the problems, which is the only way the two can be built: a
    /// memberwise init let a caller pass `.ok` alongside a hard problem, and the invariant the
    /// `problems` doc claims would then hold only by convention.
    ///
    /// - Parameter problems: what is wrong, in ``ReminderProblem`` declaration order.
    public init(problems: [ReminderProblem]) {
        self.problems = problems
        readiness =
            if problems.contains(where: \.isHard) {
                .broken
            } else if problems.isEmpty {
                .ok
            } else {
                .degraded
            }
    }

    /// Only the problems that stop a reminder outright — what a "reminders will not work"
    /// warning names.
    public var hardProblems: [ReminderProblem] {
        problems.filter(\.isHard)
    }

    /// The healthy report, so a caller never has to spell the empty case out.
    public static let ok = ReminderReadinessReport(problems: [])
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

        // The classification itself is the initializer's, so an empty list is ``ok`` here without
        // a case of its own.
        return ReminderReadinessReport(problems: problems)
    }
}

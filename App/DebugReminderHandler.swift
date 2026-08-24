#if DEBUG

    import Foundation
    import os
    import SalusCommon
    import SalusModel
    import SalusReminder

    /// A stand-in for the medication handler iOS-M4 will bring, so the reminder engine can be walked
    /// end to end on a simulator while no feature owns a reminder yet.
    ///
    /// The whole file is inside `#if DEBUG`: it does not exist in a Release build, and neither does the
    /// call site in ``AppCompositionRoot``. Even in a Debug build it stays inert unless the app is
    /// launched with the argument below, so an ordinary `⌘R` never posts a reminder nobody asked for.
    ///
    ///     xcrun simctl launch booted com.alicansekban.salus --args -SalusDebugReminderLeadMinutes 3
    ///
    /// `-key value` launch arguments land in `UserDefaults`' argument domain, which is read-only and
    /// volatile — nothing is written to the app's defaults plist, so this cannot leave a persisted key
    /// behind (`CLAUDE.md`: the thirteen settings keys are Android-verbatim and closed).
    ///
    /// The walkthrough that uses it is `scripts/m3-manual-qa.md`.
    struct DebugReminderHandler: ReminderHandler {
        /// Minutes from launch to the test dose. Absent or ≤ 0 means the handler is not installed.
        static let leadMinutesKey = "SalusDebugReminderLeadMinutes"

        /// `NOTIFICATION` or `ALARM` (a ``ReminderPresentation`` raw value). Absent means `ALARM`,
        /// which is what a real medication dose is; `NOTIFICATION` is there so the delivery step of
        /// the walkthrough can be run without AlarmKit's authorization in the way.
        static let presentationKey = "SalusDebugReminderPresentation"

        /// Category `debug`, beside `boot` and `reminder`, under the one subsystem the app logs to.
        private static let logger = Logger(subsystem: "com.alicansekban.salus", category: "debug")

        /// The fake medication this occurrence belongs to. Stable, so the ledger row is recognisable.
        private static let entityId = "debug-medication"

        let type: ReminderType = .medicationDose

        private let triggerAt: Date
        private let presentation: ReminderPresentation

        /// Anchored once, at graph creation, so every later `sync()` in this process asks for the same
        /// occurrence and the pass is idempotent. A relaunch anchors a fresh one — the previous
        /// occurrence, if it has not fired yet, is withdrawn by the next pass, which is the engine's
        /// nil-content/no-longer-wanted branch doing its job.
        init?(clock: any SalusClock, defaults: UserDefaults = .standard) {
            let leadMinutes = defaults.integer(forKey: Self.leadMinutesKey)
            guard leadMinutes > 0 else { return nil }
            // Locals, then the log line, then the properties: an `os.Logger` interpolation is an
            // escaping autoclosure, and one that read `self` inside `init` would not compile.
            let trigger = clock.now().addingTimeInterval(TimeInterval(leadMinutes) * 60)
            let presentation = defaults.string(forKey: Self.presentationKey)
                .flatMap(ReminderPresentation.init(rawValue:)) ?? ReminderPresentation.alarm
            Self.logger.info(
                """
                debug reminder armed for \(trigger.timeIntervalSince1970, privacy: .public) \
                as \(presentation.rawValue, privacy: .public)
                """
            )
            triggerAt = trigger
            self.presentation = presentation
        }

        func occurrencesBetween(from: Date, until: Date) async throws -> [ReminderOccurrence] {
            guard triggerAt >= from, triggerAt < until else { return [] }
            return [
                ReminderOccurrence(
                    entityId: Self.entityId,
                    occurrenceKey: Self.occurrenceKey(for: triggerAt),
                    triggerAt: triggerAt
                )
            ]
        }

        func notificationContent(for ref: ReminderRef) async throws -> ReminderNotificationContent? {
            guard ref.entityId == Self.entityId, ref.occurrenceKey == Self.occurrenceKey(for: triggerAt) else {
                // The occurrence a previous launch armed. Answering nil is what withdraws it.
                return nil
            }
            return ReminderNotificationContent(
                title: "Salus debug dose",
                text: "A fake MEDICATION_DOSE occurrence, scheduled by \(Self.leadMinutesKey).",
                actions: [
                    ReminderAction(id: "TAKEN", label: "Taken"),
                    ReminderAction(id: "SNOOZE", label: "Snooze")
                ],
                presentation: presentation
            )
        }

        /// The proof that an action tap reached its handler: the line this writes is what
        /// `scripts/m3-manual-qa.md` greps for.
        func onAction(ref: ReminderRef, actionId: String) async throws {
            Self.logger.info(
                """
                debug reminder action \(actionId, privacy: .public) \
                on \(ref.occurrenceKey, privacy: .public)
                """
            )
        }

        /// Epoch seconds rather than a formatted date: the key only has to be stable and deterministic
        /// within the entity, and a formatter here would need a calendar this file has no business
        /// owning (`CLAUDE.md`: the instant↔day carve-out lives in `SalusClock` and nowhere else).
        private static func occurrenceKey(for triggerAt: Date) -> String {
            String(Int(triggerAt.timeIntervalSince1970))
        }
    }

#endif

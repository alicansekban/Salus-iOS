// Kotlin's `data class copy(...)` for the models the use cases rewrite. The models are plain `let`
// structs (Task 4), so each rewrite a use case makes is named here instead of re-listing every
// field at the call site, where a forgotten one would silently reset a column.

extension SmokingPlan {
    func withMode(_ mode: SmokingMode, dailyLimit: Int64?) -> SmokingPlan {
        SmokingPlan(
            id: id,
            mode: mode,
            productType: productType,
            baselineUnitsPerDay: baselineUnitsPerDay,
            dailyLimit: dailyLimit,
            currencyCode: currencyCode,
            reason: reason,
            notificationsEnabled: notificationsEnabled,
            eveningReminderEnabled: eveningReminderEnabled,
            createdAtMs: createdAtMs,
            tzId: tzId
        )
    }

    func withCurrency(_ currencyCode: String) -> SmokingPlan {
        SmokingPlan(
            id: id,
            mode: mode,
            productType: productType,
            baselineUnitsPerDay: baselineUnitsPerDay,
            dailyLimit: dailyLimit,
            currencyCode: currencyCode,
            reason: reason,
            notificationsEnabled: notificationsEnabled,
            eveningReminderEnabled: eveningReminderEnabled,
            createdAtMs: createdAtMs,
            tzId: tzId
        )
    }

    func withSettings(
        dailyLimit: Int64?,
        reason: String?,
        notificationsEnabled: Bool,
        eveningReminderEnabled: Bool
    ) -> SmokingPlan {
        SmokingPlan(
            id: id,
            mode: mode,
            productType: productType,
            baselineUnitsPerDay: baselineUnitsPerDay,
            dailyLimit: dailyLimit,
            currencyCode: currencyCode,
            reason: reason,
            notificationsEnabled: notificationsEnabled,
            eveningReminderEnabled: eveningReminderEnabled,
            createdAtMs: createdAtMs,
            tzId: tzId
        )
    }
}

extension PricePeriod {
    func withUnitCost(_ unitCostMinor: Int64) -> PricePeriod {
        PricePeriod(id: id, effectiveFromEpochDay: effectiveFromEpochDay, unitCostMinor: unitCostMinor)
    }
}

extension QuitAttempt {
    func closed(at endedAtMs: Int64, reason: AttemptEndReason) -> QuitAttempt {
        QuitAttempt(id: id, startedAtMs: startedAtMs, tzId: tzId, endedAtMs: endedAtMs, endReason: reason)
    }

    func startingAt(_ startedAtMs: Int64) -> QuitAttempt {
        QuitAttempt(id: id, startedAtMs: startedAtMs, tzId: tzId, endedAtMs: endedAtMs, endReason: endReason)
    }
}

extension SmokingEvent {
    func withAttemptId(_ attemptId: String?) -> SmokingEvent {
        SmokingEvent(
            id: id,
            type: type,
            occurredAtMs: occurredAtMs,
            tzId: tzId,
            epochDay: epochDay,
            units: units,
            trigger: trigger,
            intensity: intensity,
            productType: productType,
            attemptId: attemptId
        )
    }

    func edited(
        occurredAtMs: Int64,
        epochDay: Int64,
        units: Int64?,
        trigger: CravingTrigger?,
        intensity: Int?
    ) -> SmokingEvent {
        SmokingEvent(
            id: id,
            type: type,
            occurredAtMs: occurredAtMs,
            tzId: tzId,
            epochDay: epochDay,
            units: units,
            trigger: trigger,
            intensity: intensity,
            productType: productType,
            attemptId: attemptId
        )
    }
}

extension SavingsGoal {
    func achieved(at achievedAtMs: Int64) -> SavingsGoal {
        SavingsGoal(
            id: id,
            title: title,
            targetMinor: targetMinor,
            createdAtMs: createdAtMs,
            achievedAtMs: achievedAtMs
        )
    }

    func edited(title: String, targetMinor: Int64) -> SavingsGoal {
        SavingsGoal(
            id: id,
            title: title,
            targetMinor: targetMinor,
            createdAtMs: createdAtMs,
            achievedAtMs: achievedAtMs
        )
    }
}

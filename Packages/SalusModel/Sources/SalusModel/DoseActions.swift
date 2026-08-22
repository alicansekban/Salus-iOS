// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/DoseActions.kt`.

/// Cross-feature contract for acting on a dose occurrence. Implemented by `FeatureMedications`
/// (the single write path also used by notification actions) and consumed by other features
/// (e.g. Home's inline "Take") through the composition root, so features never import each other.
///
/// Kotlin's `suspend fun` becomes `async throws`: Kotlin propagates failures as exceptions from a
/// suspending call, and Swift spells that `throws`.
public protocol DoseActions: Sendable {
    /// Marks the occurrence taken and decrements stock; idempotent.
    func markTaken(scheduleId: String, epochDay: Int, minuteOfDay: Int) async throws
}

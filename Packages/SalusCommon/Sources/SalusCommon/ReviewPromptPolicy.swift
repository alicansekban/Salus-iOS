// When Home may ask the store for a rating, ported 1:1 from Android
// `core/common/src/main/kotlin/com/alicansekban/salus/core/common/ReviewPromptPolicy.kt`
// (spec: `salus-android/docs/superpowers/specs/2026-09-06-in-app-review-design.md`).
//
// Pure on purpose: the two inputs come from `UserDefaults` and the clock, and the caller stamps
// the request time *before* asking StoreKit, so a request the platform swallows still consumes
// the 14-day slot. Milliseconds rather than `Date`, because the stamp is stored as `Int64`.

public enum ReviewPromptPolicy {
    /// Home arrivals before the first request may happen — the third open asks.
    public static let minOpens = 3

    /// Minimum gap between two requests, in milliseconds (14 days).
    public static let cooldownMs: Int64 = 14 * 24 * 60 * 60 * 1000

    public static func shouldRequest(openCount: Int, lastRequestedEpochMs: Int64?, nowEpochMs: Int64) -> Bool {
        guard openCount >= minOpens else { return false }
        guard let last = lastRequestedEpochMs else { return true }
        return nowEpochMs - last >= cooldownMs
    }
}

// Ported 1:1 from Android
// `core/model/src/main/kotlin/com/alicansekban/salus/core/model/Cycle.kt`.

/// How heavy a logged day's flow was.
///
/// Raw values are the Kotlin constant names (`Cycle.kt:3-8`), which is what is persisted.
public enum FlowLevel: String, CaseIterable, Equatable, Hashable, Sendable {
    case spotting = "SPOTTING"
    case light = "LIGHT"
    case medium = "MEDIUM"
    case heavy = "HEAVY"
}

/// The mood logged alongside a cycle day.
///
/// Raw values are the Kotlin constant names (`Cycle.kt:10-17`).
public enum Mood: String, CaseIterable, Equatable, Hashable, Sendable {
    case great = "GREAT"
    case good = "GOOD"
    case neutral = "NEUTRAL"
    case low = "LOW"
    case irritable = "IRRITABLE"
    case anxious = "ANXIOUS"
}

// Ported 1:1 from
// `core/navigation/src/main/kotlin/com/alicansekban/salus/core/navigation/Navigator.kt:8-12`:
//
//     sealed interface NavCommand {
//         data class Navigate(val key: NavKey) : NavCommand
//         data object Pop : NavCommand
//     }
//
// A Kotlin sealed interface with a data class and a data object is a Swift enum with one
// associated-value case and one bare case — same closed set, same value semantics.

/// What a ViewModel asked the shell to do.
///
/// `Equatable` where Kotlin gets `equals` from `data class`/`data object`; the shell never compares
/// commands, but the tests do, and a command that cannot be compared cannot be table-tested.
public enum NavCommand: Sendable, Equatable {
    /// Push `key` onto the selected tab's stack (`Navigator.kt:9`).
    case navigate(AnyNavKey)

    /// Pop the current entry (`Navigator.kt:11`).
    case pop
}

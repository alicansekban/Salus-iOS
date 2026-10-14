// No Kotlin twin. Android pushes `SmokingCravingKey` onto the one back stack like any other key.
// On iOS the craving flow is a `.fullScreenCover` (plan Task 12) — it takes over the whole screen,
// tab bar included, and has no back stack of its own to push onto.
//
// The cover is presented along ONE path, for both callers. Main's ViewModel and Home's card both
// call `navigator.navigate(SmokingCravingKey(…))`; the shell is the only thing that applies
// navigation commands, so it hands each one to this presenter before it touches a back stack. A
// craving key is presented here and consumed; a `pop` while the cover is up closes the cover
// instead of popping the stack under it, which is what the ViewModel's `navigator.pop()` means when
// it leaves. Every other command falls through to the back stacks untouched. Nothing in either
// caller changed for this, and a future caller (a notification) gets the same behaviour for free.

import Observation
import SalusNavigation

/// Which craving key is on screen as a cover, and the one door commands reach it through.
@MainActor
@Observable
public final class SmokingCravingPresenter {
    /// The key the cover was opened with, `nil` while there is no cover.
    public private(set) var presented: SmokingCravingKey?

    public init() {}

    /// Takes a navigation command if it is about the craving cover. Returns `true` when it did, so
    /// the shell leaves the back stacks alone.
    ///
    /// A craving key while the cover is already up is taken and dropped: pushing it under the cover
    /// would stack a second flow the person finds after closing the first.
    @discardableResult
    public func consume(_ command: NavCommand) -> Bool {
        switch command {
        case let .navigate(key):
            guard let craving = key.base as? SmokingCravingKey else {
                return false
            }
            if presented == nil {
                presented = craving
            }
            return true

        case .pop:
            guard presented != nil else {
                return false
            }
            presented = nil
            return true
        }
    }

    /// Closes the cover from the presentation side (the binding `fullScreenCover` writes).
    public func dismiss() {
        presented = nil
    }
}

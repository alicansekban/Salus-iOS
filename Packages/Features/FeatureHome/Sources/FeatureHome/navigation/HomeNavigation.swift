// Ported from `feature/home/src/main/kotlin/com/alicansekban/salus/feature/home/navigation/
// HomeNavigation.kt` — the key, and deliberately nothing else.
//
// **There is no `homeDestinations()`, and that is plan ruling 8.** Every other feature's navigation
// file pairs its keys with a `View` modifier that registers them on the shell's `NavigationStack`,
// because something pushes those keys. Nothing pushes `HomeKey`: Android's `homeEntries` registers
// exactly one entry, the tab's *root*, and a root is not a pushed destination on iOS — `RootView`
// builds it directly as the `NavigationStack`'s content. A `navigationDestination(for: HomeKey.self)`
// would be a destination no path can ever contain.
//
// `HomeKey` itself is carried for name parity with `HomeKey.kt` and for the shell's tab
// bookkeeping, so a reader moving between the two trees finds the same five keys named the same way.
//
// `@Serializable` has no twin, for `CycleNavigation.swift`'s reason: nothing in this tree restores a
// `NavigationPath` yet, and `Hashable` is what `NavigationPath` actually requires.
//
// The five cross-feature callbacks Kotlin's `homeEntries` takes — `onOpenMedications`,
// `onOpenAppointments`, `onOpenCycle`, `onOpenVitals`, `onOpenAiSummary` — are `HomeRoute`'s
// parameters here rather than this file's, since there is no entry builder to thread them through.
// The fifth arrived with the AI card in iOS-M10.

/// The dashboard, the Home tab's root (`HomeNavigation.kt:9-10`).
public struct HomeKey: Hashable, Sendable {
    public init() {}
}

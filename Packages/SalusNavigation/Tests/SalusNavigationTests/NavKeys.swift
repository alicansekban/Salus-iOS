// Two deliberately unrelated key types, standing in for two features that cannot see each other.
//
// Android gets this for free: every `NavKey` is declared inside the Gradle module that owns it, so
// `HomeKey` and `VitalsKey` are simply not visible to one another (`architecture-rules.md`:
// "NavKeys stay in the feature that owns them"). These two enums reproduce that shape in one test
// bundle, which is what lets the `AnyNavKey` tables assert the interesting property: two keys that
// spell their cases identically must still never compare equal.

/// Stand-in for a key owned by the Home feature.
enum SampleHomeKey: Hashable, Sendable {
    case root
    case detail(String)
}

/// Stand-in for a key owned by the Vitals feature. Same case names on purpose.
enum SampleVitalsKey: Hashable, Sendable {
    case root
    case detail(String)
}

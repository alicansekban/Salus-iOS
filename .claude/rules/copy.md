---
paths:
  - "**/*.xcstrings"
  - "**/*Strings.swift"
  - "**/Packages/Features/**"
  - "**/App/**"
---
# Salus iOS copy and localisation rules (MANDATORY)

Every rule names its **enforcement point**. Global rules are in `CLAUDE.md`.

## Copy and localisation rules

- **Banned health-claims vocabulary applies to all user-facing copy** — and to the Swift sources
  and comments around it, as on Android. Banned stems, case-insensitive substrings: `uyum` ·
  `hedef aral` · `planlan` · `adher` · `complian` · `complie` · `comply` · `planned dos` ·
  `target range` (plus the dotted-İ foldings `compli̇an` / `compli̇e`). The correct phrase is
  **"kaydedilen doz" / "recorded doses"** — no `MISSED` dose row is ever written, so the ratio
  describes recorded doses only; calling it adherence turns a fact about records into a claim
  about someone's treatment (spec §7, §12). — *enforcement: `SalusTesting`'s `BannedHealthClaims`,
  the twin of Android's, run repo-wide from
  `Packages/SalusTesting/Tests/SalusTestingTests/BannedHealthClaimsTests.swift`: "no Swift source in
  the repository names anything banned" (`assertSourcesNameNothingBanned(roots:exemptFileNames:)`)
  and "no string catalog in the repository names anything banned"
  (`assertCatalogsNameNothingBanned(paths:)`). Both fail loudly if the scan reaches zero files, so a
  broken path cannot pass as a clean tree. Both scans cover `Packages/` **and** `App/`: the catalog
  scan gained `App/` in iOS-M6, when the app target got a `Localizable.xcstrings` of its own.*
- **The AI/PDF disclaimer is verbatim and mandatory** on every AI output and every PDF page
  footer: TR *"Bu rapor bilgilendirme amaçlıdır, tıbbi tavsiye değildir."* /
  EN *"This report is for informational purposes only and is not medical advice."* — *review,
  then the same string test.*
- **TR + EN string parity.** TR is the default and the fallback (§6.4); EN is a full peer. Every
  key exists in both. Strings live in one `Localizable.xcstrings` per package under
  `Sources/<Package>/Resources/`, reached through a typed `enum` over `Bundle.module`
  (`VitalsStrings.swift`) — never a bare `String(localized:)` at a call site, which resolves against
  the *main* bundle and silently returns the key. — *enforcement: `SalusTesting`'s
  `StringCatalogParity` — `assertSourceLanguage` (tr), `assertKeys(of:are:)` against a literal key-set
  pin copied from the Android XML, and `assertEveryKeyIsLocalized` (both locales present and
  non-empty, no third locale). A new catalog gets its own test suite in the same commit; the shape is
  `Packages/Features/FeatureVitals/Tests/FeatureVitalsTests/VitalsStringsTests.swift`.*
  - **Placeholder mapping is the one place the port is not byte-for-byte**: Java's `%1$s` becomes
    `%1$@` (a Swift `String` under `%s` reads a C string pointer) and `%1$d` becomes `%1$lld`
    (Swift's `Int` is 64-bit). The sentence around the specifier never changes.
  - **A `.xcstrings` is compiled only by Xcode's build system.** `swift build` / `swift test` copies
    the catalog into the resource bundle verbatim, so a lookup under `swift test` finds no table and
    `String(localized:)` returns the key. String tests therefore assert against the **file**; the
    end-to-end check is `scripts/build-app.sh` plus a simulator run.
- **Overlines are stored upper-case in the resource, never folded at run time.** An overline —
  "BUGÜN", "HESAP", "SALUS HEALTH", the vitals field labels, the onboarding step counter — ships
  upper-case in both locales of the catalog, and no call site ever calls `uppercased()` on it.
  Turkish has two dotted i's and a runtime fold cannot know which one a label means, so the
  decision belongs to whoever wrote the string. (`SalusAvatar`'s initials are not an overline: it
  folds a *name* the user typed, which has no resource to be stored upper-case in.) — *enforcement:
  a per-catalog pin, the shape set by
  `Packages/Features/FeatureVitals/Tests/FeatureVitalsTests/VitalsStringsTests.swift:90` and
  `Packages/Features/FeatureOnboarding/Tests/FeatureOnboardingTests/OnboardingStringsTests.swift:91`
  — each asserts `value == value.uppercased(with: Locale(identifier: locale))` for every overline
  key it owns.*

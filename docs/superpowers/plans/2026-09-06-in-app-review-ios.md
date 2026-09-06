# In-app review — iOS implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.
> Compact plan: contracts and behaviour, not full code. Executors read the spec + the Android
> plan (`salus-android/docs/superpowers/plans/2026-09-06-in-app-review-android.md`) first.

**Goal:** StoreKit `requestReview` from Home on the 3rd open onward with a 14-day cooldown; a
"Rate Salus" row in More that opens the App Store write-review page.

**Architecture:** Two `UserDefaults` keys in `SalusSettings`, a pure `ReviewPromptPolicy` in
`SalusCommon`, a `HomeEffect.requestReview` from `HomeViewModel` consumed in `HomeRoute` via
`@Environment(\.requestReview)`. More reuses `MoreEffect.openUrl`.

**Tech stack:** Swift 6, SwiftUI, StoreKit (SDK), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-09-06-in-app-review-design.md` (pointer) → Android spec.

**Branch:** `feature/in-app-review` from `main`. Independent of `feature/reminder-readiness`;
both touch `HomeViewModel`/`HomeScreen`; the second to merge rebases and resolves.

## Global constraints

- Write the cooldown stamp **before** emitting the effect.
- Strings via `Localizable.xcstrings` + `*Strings` enums, TR source + EN, parity tests extended.
- No new dependency.

---

### Task 1: `ReviewPromptPolicy`

**Files**
- Create `Packages/SalusCommon/Sources/SalusCommon/ReviewPromptPolicy.swift`
- Test `Packages/SalusCommon/Tests/SalusCommonTests/ReviewPromptPolicyTests.swift`

**Produces**
```swift
public enum ReviewPromptPolicy {
    public static let minOpens = 3
    public static let cooldown: TimeInterval = 14 * 24 * 60 * 60
    public static func shouldRequest(openCount: Int, lastRequestedEpochMs: Int64?, nowEpochMs: Int64) -> Bool
}
```
**Tests:** same five cases as Android (2 never → false; 3 never → true; 13 d → false; exactly
14 d → true; last = now → false).

- [ ] Tests → fail; implement → pass; `swift test --package-path Packages/SalusCommon`
- [ ] Commit `feat(common): review prompt policy`

### Task 2: Preferences

**Files**
- Modify `Packages/SalusSettings/Sources/SalusSettings/SettingsKeys.swift`:
  `homeOpenCount = "home_open_count"`, `reviewLastRequestedMs = "review_last_requested_ms"`.
- Modify `SalusPreferencesDataSource.swift`: `public struct ReviewState: Sendable, Equatable { homeOpenCount: Int, lastRequestedEpochMs: Int64? }`;
  `public func reviewState() -> ReviewState`; `@discardableResult public func incrementHomeOpenCount() -> Int`;
  `public func setReviewLastRequested(epochMs: Int64)`.
- Tests: in-memory `UserDefaults(suiteName:)` as the existing tests do; increment twice → 2;
  stamp round-trips; defaults when absent.

- [ ] Tests → fail; implement → pass; `swift test --package-path Packages/SalusSettings`
- [ ] Commit `feat(settings): review prompt state`

### Task 3: Home trigger

**Files**
- Modify `.../FeatureHome/ui/HomeUiState.swift`: event `.appeared` (reuse if
  `feature/reminder-readiness` added it); `public enum HomeEffect: Equatable { case requestReview }`.
- Modify `HomeViewModel.swift`: init gains `preferences: SalusPreferencesDataSource` (`clock`
  present); `pendingEffects`/`consumeEffects()`; `.appeared` → `let count = preferences.incrementHomeOpenCount()`,
  `if ReviewPromptPolicy.shouldRequest(openCount: count, lastRequestedEpochMs: state.lastRequestedEpochMs, nowEpochMs: clock.now().epochMs) { preferences.setReviewLastRequested(epochMs: now); pendingEffects.append(.requestReview) }`;
  `func sceneDidBecomeActive()` sends `.appeared` (shared with the readiness plan; one method).
- Modify `HomeScreen.swift` `HomeRoute`: `@Environment(\.requestReview) private var requestReview`;
  `.task { viewModel.onEvent(.appeared); consume() }`; consume → `.requestReview`: `requestReview()`.
  Foreground: the `.active` arm in `App/SalusApp.swift` calls `sceneDidBecomeActive()` through
  the composition root (same one line the readiness plan adds; if it is already there, nothing to do).
- `App/AppCompositionRoot*.swift`: pass `preferences` to the Home factory.
- Tests `HomeViewModelTests.swift` with a fake preferences + fixed clock: opens 1, 2 → no effect;
  3 → one effect + stamp; 4 same day → none; +14 d → one.

- [ ] Tests → fail; implement → pass; `swift test --package-path Packages/Features/FeatureHome`
- [ ] Commit `feat(home): native review request from the third open`

### Task 4: More "Rate Salus" row

**Files**
- Modify `.../FeatureSettings/ui/more/MoreUiState.swift`: `MoreEvent.rateUsClicked`.
- Modify `MoreViewModel.swift`: `public static let appStoreWriteReviewUrl = "https://apps.apple.com/app/id6807102436?action=write-review"`;
  `.rateUsClicked` → `pendingEffects.append(.openUrl(appStoreWriteReviewUrl))`.
- Modify `MoreScreen.swift`: row after About, `SettingsStrings.settingsRateUs` /
  `settingsRateUsDesc`, icon `star`.
- Strings (FeatureSettings xcstrings): `settingsRateUs` TR "Bizi değerlendirin" / EN "Rate Salus";
  `settingsRateUsDesc` TR "Görüşünüz Salus'un gelişmesine yardımcı olur" / EN "Your feedback helps Salus improve".
- Tests `MoreViewModelTests.swift`: `.rateUsClicked` → `[.openUrl(appStoreWriteReviewUrl)]`.

- [ ] Tests → fail; implement → pass; `swift test --package-path Packages/Features/FeatureSettings`
- [ ] Commit `feat(settings): rate-us row opens the App Store review page`

### Task 5: Integration, QA, ledger

- [ ] `xcodebuild -scheme Salus -destination 'generic/platform=iOS Simulator' build` clean; touched
  packages' `swift test` green.
- [ ] `docs/qa/in-app-review-manual-qa.md`: third foreground → StoreKit sheet (simulator shows it
  every time, device honours Apple's cap; note it); More → Rate Salus opens App Store (page 404s
  until the listing is approved; note it).
- [ ] Parity ledger entry (keys, constants, effect names).
- [ ] `git rebase main`, `git merge --ff-only`, push.

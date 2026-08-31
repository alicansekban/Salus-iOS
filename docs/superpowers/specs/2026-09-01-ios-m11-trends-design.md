# iOS-M11 — Advanced Trends Design

**Date:** 2026-09-01 · **Path:** architectural (new subsystem, no new SPM dependency)
**Parity target:** `salus-android` "Plan 3 — Gelişmiş Trendler" (`docs/superpowers/plans/2026-08-20-plan3-trends.md`), shipped on `main`.
**Spec authority:** `salus-android/docs/superpowers/specs/2026-08-19-premium-subscription-design.md` §6 "Gelişmiş trendler", `salus-android/docs/ios-v1-plan.md` §10 (iOS-M11 row), `salus-android/docs/parity-ledger.md` rows S-3 / S-15.
**Status:** draft — awaiting user review before the implementation plan is written.

## 1. Goal

Land the premium trends screen the M9 paywall gates promised. Concretely:

1. **`FeatureTrends`** becomes the real `:feature:trends` twin: `TrendsViewModel`/`TrendsScreen` (period selector, four analysis cards, locked preview), `TrendsRepository` (premium gate + safe analysis orchestration), `TrendsDataReader` (DAO seam), domain models, and four pure analysis modules (time-of-day breakdown, multi-metric overlay, weekly dose ratio, metric summaries with period-over-period change).
2. **`SalusUI`** gains two new chart components: `SalusBarChart` (grouped bar, Swift Charts `BarMark`) and `SalusMultiSeriesChart` (N-series line, Swift Charts `LineMark`). The existing `ChartUiModel`/`SalusLineChart` (Vitals, Home) is untouched.
3. **The Home/Vitals `onOpenTrends` no-ops** (`TODO(M11)` since M7/M9) become real `TrendsKey` navigation callbacks. The More row's `trendsClicked` (M9) becomes a real callback too.
4. **The paywall feature list** is updated to sell only shipped features — trends replaces the placeholder "Sınırsız trend ve geçmiş analizi" copy with the real four-card description, and `backup` stays deferred (not sold).
5. **No new SPM dependency** — Swift Charts is a system framework, already wrapped in `SalusUI` since iOS-M2. The allowlist stays closed at three.

Nothing else ships in M11. The encrypted backup (Android Phase 2, deferred) and the release (iOS-M12) keep their no-op callbacks.

## 2. Settled decisions (from the port contract — not re-litigated)

| # | Decision | Source |
|---|---|---|
| D1 | **No existing free feature is restricted.** `FeatureVitals`'s `ChartRange` chips (WEEK/MONTH/QUARTER/YEAR) stay free; the `ChartRange` enum and Vitals chart are untouched. Trends carries its own `TrendsRange` enum. | Android plan Global Constraints |
| D2 | **"Uyum" / "adherence" / "planlanan doz" / "hedef aralık" are banned.** `MISSED` dose rows are never written, so the ratio's denominator is recorded doses. UI copy says "kaydedilen doz" / "recorded doses" only. The repo-wide `BannedHealthClaims` scan covers the new strings automatically. | spec §7, `CLAUDE.md` banned-claims |
| D3 | **No "normal range" / "good/bad" claims.** The app ships as "not a medical device". No card qualifies a value as good/bad/normal — only number, average, and change are shown. | Android plan Global Constraints |
| D4 | **Premium check is at the repository level, not only in the UI.** A free user's `TrendsRepository.load()` returns `.locked` without touching any DAO. The screen renders a locked preview with sample data. | parity ledger S-15 |
| D5 | **No network.** All computation is local; this plan adds no AI call. | Android plan Global Constraints |
| D6 | **`MetricStats` / `Trend` / `metricStatsOf` / `trendOf` already live in `SalusModel`.** Android Task 1 (moving them from `:core:ai` to `:core:model`) has no iOS twin — they were always in `SalusModel`. | iOS-M10 verification |
| D7 | **Features never import Charts.** `SalusUI` owns the chart adapters; `FeatureTrends` reaches them through `BarChartUiModel`/`SalusBarChart` and `MultiSeriesChartUiModel`/`SalusMultiSeriesChart` only. The `no_charts_in_features` lint rule enforces this. | `CLAUDE.md` UI rules |
| D8 | **Cross-feature navigation is a shell callback.** `TrendsKey` lives in `FeatureTrends`; Vitals and More reach it through `onOpenTrends` → `root.navigator.navigate(TrendsKey())`. No feature-to-feature dependency. | spec §4 |

## 3. Open decisions (resolved at planning time, with the user)

| # | Question | Resolution |
|---|---|---|
| O1 | Backup milestone (M12) deferred to Phase 2 | **Confirmed.** iOS-M12 = Release (TestFlight, App Store Connect, privacy labels). Backup is skipped on both platforms. The paywall feature list drops `backup`; the string stays for reuse. |
| O2 | Blur + scrim on locked view | **Both.** SwiftUI `.blur(radius: 16)` works on all iOS 17 platforms (unlike Android's `Modifier.blur` which is no-op below API 31). The scrim (`Color.background.opacity(0.6)`) is kept anyway for visual depth and Android parity — the locked preview must look the same on both platforms. |
| O3 | Locked view tap-blocking | **`.allowsHitTesting(false)`** on the sample-data stack, with the "Premium ile aç" button in a separate layer with `.allowsHitTesting(true)`. Cleaner than Android's `Modifier.pointerInput(Unit) { }` — SwiftUI has a native hit-testing toggle. Recorded as divergence `D-M11-a`. |

## 4. Architecture

### 4.1 Module graph delta

```
FeatureTrends  (← :feature:trends)  deps: SalusModel, SalusCommon, SalusDatabase, SalusPremium,
                                    SalusNavigation, SalusSettings, SalusDesignSystem, SalusUI
SalusUI                            gains: BarChartUiModel/SalusBarChart, MultiSeriesChartUiModel/SalusMultiSeriesChart
App                                links: FeatureTrends (new in project.yml)
```

`FeatureTrends` already exists as an empty placeholder (M0) with its `Package.swift` deps pre-declared. No new remote dependency — Swift Charts is system. `project.yml` gains `FeatureTrends` in `packages:` and app `dependencies:` (if not already present).

`.macOS(.v14)`: `FeatureTrends` reaches SwiftUI — the "Reaches SwiftUI" concession. Already declared in the existing `Package.swift`.

### 4.2 `FeatureTrends` — public API (the `:feature:trends` twin)

- **`domain/TrendsModels.swift`**: `TrendsRange { month, quarter, halfYear, year }` (28/91/182/365 days), `TrendMeasurement(type:epochDay:minuteOfDay:primary:secondary:tertiary:)`, `TrendDose(epochDay:taken:)`, `TrendsRecords(measurements:doses:)`, `TrendsData` enum (`.locked`, `.empty`, `.ready` — fields filled task by task).
- **`domain/TrendsReader.swift`**: `protocol TrendsReader: Sendable { func records(days: ClosedRange<Int>, timeZone: TimeZone) async throws -> TrendsRecords }`. Module boundary — `SalusDatabase` DAO types never leak.
- **`data/TrendsDataReader.swift`**: `TrendsDataReader(vitalsDao:medicationDao:profileId:)`. Thin DAO reads → domain mapping. No notes, names, or profile read.
- **`data/TrendsRepository.swift`**: `protocol TrendsRepository: Sendable { func load(range: TrendsRange) async -> TrendsData }`, `TrendsRepositoryImpl(reader:premiumRepository:clock:)`. Premium gate first line: not entitled → `.locked`, reader untouched. Premium + empty → `.empty`. Premium + data → `.ready`. Day window: `(todayEpochDay - range.days + 1)...todayEpochDay`.
- **`analysis/TimeOfDay.swift`**: `DayPart { morning, midday, evening, night }` (minute buckets), `DayPartStats`, `TimeOfDayBreakdown`, `timeOfDayBreakdownOf(_:type:)`. Pure function.
- **`analysis/Overlay.swift`**: `OverlaySeries`, `MetricOverlay`, `metricOverlayOf(_:days:)`. Pure function. Normalize to 0..1, all-equal → 0.5.
- **`analysis/DoseWeeks.swift`**: `DoseWeek`, `weekStartOf(_:)`, `doseWeeksOf(doses:measurements:days:)`. Pure function. Monday-start weeks.
- **`analysis/Summaries.swift`**: `MetricSummary`, `MetricSummaries`, `metricSummariesOf(current:previous:)`. Pure function. Uses `metricStatsOf` from `SalusModel`.
- **`ui/TrendsUiState.swift`**: `TrendsUiState(isLoading:range:data:)`, `TrendsEvent(rangeSelected:upgradeClicked:)`.
- **`ui/TrendsViewModel.swift`**: `@MainActor @Observable`. Period selection, premium flow, paywall call. Auto-reload on premium arrival.
- **`ui/TrendsScreen.swift`**: Route + Screen. `TrendsRange` filter chips, `.locked` → sample data + blur + scrim + "Premium ile aç" button, `.empty` → `SalusEmptyState`, `.ready` → four cards.
- **`ui/TrendsSample.swift`**: `sampleTrendsReady() -> TrendsData.Ready`. Deterministic, hand-written, no clock/random.
- **`navigation/TrendsNavigation.swift`**: `TrendsKey: Hashable, Sendable`, `trendsDestinations()`.
- **`TrendsStrings.swift`** + `Resources/Localizable.xcstrings`: `trends_*` keys, TR + EN. Banned-claims safe.
- **`TrendsModule.swift`**: `@MainActor struct TrendsModule { makeTrendsViewModel }`, `@Entry`.

### 4.3 `SalusUI` — two new chart components

- **`chart/BarChartUiModel.swift`**: `BarEntry(label:value:secondaryValue:)`, `BarChartUiModel(bars:yLabel:)`.
- **`chart/SalusBarChart.swift`**: Swift Charts `Chart { BarMark }`. Grouped bars when `secondaryValue` present. `#if canImport(Charts)`. Colors from `@Environment(\.salusTheme)`. `contentDescription` param for a11y.
- **`chart/MultiSeriesChartUiModel.swift`**: `SeriesRole { primary, secondary, tertiary }`, `ChartSeries(points:role:)`, `MultiSeriesChartUiModel(series:xLabel:)`.
- **`chart/SalusMultiSeriesChart.swift`**: Swift Charts `Chart { LineMark }` N series. `#if canImport(Charts)`. Existing `ChartUiModel`/`SalusLineChart` untouched (Vitals/Home call sites unchanged).

### 4.4 Shell wiring

- **`RootView.swift`**: `onOpenTrends` (Vitals + More) → `root.navigator.navigate(TrendsKey())`. `TODO(M11)` comments removed. `.trendsDestinations()` added to Vitals and More tab `NavigationStack`s.
- **`AppCompositionRoot`**: `trendsModule` injected. `TrendsRepositoryImpl` built over real `TrendsDataReader` + `PremiumRepository` + `SalusClock`.
- **`project.yml`**: `FeatureTrends` in `packages:` + app `dependencies:`. `xcodegen generate`.

### 4.5 Paywall alignment

- **`FeaturePaywall/PaywallSheet.swift`**: feature list updated — 4 shipped features (AI summary, doctor report, trends, themes). `backup` bullet removed. Trend copy: TR "Sabah-akşam dağılımı, çoklu metrik ve doz-ölçüm analizi" / EN "Time-of-day breakdown, multi-metric overlay and dose-vs-measurement analysis".
- **`FeaturePaywall/Localizable.xcstrings`**: `paywall_feature_trends` updated. `paywall_feature_backup` kept (deferred, not deleted).

## 5. Data flow

```
TrendsViewModel.load(range)
   │
   ▼
TrendsRepositoryImpl.load(range)
   │ premiumRepository.status.isEntitled? no → .locked (reader untouched)
   │ yes → TrendsDataReader.records(days, timeZone)
   │          ▼
   │          VitalsDao.getMeasurementsBetween + MedicationDao.getIntakeLogsBetween
   │          ▼
   │          TrendsRecords(measurements, doses)
   ▼
TrendsData.Ready(
   timeOfDay: timeOfDayBreakdownOf(...),
   overlay: metricOverlayOf(...),
   doseWeeks: doseWeeksOf(...),
   summaries: metricSummariesOf(current, previous)
)
   │
   ▼
TrendsScreen → SalusBarChart / SalusMultiSeriesChart / summary cards
```

Previous period read: `previousDays = (days.first - range.days)...(days.first - 1)` — second `TrendsReader.records` call. Free user: neither read happens.

## 6. Error handling

- **Free user**: `.locked` — no DAO access, no computation. Screen shows sample data behind blur + scrim + "Premium ile aç" button.
- **Premium + no data**: `.empty` — `SalusEmptyState` card.
- **Premium + partial data**: `.ready` with available cards; cards with no data for their metric are hidden (timeOfDay hidden if no BP/glucose; overlay hidden if <2 metrics; doseWeeks hidden if no doses; summaries shows only metrics with readings).
- **Premium lapse mid-session**: `observeEntitlement` auto-reloads on premium arrival; on lapse, the next `load` returns `.locked`.
- **DAO read failure**: `TrendsReader.records` is `async throws`; repository catches and returns `.empty` (graceful degradation — a corrupt DB should not crash the trends screen).

## 7. Testing

- **`FeatureTrendsTests`**: `TrendsRepositoryTests` (4: free → `.locked` + reader untouched; premium + empty → `.empty`; premium + data → `.ready`; previous period read skipped for free), `TrendsViewModelTests` (4: initial QUARTER + isLoading; rangeSelected → reload; upgradeClicked → paywall; premium arrival → auto-reload), `TimeOfDayTests` (7), `OverlayTests` (8), `DoseWeeksTests` (8), `SummariesTests` (7), `TrendsSampleTests` (3), `TrendsStringsTests` (parity + banned-claims).
- **`FeaturePaywallTests`**: `PaywallFeatureListTest` (3: 4 features; `backup` absent; trend copy matches).
- **`SalusUITests`**: `SalusBarChartTests` / `SalusMultiSeriesChartTests` — model construction + a11y (visual rendering tested on simulator only).
- **Repo-wide**: `BannedHealthClaims` stays green (new `trends_*` strings scanned automatically); `scripts/ci.sh` 5/5; `scripts/test-packages.sh FeatureTrends FeaturePaywall SalusUI FeatureHome FeatureVitals FeatureSettings` + `scripts/build-app.sh` green per task.
- **Manual QA** (`scripts/m11-manual-qa.md`): (1) free user: Trends screen opens, sample data blurred, "Premium ile aç" → paywall; (2) premium user: four cards render with real data; (3) period switch reloads; (4) cards hide when their metric has no data; (5) no banned words visible; (6) Vitals "Analiz" icon → Trends; More "Trendler" row → Trends; (7) paywall feature list shows 4 items; (8) existing Vitals chart chips unchanged (free).

## 8. Files touched (summary)

**New (FeatureTrends):** `domain/TrendsModels.swift`, `domain/TrendsReader.swift`, `data/TrendsDataReader.swift`, `data/TrendsRepository.swift`, `analysis/TimeOfDay.swift`, `analysis/Overlay.swift`, `analysis/DoseWeeks.swift`, `analysis/Summaries.swift`, `ui/TrendsUiState.swift`, `ui/TrendsViewModel.swift`, `ui/TrendsScreen.swift`, `ui/TrendsSample.swift`, `navigation/TrendsNavigation.swift`, `TrendsStrings.swift`, `Resources/Localizable.xcstrings`, `TrendsModule.swift`, tests × 8. (Placeholder `FeatureTrends.swift` deleted.)
**New (SalusUI):** `chart/BarChartUiModel.swift`, `chart/SalusBarChart.swift`, `chart/MultiSeriesChartUiModel.swift`, `chart/SalusMultiSeriesChart.swift`, tests.
**Modified:** `App/RootView.swift` (real `onOpenTrends`), `App/AppCompositionRoot.swift` (+ trends graph), `App/AppCompositionRoot+Modules.swift`, `project.yml` (+ regenerated pbxproj), `Packages/Features/FeaturePaywall/.../PaywallSheet.swift` (feature list), `Localizable.xcstrings` (trend copy), `PaywallFeatureListTest.swift`.
**Deleted:** `FeatureTrends/Sources/FeatureTrends/FeatureTrends.swift` (placeholder).

## 9. Divergences (recorded in the parity ledger)

| ID | Area | iOS behaviour | Android behaviour | Why | Mirror? |
|---|---|---|---|---|---|
| D-M11-a | locked view tap-block | `.allowsHitTesting(false)` on sample stack, button in separate layer | `Modifier.pointerInput(Unit) { }` swallow-all | SDK (SwiftUI has native hit-testing toggle) | no |
| D-M11-b | blur | `.blur(radius: 16)` works on all iOS 17 platforms | `Modifier.blur` no-op below API 31, scrim is load-bearing | SDK (iOS 17 floor) | no |

No other divergences — the four analyses, gating, banned-claims wording, and premium gate are all shared decisions.

## 10. Out of scope

- Encrypted backup (Android Phase 2, deferred on both platforms).
- Release / TestFlight / App Store Connect (iOS-M12).
- New `TrendsRange` values beyond month/quarter/halfYear/year.
- Trends export or sharing.
- Multi-profile trends.

## 11. Verification (milestone done-when)

- All ported test tables green (`FeatureTrends` 40+ cases, `FeaturePaywall` updated, `SalusUI` chart tests).
- `scripts/ci.sh` 5/5 green; `scripts/build-app.sh` green.
- Manual QA matrix (`scripts/m11-manual-qa.md`) executed by the user: free user locked preview, premium user four cards, period switch, card hiding, no banned words, Vitals + More entry points, paywall feature list.
- Parity ledger updated: `D-M11-a`, `D-M11-b` recorded.
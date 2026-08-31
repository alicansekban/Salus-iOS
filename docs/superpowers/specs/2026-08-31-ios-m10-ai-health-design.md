# iOS-M10 — AI Health Summary + Doctor Report PDF Design

**Date:** 2026-08-31 · **Path:** architectural (new subsystem, third and final SPM dependency `firebase-ios-sdk`)
**Parity target:** `salus-android` "Plan 2 — AI Sağlık Özeti + AI Doktor Raporu (PDF)" (`docs/superpowers/plans/2026-08-20-plan2-ai-health.md`), shipped on `main`.
**Spec authority:** `salus-android/docs/superpowers/specs/2026-08-19-premium-subscription-design.md` (§2 Infrastructure, §3 core/ai, §5 AI Features, §7 Testing, §9 Compliance), `salus-android/docs/ios-v1-plan.md` §10 (iOS-M10 row) + §7 (AI contract), `salus-android/docs/parity-ledger.md` rows S-3 / S-15 / A3.
**Status:** draft — awaiting user review before the implementation plan is written.

## 1. Goal

Land the two premium AI features the M9 paywall gates promised. Concretely:

1. **`SalusAI`** becomes the real `:core:ai` twin: `SummaryModels` (`SummaryPeriod`, `AiLanguage`, `HealthPeriodStats`, `AiPrompt`, `disclaimerFor`, `DAILY_AI_CALL_LIMIT`, `minimumRecordDays`), `PromptBuilder` (fixed TR/EN prompt templates), `PlainText` (markdown stripper), `AiClient` + `FirebaseAiClient` adapter over `firebase-ios-sdk` (Firebase AI Logic, Gemini), `HealthStatsAggregator` (DAO reads → de-identified `HealthPeriodStats`), `AiSummaryRepository` (five-gate gating core).
2. **`FeatureAIHealth`** becomes the real `:feature:aihealth` twin: `AiSummaryViewModel`/`AiSummaryScreen` (summary screen with WEEKLY/MONTHLY segments), `DoctorReportViewModel`/`DoctorReportScreen` (report screen with PDF generation), `DoctorReportRepository`, `PdfReportGenerator` (`UIGraphicsPDFRenderer`), `ReportBlocks`/`ReportCopy`/`ReportWriter`/`ReportSurface` (the three-layer report layout), and the **PDFKit in-app preview screen** (`PDFView` — the iOS-specific addition the v1 plan calls for, Android uses `PdfRenderer` bitmaps).
3. **The `firebase-ios-sdk` SPM dependency** is added (the allowlist's third and **final** entry, closed at three: GRDB + `purchases-ios` + `firebase-ios-sdk`).
4. **The Home AI summary card** is wired in (the `HomeAiSummaryAvailability` adapter M7 set up gains a real `onOpenAiSummary` navigation callback), and the **More "Doctor Report (PDF)" row** is wired from its M9 no-op to a real `onOpenDoctorReport` navigation callback.
5. **`GoogleService-Info.plist`** is moved from `~/Downloads/` into the app target, git-ignored, and `FirebaseApp.configure()` runs only when the file is present — the "keyless build never crashes" guarantee, symmetric to Android's optional `google-services.json`.

Nothing else ships in M10. The advanced trends screen (iOS-M11) and the encrypted backup (iOS-M12) keep their M9 no-op callbacks in `RootView`.

## 2. Settled decisions (from the port contract — not re-litigated)

| # | Decision | Source |
|---|---|---|
| D1 | **`firebase-ios-sdk` is the third and final SPM dep**, pinned `from: "<latest stable>"` at execution time. The allowlist stays closed at three. Declared in `SalusAI/Package.swift` (the owner) and reached transitively by `FeatureAIHealth` and the app, exactly as GRDB is reached through `SalusDatabase` and `purchases-ios` through `SalusPremium`. | iOS `CLAUDE.md` (allowlist) |
| D2 | **Premium is per-platform; the premium check is never only in the UI.** `AiSummaryRepository` and `DoctorReportRepository` both re-check `PremiumRepository.status` before the AI call (parity ledger S-15). M9 wired the repository and the gate; M10 consumes it. | `ios-v1-plan.md` §6.3, S-15 |
| D3 | **One free AI summary per install, lifetime.** The `freeSummaryUsed` flag is in `AiUsageDataSource` (M1, already present). Reset on reinstall is accepted leakage (spec §1). The doctor report is premium in full — the free credit does not apply. | spec §1, §5 |
| D4 | **The model receives only `HealthPeriodStats` — aggregated, de-identified numbers.** No name, birth date, note text, medication name, or raw row ever leaves the device. The PDF tables are rendered on-device from `HealthPeriodRows` which also never leave the device. | spec §3, §9 |
| D5 | **Prompt templates are fixed; there is no free-form user input.** The system instruction forbids diagnosis and treatment advice in both languages, and enforces the "kaydedilen doz" / "recorded doses" wording (no "adherence"/"compliance"/"planned doses"). | spec §5, §7 (banned-claims) |
| D6 | **AI failure never fails the doctor report.** The deterministic tables are always produced; the AI narrative is strictly optional and skipped (with a note) on quota exhaustion, model error, or unconfigured SDK. | spec §5 |
| D7 | **`GoogleService-Info.plist` is git-ignored and optional.** `FirebaseApp.configure()` runs only when the file is present in the main bundle. A keyless build launches, runs fully without AI, and `isConfigured == false` surfaces `.unavailable` — never crashes. Symmetric to Android's optional `google-services.json`. | Android plan Task 1 |
| D8 | **The AI/PDF disclaimer is verbatim and mandatory** on every AI output and every PDF page footer: TR *"Bu rapor bilgilendirme amaçlıdır, tıbbi tavsiye değildir."* / EN *"This report is for informational purposes only and is not medical advice."* | spec §5, §9, `CLAUDE.md` |

## 3. Open decisions (resolved at planning time, with the user)

| # | Question | Resolution |
|---|---|---|
| O1 | `firebase-ios-sdk` version pin | **Latest stable at execution time**, pinned `from:` in `SalusAI/Package.swift`. Verified against the Firebase release feed. The pin is recorded in `README.md`'s Toolchain table alongside GRDB and `purchases-ios`. |
| O2 | `GoogleService-Info.plist` handling | **Git-ignored + optional runtime check.** The file is moved from `~/Downloads/GoogleService-Info.plist` into `App/` (or `App/Resources/`), added to `.gitignore`. `project.yml` references it as an optional resource (the file exists on disk for local builds; CI either injects it via a base64 secret or skips it — `swift test` never needs it because `FakeAiClient` backs all tests). `SalusApp.swift` checks `Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist")` and calls `FirebaseApp.configure()` only when present. A `GoogleService-Info.plist.example` (blank values) is **not** committed — unlike Android's `google-services.json`, the iOS plist is app-specific and a blank one is useless. The keyless path is documented in the manual QA matrix. |
| O3 | PDFKit preview vs Android PdfRenderer | **PDFKit `PDFView`** — the iOS v1 plan §10 mandates it. `PDFView` is a `UIView` that handles its own scroll/zoom/render and file descriptor lifecycle, so the Android `ReportDocumentOpener`/`ReportDocument`/`ReportPageScale`/`reportPageBitmapSize` infrastructure is **not ported**. The preview is a `.fullScreenCover` with a `PDFViewRepresentable` + close + `ShareLink`. This is the one place the iOS port is deliberately simpler than Android, and it is recorded as a divergence (`D-M10-a`). |

## 4. Architecture

### 4.1 Module graph delta

Two packages go from empty placeholders to real, and link into the app:

```
SalusAI          (← :core:ai)          deps: SalusModel, SalusCommon, SalusDatabase, SalusSettings,
                                        SalusPremium, firebase-ios-sdk (remote — 3rd and final)
FeatureAIHealth  (← :feature:aihealth) deps: SalusAI, SalusPremium, SalusNavigation, SalusSettings,
                                        SalusCommon, SalusDesignSystem, SalusUI
App                                   links: SalusAI, FeatureAIHealth (new in project.yml)
```

`SalusAI` owns the `firebase-ios-sdk` `.package(url:)` line — the **only** third remote dep in the tree. `FeatureAIHealth` and the app reach it transitively (the GRDB-through-`SalusDatabase` and `purchases-ios`-through-`SalusPremium` patterns). `project.yml`'s `packages:` block gains the two local packages; the app target's `dependencies:` gains `product: SalusAI` and `product: FeatureAIHealth`.

`.macOS(.v14)`: `SalusAI` reaches GRDB (via `SalusDatabase`) and therefore inherits GRDB's macOS 10.15 floor — the "Reaches GRDB" concession. `FeatureAIHealth` reaches SwiftUI — the "Reaches SwiftUI" concession. Both declare `[.iOS(.v17), .macOS(.v14)]`.

### 4.2 `SalusAI` — public API (the `:core:ai` twin)

Every type is the 1:1 port of its Kotlin file. Tests are the 1:1 port of the Kotlin test tables (the drift detector).

- **`SummaryModels.swift`**: `public enum SummaryPeriod: Sendable { case weekly, monthly }`; `public enum AiLanguage: Sendable { case tr, en }`; `public func disclaimerFor(_ language: AiLanguage) -> String`; `public let DAILY_AI_CALL_LIMIT = 5`; `public extension SummaryPeriod { var minimumRecordDays: Int }` (weekly=3, monthly=7); `public struct HealthPeriodStats: Equatable, Sendable` (periodType, startEpochDay, endEpochDay, distinctRecordDays, systolic/diastolic/pulse/glucoseMgDl/weightKg as `MetricStats?`, loggedDoses, takenDoses) with `var takenPercent: Int?` computed (loggedDoses<=0 → nil; else `round(takenDoses*100/loggedDoses)`); `public struct AiPrompt: Equatable, Sendable { let system: String; let user: String }`.
- **`PromptBuilder.swift`**: `public enum PromptBuilder` with `summaryPrompt(_:language:)` and `doctorReportPrompt(_:language:)`. Fixed system instruction (no diagnosis, no treatment advice, "değerlerinizi doktorunuzla paylaşın" / "talk to your doctor", plain text not markdown, "kaydedilen doz"/"recorded doses" enforced). `TurkishCopy`/`EnglishCopy` private structs. Locale-independent one-decimal `format(_:)`.
- **`PlainText.swift`**: `extension String { func asPlainText() -> String }` — markdown stripper (headings → no hashes, bullets → `•`, emphasis/code markers removed, words kept).
- **`AiClient.swift`**: `public enum AiResult: Equatable, Sendable { case success(String), case unavailable, case error(String) }`; `public protocol AiClient: Sendable { var isConfigured: Bool { get }; func generate(_ prompt: AiPrompt) async -> AiResult }`. Cancellation propagates naturally (Swift async); SDK failures map to `.error(message)`. No `throws` — everything maps to `AiResult`, matching Android's `suspend fun ... : AiResult`.
- **`FirebaseAiClient.swift`**: the adapter, behind `#if canImport(FirebaseAI)`. `isConfigured` → `FirebaseApp.app() != nil` (Android: `FirebaseApp.getApps(appContext).isNotEmpty()`). Unconfigured → `generate` returns `.unavailable` without touching the SDK. Configured → `GenerativeModel` with `modelName = "gemini-3.6-flash"`, `temperature = 0.4`, `maxOutputTokens = 2048`, `thinkingConfig = .minimal` (Android-identical). Blank/null response → `.error("empty response")`. All exceptions → `.error(message)`. Response text stripped via `asPlainText()`. Constants: `MODEL_NAME`, `TEMPERATURE`, `MAX_OUTPUT_TOKENS`, `EMPTY_RESPONSE`, `GENERATION_FAILED`.
- **`HealthPeriodReader.swift`**: `public protocol HealthPeriodReader: Sendable` with `aggregate(period:todayEpochDay:timeZone:) async -> HealthPeriodStats` and `periodRows(period:todayEpochDay:timeZone:) async -> HealthPeriodRows`. The module-boundary seam — `SalusAI` takes `SalusDatabase` as `implementation`, so DAO types never reach a feature.
- **`HealthStatsAggregator.swift`**: `HealthStatsAggregator` struct taking `VitalsDao`, `MedicationDao`, `profileId`. `aggregate` and `periodRows` do thin DAO reads, delegate to pure functions. `periodBoundsOf(_:todayEpochDay:) -> ClosedRange<Int>` (weekly=7, monthly=30). `epochMsBoundsOf(_:timeZone:) -> ClosedRange<Int64>`. `healthStatsOf(...)` — pure: maps measurements to day-bucketed stats, counts distinct record days, `metricStatsOf` per metric, dose counts from intake logs. `healthRowsOf(...)` — pure: maps measurements to note-free row types, oldest first.
- **`PeriodRows.swift`**: `HealthPeriodRows` (bloodPressure/glucose/weight `[Row]`, `isEmpty`), `BloodPressureRow`, `GlucoseRow` (context: `MeasurementContext?`), `WeightRow`.
- **`AiSummaryRepository.swift`**: `AiSummary` struct, `SummaryFailureReason { error, unavailable }`, `SummaryOutcome` enum (`.ready(summary:fromCache:)`, `.needsMoreData`, `.needsPremium`, `.dailyLimitReached`, `.failed(reason:)`), `protocol AiSummaryRepository: Sendable`, `AiSummaryRepositoryImpl`. Five gates in order: (1) cache, (2) enough data, (3) entitlement (re-check store once on "no"), (4) daily quota, (5) the call. Success → append disclaimer + cache upsert + `recordCall` + (free) `markFreeSummaryUsed`. Failure → nothing spent. `freeSummaryAvailable: AsyncStream<Bool>` for the UI badge.

**Tests** (`SalusAITests`): `PromptBuilderTest` (5: TR/EN instruction, null metrics omitted, "teşhis" ban, takenPercent null → no dose line, adherence math), `PlainTextTest` (markdown stripping), `HealthStatsAggregatorTest` (4 pure-function behaviors), `AiSummaryRepositoryTest` (8: cache hit, insufficient data, free+spent → needsPremium, free+available → call+mark, premium+quota=5 → dailyLimit, error → failed+nothing spent, success → disclaimer+cached, offline → credit survives). `FakeAiClient` (queued results + recorded prompts). The `FirebaseAiClient` adapter is **not** unit-tested (no SDK in `swift test`) — covered by fake-backed tests + manual QA, exactly as Android covers `RevenueCatPurchasesGateway`.

### 4.3 `FeatureAIHealth` — the `:feature:aihealth` twin

- **`domain/AiLanguageProvider.swift`**: `protocol AiLanguageProvider: Sendable { func current() -> AiLanguage }`. App locale "en" → `.en`, else `.tr`.
- **`ui/AiSummaryUiState.swift`**: `AiSummaryResult` (`.loading`, `.content(text:fromCache:)`, `.insufficientData`, `.premiumRequired`, `.dailyLimit`, `.error(reason:)`), `AiSummaryUiState` (period + result), `AiSummaryEvent` (`.periodSelected`, `.retryClicked`, `.upgradeClicked`).
- **`ui/AiSummaryViewModel.swift`**: `@MainActor @Observable`. Takes `AiSummaryRepository`, `PremiumRepository`, `PaywallController`, `AiLanguageProvider`, `SalusClock`. `load(_:)` cancels in-flight task. `observeEntitlement` — premium arrival while `.premiumRequired` → auto-retry. `.upgradeClicked` → `paywallController.show(.aiSummary)`.
- **`ui/AiSummaryScreen.swift`**: Route (stateful) + Screen (stateless + `#Preview`). WEEKLY/MONTHLY segmented control. Per-state UI: content → text + disclaimer; insufficientData → "keep logging"; premiumRequired → upgrade button (paywall); dailyLimit → "try tomorrow"; error → retry (only `.error`, not `.unavailable`).
- **`report/ReportBlocks.swift`**: `ReportBlock` enum (`.title`, `.section`, `.body`, `.gap`, `.table(heading:columns:weights:rows:)`). `reportBlocksOf(stats:rows:narrative:copy:generatedOn:)`. `formatReportDate(epochDay:)` (`dd.MM.yyyy`). `asInteger()`/`asDecimal()` helpers.
- **`report/ReportCopy.swift`**: `protocol ReportCopy` + `TurkishReportCopy`/`EnglishReportCopy`. Kotlin copy (not resources) — the document outlives the session and must not change with a language switch.
- **`report/ReportWriter.swift`**: `ReportTextStyle` enum, `ReportSurface` protocol (`.startPage`, `.drawText`, `.widthOf`, `.finishPage`), `ReportWriter` class. A4 595×842pt, margin 40, footer disclaimer on every page, page break logic, text wrapping, table column offsets — Android 1:1.
- **`report/PdfReportGenerator.swift`**: `protocol PdfReportGenerator` + `IosPdfReportGenerator`. `UIGraphicsPDFRenderer` for A4 PDF. Output to `cachesDirectory/reports/salus-report-<start>-<end>.pdf`. Stale files pruned. `generate(stats:rows:narrative:language:) -> URL`.
- **`report/DoctorReportRepository.swift`**: `ReportOutcome` (`.ready(pdfFile:narrativeIncluded:)`, `.needsPremium`, `.needsMoreData`, `.failed(message:)`), `DoctorReportRepositoryImpl`. Three rules: (1) premium gate first (free credit does not apply), (2) deterministic half never depends on AI, (3) narrative optional — skipped on thin data, quota, or error (with note, never UI error).
- **`ui/DoctorReportUiState.swift`**: `DoctorReportResult` (`.idle`, `.generating`, `.ready(pdfFile:narrativeIncluded:)`, `.premiumRequired`, `.insufficientData`, `.failed`), `DoctorReportPreview` (`.hidden`, `.opening`, `.ready(url:)`, `.failed`), `DoctorReportEvent` (`.periodSelected`, `.generateClicked`, `.upgradeClicked`, `.previewClicked`, `.previewDismissed`).
- **`ui/DoctorReportViewModel.swift`**: `@MainActor @Observable`. `generateTask`/`previewTask` cancellation. `observeEntitlement` — premium arrival while `.premiumRequired` → `.idle` (no auto-generate). `openPreview()` → URL non-nil → `.ready(url:)`; nil → `.failed`. `closePreview()` → `.hidden`. No file descriptor lifecycle (PDFKit manages it).
- **`ui/DoctorReportScreen.swift`**: Route + Screen. Period selector, generate button, per-state UI. `needsPremium` → paywall button (`.doctorReport`). `ready` → share/regenerate + **preview button**.
- **`ui/DoctorReportPreviewScreen.swift`** (iOS-specific): `.fullScreenCover`. `PDFViewRepresentable` (`UIViewRepresentable` wrapping `PDFView`) with `PDFDocument(url:)`. Close button + `ShareLink(item: url)` (iOS 17+ native). Behind `#if canImport(PDFKit)`.
- **`navigation/AiHealthNavigation.swift`**: `AiSummaryKey: Hashable, Sendable`, `DoctorReportKey: Hashable, Sendable`. `aiHealthDestinations(onOpenAiSummary:onOpenDoctorReport:)`.
- **`AiHealthStrings.swift`** + `Resources/Localizable.xcstrings`: `ai_summary_*` and `doctor_report_*` key prefixes. TR + EN. Banned-claims test.
- **`AiHealthModule.swift`**: `makeAiSummaryViewModel()`, `makeDoctorReportViewModel()`.

**Tests** (`FeatureAIHealthTests`): `AiSummaryViewModelTest` (5: weekly load, needsPremium → premiumRequired + paywall on button only, premium arrival → auto-retry, segment change → monthly query, failed → error + retry), `DoctorReportRepositoryTest` (5: free → needsPremium, AI error → ready(narrativeIncluded:false), AI success → ready(narrativeIncluded:true) + recordCall, quota full → AI skipped, no data → needsMoreData), `ReportBlocksTest` (pure block generation), `AiHealthStringsTest` (parity + banned-claims).

### 4.4 Home + More wiring

- **Home card** (`FeatureHome`): `HomeAiSummaryAvailability` adapter (M7) already publishes `freeSummaryAvailable`. The card (`HomeScreen.swift`) gains `onOpenAiSummary` callback. `freeAiSummaryAvailable` → "1 ücretsiz deneme hakkın var" subtitle. Tap → `AiSummaryKey` push. `HomeNavigation.swift`'s `onOpenAiSummary` (currently a `TODO(M10)` no-op) becomes a real callback. `RootView.swift` wires it.
- **More row** (`FeatureSettings`): `doctorReportClicked` (M9) already routes entitled → `onOpenDoctorReport`, free → `paywallController.show(.doctorReport)`. `onOpenDoctorReport` (currently `TODO(M10)` no-op in `RootView`) becomes a real `DoctorReportKey` push.

### 4.5 Shell wiring (`App`)

- **`AppCompositionRoot.swift`**: new `let aiClient: any AiClient`, `let healthStatsAggregator: HealthStatsAggregator`, `let aiSummaryRepository: any AiSummaryRepository`. `makeHomeModule` gains `onOpenAiSummary`. `makeSettingsModule`'s `onOpenDoctorReport` becomes real.
- **`SalusApp.swift`**: at launch, `if let plist = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") { FirebaseApp.configure() }` before the composition root builds the AI client. The `isConfigured` check on `FirebaseAiClient` answers `false` when `FirebaseApp.app() == nil`.
- **`RootView.swift`**: `onOpenAiSummary` and `onOpenDoctorReport` push `AiSummaryKey`/`DoctorReportKey`. The `TODO(M10)` comments are removed.
- **`AppCompositionRoot+Modules.swift`**: `makeAiHealthModule` (or inline factories) for the two ViewModels.
- **`project.yml`**: `SalusAI` + `FeatureAIHealth` in `packages:` and app `dependencies:`. `GoogleService-Info.plist` referenced as a resource (present on disk for local builds; `.gitignore`'d). Regenerated `pbxproj` committed together.
- **`.gitignore`**: `App/GoogleService-Info.plist` added.
- **`README.md`**: Toolchain table gains `firebase-ios-sdk` pin.

## 5. Data flow

```
FirebaseAI Logic (Gemini)
   │ generateContent
   ▼
FirebaseAiClient ──AiResult──▶ AiSummaryRepositoryImpl ──SummaryOutcome──▶ AiSummaryViewModel
   │                                │                                          │
   │                                ▼                                          ▼
   │                     HealthStatsAggregator ──HealthPeriodStats────▶ PromptBuilder (prompt)
   │                                │
   │                                ▼
   │                     VitalsDao + MedicationDao (SalusDatabase)
   │
   ▼
DoctorReportRepositoryImpl ──ReportOutcome──▶ DoctorReportViewModel
   │                                               │
   ▼                                               ▼
PdfReportGenerator (UIGraphicsPDFRenderer)     DoctorReportScreen → PDFKit preview → ShareLink
   │
   ▼
cachesDirectory/reports/salus-report-<start>-<end>.pdf
```

The repository is the single source of gating. The paywall controller (M9) is the single channel for "open the paywall". Premium status flows from `PremiumRepository` (M9) into both repositories.

## 6. Error handling

- **Unconfigured SDK** (no `GoogleService-Info.plist`, keyless build): `FirebaseApp.app() == nil` → `isConfigured == false` → `generate` returns `.unavailable`. Summary screen shows "AI not available on this build" (no retry). Doctor report: narrative skipped, PDF still produced. The app runs fully without AI, never crashes. (D7)
- **Network/quota/model error**: `AiResult.error` → summary `.failed(.error)` (retry offered); doctor report narrative skipped, PDF produced with note.
- **Cache hit**: summary returned as-is, no AI call, no quota spent, no gate re-checked. A lapsed premium user keeps summaries they already paid for.
- **Insufficient data**: `distinctRecordDays < minimumRecordDays` → summary `.needsMoreData` (no AI call, sits above entitlement gate — a free user with two days of records is told to keep logging, never shown a paywall for a summary of nothing). Doctor report: tables still produced if `distinctRecordDays > 0`; narrative skipped if below threshold.
- **Concurrent generation**: `loadTask?.cancel()` / `generateTask?.cancel()` — a period switch cancels the in-flight request.

## 7. Testing

- **`SalusAITests`**: `PromptBuilderTest` (5), `PlainTextTest`, `HealthStatsAggregatorTest` (4), `AiSummaryRepositoryTest` (8) — over `FakeAiClient` + fake DAO/usage/premium. `FirebaseAiClient` is **not** unit-tested (no SDK in `swift test`).
- **`FeatureAIHealthTests`**: `AiSummaryViewModelTest` (5), `DoctorReportRepositoryTest` (5), `ReportBlocksTest`, `AiHealthStringsTest` (parity + banned-claims).
- **`FeatureHomeTests`**: `HomeViewModelTests` — the `onOpenAiSummary` callback assertion (the card's tap target is now real).
- **`FeatureSettingsTests`**: `MoreViewModelTests` — `doctorReportClicked` entitled path now navigates (the M9 test asserted the gate; the navigation assertion becomes real).
- **Repo-wide**: `BannedHealthClaims` stays green (the AI strings, report copy, and prompt templates all contain "kaydedilen doz"/"recorded doses"); `scripts/ci.sh` 5/5; `scripts/test-packages.sh SalusAI FeatureAIHealth FeatureHome FeatureSettings SalusModel SalusSettings SalusPremium SalusDatabase` + `scripts/build-app.sh` green per task.
- **Manual QA** (`scripts/m10-manual-qa.md`, written by executors, run by the user): (1) keyless build (no plist) launches, AI screens show "unavailable", app never crashes; (2) configured build: weekly summary with ≥3 record days produces text + disclaimer; (3) monthly summary with <7 days → "needs more data"; (4) free user: one free summary, then paywall; (5) premium user: daily limit after 5 calls; (6) doctor report: premium-only, PDF produced with tables, narrative optional; (7) PDFKit preview opens, scrolls, shares via `ShareLink`; (8) offline: summary → retry → credit survives; doctor report → PDF without narrative; (9) Home card tap → summary screen; More row tap → doctor report screen; (10) banned-claims scan repo-wide stays green.

## 8. Files touched (summary)

**New (SalusAI):** `SummaryModels.swift`, `PromptBuilder.swift`, `PlainText.swift`, `AiClient.swift`, `FirebaseAiClient.swift`, `HealthPeriodReader.swift`, `HealthStatsAggregator.swift`, `PeriodRows.swift`, `AiSummaryRepository.swift`, `Package.swift` (deps + `firebase-ios-sdk`), tests × 4, `FakeAiClient.swift`.
**New (FeatureAIHealth):** `domain/AiLanguageProvider.swift`, `ui/AiSummaryUiState.swift`, `ui/AiSummaryViewModel.swift`, `ui/AiSummaryScreen.swift`, `ui/DoctorReportUiState.swift`, `ui/DoctorReportViewModel.swift`, `ui/DoctorReportScreen.swift`, `ui/DoctorReportPreviewScreen.swift` (iOS-specific), `report/ReportBlocks.swift`, `report/ReportCopy.swift`, `report/ReportWriter.swift`, `report/PdfReportGenerator.swift`, `report/DoctorReportRepository.swift`, `navigation/AiHealthNavigation.swift`, `AiHealthStrings.swift`, `Resources/Localizable.xcstrings`, `AiHealthModule.swift`, `Package.swift` (deps), tests × 4.
**New (App):** `scripts/m10-manual-qa.md`. `GoogleService-Info.plist` (moved from `~/Downloads/`, git-ignored).
**Modified:** `App/SalusApp.swift` (`FirebaseApp.configure`), `App/RootView.swift` (real `onOpenAiSummary`/`onOpenDoctorReport`), `App/AppCompositionRoot.swift` (+ AI graph), `App/AppCompositionRoot+Modules.swift`, `project.yml` (+ regenerated pbxproj), `README.md` (Toolchain table), `.gitignore` (`GoogleService-Info.plist`), `Packages/Features/FeatureHome/.../HomeScreen.swift` (AI card tap), `HomeNavigation.swift`, `HomeModule.swift`, `Packages/Features/FeatureSettings/.../navigation/SettingsNavigation.swift` (real `onOpenDoctorReport`), `Packages/SalusDatabase/.../Migrations.swift` (if `AiSummaryDao` needs adding — the record exists, the DAO may not).

## 9. Divergences (recorded in the parity ledger)

| ID | Area | iOS behaviour | Android behaviour | Why | Mirror? |
|---|---|---|---|---|---|
| D-M10-a | PDF preview | `PDFKit PDFView` — `UIView` that manages its own scroll/zoom/render and file descriptor lifecycle | `PdfRenderer` + `ReportDocumentOpener`/`ReportDocument` + `reportPageBitmapSize` + bitmap rendering + monitor lock for single-open-page | SDK (PDFKit is near-free on iOS; the Android infrastructure exists because `PdfRenderer` is bare) | no |

No other divergences — the rest is a 1:1 port. The gating order, prompt templates, disclaimer text, `DAILY_AI_CALL_LIMIT`, `minimumRecordDays`, and `takenPercent` rule are all shared decisions (S-9, spec §5/§7/§9).

## 10. Out of scope (M11+)

- Advanced trends screen (iOS-M11).
- Encrypted backup (iOS-M12; `PaywallSource.backup` reserved, no caller).
- App Store Connect / Firebase console configuration (manual steps in the QA matrix, not code).
- Multi-profile (every table carries `profile_id`; the single-profile assumption is confined to one place per module).

## 11. Verification (milestone done-when)

- All ported test tables green (`SalusAI` 17+ cases, `FeatureAIHealth` 14+ cases, updated `HomeViewModel`/`MoreViewModel` tests).
- `scripts/ci.sh` 5/5 green; `scripts/build-app.sh` green with `firebase-ios-sdk` resolved.
- A keyless build (no `GoogleService-Info.plist`) launches, AI screens show "unavailable", app never crashes.
- Manual QA matrix (`scripts/m10-manual-qa.md`) executed by the user: summary generation, free credit, premium gate, daily limit, doctor report PDF, PDFKit preview, offline fallback, Home/More wiring.
- Parity ledger updated: `D-M10-a` recorded; A3 ("Finish AI Plan 2") marked landed on iOS.
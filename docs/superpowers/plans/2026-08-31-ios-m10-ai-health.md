# iOS-M10 — AI Health Summary + Doctor Report PDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Format notu:** Bu plan bilinçli olarak KOMPAKT yazılmıştır (kullanıcı tercihi): tam kod
> yerine sözleşme + davranış listesi verilir. Implementer tam kodu kendisi yazar, testleri
> davranış listelerinden türetir. Executor subagent'lar `model: "opus"` ile dispatch edilir.
> Test komutları context-mode gereği `ctx_execute(language: "shell")` ile koşulur.

**Goal:** Android'in "Plan 2 — AI Sağlık Özeti + AI Doktor Raporu PDF" planının iOS portunu yapmak: `SalusAI` modülü (Firebase AI Logic + App Check), `FeatureAIHealth` (özet ekranı + doktor raporu PDF + PDFKit önizleme), Home kartı ve More satırı wiring.

**Architecture:** Yeni `SalusAI` paketi Firebase AI Logic (Gemini) client'ını, sabit prompt şablonlarını, istatistik toplayıcıyı ve hak/gating repository'sini taşır; yeni `FeatureAIHealth` paketi özet ekranını, PDF rapor üretimini (`UIGraphicsPDFRenderer`) ve PDFKit önizlemeyi taşır. AI'ya asla ham kayıt gitmez — yalnızca önceden hesaplanmış anonim istatistik özeti. Tüm premium/hak kontrolleri repository seviyesindedir; AI başarısız olsa da PDF üretilir.

**Tech Stack:** `firebase-ios-sdk` (`FirebaseAI Logic` product — Gemini, model `gemini-3.6-flash`; `FirebaseAppCheck` — App Attest iOS'ta, Android'deki Play Integrity yerine), GRDB (mevcut), `UIGraphicsPDFRenderer` (PDF üretimi), PDFKit `PDFView` (önizleme — iOS-specific, Android'in `PdfRenderer` bitmap altyapısı yerine), `ShareLink` (iOS 17+ native paylaşım), SwiftUI, Swift 6, `@Observable`.

**Spec:** `salus-ios/docs/superpowers/specs/2026-08-31-ios-m10-ai-health-design.md` (approved) — the plan argues from the spec, so the spec travels with it; executors read both.

## Global Constraints

- Premium/tek-hak kontrolü **repository seviyesinde**, AI çağrısından hemen önce tekrarlanır; UI kilidi yalnızca deneyimdir (spec §4.2, §4.3).
- Modele **kimlik bilgisi gitmez** (isim, doğum tarihi, not metinleri, ilaç adları); yalnızca sayısal istatistik özeti (spec D4).
- Prompt şablonları **sabittir**, serbest kullanıcı girdisi yoktur (spec D5).
- Veri yetersizse AI çağrısı yapılmaz: haftalık özet için ≥3 farklı gün, aylık için ≥7 farklı gün kayıt (spec §4.2).
- Aynı dönem için üretilmiş özet cache'den gelir, **yeni AI çağrısı yapılmaz** (spec §4.2).
- Cihaz başına **günlük 5 AI çağrısı** limiti, `AiUsageDataSource` sayacıyla (mevcut, M1'den beri).
- Her AI çıktısı ve her PDF sayfasında sabit ibare: **"Bu rapor bilgilendirme amaçlıdır, tıbbi tavsiye değildir."** / EN: "This report is for informational purposes only and is not medical advice." (spec D8).
- AI kısmı başarısız olursa (ağ yok, kota, unconfigured) **PDF yine üretilir**, anlatı notla atlanır (spec D6).
- `GoogleService-Info.plist` **asla commit edilmez** (`.gitignore`'a girer); dosya yokken `FirebaseApp.configure()` çağrılmaz ve app AI'sız çalışır (spec D7, O2).
- Ücretsiz AI Sağlık Özeti hakkı **ömür boyu 1 kez**; `AiUsageDataSource.freeSummaryUsed` bayrağı (mevcut).
- Her kullanıcıya görünen string: `Localizable.xcstrings` (TR source + EN).
- Mevcut konvansiyonlar: SwiftPM paketleri, `@MainActor @Observable` ViewModel'lar, Route/Screen split, `…Destinations()`, `@Environment(\.<name>Module)`, `Bundle.module` string access, `SalusTesting` test-target-only.
- `firebase-ios-sdk` allowlist'in **3. ve son** girişi; başka remote dep eklenmez.
- `versionCode`/build number bu planda DEĞİŞMEZ (release işi ayrı).
- `SalusAI` paketi **henüz mevcut değil** — Task 1 oluşturur. `FeatureAIHealth` paketi **boş placeholder** olarak mevcut — Task 6+ doldurur.

---

## Dosya Haritası

| Birim | Sorumluluk |
|---|---|
| `SalusAI` (YENİ paket) | `SummaryModels`, `PromptBuilder`, `PlainText`, `AiClient` + `FirebaseAiClient`, `HealthPeriodReader`/`HealthStatsAggregator` + `PeriodRows`, `AiSummaryRepository` (gating çekirdeği) |
| `SalusDatabase` | `AiSummaryDao` (yeni — `AiSummaryRecord` zaten mevcut) |
| `FeatureAIHealth` (mevcut placeholder) | Özet ekranı, doktor raporu ekranı, PDFKit önizleme, `PdfReportGenerator`, `DoctorReportRepository`, `ReportBlocks`/`ReportCopy`/`ReportWriter`/`ReportSurface` |
| `FeatureHome` | "AI Sağlık Özeti" kartı + `onOpenAiSummary` navigasyon callback |
| `FeatureSettings` | More ekranındaki `onOpenDoctorReport` no-op'tan gerçek navigate'e |
| `App` | `FirebaseApp.configure()`, `GoogleService-Info.plist` taşıma, Koin modül kayıtları yerine composition root, project.yml güncellemesi |

---

### Task 1: `SalusAI` paketi iskeleti + `SummaryModels` + `PromptBuilder` + `PlainText` (saf Swift)

**Files:**
- Create: `Packages/SalusAI/Package.swift`, `Packages/SalusAI/Sources/SalusAI/SummaryModels.swift`, `Packages/SalusAI/Sources/SalusAI/PromptBuilder.swift`, `Packages/SalusAI/Sources/SalusAI/PlainText.swift`
- Test: `Packages/SalusAI/Tests/SalusAITests/PromptBuilderTests.swift`, `Packages/SalusAI/Tests/SalusAITests/PlainTextTests.swift`

**Interfaces (Produces):**
```swift
public enum SummaryPeriod: Sendable { case weekly, monthly }
public enum AiLanguage: Sendable { case tr, en }
public func disclaimerFor(_ language: AiLanguage) -> String
public let DAILY_AI_CALL_LIMIT = 5
public extension SummaryPeriod { var minimumRecordDays: Int }  // weekly=3, monthly=7
public struct HealthPeriodStats: Equatable, Sendable {
    public let periodType: SummaryPeriod
    public let startEpochDay: Int
    public let endEpochDay: Int
    public let distinctRecordDays: Int
    public let systolic: MetricStats?
    public let diastolic: MetricStats?
    public let pulse: MetricStats?
    public let glucoseMgDl: MetricStats?
    public let weightKg: MetricStats?
    public let loggedDoses: Int
    public let takenDoses: Int
    public var takenPercent: Int?  // loggedDoses<=0 → nil; else round(takenDoses*100/loggedDoses)
}
public struct AiPrompt: Equatable, Sendable { public let system: String; public let user: String }
public enum PromptBuilder {
    public static func summaryPrompt(_ stats: HealthPeriodStats, language: AiLanguage) -> AiPrompt
    public static func doctorReportPrompt(_ stats: HealthPeriodStats, language: AiLanguage) -> AiPrompt
}
extension String { func asPlainText() -> String }  // markdown stripper
```

**Davranış sözleşmesi:**
- `Package.swift`: `// swift-tools-version: 6.0`; platforms `[.iOS(.v17), .macOS(.v14)]` (GRDB via SalusDatabase → macOS floor); deps: `SalusModel`, `SalusCommon`, `SalusDatabase`, `SalusSettings`, `SalusPremium` (hepsi `.package(path:)`); product `SalusAI`; test target deps `SalusTesting`. `firebase-ios-sdk` bu task'ta **EKLENMEZ** — Task 2'de gelir.
- `SummaryModels.swift`: Android `SummaryModels.kt` 1:1 port. `disclaimerFor` sabit TR/EN cümle. `minimumRecordDays`: weekly=3, monthly=7 (private constants). `takenPercent`: `loggedDoses <= 0` → nil; else `(Double(takenDoses) * 100 / Double(loggedDoses)).rounded()`.
- `PromptBuilder.swift`: Android `PromptBuilder.kt` 1:1 port. System talimatı sabit: sağlık verisi gözlemcisisin; teşhis koyma, tedavi/ilaç önerme; "kaydedilen doz" ifadesi zorunlu (banned stems yok); düz metin (markdown yok). `TurkishCopy`/`EnglishCopy` private struct'lar. `format(_:)` locale-independent one-decimal (Android'deki `roundToLong` mantığı).
- `PlainText.swift`: Android `PlainText.kt` 1:1 port. `asPlainText()`: heading → başlıksız, bullet (`-`/`*`/`+`) → `• `, emphasis (`**`/`__`/`*`/`` ` ``) → kaldırılır, kelimeler korunur. Blank leading/trailing lines trim.

**Test davranışları (`PromptBuilderTests`):** (1) TR system talimatı "teşhis" yasağını içerir, "Türkçe" ister; EN "diagnose" yasağını içerir, "English" ister; (2) null metrikler (systolic=nil vb.) prompt'ta hiç geçmez — user metni boş ölçüm listesi içermez; (3) system talimatı "teşhis"/"diagnose" yasağını içerir; (4) `takenPercent` nil iken (loggedDoses=0) ilaç cümlesi prompt'ta yok; (5) `takenPercent` hesabı: 0 planned → nil, 3/4 → 75.
**Test davranışları (`PlainTextTests`):** (1) `**bold**` → `bold`; (2) `# Heading` → `Heading`; (3) `- item` → `• item`; (4) `` `code` `` → `code`; (5) plain text korunur; (6) blank leading/trailing lines trim, iç boşluklar korunur.

**Adımlar:**
- [ ] `Packages/SalusAI/` dizin yapısı + `Package.swift` (firebase yok, core deps var) → [ ] failing testler → [ ] implementasyon (`SummaryModels` + `PromptBuilder` + `PlainText`) → [ ] testler yeşil (ctx_execute: `swift test --package-path Packages/SalusAI`) → [ ] Commit: `feat(ai): add SalusAI package with period stats model and fixed prompt templates`

---

### Task 2: `AiClient` arayüzü + `FirebaseAiClient` adapter'ı + Firebase bağımlılığı

**Files:**
- Create: `Packages/SalusAI/Sources/SalusAI/AiClient.swift`, `Packages/SalusAI/Sources/SalusAI/FirebaseAiClient.swift`, `Packages/SalusAI/Tests/SalusAITests/FakeAiClient.swift`
- Modify: `Packages/SalusAI/Package.swift` (`firebase-ios-sdk` remote dep ekle)

**Interfaces (Produces):**
```swift
public enum AiResult: Equatable, Sendable {
    case success(String)
    case unavailable
    case error(String)
}
public protocol AiClient: Sendable {
    var isConfigured: Bool { get }
    func generate(_ prompt: AiPrompt) async -> AiResult
}
// FirebaseAiClient: behind #if canImport(FirebaseAI) — not compiled in `swift test` host build
// FakeAiClient: in test target — queued results + recorded prompts
```

**Davranış sözleşmesi:**
- `Package.swift`: `dependencies`'e `.package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "<latest stable>")` eklenir. Target deps'e `.product(name: "FirebaseAI", package: "firebase-ios-sdk")` ve `.product(name: "FirebaseAppCheck", package: "firebase-ios-sdk")`. **Allowlist 3'te kapatıldı.**
- `AiClient.swift`: `AiResult` enum (`.success`, `.unavailable`, `.error(String)`). `AiClient` protocol: `isConfigured`, `generate(_:) async -> AiResult` (throws yok — her şey AiResult'a map'lenir, cancellation otomatik propagate).
- `FirebaseAiClient.swift`: **`#if canImport(FirebaseAI)` guard'ı** — `swift test` macOS host build'de Firebase iOS framework yok, bu dosya derlenmez; app build'de (iOS) derlenir. `isConfigured` → `FirebaseApp.app() != nil`. Unconfigured → `generate` SDK'ya dokunmadan `.unavailable`. Configured → `GenerativeModel` config: `modelName = "gemini-3.6-flash"`, `temperature = 0.4`, `maxOutputTokens = 2048`, `thinkingConfig = .minimal` (Android ile aynı). Boş/null yanıt → `.error("empty response")`. Tüm exception'lar `do/catch` → `.error(message ?? GENERATION_FAILED)`. Response text `asPlainText()` ile strip'lenir. Constants: `MODEL_NAME`, `TEMPERATURE`, `MAX_OUTPUT_TOKENS`, `EMPTY_RESPONSE`, `GENERATION_FAILED`.
- `FakeAiClient.swift` (test): Queued `AiResult` listesi + recorded prompt'lar. `isConfigured` configurable. `generate` bir sonraki queued result'ı döner (queue boşsa `.error("no queued result")`).

**Test davranışları:** Firebase SDK'sı unit test edilmez (Android ile aynı — "no SDK in `swift test`"). `FakeAiClient` sonraki task'ların ortak fake'i. Bu task'ta sadece `FakeAiClient`'in kendi davranışları test edilir: (1) queued result sırayla döner; (2) `isConfigured` propagate edilir; (3) prompt'lar recorded listesine eklenir.

**Adımlar:**
- [ ] `Package.swift` firebase dep ekle → [ ] `AiClient.swift` + `FakeAiClient.swift` → [ ] failing testler → [ ] `FirebaseAiClient.swift` (`#if canImport` guard) → [ ] testler yeşil + `swift build` (host, Firebase olmadan) yeşil (ctx_execute) → [ ] Commit: `feat(ai): add AiClient seam with Firebase AI Logic adapter`

---

### Task 3: `HealthStatsAggregator` + `HealthPeriodReader` + `PeriodRows` (DAO okumaları + saf hesap)

**Files:**
- Create: `Packages/SalusAI/Sources/SalusAI/HealthPeriodReader.swift`, `Packages/SalusAI/Sources/SalusAI/HealthStatsAggregator.swift`, `Packages/SalusAI/Sources/SalusAI/PeriodRows.swift`
- Test: `Packages/SalusAI/Tests/SalusAITests/HealthStatsAggregatorTests.swift`

**Interfaces (Produces):**
```swift
public protocol HealthPeriodReader: Sendable {
    func aggregate(period: SummaryPeriod, todayEpochDay: Int, timeZone: TimeZone) async -> HealthPeriodStats
    func periodRows(period: SummaryPeriod, todayEpochDay: Int, timeZone: TimeZone) async -> HealthPeriodRows
}
public struct HealthStatsAggregator: HealthPeriodReader { /* vitalsDao, medicationDao, profileId */ }
public struct HealthPeriodRows: Equatable, Sendable { /* bloodPressure, glucose, weight; isEmpty */ }
public struct BloodPressureRow: Equatable, Sendable { /* epochDay, systolic, diastolic?, pulse? */ }
public struct GlucoseRow: Equatable, Sendable { /* epochDay, mgDl, context: MeasurementContext? */ }
public struct WeightRow: Equatable, Sendable { /* epochDay, kilograms */ }
// Pure helpers (internal):
func periodBoundsOf(_ period: SummaryPeriod, todayEpochDay: Int) -> ClosedRange<Int>  // weekly=7, monthly=30
func epochMsBoundsOf(_ days: ClosedRange<Int>, timeZone: TimeZone) -> ClosedRange<Int64>
func healthStatsOf(period:days:measurements:intakeLogs:timeZone:) -> HealthPeriodStats
func healthRowsOf(days:measurements:timeZone:) -> HealthPeriodRows
```

**Davranış sözleşmesi:**
- `HealthPeriodReader.swift`: Protocol — modül sınırı için. `SalusAI` `SalusDatabase`'i `implementation` (target dep) ile alır, DAO tipleri feature'lara sızamaz. Consumer'lar bu protocol üzerinden değiştirebilir.
- `HealthStatsAggregator.swift`: `VitalsDao`, `MedicationDao`, `profileId` alır. `aggregate`: `periodBoundsOf` → `epochMsBoundsOf` → `vitalsDao.getMeasurementsBetween(profileId, millisFirst, millisLast)` + `medicationDao.getIntakeLogsBetween(profileId, daysFirst, daysLast)` → `healthStatsOf`. `periodRows`: aynı DAO okumaları → `healthRowsOf` (sadece vitals — dose figures `aggregate`'ten gelir).
- `PeriodRows.swift`: `HealthPeriodRows` (3 liste, `isEmpty`), `BloodPressureRow`, `GlucoseRow` (context `MeasurementContext?`), `WeightRow`. Android `PeriodRows.kt` 1:1.
- Saf fonksiyonlar: `periodBoundsOf` (weekly=7, monthly=30 gün, `(today - dayCount + 1)...today`), `epochMsBoundsOf` (LocalDate.fromEpochDays → atStartOfDayIn → epochMs), `healthStatsOf` (measurements day-bucket'lanır, `metricStatsOf` per metric, `distinctRecordDays` set'inden, dose counts intake logs'tan), `healthRowsOf` (measurements → note-free row types, oldest first).
- **Mevcut DAO'lar:** `VitalsDao.getMeasurementsBetween` ve `MedicationDao.getIntakeLogsBetween` zaten mevcut (doğrulandı). Yeni sorgu eklenmez.
- `epochDayIn(timeZone)` helper: `Instant.fromEpochMilliseconds(measuredAtEpochMs).toLocalDateTime(timeZone).date.epochDay`.

**Test davranışları (`HealthStatsAggregatorTests`):** Saf fonksiyonlar test edilir, DAO erişimi ince tutulur: (1) `metricStatsOf([])` → nil; tek değer → avg=min=max, `.stable`; (2) `trendOf` yükselen/düşen/sabit seriler (<4 değer → `.stable`); (3) `healthStatsOf`: `loggedDoses=0` → `takenPercent` nil; `distinctRecordDays` aynı güne iki kayıtta 1 sayar; (4) `periodBoundsOf`: weekly bugün dahil 7 gün, monthly 30 gün; (5) `healthRowsOf`: BP/glucose/weight doğru type'a map'lenir, notes yok, oldest first.

**Adımlar:**
- [ ] `PeriodRows.swift` → [ ] `HealthPeriodReader.swift` + `HealthStatsAggregator.swift` → [ ] failing testler → [ ] implementasyon → [ ] testler yeşil (ctx_execute) → [ ] Commit: `feat(ai): aggregate period health stats for AI prompts`

---

### Task 4: `AiSummaryDao` + `AiSummaryRepository` (gating çekirdeği)

**Files:**
- Create: `Packages/SalusDatabase/Sources/SalusDatabase/AiSummaryDao.swift`, `Packages/SalusAI/Sources/SalusAI/AiSummaryRepository.swift`
- Test: `Packages/SalusAI/Tests/SalusAITests/AiSummaryRepositoryTests.swift`, `Packages/SalusAI/Tests/SalusAITests/Fakes.swift` (fake DAO/usage/premium)

**Interfaces (Produces):**
```swift
// SalusDatabase
public struct AiSummaryDao: Sendable {
    public func get(periodType: String, startEpochDay: Int, language: String) async -> AiSummaryRecord?
    public func upsert(_ record: AiSummaryRecord) async
}
// SalusAI
public struct AiSummary: Equatable, Sendable { /* periodType, startEpochDay, endEpochDay, language, text, createdAtEpochMs */ }
public enum SummaryFailureReason: Sendable { case error, unavailable }
public enum SummaryOutcome: Equatable, Sendable {
    case ready(summary: AiSummary, fromCache: Bool)
    case needsMoreData
    case needsPremium
    case dailyLimitReached
    case failed(reason: SummaryFailureReason)
}
public protocol AiSummaryRepository: Sendable {
    var freeSummaryAvailable: AsyncStream<Bool> { get }
    func getSummary(period: SummaryPeriod, todayEpochDay: Int, language: AiLanguage) async -> SummaryOutcome
}
public final class AiSummaryRepositoryImpl: AiSummaryRepository { /* aiClient, aggregator, summaryDao, usageDataSource, premiumRepository, clock */ }
```

**Davranış sözleşmesi:**
- `AiSummaryDao.swift` (`SalusDatabase`): `AiSummaryRecord` zaten mevcut. DAO: `get` — `SELECT * FROM ai_summaries WHERE period_type=? AND start_epoch_day=? AND language=?`; `upsert` — GRDB `save` (insert-or-update by PK). Android `AiSummaryDao` twin'i.
- `AiSummaryRepository.swift`: `AiSummary` struct, `SummaryFailureReason` (`.error` retry-worthy, `.unavailable` not), `SummaryOutcome` enum, `AiSummaryRepositoryImpl`.
- **`getSummary` sıralı kapılar (bağlayıcı):**
  1. **Cache:** `summaryDao.get(period.name, startEpochDay, language.tag)` doluysa → `.ready(fromCache: true)`. Hak/limit bakılmaz.
  2. **Veri yeterliliği:** `aggregator.aggregate(...)`; `distinctRecordDays < minimumRecordDays` → `.needsMoreData` (AI çağrısı YOK).
  3. **Hak:** `premiumRepository.status`'ün güncel değeri `.isEntitled` DEĞİLSE ve `usage.freeSummaryUsed` → `.needsPremium`. "Not entitled" bir kez store'da re-check (`premiumRepository.refresh()`).
  4. **Günlük limit:** `usage.callsOn(todayEpochDay) >= DAILY_AI_CALL_LIMIT` → `.dailyLimitReached`.
  5. **Çağrı:** `aiClient.generate(PromptBuilder.summaryPrompt(stats, language))`. `.success` → disclaimer ekle + cache upsert + `recordCall` + (free ise) `markFreeSummaryUsed` → `.ready(fromCache: false)`. `.unavailable` → `.failed(.unavailable)`. `.error` → `.failed(.error)`. Hak HARCANMAZ, sayaç ARTMAZ.
- `language.tag`: `.tr` → `"tr"`, `.en` → `"en"`.
- `freeSummaryAvailable`: `usageDataSource.usage.map { !$0.freeSummaryUsed }.distinctUntilChanged()`.
- `resolveEntitlement()`: ilk okuma entitled → true; değilse `refresh()` sonra tekrar oku.
- `withContext(dispatchers.io)` karşılığı: iOS'ta repository `nonisolated` async — I/O `Task` içinde. `nonisolated` fonksiyonlar `@MainActor` VM'den çağrılır.

**Test davranışları (`AiSummaryRepositoryTests`, 8 davranış):** (1) cache hit → AI çağrılmaz, hak durumu ne olursa olsun `.ready(fromCache: true)`; (2) 2 günlük veriyle weekly → `.needsMoreData`, AI çağrılmaz; (3) free + hak kullanılmış → `.needsPremium`; (4) free + hak duruyor → çağrı yapılır, sonra `markFreeSummaryUsed`; (5) premium + sayaç 5 → `.dailyLimitReached`; (6) `AiResult.error` → `.failed(.error)` + hak/sayaç değişmez; (7) `AiResult.success` → metin disclaimer içerir ve dao'ya yazılır; (8) offline'da (error) sonraki denemede hak hâlâ durur. `FakeAiClient` + fake DAO/usage/premium ile.

**Adımlar:**
- [ ] `AiSummaryDao.swift` → [ ] `AiSummaryRepository.swift` + fakes → [ ] failing testler → [ ] implementasyon → [ ] testler yeşil (ctx_execute) → [ ] Commit: `feat(ai): summary repository with entitlement, quota and cache gates`

---

### Task 5: `FeatureAIHealth` özet ekranı + Home kartı

**Files:**
- Create: `Packages/Features/FeatureAIHealth/Sources/FeatureAIHealth/domain/AiLanguageProvider.swift`, `ui/AiSummaryUiState.swift`, `ui/AiSummaryViewModel.swift`, `ui/AiSummaryScreen.swift`, `navigation/AiHealthNavigation.swift`, `AiHealthStrings.swift`, `Resources/Localizable.xcstrings`, `AiHealthModule.swift`
- Modify: `Packages/Features/FeatureAIHealth/Package.swift` (deps zaten çoğu var), `Packages/Features/FeatureAIHealth/Sources/FeatureAIHealth/FeatureAIHealth.swift` (placeholder silinir), `Packages/Features/FeatureHome/Sources/FeatureHome/ui/HomeScreen.swift` (`onOpenAiSummary` + AI kartı), `Packages/Features/FeatureHome/Sources/FeatureHome/navigation/HomeNavigation.swift`
- Test: `Packages/Features/FeatureAIHealth/Tests/FeatureAIHealthTests/AiSummaryViewModelTests.swift`, `Packages/Features/FeatureAIHealth/Tests/FeatureAIHealthTests/AiHealthStringsTests.swift`

**Interfaces:**
- Consumes: `AiSummaryRepository` (SalusAI), `PremiumRepository` + `PaywallController` (SalusPremium), `SalusClock` (SalusCommon), `Navigator` (SalusNavigation)
- Produces: `AiSummaryKey: Hashable, Sendable`, `aiHealthDestinations()`, `AiHealthModule` (makeAiSummaryViewModel), `AiLanguageProvider`

**Davranış sözleşmesi:**
- **`AiLanguageProvider.swift`:** `protocol AiLanguageProvider: Sendable { func current() -> AiLanguage }`. Production impl app'de (locale "en" → `.en`, else `.tr`). Android `ResourceAiLanguageProvider` twin'i — iOS'ta `Bundle.main.preferredLocalizations` ile.
- **`AiSummaryUiState.swift`:** `AiSummaryResult` enum (`.loading`, `.content(text:fromCache:)`, `.insufficientData`, `.premiumRequired`, `.dailyLimit`, `.error(reason:)`). `AiSummaryUiState(period:result:)`. `AiSummaryEvent` (`.periodSelected(SummaryPeriod)`, `.retryClicked`, `.upgradeClicked`).
- **`AiSummaryViewModel.swift`:** `@MainActor @Observable`. Params: `AiSummaryRepository`, `PremiumRepository`, `PaywallController`, `AiLanguageProvider`, `SalusClock`. `loadTask: Task<Void, Never>?` — period switch cancel eder. `init` → `load(.weekly)` + `observeEntitlement`. `onEvent`: `.periodSelected` → sadece period farklıysa `load`; `.retryClicked` → `load(currentPeriod)`; `.upgradeClicked` → `paywallController.show(.aiSummary)`. `observeEntitlement`: `premiumRepository.status.map { $0.isEntitled }.distinctUntilChanged()` — entitled gelirse ve state `.premiumRequired` ise `load(currentPeriod)` (auto-retry). `load(period)`: `loadTask?.cancel()`, state `.loading`, `repository.getSummary(period:todayEpochDay:language:)`, `outcome.toResult()`.
- **`AiSummaryScreen.swift`:** `AiSummaryRoute` (stateful, `@Environment(\.aiHealthModule)`, `@State viewModel`) + `AiSummaryScreen` (stateless, `#Preview`). WEEKLY/MONTHLY `Picker(.segmented)`. Per-state UI: `.content` → metin + `fromCache` rozet + disclaimer; `.insufficientData` → "daha çok kayıt gerek"; `.premiumRequired` → "Premium'a geç" butonu (`paywallController.show(.aiSummary)`); `.dailyLimit` → "yarın tekrar dene"; `.error(.error)` → retry + "bağlantını kontrol et"; `.error(.unavailable)` → "bu kurulumda AI yok" (retry yok).
- **`AiHealthNavigation.swift`:** `AiSummaryKey: Hashable, Sendable` (value type, `init()`). `aiHealthDestinations()` — `AiSummaryKey` → `AiSummaryRoute()` (push transition).
- **`AiHealthStrings.swift`** + `Localizable.xcstrings`: Android `strings.xml`'den 1:1 key set (TR source + EN). `ai_summary_*` prefix. `ai_language_code` key (translatable, "tr"/"en"). Placeholder mapping: `%1$s`→`%1$@`, `%1$d`→`%1$lld`.
- **`AiHealthModule.swift`:** `@MainActor public struct AiHealthModule { let makeAiSummaryViewModel: @MainActor () -> AiSummaryViewModel }` + `@Entry public var aiHealthModule: AiHealthModule?`.
- **Home kartı:** `HomeScreen.swift`'de `onOpenAiSummary: @escaping () -> Void` parametre ekle. AI kartı: `SalusSectionHeader(HomeStrings.aiSummaryTitle)` + `SalusCard(onTap: onOpenAiSummary)` — başlık `aiSummaryDescription`, `freeAiSummaryAvailable && !isPremium` → `aiSummaryFreeCredit` alt satırı. `HomeRoute.init`'e `onOpenAiSummary` ekle. `RootView`'de `onOpenAiSummary: { root.navigator.navigate(AiSummaryKey()) }`.

**Test davranışları (`AiSummaryViewModelTests`, 5):** (1) açılışta weekly yüklenir — `FakeAiSummaryRepository` `.ready` döner → state `.content`; (2) `.needsPremium` → state `.premiumRequired`, paywall **sadece butonla** çağrılır; (3) premium'a geçiş (entitlement stream `.premium` emit) → auto-retry, state `.content`; (4) segment değişimi monthly → yeni sorgu, `.loading` sonra sonuç; (5) `.failed(.error)` → state `.error(.error)`, retry → yeni çağrı. `FakeAiSummaryRepository` (queued outcomes).

**Adımlar:**
- [ ] Placeholder sil + `AiHealthStrings.swift` + `Localizable.xcstrings` → [ ] `AiLanguageProvider` + `AiHealthNavigation` + `AiHealthModule` → [ ] `AiSummaryUiState` + `AiSummaryViewModel` → [ ] failing VM testleri → [ ] `AiSummaryScreen` → [ ] Home kartı + `onOpenAiSummary` → [ ] testler + `swift build` yeşil (ctx_execute) → [ ] Commit: `feat(aihealth): AI health summary screen with home entry`

---

### Task 6: Doktor raporu — deterministik PDF + AI anlatı + girişler

**Files:**
- Create: `Packages/Features/FeatureAIHealth/Sources/FeatureAIHealth/report/ReportBlocks.swift`, `report/ReportCopy.swift`, `report/ReportWriter.swift`, `report/PdfReportGenerator.swift`, `report/DoctorReportRepository.swift`, `ui/DoctorReportUiState.swift`, `ui/DoctorReportViewModel.swift`, `ui/DoctorReportScreen.swift`
- Modify: `AiHealthNavigation.swift` (`DoctorReportKey`), `AiHealthModule.swift` (makeDoctorReportViewModel), `AiHealthStrings.swift` + `Localizable.xcstrings` (`doctor_report_*` keys), `Packages/Features/FeatureSettings/Sources/FeatureSettings/navigation/SettingsNavigation.swift` (`onOpenDoctorReport` gerçek navigate)
- Test: `Packages/Features/FeatureAIHealth/Tests/FeatureAIHealthTests/DoctorReportRepositoryTests.swift`, `Packages/Features/FeatureAIHealth/Tests/FeatureAIHealthTests/ReportBlocksTests.swift`

**Interfaces (Produces):**
```swift
// report
internal enum ReportBlock { /* .title, .section, .body, .gap, .table(heading:columns:weights:rows:) */ }
internal func reportBlocksOf(stats:rows:narrative:copy:generatedOn:) -> [ReportBlock]
internal protocol ReportCopy { /* documentTitle, headings, columns, narrativeUnavailable, periodRange, generatedOn, loggedDoseLine, contextLabel, date */ }
internal enum ReportTextStyle { /* title, section, body, columnHeader, footer */ }
internal protocol ReportSurface { /* startPage, drawText, widthOf, finishPage */ }
internal final class ReportWriter { /* draw(blocks:) */ }
public protocol PdfReportGenerator { func generate(stats:rows:narrative:language:) -> URL }
public enum ReportOutcome: Equatable, Sendable { /* .ready(pdfFile:narrativeIncluded:), .needsPremium, .needsMoreData, .failed(message:) */ }
public protocol DoctorReportRepository: Sendable { func generate(period:todayEpochDay:language:) async -> ReportOutcome }
// ui
public enum DoctorReportResult { /* .idle, .generating, .ready(pdfFile:narrativeIncluded:), .premiumRequired, .insufficientData, .failed */ }
public enum DoctorReportPreview { /* .hidden, .opening, .ready(url:), .failed */ }
public struct DoctorReportUiState { /* period, result, preview */ }
public enum DoctorReportEvent { /* .periodSelected, .generateClicked, .upgradeClicked, .previewClicked, .previewDismissed */ }
public final class DoctorReportViewModel: Observable { /* generateTask, previewTask, observeEntitlement */ }
public struct DoctorReportKey: Hashable, Sendable
```

**Davranış sözleşmesi:**
- **`ReportBlocks.swift`:** Android `ReportBlocks.kt` 1:1. `ReportBlock` enum, `reportBlocksOf(stats:rows:narrative:copy:generatedOn:)`. `formatReportDate(epochDay:)` (`dd.MM.yyyy`, `LocalDate.fromEpochDays`). `asInteger()`/`asDecimal()` helpers. Boş metric table omit edilir. `addNarrative`: narrative nil → `copy.narrativeUnavailable` note; varsa satır satır (`Gap` blank lines ile).
- **`ReportCopy.swift`:** Android `ReportCopy.kt` 1:1. `protocol ReportCopy` + `TurkishReportCopy`/`EnglishReportCopy`. **Kotlin copy (resource değil)** — dil `AiLanguage` parametresi ile, cihaz konfigürasyonu değil. `loggedDoseLine` "kaydedilen doz" ifadesi kullanır.
- **`ReportWriter.swift`:** Android `ReportWriter.kt` 1:1. `ReportSurface` protocol + `ReportWriter` class. A4 595×842pt, margin 40, `CONTENT_BOTTOM`, footer disclaimer **her sayfada** (`closePage` tek path). Page break, text wrap, table column offsets, header redraw after break.
- **`PdfReportGenerator.swift`:** `protocol PdfReportGenerator` + `IosPdfReportGenerator`. **`UIGraphicsPDFRenderer`** (Android `PdfDocument` yerine). `generate(stats:rows:narrative:language:) -> URL`. `reportBlocksOf` → `ReportWriter(surface:)`. `ReportSurface` impl: `UIGraphicsPDFRenderer.Context` üzerine `NSString.draw(in:withAttributes:)`. Paint/font mapping: TITLE 18pt bold, SECTION 12pt bold, BODY 10pt, FOOTER 8pt. Output: `cachesDirectory/reports/salus-report-<start>-<end>.pdf`. Stale dosyalar prune. **`#if canImport(UIKit)`** guard — `swift test` host build'de derlenmez.
- **`DoctorReportRepository.swift`:** Android `DoctorReportRepository.kt` 1:1. 3 kural: (1) premium gate ilk — `premiumRepository.status.isEntitled` değilse `.needsPremium` (free hak geçersiz, re-check yok — Android ile aynı); (2) deterministic kısım AI'dan bağımsız — `periodReader.aggregate` + `periodRows`, `distinctRecordDays == 0` → `.needsMoreData`; (3) AI narrative opsiyonel — `distinctRecordDays < minimumRecordDays` → skip; quota dolu → skip; `aiClient.generate` error/unavailable → skip; success → `recordCall`. PDF her zaman üretilir (AI skip → note). `runCatching` → `do/catch` (`CancellationError` rethrow). `Failed(message:)` sadece PDF yazım hatası.
- **`DoctorReportUiState.swift`:** `DoctorReportResult` (`.idle`, `.generating`, `.ready(pdfFile:narrativeIncluded:)`, `.premiumRequired`, `.insufficientData`, `.failed`). `DoctorReportPreview` (`.hidden`, `.opening`, `.ready(url:)`, `.failed`). `DoctorReportEvent` (5 case). `DoctorReportUiState(period:result:preview:)`.
- **`DoctorReportViewModel.swift`:** `@MainActor @Observable`. `generateTask`/`previewTask`. `observeEntitlement` — premium gelirse `.premiumRequired` → `.idle` (auto-generate yok). `openPreview()`: `.ready` state'inde URL'yi al → `.ready(url:)`; nil → `.failed`. `closePreview()` → `.hidden`. **File descriptor lifecycle yok** — PDFKit yönetir (Task 7'de).
- **`DoctorReportScreen.swift`:** Route + Screen. Period selector, generate butonu. `.idle` → tanım + "Rapor oluştur" butonu; `.generating` → spinner; `.ready` → paylaş/yeniden üret + **önizleme butonu**; `.premiumRequired` → paywall butonu; `.insufficientData` → "kayıt yok"; `.failed` → retry. `.fullScreenCover(isPresented:)` preview için (Task 7'de doldurulur, bu task'ta placeholder).
- **`DoctorReportKey`:** `AiHealthNavigation.swift`'e ekle. `aiHealthDestinations()` — `DoctorReportKey` → `DoctorReportRoute()`.
- **More wiring:** `SettingsNavigation.swift`'de `onOpenDoctorReport` callback'i zaten M9'dan beri var (TODO no-op). `RootView`'de `onOpenDoctorReport: { root.navigator.navigate(DoctorReportKey()) }` — `TODO(M10)` kaldırılır.
- **`AiHealthStrings.swift`** + `Localizable.xcstrings`: `doctor_report_*` key'leri ekle (Android `strings.xml`'den 1:1). `doctor_report_preview_*` keys dahil.

**Test davranışları (`DoctorReportRepositoryTests`, 5):** (1) free → `.needsPremium`, AI ve PDF hiç çalışmaz; (2) `AiResult.error` → `.ready(narrativeIncluded: false)` — PDF yine üretilir (fake generator); (3) `AiResult.success` → `.ready(narrativeIncluded: true)` + `recordCall` çağrılır; (4) günlük limit dolu → AI çağrılmaz, `narrativeIncluded: false`; (5) hiç veri yok (`distinctRecordDays == 0`) → `.needsMoreData`. `FakeAiClient` + fake premium/usage/periodReader/generator ile.
**Test davranışları (`ReportBlocksTests`):** Saf block üretimi: (1) boş `HealthPeriodRows` → `noMeasurements` body, table yok; (2) BP rows → table doğru kolonlar + satırlar; (3) narrative nil → `narrativeUnavailable`; (4) `takenPercent` nil → `noDoses`; (5) dil TR/EN doğru copy.

**Adımlar:**
- [ ] `ReportBlocks.swift` + `ReportCopy.swift` → [ ] `ReportWriter.swift` → [ ] `PdfReportGenerator.swift` (`#if canImport(UIKit)`) → [ ] `DoctorReportRepository.swift` → [ ] failing repository testleri → [ ] `DoctorReportUiState` + `DoctorReportViewModel` → [ ] `DoctorReportScreen` + `DoctorReportKey` + More wiring → [ ] `doctor_report_*` strings → [ ] testler + `swift build` yeşil (ctx_execute) → [ ] Commit: `feat(aihealth): premium doctor report PDF with optional AI narrative`

---

### Task 7: PDFKit önizleme ekranı (iOS-specific ek) + shell wiring + plist taşıma

**Files:**
- Create: `Packages/Features/FeatureAIHealth/Sources/FeatureAIHealth/ui/DoctorReportPreviewScreen.swift`, `scripts/m10-manual-qa.md`
- Modify: `Packages/Features/FeatureAIHealth/Sources/FeatureAIHealth/ui/DoctorReportScreen.swift` (`.fullScreenCover` preview mount), `App/SalusApp.swift` (`FirebaseApp.configure()`), `App/AppCompositionRoot.swift` (AI graph), `App/AppCompositionRoot+Modules.swift` (makeAiHealthModule), `App/RootView.swift` (real `onOpenAiSummary`/`onOpenDoctorReport`), `project.yml` (`SalusAI` + `FeatureAIHealth` packages + app deps), `.gitignore` (`GoogleService-Info.plist`), `README.md` (Toolchain table)
- Move: `~/Downloads/GoogleService-Info.plist` → `App/GoogleService-Info.plist` (git-ignored)
- Test: `Packages/Features/FeatureAIHealth/Tests/FeatureAIHealthTests/DoctorReportViewModelPreviewTests.swift`

**Interfaces:**
- Consumes: `PDFKit` (`PDFView`, `PDFDocument` — iOS-only, `#if canImport(PDFKit)`)
- Produces: `DoctorReportPreviewScreen` view, full Firebase + AI graph wiring

**Davranış sözleşmesi:**
- **`DoctorReportPreviewScreen.swift`:** **`#if canImport(PDFKit)`** guard. `PDFViewRepresentable: UIViewRepresentable` — `PDFView` host. `PDFDocument(url: url)` yüklenir, `PDFView.autoScales = true`. `DoctorReportPreviewScreen(url: URL, onClose: () -> Void)`: `PDFViewRepresentable` + close button + `ShareLink(item: url)` (iOS 17+ native). SwiftUI `.fullScreenCover` içinde gösterilir.
- **`DoctorReportScreen.swift` güncelleme:** `.fullScreenCover(isPresented: $showPreview)` — `showPreview` state, `preview == .ready(url:)` → `DoctorReportPreviewScreen(url:onClose:)`. `previewClicked` → `viewModel.onEvent(.previewClicked)`, `previewDismissed` → `.previewDismissed`.
- **`DoctorReportViewModel` preview logic (Task 6'dan sadeleştirme):** `openPreview()`: `.ready` state'inde `pdfFile` URL'yi al → state `.preview = .ready(url: url)` (PDFDocument oluşturulmaz — ViewModel sadece URL'yi taşır, `PDFView` kendisi açar). `closePreview()` → `.preview = .hidden`. **File descriptor lifecycle yok** — PDFKit yönetir. Android'in `ReportDocumentOpener`/`ReportDocument`/`reportPageBitmapSize` infrastructure'ı **port edilmez** (`D-M10-a` divergence'ı).
- **`SalusApp.swift`:** Launch'ta `if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil { FirebaseApp.configure() }`. Composition root bundan sonra AI client'ı build eder.
- **`AppCompositionRoot.swift`:** `let aiClient: any AiClient` (`FirebaseAiClient()` — `#if canImport` production'da; test'te fake), `let healthStatsAggregator: HealthStatsAggregator`, `let aiSummaryRepository: any AiSummaryRepository`. `makeHomeModule`'a `onOpenAiSummary` geçer (HomeModule zaten `aiUsage` alıyor). `makeSettingsModule`'ın `onOpenDoctorReport`'u real callback.
- **`AppCompositionRoot+Modules.swift`:** `makeAiHealthModule()` — `AiHealthModule` factory'leri.
- **`RootView.swift`:** `HomeRoute`'a `onOpenAiSummary: { root.navigator.navigate(AiSummaryKey()) }`. `MoreRoute`'ta `onOpenDoctorReport: { root.navigator.navigate(DoctorReportKey()) }` — `TODO(M10)` kaldırılır. `.aiHealthDestinations()` More ve Home stack'lerine eklenir.
- **`project.yml`:** `packages:`'a `SalusAI: path: Packages/SalusAI` + `FeatureAIHealth: path: Packages/Features/FeatureAIHealth` (FeatureAIHealth zaten packages'ta olabilir — kontrol et). App `dependencies:`'e `- package: SalusAI` + `- package: FeatureAIHealth`. `xcodegen generate` çalıştır, `pbxproj` commit.
- **`.gitignore`:** `App/GoogleService-Info.plist` ekle.
- **`README.md`:** Toolchain table'a `firebase-ios-sdk` pin ekle.
- **`scripts/m10-manual-qa.md`:** Manuel QA matrix — keyless build, configured build, summary generation, free credit, premium gate, daily limit, doctor report PDF, PDFKit preview, offline fallback, Home/More wiring.
- **`GoogleService-Info.plist`:** `~/Downloads/GoogleService-Info.plist` → `App/GoogleService-Info.plist` (move, NOT copy — git-ignored).

**Test davranışları (`DoctorReportViewModelPreviewTests`):** (1) `.ready` state'inde `previewClicked` → `.preview == .ready(url:)` (URL doğru); (2) `previewDismissed` → `.preview == .hidden`; (3) `.idle`'de `previewClicked` → no-op (preview `.hidden`); (4) `.generating`'de `previewClicked` → no-op. ViewModel `PDFDocument` oluşturmaz — sadece URL taşır.

**Adımlar:**
- [ ] `DoctorReportPreviewScreen.swift` (`#if canImport(PDFKit)`) → [ ] `DoctorReportScreen.swift` `.fullScreenCover` mount → [ ] failing preview VM testleri → [ ] `SalusApp.swift` + `AppCompositionRoot` AI graph → [ ] `RootView` wiring (`onOpenAiSummary`/`onOpenDoctorReport` real) → [ ] `project.yml` + `xcodegen generate` → [ ] `.gitignore` + `README.md` → [ ] `GoogleService-Info.plist` move → [ ] `scripts/m10-manual-qa.md` → [ ] testler + `swift build` yeşil + `scripts/build-app.sh` yeşil (ctx_execute) → [ ] Commit: `feat(aihealth): PDFKit preview + Firebase wiring + shell integration`

---

## Self-review notları (plan yazarı doğruladı)

- **Spec kapsaması:** §4.2 `SalusAI` API → Task 1-4; §4.3 `FeatureAIHealth` → Task 5-7; §4.4 Home/More wiring → Task 5 + Task 7; §4.5 Shell wiring → Task 7; §5 Data flow → Task 4-6; §6 Error handling → Task 4 (summary) + Task 6 (report); §7 Testing → her task'in test davranışları; §9 Divergence `D-M10-a` → Task 7 (PDFKit vs PdfRenderer); O2 (plist handling) → Task 7.
- **Tip tutarlılığı:** `SummaryPeriod`/`AiLanguage`/`HealthPeriodStats`/`AiPrompt` Task 1'de tanımlanır, 2-7 aynı imzaları tüketir; `AiResult` Task 2, `SummaryOutcome` Task 4, `ReportOutcome` Task 6; `AiSummaryKey`/`DoctorReportKey` Task 5/6'da tanımlanır, Task 7'de `RootView` kullanır; `DoctorReportPreview.ready(url:)` Task 6'da tanımlanır, Task 7'de `DoctorReportPreviewScreen` kullanır.
- **Sıra bağımlılığı:** 1→2→3→4→5→6→7 lineer. Task 1 `SalusAI` paketini oluşturur (mevcut değil), Task 2 Firebase ekler, Task 3 DAO okumaları, Task 4 repository, Task 5 özet ekranı + Home, Task 6 rapor ekranı + More, Task 7 PDFKit + shell + plist.
- **Bilinçli sapma:** Kompakt format (tam kod yok) kullanıcının açık tercihi; implementer'lar Opus. `GoogleService-Info.plist` git-ignored + optional (Android simetrisi). PDFKit ile Android `PdfRenderer` altyapısı port edilmiyor (`D-M10-a`).
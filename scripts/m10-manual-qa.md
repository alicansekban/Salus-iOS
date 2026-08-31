# iOS-M10 manual QA — AI health summary and the doctor report PDF

iOS-M10's acceptance is *the AI health summary, the premium doctor report PDF, and the shell wiring
that reaches both*. The automated half is mapped case-by-case in the execution records of
`docs/superpowers/plans/2026-08-31-ios-m10-ai-health/*` — the `AiSummaryRepository` gate table, the
`DoctorReportRepository` gate table, the `DoctorReportViewModel` preview lifecycle, the string
parity. This document is the other half: everything that needs a tap, a real Firebase project, a
real store, and the shell wiring that only a running app exercises.

**Agents do not run this script.** From 2026-08-30 the simulator and device passes are the user's
(the coordinator's decision, recorded in the ledger); implementers run tests, lint and the build,
and write this file from the code. Every step below says **NOT RUN** until someone runs it.

Each section is written by the task that shipped the behaviour it checks, so the file grows a
section at a time and the numbering follows the plan rather than the reading order.

**Language.** The steps quote the Turkish strings, which is what a default simulator shows
(spec §6.4 — Turkish is the default *and* the fallback).

---

## §1. The keyless build (Task 7)

Written by Task 7 from `App/SalusApp.swift` (the `FirebaseApp.configure()` guard) and
`Packages/SalusAI/Sources/SalusAI/FirebaseAiClient.swift` (`isConfigured`). The automated half is
the `FirebaseAiClient`'s `isConfigured` short-circuit and the repository gate tests; what no test
can reach is a launched app with no `GoogleService-Info.plist` at all.

**How it works.** `SalusApp.init` calls `FirebaseApp.configure()` only when
`App/GoogleService-Info.plist` is present (it is git-ignored and optional). Without it there is no
`FirebaseApp`, so `FirebaseAiClient.isConfigured == false` and every `generate` answers
`AiResult.unavailable` before touching the SDK. The summary screen renders its "unavailable" state
and the doctor report produces the PDF with a note in place of the narrative. Nothing crashes.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 1.1 | Build and launch with **no** `App/GoogleService-Info.plist` (delete it, or a fresh clone). | The app launches and runs normally. The AI summary screen shows the `ai_summary_unavailable_*` state ("AI özetleri şu an kullanılamıyor…"). No crash. | **NOT RUN** |
| 1.2 | On the keyless build, generate a doctor report (premium user). | The PDF is produced with the tables and a note in place of the narrative (`doctor_report_ready_without_narrative`). No crash. | **NOT RUN** |
| 1.3 | On the keyless build, open the PDF preview. | The preview opens and shows the report. No crash. | **NOT RUN** |

---

## §2. The configured build (Task 7)

Written by Task 7 from `App/SalusApp.swift` (the `FirebaseApp.configure()` call) and the
`AppCompositionRoot` AI graph. The automated half is the repository gate tables; what no test can
reach is a real Firebase project answering a real model call.

**How to configure.** Drop a real `GoogleService-Info.plist` at `App/GoogleService-Info.plist`
(git-ignored) and rebuild. `SalusApp.init` then configures Firebase, `FirebaseAiClient.isConfigured`
is true, and the model answers.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 2.1 | Build and launch with `App/GoogleService-Info.plist` present. | The app launches and configures Firebase. The AI summary screen loads a real summary for a period with enough recorded days. | **NOT RUN** |
| 2.2 | Generate a doctor report (premium user) with the plist present. | The PDF is produced **with** the AI narrative section. | **NOT RUN** |

---

## §3. The summary generation (Tasks 4-5)

Written by Tasks 4-5 from `AiSummaryRepository` and `AiSummaryScreen`. The automated half is the
`AiSummaryRepositoryTests` gate table; what no test can reach is the rendered screen and the real
model output.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 3.1 | Open the AI summary (Home → the AI card). | The weekly summary loads and shows the model text, the period selector (Haftalık/Aylık), and the disclaimer ("Bu rapor bilgilendirme amaçlıdır, tıbbi tavsiye değildir."). | **NOT RUN** |
| 3.2 | Switch to Aylık (monthly) with **fewer than 7** recorded days. | The screen shows the `ai_summary_insufficient_*` state ("Bu dönem için yeterli veri yok…"). | **NOT RUN** |
| 3.3 | Switch back to Haftalık (weekly) with **at least 3** recorded days. | The weekly summary loads again. | **NOT RUN** |

---

## §4. The free credit and the paywall (Tasks 4-5)

Written by Tasks 4-5 from `AiSummaryRepository` (the `ai_free_summary_used` gate) and the paywall
wiring. The automated half is the repository gate table; what no test can reach is the rendered
paywall from the summary screen.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 4.1 | As a **free** user, generate the first summary. | The one-off free credit is spent: the summary loads, and `ai_free_summary_used` is set. | **NOT RUN** |
| 4.2 | As a **free** user, generate a second summary. | The screen shows the premium wall (`ai_summary_premium_*`), and the paywall opens only on the button tap. | **NOT RUN** |

---

## §5. The premium daily limit (Tasks 4-5)

Written by Tasks 4-5 from `AiSummaryRepository` (the `ai_calls_count` / `ai_calls_epoch_day` gate).
The automated half is the repository gate table; what no test can reach is the rendered daily-limit
state.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 5.1 | As a **premium** user, generate summaries until the day's 5 calls are spent. | The 6th request shows the `ai_summary_daily_limit_*` state ("Günlük AI özeti limitine ulaştınız…"). | **NOT RUN** |
| 5.2 | Wait for the next day (or reset the counters) and generate again. | The limit resets and a new summary loads. | **NOT RUN** |

---

## §6. The doctor report (Task 6)

Written by Task 6 from `DoctorReportRepository` and `DoctorReportScreen`. The automated half is the
`DoctorReportRepositoryTests` gate table; what no test can reach is the rendered screen and the
written PDF.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 6.1 | Open the doctor report (More → the doctor report row) as a **free** user. | The screen shows the premium wall (`doctor_report_premium_*`), and the paywall opens only on the button tap. | **NOT RUN** |
| 6.2 | As a **premium** user, generate a report for a period with no records. | The screen shows the `doctor_report_insufficient_*` state. | **NOT RUN** |
| 6.3 | As a **premium** user, generate a report for a period with records. | The PDF is produced and the screen shows the ready state with Share, Preview and Regenerate buttons. | **NOT RUN** |

---

## §7. The PDFKit preview (Task 7)

Written by Task 7 from `DoctorReportPreviewScreen` and the `DoctorReportViewModel` preview
lifecycle. The automated half is `DoctorReportViewModelPreviewTests` (the four preview behaviours);
what no test can reach is the rendered `PDFView` and the share sheet.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 7.1 | With a finished report on screen, tap "Önizle" (Preview). | The full-screen cover opens with the PDF auto-scaled to fit, scrollable and zoomable. | **NOT RUN** |
| 7.2 | Tap the close (x) button. | The preview dismisses and the report screen returns. | **NOT RUN** |
| 7.3 | Tap the share button in the preview. | The system share sheet opens with the PDF file. | **NOT RUN** |
| 7.4 | Tap Preview while no report is on screen (idle or generating). | Nothing happens — the preview stays closed. | **NOT RUN** |

---

## §8. The offline fallback (Tasks 4-6)

Written by Tasks 4-6 from the repositories' AI-failure handling. The automated half is the
`modelErrorStillProducesPdf` and summary-failure cases; what no test can reach is a real device in
airplane mode.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 8.1 | Go offline, then generate a summary (premium user with credit). | The summary shows the error state with a retry button; the free credit is **not** spent on a failed call. | **NOT RUN** |
| 8.2 | Go offline, then generate a doctor report (premium user). | The PDF is produced **without** the narrative (a note in its place). The day's AI quota is untouched. | **NOT RUN** |

---

## §9. The Home and More wiring (Tasks 5-7)

Written by Tasks 5-7 from `App/RootView.swift` (the `onOpenAiSummary` / `onOpenDoctorReport`
callbacks and the `aiHealthDestinations()` registration). The automated half is the shell's
navigation tests; what no test can reach is a tap on the running app.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 9.1 | Tap the AI summary card on Home. | The AI summary screen pushes onto Home's stack (the tab bar hides). | **NOT RUN** |
| 9.2 | Tap the doctor report row in More. | The doctor report screen pushes onto More's stack (the tab bar hides). | **NOT RUN** |

---

## §10. The banned-claims scan (Tasks 1-7)

Written by the port's standing rule (`CLAUDE.md`): no Swift source or string catalog in the
repository names any banned health-claims vocabulary. The automated half is
`BannedHealthClaimsTests`, run repo-wide from `Packages/SalusTesting`; it must stay green across
every M10 change.

| # | Step | Expected | Status |
|---|------|----------|--------|
| 10.1 | Run `swift test --package-path Packages/SalusTesting`. | `BannedHealthClaimsTests` passes: no source or catalog in `Packages/` or `App/` names a banned stem. | **NOT RUN** |

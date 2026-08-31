// Ported 1:1 from Android
// `feature/aihealth/src/main/kotlin/com/alicansekban/salus/feature/aihealth/report/
// DoctorReportRepository.kt`.

import Foundation
import os
import SalusAI
import SalusCommon
import SalusPremium
import SalusSettings

/// Everything `DoctorReportRepository.generate` can answer.
///
/// There is deliberately no failure member for the AI half. The report's value is the table of
/// numbers the user recorded, and those need no network at all — so a model that is offline,
/// rate-limited or unconfigured must still produce a document, with the narrative section
/// carrying a note in place of prose.
public enum ReportOutcome: Equatable, Sendable {
    /// - Parameters:
    ///   - pdfFile: the written document, inside the app cache directory and therefore shareable
    ///     through the app's share sheet.
    ///   - narrativeIncluded: false when the AI section was skipped, so the screen can say so
    ///     before the user forwards the file to a doctor.
    case ready(pdfFile: URL, narrativeIncluded: Bool)

    /// Not entitled. The doctor report is premium in full — the free AI credit does not apply.
    case needsPremium

    /// Not one record in the period. There is nothing to tabulate, let alone summarise.
    case needsMoreData

    /// The report could not be produced: the records could not be read, or the file could not be
    /// written. Never the model — an AI failure downgrades the report, it does not fail it.
    ///
    /// `message` is the underlying exception text, kept for the log the same way
    /// `SummaryOutcome.failed` keeps its reason: it is untranslated and platform-worded, so no
    /// screen may render it. `DoctorReportScreen` shows copy of its own instead.
    case failed(message: String)
}

/// Produces the premium doctor report and owns every rule about what one costs.
public protocol DoctorReportRepository: Sendable {
    /// Writes the report for `period` ending on `todayEpochDay`.
    ///
    /// - Parameter todayEpochDay: the local day the period ends on, passed in so the day the AI
    ///   quota is counted against is the one the caller calls today.
    func generate(
        period: SummaryPeriod,
        todayEpochDay: Int,
        language: AiLanguage
    ) async -> ReportOutcome
}

/// The doctor report's gating core.
///
/// Three rules shape it, and each one is a product decision rather than an implementation detail:
///
/// 1. **Premium first, at this level.** An unentitled user is answered `ReportOutcome.needsPremium`
///    before anything is read, aggregated, called or written. The one-off free AI credit
///    explicitly does **not** apply here — the report is premium in full — so unlike
///    `AiSummaryRepository` there is nothing irreversible to spend and therefore no reason to
///    re-check the store on a "no". A premium user who opens this during the launch window before
///    the store answers simply sees the paywall button and taps again.
/// 2. **The deterministic half never depends on the AI half.** Statistics and rows come from the
///    local database, so once there is data the PDF is produced whatever the model — or the quota
///    counter it reads — does. `ReportOutcome.failed` means the records could not be read or the
///    file could not be written, and nothing else.
/// 3. **The narrative is the optional half.** It is skipped — silently, with a note on the page —
///    when the period is too thin to say anything honest about, when the day's AI quota is spent,
///    or when the call does not succeed. None of those cost the user anything, and none of them
///    reach the UI as an error.
///
/// The whole body runs off the main actor: the model call, the two database reads and writing the
/// file are all blocking work. This is the iOS twin of Android's `withContext(dispatchers.io)` —
/// the repository is `nonisolated`, so a `@MainActor` ViewModel calls it and the work hops off the
/// main actor.
public final class DoctorReportRepositoryImpl: DoctorReportRepository {
    private let aiClient: any AiClient
    private let periodReader: any HealthPeriodReader
    private let usageDataSource: AiUsageDataSource
    private let premiumRepository: any PremiumRepository
    private let generator: any PdfReportGenerator
    private let clock: any SalusClock

    public init(
        aiClient: any AiClient,
        periodReader: any HealthPeriodReader,
        usageDataSource: AiUsageDataSource,
        premiumRepository: any PremiumRepository,
        generator: any PdfReportGenerator,
        clock: any SalusClock
    ) {
        self.aiClient = aiClient
        self.periodReader = periodReader
        self.usageDataSource = usageDataSource
        self.premiumRepository = premiumRepository
        self.generator = generator
        self.clock = clock
    }

    public func generate(
        period: SummaryPeriod,
        todayEpochDay: Int,
        language: AiLanguage
    ) async -> ReportOutcome {
        // Gate 1 — before any read, so a free user's tap costs one status lookup.
        let entitled = await premiumRepository.status.firstValue()?.isEntitled ?? false
        if !entitled {
            return .needsPremium
        }

        // Everything past the gate is I/O that can fail: the database can throw on a corrupt
        // store and writing the file can throw on a full disk. This is an `async` call running in
        // the ViewModel's task, so an escaping error is a process crash and a screen stuck on its
        // spinner — the caller has no state left to move to. Answering `failed` keeps the one
        // "something went wrong" path the screen already knows how to render.
        do {
            return try await buildReport(period: period, todayEpochDay: todayEpochDay, language: language)
        } catch is CancellationError {
            // Cancellation is the caller going away, not a failure of ours. The ViewModel's task
            // guard discards whatever this returns, so a cancelled request never publishes a
            // result — the twin of Android rethrowing `CancellationException`.
            return .failed(message: reportFailed)
        } catch {
            logger.warning("Doctor report could not be produced: \(String(describing: error), privacy: .private)")
            return .failed(message: error.localizedDescription.isEmpty ? reportFailed : error.localizedDescription)
        }
    }

    /// The report itself, once the user is known to be entitled.
    ///
    /// Free to throw: `generate` turns anything that escapes into `ReportOutcome.failed`.
    private func buildReport(
        period: SummaryPeriod,
        todayEpochDay: Int,
        language: AiLanguage
    ) async throws -> ReportOutcome {
        // The zone is resolved here rather than passed in: day boundaries are a property of the
        // device the records were logged on, not of the calling screen.
        let timeZone = clock.timeZone()
        let stats = try await periodReader.aggregate(period: period, todayEpochDay: todayEpochDay, timeZone: timeZone)

        // Gate 2 — an empty period, and only an empty period. A thin one still gets its tables;
        // it is the narrative that needs enough days to be worth writing.
        if stats.distinctRecordDays == 0 {
            return .needsMoreData
        }

        let rows = try await periodReader.periodRows(period: period, todayEpochDay: todayEpochDay, timeZone: timeZone)
        let narrative = await narrativeFor(stats: stats, todayEpochDay: todayEpochDay, language: language)

        return try .ready(
            pdfFile: generator.generate(stats: stats, rows: rows, narrative: narrative, language: language),
            narrativeIncluded: narrative != nil
        )
    }

    /// The AI section's text, or `nil` when it was skipped for any of the three reasons.
    ///
    /// Every `nil` here is a note on the page and never an error on the screen, so the reasons are
    /// not distinguished in the return type — they are distinguished in the log, which is the only
    /// diagnostic trail this app has by design.
    private func narrativeFor(
        stats: HealthPeriodStats,
        todayEpochDay: Int,
        language: AiLanguage
    ) async -> String? {
        // Too thin to narrate: the same threshold the summary uses, because the failure mode is
        // the same one — confident-sounding prose about two readings of noise.
        if stats.distinctRecordDays < stats.periodType.minimumRecordDays {
            return nil
        }

        // Total on purpose, so the optional half stays optional. The quota lives in
        // `UserDefaults`, which cannot throw, and `AiClient` only promises not to throw for an
        // *SDK* failure. Letting either escape would turn a working report — the tables the user
        // actually came for — into `failed` because the AI half was unwell.
        do {
            return try await generatedNarrative(stats: stats, todayEpochDay: todayEpochDay, language: language)
        } catch is CancellationError {
            // Cancellation is the caller going away, not a failure of ours.
            return nil
        } catch {
            logger.warning("Doctor report narrative skipped: \(String(describing: error), privacy: .private)")
            return nil
        }
    }

    private func generatedNarrative(
        stats: HealthPeriodStats,
        todayEpochDay: Int,
        language: AiLanguage
    ) async throws -> String? {
        // `callsOn` and never `callsToday`: the stored count is only reset by the next write, so
        // before the day's first call it still belongs to a previous day.
        let usage = await usageDataSource.usage.firstValue() ?? .default
        if usage.callsOn(todayEpochDay: todayEpochDay) >= dailyAiCallLimit {
            return nil
        }

        switch await aiClient.generate(PromptBuilder.doctorReportPrompt(stats, language: language)) {
        case let .success(text):
            // Recorded through `recordCall`, which reads and writes the counter in one
            // transaction — the count read above is a gate, never a value to write back.
            // A failed counter write must not discard a narrative the user was already billed
            // for, so the write is isolated and the text is returned regardless.
            usageDataSource.recordCall(todayEpochDay: todayEpochDay)
            return text

        // Nothing is spent for either failure, and neither text is ever printed: it is
        // untranslated vendor output that would end up in front of a doctor.
        case .unavailable:
            logger.warning("Doctor report narrative unavailable: \(unavailableMessage, privacy: .public)")
            return nil

        case let .error(message):
            logger.warning("Doctor report narrative failed: \(message, privacy: .public)")
            return nil
        }
    }
}

/// No Firebase configuration on this build, so the request was never sent.
private let unavailableMessage = "AI narratives are not available on this build."

private let reportFailed = "The report could not be produced."

/// Shared with the rest of the app's log output, so one filter catches everything.
private let logger = Logger(subsystem: "com.alicansekban.salus", category: "ai")

extension AsyncStream {
    /// The stream's current value — the twin of Kotlin's `flow.first()`. Both the usage and the
    /// premium status streams emit their stored value as soon as a consumer arrives, so this
    /// awaits a real element instead of sleeping.
    fileprivate func firstValue() async -> Element? {
        for await value in self {
            return value
        }
        return nil
    }
}

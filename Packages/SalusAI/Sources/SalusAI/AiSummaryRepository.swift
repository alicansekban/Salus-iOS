// Ported 1:1 from Android
// `core/ai/src/main/kotlin/com/alicansekban/salus/core/ai/AiSummaryRepository.kt`.

import Foundation
import os
import SalusCommon
import SalusDatabase
import SalusPremium
import SalusSettings

/// A generated health summary, whether freshly produced or read back out of the cache
/// (`AiSummaryRepository.kt:20-27`).
public struct AiSummary: Equatable, Sendable {
    public let periodType: SummaryPeriod
    public let startEpochDay: Int
    public let endEpochDay: Int
    public let language: AiLanguage
    public let text: String
    public let createdAtEpochMs: Int64

    public init(
        periodType: SummaryPeriod,
        startEpochDay: Int,
        endEpochDay: Int,
        language: AiLanguage,
        text: String,
        createdAtEpochMs: Int64
    ) {
        self.periodType = periodType
        self.startEpochDay = startEpochDay
        self.endEpochDay = endEpochDay
        self.language = language
        self.text = text
        self.createdAtEpochMs = createdAtEpochMs
    }
}

/// Why a summary request failed, in terms a screen can act on
/// (`AiSummaryRepository.kt:37-44`).
///
/// The distinction is the difference between two pieces of advice that must never be swapped:
/// `.error` is worth retrying and usually means the network, while `.unavailable` means this build
/// has no Firebase configuration at all — telling that user to "check your connection" would send
/// them chasing a problem they cannot fix.
public enum SummaryFailureReason: Sendable {
    /// The request was sent and did not succeed. Retrying may work.
    case error

    /// No Firebase configuration on this build, so nothing was ever sent. Retrying cannot help.
    case unavailable
}

/// Everything `AiSummaryRepository.getSummary` can answer (`AiSummaryRepository.kt:53-76`).
///
/// The three "cannot run" cases are deliberately distinct rather than one failure: each one is a
/// different screen. `.needsMoreData` asks the user to keep logging, `.needsPremium` opens the
/// paywall, `.dailyLimitReached` says "tomorrow", and only `.failed` offers a retry.
public enum SummaryOutcome: Equatable, Sendable {
    /// `fromCache` is true when no AI call was made, so nothing was spent for this answer.
    case ready(summary: AiSummary, fromCache: Bool)

    /// Too few days in the period carry a record for a summary to say anything.
    case needsMoreData

    /// Not entitled, and the one-off free summary is already spent.
    case needsPremium

    /// Entitled, but today's call quota is used up. Resets at the next local midnight.
    case dailyLimitReached

    /// The request was sent (or could not be sent) and failed. Nothing was spent.
    ///
    /// Carries only a `reason`, never the underlying text. That text comes from the model SDK: it
    /// is untranslated, vendor-worded and occasionally echoes the request, so it is diagnostics
    /// and nothing else. It is written to the log where it is produced — see
    /// `AiSummaryRepositoryImpl` — so no screen can render it by accident.
    case failed(reason: SummaryFailureReason)
}

/// Produces and caches the AI health summaries, and owns every rule about what one costs
/// (`AiSummaryRepository.kt:79-102`).
public protocol AiSummaryRepository: Sendable {
    /// Whether the one-off free summary is still unspent, for the UI badge
    /// (`AiSummaryRepository.kt:81-88`).
    ///
    /// This says nothing about entitlement: a premium user also reads `true` here until they
    /// happen to generate one as a free user. Screens that show the badge already know the
    /// premium status and decide whether the badge is worth showing.
    var freeSummaryAvailable: AsyncStream<Bool> { get }

    /// Answers with the summary for `period` ending on `todayEpochDay`, generating one only when
    /// every gate allows it (`AiSummaryRepository.kt:90-101`).
    ///
    /// - Parameters:
    ///   - todayEpochDay: the local day the period ends on, passed in so the caller's notion of
    ///     "today" is the one the quota is counted against.
    func getSummary(
        period: SummaryPeriod,
        todayEpochDay: Int,
        language: AiLanguage
    ) async -> SummaryOutcome
}

/// The gating core of the AI feature (`AiSummaryRepository.kt:104-135`).
///
/// `getSummary` walks five gates **in this order**, and the order is a product decision, not an
/// implementation detail:
///
/// 1. **Cache.** A stored summary for the same period and language is returned as-is. It was
///    already paid for when it was generated, so re-opening it must not be re-gated — otherwise a
///    user who lets their subscription lapse loses summaries they already spent an allowance on.
/// 2. **Enough data.** A period with too few recorded days is answered `.needsMoreData` without an
///    AI call. This sits *above* the entitlement gate on purpose: a free user with two days of
///    records is told to keep logging, never shown a paywall for a summary of nothing.
/// 3. **Entitlement.** A user who is not entitled and has spent their free summary hits the
///    paywall. A "not entitled" answer is re-checked against the store once first — see
///    `resolveEntitlement`.
/// 4. **Daily quota.** `DAILY_AI_CALL_LIMIT` calls per day, entitled or not — the cost ceiling.
/// 5. **The call.** Only an `AiResult.success` spends anything; a failure leaves the free summary
///    and the counter exactly as they were, so an offline attempt is free.
///
/// The whole body runs off the main actor: the model call, the aggregator's two queries and the
/// cache read/write are all blocking work, and nothing here may assume the SDK pins a thread of
/// its own. This is the iOS twin of Android's `withContext(dispatchers.io)` — the repository is
/// `nonisolated`, so a `@MainActor` ViewModel calls it and the work hops off the main actor.
public final class AiSummaryRepositoryImpl: AiSummaryRepository {
    private let aiClient: any AiClient
    private let aggregator: any HealthPeriodReader
    private let summaryDao: AiSummaryDao
    private let usageDataSource: AiUsageDataSource
    private let premiumRepository: any PremiumRepository
    private let clock: any SalusClock

    public init(
        aiClient: any AiClient,
        aggregator: any HealthPeriodReader,
        summaryDao: AiSummaryDao,
        usageDataSource: AiUsageDataSource,
        premiumRepository: any PremiumRepository,
        clock: any SalusClock
    ) {
        self.aiClient = aiClient
        self.aggregator = aggregator
        self.summaryDao = summaryDao
        self.usageDataSource = usageDataSource
        self.premiumRepository = premiumRepository
        self.clock = clock
    }

    public var freeSummaryAvailable: AsyncStream<Bool> {
        // The twin of Kotlin's `usage.map { !it.freeSummaryUsed }.distinctUntilChanged()`: the
        // badge follows the stored usage, and a change to the call counter that leaves
        // `freeSummaryUsed` untouched does not re-emit it.
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            var last: Bool?
            let task = Task {
                for await usage in usageDataSource.usage {
                    let available = !usage.freeSummaryUsed
                    if available != last {
                        last = available
                        continuation.yield(available)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    public func getSummary(
        period: SummaryPeriod,
        todayEpochDay: Int,
        language: AiLanguage
    ) async -> SummaryOutcome {
        // Gate 1 — the cache key is the period's first day, which is derivable without reading
        // a single record, so a cache hit costs one indexed lookup and nothing else.
        let startEpochDay = periodBoundsOf(period, todayEpochDay: todayEpochDay).lowerBound
        if let cached = await cachedSummary(period, startEpochDay: startEpochDay, language: language) {
            return .ready(summary: cached, fromCache: true)
        }

        // Gate 2 — the zone is resolved here rather than passed in: day boundaries are a property
        // of the device the records were logged on, not of the calling screen.
        //
        // One divergence from Android, in the safe direction: Room's `aggregate` never throws,
        // while the GRDB reads behind `HealthPeriodReader.aggregate` can. A failed read degrades
        // to a retryable failure that spends nothing — the closest `SummaryOutcome` the Android
        // twin has for "the data could not be read".
        guard let stats = try? await aggregator.aggregate(
            period: period,
            todayEpochDay: todayEpochDay,
            timeZone: clock.timeZone()
        ) else {
            return .failed(reason: .error)
        }
        if stats.distinctRecordDays < period.minimumRecordDays {
            return .needsMoreData
        }

        // Gate 3 — resolved before the quota gate and reused by `spendAllowance`, so the free
        // summary can never be burned against a status this call already knows is stale.
        let entitled = await resolveEntitlement()
        let usage = await usageDataSource.usage.firstValue() ?? .default
        if !entitled, usage.freeSummaryUsed {
            return .needsPremium
        }

        // Gate 4 — `callsOn` and never `callsToday`: the stored count is only reset by the next
        // write, so before the day's first call it still belongs to a previous day.
        if usage.callsOn(todayEpochDay: todayEpochDay) >= DAILY_AI_CALL_LIMIT {
            return .dailyLimitReached
        }

        // Gate 5.
        switch await aiClient.generate(PromptBuilder.summaryPrompt(stats, language: language)) {
        case let .success(text):
            let summary = await store(stats, language: language, text: text.withDisclaimer(language))
            await spendAllowance(todayEpochDay: todayEpochDay, entitled: entitled)
            return .ready(summary: summary, fromCache: false)

        // Nothing is spent for either failure: an offline attempt must stay free.
        //

        // The underlying text dies here, in the log. It is the only trail there is — the app
        // ships no analytics and no crash reporter by design — so a support question about "the
        // summary never works" is answerable from a bug report, while the string itself stays out
        // of the outcome and therefore out of the UI.
        case .unavailable:
            logger.warning("AI summary unavailable: \(Self.unavailableMessage)")
            return .failed(reason: .unavailable)

        case let .error(message):
            logger.warning("AI summary failed: \(message)")
            return .failed(reason: .error)
        }
    }

    /// Whether the user is entitled, re-checking the store once when the cached answer says no
    /// (`AiSummaryRepository.kt:197-214`).
    ///
    /// `PremiumRepositoryImpl.status` starts at `.free` and only leaves it once the store's
    /// customer stream answers, so "not entitled" right after launch may just mean "the store has
    /// not replied yet". Spending the one-off free summary is irreversible and unrefundable, so it
    /// is worth one refresh to be sure — a paying user who opens a summary too early must not be
    /// charged their free credit for it.
    ///
    /// The refresh is skipped entirely when the first read is already entitled, so a premium user
    /// never pays for extra store chatter. `refresh()` is defined to leave the status untouched
    /// when the store cannot be reached, so an offline call simply proceeds as free.
    private func resolveEntitlement() async -> Bool {
        if await premiumRepository.status.firstValue()?.isEntitled == true {
            return true
        }
        await premiumRepository.refresh()
        return await premiumRepository.status.firstValue()?.isEntitled == true
    }

    private func cachedSummary(
        _ period: SummaryPeriod,
        startEpochDay: Int,
        language: AiLanguage
    ) async -> AiSummary? {
        guard let row = await summaryDao.get(
            periodType: period.name,
            startEpochDay: startEpochDay,
            language: language.tag
        ) else {
            return nil
        }
        // The period and the language are the query keys, so they are known without parsing the
        // stored strings back into enums.
        return AiSummary(
            periodType: period,
            startEpochDay: row.startEpochDay,
            endEpochDay: row.endEpochDay,
            language: language,
            text: row.text,
            createdAtEpochMs: row.createdAtEpochMs
        )
    }

    /// Caches `text` under the period + language key, replacing any older summary for it
    /// (`AiSummaryRepository.kt:234-259`).
    private func store(
        _ stats: HealthPeriodStats,
        language: AiLanguage,
        text: String
    ) async -> AiSummary {
        let summary = AiSummary(
            periodType: stats.periodType,
            startEpochDay: stats.startEpochDay,
            endEpochDay: stats.endEpochDay,
            language: language,
            text: text,
            createdAtEpochMs: clock.nowEpochMilliseconds()
        )
        await summaryDao.upsert(
            AiSummaryRecord(
                periodType: summary.periodType.name,
                startEpochDay: summary.startEpochDay,
                endEpochDay: summary.endEpochDay,
                language: summary.language.tag,
                text: summary.text,
                createdAtEpochMs: summary.createdAtEpochMs
            )
        )
        return summary
    }

    /// Charges a successful call: one against today's quota, plus the free summary when the user
    /// is not entitled (`AiSummaryRepository.kt:261-272`).
    ///
    /// `AiUsageDataSource.recordCall` reads and writes the counter inside one transaction, so the
    /// count is never read here and handed back — two concurrent successes cannot both write the
    /// same value.
    private func spendAllowance(todayEpochDay: Int, entitled: Bool) async {
        usageDataSource.recordCall(todayEpochDay: todayEpochDay)
        if !entitled {
            usageDataSource.markFreeSummaryUsed()
        }
    }

    /// No Firebase configuration on this build, so the request was never sent
    /// (`AiSummaryRepository.kt:290`).
    private static let unavailableMessage = "AI summaries are not available on this build."
}

/// Appends the shared `disclaimerFor` sentence before the text is cached, so a summary read back
/// out of the cache carries it too and no screen has to remember to add it
/// (`AiSummaryRepository.kt:275-280`).
extension String {
    fileprivate func withDisclaimer(_ language: AiLanguage) -> String {
        "\(trimmingTrailingWhitespace())\n\n\(disclaimerFor(language))"
    }

    /// Kotlin's `trimEnd()` — trailing whitespace and newlines only, never the leading edge.
    private func trimmingTrailingWhitespace() -> String {
        var end = endIndex
        while end > startIndex {
            let before = index(before: end)
            let char = self[before]
            if char.isWhitespace || char.isNewline {
                end = before
            } else {
                break
            }
        }
        return String(self[..<end])
    }
}

/// BCP-47 tag stored in `ai_summaries.language` (`AiSummaryRepository.kt:282-287`).
extension AiLanguage {
    fileprivate var tag: String {
        switch self {
        case .tr: "tr"
        case .en: "en"
        }
    }
}

/// The period name stored in `ai_summaries.period_type` — the twin of Kotlin's `enum.name`.
extension SummaryPeriod {
    fileprivate var name: String {
        switch self {
        case .weekly: "WEEKLY"
        case .monthly: "MONTHLY"
        }
    }
}

/// Shared with the rest of the app's log output, so one filter catches everything
/// (`AiSummaryRepository.kt:293`).
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

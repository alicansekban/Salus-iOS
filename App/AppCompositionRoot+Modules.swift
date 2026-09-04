import FeatureAIHealth
import FeatureAppointments
import FeatureCycle
import FeatureHome
import FeatureMedications
import FeatureOnboarding
import FeaturePaywall
import FeatureSettings
import FeatureTrends
import FeatureVitals
import SalusAI
import SalusCommon
import SalusDatabase
import SalusNavigation
import SalusPremium
import SalusProfile
import SalusSettings
import SalusUI
import UIKit

/// The module bundles `AppCompositionRoot`'s builders hand back, and the one module builder that no
/// longer fits beside them.
///
/// Split out of `AppCompositionRoot.swift` for the reason `AppCompositionRoot+Reminder.swift` was:
/// the root file is meant to stay a readable list of `let`s and the builders that fill them, and it
/// sits against the 500-line budget. Nothing here is `public`, so the app's assembly is still
/// invisible outside the app target; the members are `internal` rather than `private` only because
/// `makeFeatureModules` and `makeScheduledModules` live in the other file.
extension AppCompositionRoot {
    /// `homeModule` (`feature/home/.../di/HomeModule.kt:11-23`).
    ///
    /// A builder of its own, called *after* ``makeScheduledModules(infrastructure:reminderScheduler:)``,
    /// because the dashboard is the one module assembled out of another feature's: its "Al" button is
    /// Medications' `MarkDoseTakenUseCase`, taken from the medications module by the
    /// `medications.makeMarkDoseTakenUseCase()` call below — the twin of Koin's
    /// `factoryOf(::MarkDoseTakenUseCase) bind DoseActions::class` (`MedicationsModule.kt:30`), so
    /// every caller gets a fresh use case over the one repository. Reusing that factory is what
    /// keeps the card from opening a second medications graph.
    ///
    /// The four DAOs are opened here exactly as every other module's are — a DAO is a value over the
    /// one `SalusDatabase`, so a second instance is not a second connection — and the profile id is
    /// spelled out rather than left to the default, so the one construction site says which profile
    /// the dashboard reads.
    static func makeHomeGraph(
        infrastructure: Infrastructure,
        medications: MedicationsModule,
        homePremiumStatus: any HomePremiumStatus
    ) -> HomeModule {
        let database = infrastructure.database
        return makeHomeModule(
            medicationDao: MedicationDao(database: database),
            appointmentDao: AppointmentDao(database: database),
            cycleDao: CycleDao(database: database),
            vitalsDao: VitalsDao(database: database),
            preferences: infrastructure.preferences,
            aiUsage: infrastructure.aiUsage,
            homePremiumStatus: homePremiumStatus,
            clock: infrastructure.clock,
            doseActions: medications.makeMarkDoseTakenUseCase(),
            profileId: SalusDatabase.defaultProfileId
        )
    }

    /// `onboardingModule` (`feature/onboarding/.../di/OnboardingModule.kt:10-23`).
    ///
    /// A builder of its own for the reason ``makeHomeGraph(infrastructure:medications:)`` is one:
    /// it is assembled out of another feature's module. The weight step writes through Vitals'
    /// `VitalsQuickEntry` — Koin's `single<VitalsQuickEntry>` (`VitalsModule.kt:26`), which the
    /// root already exposes "for onboarding's current weight step" and which ruling 7 names as
    /// `finish()`'s second write. Taking it from the vitals module rather than building a second
    /// save-weight use case is what keeps the flow writing into the same repository the vitals tab
    /// reads.
    ///
    /// `OnboardingPreferences` is **not** passed: `makeOnboardingModule` builds
    /// `OnboardingPreferencesImpl` over the one `SalusPreferencesDataSource` inside the package,
    /// exactly as `makeSettingsModule` does with `SettingsPreferencesImpl`. That store is the one
    /// `RootView`'s `userSettings` loop watches, which is the whole of the gate's dismissal.
    static func makeOnboardingGraph(
        infrastructure: Infrastructure,
        vitals: VitalsModule
    ) -> OnboardingModule {
        makeOnboardingModule(
            profileRepository: infrastructure.profileRepository,
            vitalsQuickEntry: vitals.makeSaveWeightEntryUseCase(),
            preferencesDataSource: infrastructure.preferences,
            clock: infrastructure.clock
        )
    }

    /// The premium singletons, built once here. `premiumModule` (`PremiumModule.kt:13-19`) is
    /// `single<PremiumRepository>` over `single<PurchasesGateway>`; the `paywallModule` rides on
    /// the same two. `Purchases.isConfigured` is already final here — `SalusApp` configures
    /// RevenueCat before composing the root.
    static func makePremiumGraph() -> PremiumGraph {
        let purchasesGateway = RevenueCatPurchasesGateway()
        let premiumRepository: any PremiumRepository = PremiumRepositoryImpl(gateway: purchasesGateway)
        let paywallController = PaywallController()
        let paywallModule = makePaywallModule(
            gateway: purchasesGateway,
            premiumRepository: premiumRepository,
            paywallController: paywallController,
            makePurchaseHost: {
                // The key window the store sheet attaches to, captured at presentation time.
                let window = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                    .first(where: \.isKeyWindow)
                    .flatMap { WindowPurchaseHost(window: $0) }
                return window ?? WindowPurchaseHost(window: nil)
            }
        )
        return PremiumGraph(
            premiumRepository: premiumRepository,
            paywallController: paywallController,
            paywallModule: paywallModule
        )
    }

    /// The AI health graph — `FeatureAIHealth`'s `makeAiHealthModule`, wired with the real
    /// production dependencies from the root's own singletons.
    ///
    /// `FirebaseAiClient` is the real client: it answers `AiResult.unavailable` on a build with no
    /// GoogleServices plist, so the screens render their "unavailable" state honestly before the
    /// Task 7 configure work lands. Nothing else here is Task 7's — the plist configuration is the
    /// only remaining piece, and this is its consumption point.
    static func makeAiHealthGraph(
        infrastructure: Infrastructure,
        premium: PremiumGraph
    ) -> AiHealthModule {
        let database = infrastructure.database
        let aiUsage = infrastructure.aiUsage
        let aggregator: any HealthPeriodReader = HealthStatsAggregator(
            vitalsDao: VitalsDao(database: database),
            medicationDao: MedicationDao(database: database),
            profileId: SalusDatabase.defaultProfileId
        )
        let summaryRepository: any AiSummaryRepository = AiSummaryRepositoryImpl(
            aiClient: FirebaseAiClient(),
            aggregator: aggregator,
            summaryDao: GRDBAiSummaryDao(database: database),
            usageDataSource: aiUsage,
            premiumRepository: premium.premiumRepository,
            clock: infrastructure.clock
        )
        let doctorReportRepository: any DoctorReportRepository = DoctorReportRepositoryImpl(
            aiClient: FirebaseAiClient(),
            periodReader: aggregator,
            usageDataSource: aiUsage,
            premiumRepository: premium.premiumRepository,
            generator: IosPdfReportGenerator(clock: infrastructure.clock),
            clock: infrastructure.clock
        )
        return makeAiHealthModule(
            summaryRepository: summaryRepository,
            doctorReportRepository: doctorReportRepository,
            premiumRepository: premium.premiumRepository,
            paywallController: premium.paywallController,
            languageProvider: ResourceAiLanguageProvider(),
            clock: infrastructure.clock
        )
    }

    /// `trendsModule` (`feature/trends/.../di/TrendsModule.kt`).
    ///
    /// A builder of its own because it is assembled out of the same singletons the other premium
    /// features already share — the premium repository and paywall controller from
    /// `makePremiumGraph`, and the one `SalusPreferencesDataSource` — over a `TrendsDataReader`
    /// that reaches the two DAOs the analytics read. `TrendsRepositoryImpl` enforces the
    /// premium gate, so a free user's `load` costs one status lookup and touches no database.
    static func makeTrendsGraph(
        infrastructure: Infrastructure,
        premium: PremiumGraph
    ) -> TrendsModule {
        let database = infrastructure.database
        let reader: any TrendsReader = TrendsDataReader(
            vitalsDao: VitalsDao(database: database),
            medicationDao: MedicationDao(database: database),
            profileId: SalusDatabase.defaultProfileId
        )
        let repository: any TrendsRepository = TrendsRepositoryImpl(
            reader: reader,
            premiumRepository: premium.premiumRepository,
            clock: infrastructure.clock
        )
        return makeTrendsModule(
            repository: repository,
            paywallController: premium.paywallController,
            premiumRepository: premium.premiumRepository,
            preferences: infrastructure.preferences
        )
    }

    /// Opens `<Application Support>/salus.db`, creating the directory first and excluding it
    /// from backup.
    ///
    /// `SalusDatabase.init` does not create parent directories, and `Application Support` — unlike
    /// `Documents` — is not created for an app by the system. Two things can fail here, and both
    /// are fatal: a health log that cannot open its store must not run silently, showing empty
    /// screens and quietly discarding everything the user types into it. Android reaches the same
    /// end by a different road — Room throws on first query — so this is the port of a behaviour,
    /// not a new policy.
    static func openDatabase(clock: any SalusClock) -> SalusDatabase {
        let fileManager = FileManager.default
        do {
            let directory = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent(SalusDatabase.name)
            let database = try SalusDatabase(path: file.path, clock: clock)
            // Parity-ledger S-10: Android's `allowBackup=false` has no iOS manifest twin, so the
            // store is marked here, after the open that creates it. Fatal like the open itself —
            // a health log that silently ships to iCloud is exactly what the listing and
            // `about_privacy_body` promise it will not do.
            try SalusDatabase.excludeFromBackup(at: file)
            return database
        } catch {
            let reason = String(describing: error)
            AppCompositionRoot.logger.critical(
                "cannot open \(SalusDatabase.name, privacy: .public): \(reason, privacy: .private)"
            )
            fatalError("Salus cannot open its database (\(SalusDatabase.name)): \(reason)")
        }
    }

    /// `get<SalusPreferencesDataSource>().userSettings.map { it.appLockEnabled }.distinctUntilChanged()`
    /// (`AppModules.kt:45-52`) — Koin's one-line flow, spelled as the `AsyncStream<Bool>`
    /// `AppLockManager.init` takes.
    ///
    /// Hand-written rather than `AsyncMapSequence` plus a de-duplicating wrapper for two reasons:
    /// the manager's parameter is the concrete `AsyncStream`, not `some AsyncSequence`, and
    /// `distinctUntilChanged` has no Swift-concurrency equivalent to reach for — the two-line fold
    /// below *is* the operator. `previous` starts `nil` so the very first value is always yielded,
    /// which is what makes this a cold flow that replays: the manager's `hasReadSetting` depends on
    /// getting one emission per subscription, not one per change.
    ///
    /// The task is cancelled on termination, so a dropped manager (a second graph in a preview,
    /// say) stops observing rather than leaking a subscription to `UserDefaults`.
    static func appLockEnabledStream(of preferences: SalusPreferencesDataSource) -> AsyncStream<Bool> {
        let settings = preferences.userSettings
        return AsyncStream { continuation in
            let task = Task {
                var previous: Bool?
                for await value in settings {
                    guard value.appLockEnabled != previous else { continue }
                    previous = value.appLockEnabled
                    continuation.yield(value.appLockEnabled)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// The process-lifetime singletons, handed back from `makeInfrastructure` in one piece.
///
/// `internal` rather than `private` because ``AppCompositionRoot/makeHomeGraph(infrastructure:medications:)``
/// and ``AppCompositionRoot/makeOnboardingGraph(infrastructure:vitals:)`` live here and take it.
/// Moved out of `AppCompositionRoot.swift` in iOS-M8 T11, so all three of the graph's bundle types
/// sit together and the root file stays inside its 500-line budget.
struct Infrastructure {
    let clock: any SalusClock
    let idGenerator: any IdGenerator
    let database: SalusDatabase
    let profileDao: ProfileDao
    let appLockFlagStore: any AppLockFlagStore
    let preferences: SalusPreferencesDataSource
    let aiUsage: AiUsageDataSource
    let profileRepository: any ProfileRepository
    let pendingDelete: PendingDeleteController
    let appLockManager: AppLockManager
    let navigator: Navigator
    let snackbar: SalusSnackbarController
}

/// The modules that own a reminder handler, handed back from `makeScheduledModules` in one piece.
/// A milestone that gives a fourth feature a reminder adds one field here.
struct ScheduledModules {
    let appointments: AppointmentsModule
    let medications: MedicationsModule
    let cycle: CycleModule
}

/// The feature modules, handed back from `makeFeatureModules` in one piece with the reminder
/// sub-graph they were wired against. A milestone that adds a feature adds one field here.
struct FeatureModules {
    let reminder: ReminderGraph
    let vitals: VitalsModule
    let appointments: AppointmentsModule
    let medications: MedicationsModule
    let cycle: CycleModule
    let settings: SettingsModule
    let home: HomeModule
    let onboarding: OnboardingModule
    let aiHealth: AiHealthModule
    let trends: TrendsModule
    let premiumRepository: any PremiumRepository
    let paywallController: PaywallController
    let paywallModule: PaywallModule
}

/// The premium sub-graph `makePremiumGraph` hands back — the repository, and the paywall
/// controller and module every premium-gated caller shares.
struct PremiumGraph {
    let premiumRepository: any PremiumRepository
    let paywallController: PaywallController
    let paywallModule: PaywallModule
}

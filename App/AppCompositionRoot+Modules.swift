import FeatureAppointments
import FeatureCycle
import FeatureHome
import FeatureMedications
import FeatureSettings
import FeatureVitals
import SalusDatabase

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
    /// Medications' `MarkDoseTakenUseCase`, the same Koin `factory` ``AppCompositionRoot/doseActions``
    /// exposes. Reusing that seam is what keeps the card from opening a second medications graph.
    ///
    /// The four DAOs are opened here exactly as every other module's are — a DAO is a value over the
    /// one `SalusDatabase`, so a second instance is not a second connection — and the profile id is
    /// spelled out rather than left to the default, so the one construction site says which profile
    /// the dashboard reads.
    static func makeHomeGraph(
        infrastructure: Infrastructure,
        medications: MedicationsModule
    ) -> HomeModule {
        let database = infrastructure.database
        return makeHomeModule(
            medicationDao: MedicationDao(database: database),
            appointmentDao: AppointmentDao(database: database),
            cycleDao: CycleDao(database: database),
            vitalsDao: VitalsDao(database: database),
            preferences: infrastructure.preferences,
            aiUsage: infrastructure.aiUsage,
            clock: infrastructure.clock,
            doseActions: medications.makeMarkDoseTakenUseCase(),
            profileId: SalusDatabase.defaultProfileId
        )
    }
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
}

// Twin of `core/smoking/.../di/SmokingCoreModule.kt`: the repository plus the sixteen use cases,
// built once over one store, so every use case and the repository's repair share one write path.
//
// Koin's `getAll<SmokingChangeListener>()` becomes ``changeListeners``: the composition root builds
// the module with an empty registry, and the task that wires the reminder resync (plan Task 17)
// calls `add(_:)` on it without touching a use case. With none registered, writes still work.

import SalusCommon
import SalusDatabase

public struct SmokingCoreModule: Sendable {
    public let repository: any SmokingRepository
    public let changeListeners: SmokingChangeListeners

    public let setUp: SetUpSmoking
    public let logSmoked: LogSmoked
    public let logNoneToday: LogNoneToday
    public let logCravingResisted: LogCravingResisted
    public let resolveSlip: ResolveSlip
    public let switchMode: SwitchMode
    public let updatePrice: UpdatePrice
    public let updateCurrency: UpdateCurrency
    public let updatePlanFields: UpdatePlanFields
    public let editQuitDate: EditQuitDate
    public let editEvent: EditEvent
    public let deleteEvent: DeleteEvent
    public let saveSavingsGoal: SaveSavingsGoal
    public let updateSavingsGoal: UpdateSavingsGoal
    public let markGoalAchieved: MarkGoalAchieved
    public let resetSmoking: ResetSmoking

    public init(
        smokingDao: SmokingDao,
        clock: any SalusClock,
        idGenerator: any IdGenerator,
        changeListeners: SmokingChangeListeners = SmokingChangeListeners()
    ) {
        let store = DaoSmokingStore(dao: smokingDao, listeners: changeListeners)
        self.changeListeners = changeListeners
        repository = SmokingRepositoryImpl(dao: smokingDao, store: store, clock: clock, idGenerator: idGenerator)
        setUp = SetUpSmoking(store: store, clock: clock, idGenerator: idGenerator)
        logSmoked = LogSmoked(store: store, clock: clock, idGenerator: idGenerator)
        logNoneToday = LogNoneToday(store: store, clock: clock, idGenerator: idGenerator)
        logCravingResisted = LogCravingResisted(store: store, clock: clock, idGenerator: idGenerator)
        resolveSlip = ResolveSlip(store: store, clock: clock, idGenerator: idGenerator)
        switchMode = SwitchMode(store: store, clock: clock, idGenerator: idGenerator)
        updatePrice = UpdatePrice(store: store, clock: clock, idGenerator: idGenerator)
        updateCurrency = UpdateCurrency(store: store)
        updatePlanFields = UpdatePlanFields(store: store)
        editQuitDate = EditQuitDate(store: store, clock: clock)
        editEvent = EditEvent(store: store)
        deleteEvent = DeleteEvent(store: store)
        saveSavingsGoal = SaveSavingsGoal(store: store, clock: clock, idGenerator: idGenerator)
        updateSavingsGoal = UpdateSavingsGoal(store: store)
        markGoalAchieved = MarkGoalAchieved(store: store, clock: clock)
        resetSmoking = ResetSmoking(store: store)
    }
}

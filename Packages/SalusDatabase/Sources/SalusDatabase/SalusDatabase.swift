// The GRDB twin of
// `core/database/src/main/kotlin/com/alicansekban/salus/core/database/SalusDatabase.kt` and of the
// `Room.databaseBuilder` call in `di/DatabaseModule.kt`.
//
// Room's `@Database` annotation is a code generator; there is nothing to port from it. What is
// portable is what it configures — the file name, the seeded default profile id, the migration
// list and foreign keys — and that is what this type holds.

import GRDB
import SalusCommon

/// The application database.
///
/// Ported from `SalusDatabase.kt:38-68`. The Kotlin class exposes seven abstract DAO getters;
/// here a DAO is a small struct built over this database (`ProfileDao`), so the DAOs ship with
/// the features that read them instead of all being declared up front.
public final class SalusDatabase: Sendable {
    /// The database file name (`SalusDatabase.kt:60`). Both platforms write `salus.db`.
    public static let name = "salus.db"

    /// Single-user v1: every data table carries `profile_id` so multi-profile lands in v2 without
    /// schema surgery. This fixed id is seeded on database creation (`SalusDatabase.kt:64`).
    public static let defaultProfileId = "default-profile"

    /// A queue rather than a pool, and that is a decision, not a stopgap: Salus is a single-user
    /// app whose writes are one row at a time, so the reader concurrency a `DatabasePool` buys
    /// has nothing to spend itself on, while its WAL files and checkpointing are real complexity.
    /// Everything outside this type sees `writer` / `reader`, so a pool can replace it later
    /// without a single call site changing.
    private let queue: DatabaseQueue

    /// The write access point. `DatabaseWriter` is also a `DatabaseReader`, so a call site that
    /// needs both takes this one.
    public var writer: any DatabaseWriter { queue }

    /// The read access point, including `ValueObservation`.
    public var reader: any DatabaseReader { queue }

    /// Opens (creating it if needed) the database at `path` and migrates it to the current
    /// schema — the twin of `Room.databaseBuilder(...).addMigrations(*salusMigrations).build()`,
    /// except that Room defers the work to the first query and this does it now, where the error
    /// still has a caller to hand it to.
    ///
    /// - Parameter clock: the time source the seeded default profile's `created_at` is read from.
    public init(path: String, clock: any SalusClock) throws {
        queue = try DatabaseQueue(path: path, configuration: Self.configuration)
        try SalusMigrations.makeMigrator(clock: clock).migrate(queue)
    }

    /// An in-memory database, migrated the same way — the twin of
    /// `Room.inMemoryDatabaseBuilder(...)` that `DaoSmokeTest` builds on.
    public static func inMemory(clock: any SalusClock) throws -> SalusDatabase {
        try SalusDatabase(queue: DatabaseQueue(configuration: configuration), clock: clock)
    }

    private init(queue: DatabaseQueue, clock: any SalusClock) throws {
        self.queue = queue
        try SalusMigrations.makeMigrator(clock: clock).migrate(queue)
    }

    /// Foreign keys are on. GRDB already defaults to that, unlike raw SQLite and unlike Room
    /// before it enables them itself; it is spelled out because the schema leans on it — deleting
    /// a profile has to cascade to eleven tables — and because a silent default is a silent
    /// regression. `SalusDatabaseTests` asserts the pragma on an open connection.
    private static var configuration: Configuration {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        return configuration
    }
}

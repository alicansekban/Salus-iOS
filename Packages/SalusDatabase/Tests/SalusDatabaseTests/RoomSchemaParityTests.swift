// The drift detector for the whole port: Room's exported schema is the contract, and this file
// is the only place that reads it. Android proves its migrations with
// `MigrationTestHelper.runMigrationsAndValidate`, which compares the migrated database against
// `schemas/…/{n}.json`. There is no GRDB equivalent, so the comparison is written out here:
// migrate a fresh database up to `"v{n}"`, then read back its tables, columns, indices and
// foreign keys with the SQLite pragmas and check them against `{n}.json`.
//
// Fixtures: `Resources/RoomSchemas/{1,2,3}.json`, verbatim copies of the Android export
// (see the README beside them).

import Foundation
import GRDB
import SalusTesting
import Testing

@testable import SalusDatabase

// MARK: - Room schema export (the JSON contract)

/// The subset of Room's schema export this test reads. Room writes more (`identityHash`,
/// `setupQueries`, `createSql`, index `orders`, `autoGenerate`); none of it describes the shape
/// SQLite ends up with, which is what parity means here.
private struct RoomSchemaExport: Decodable {
    let database: RoomDatabase

    struct RoomDatabase: Decodable {
        let version: Int
        let entities: [RoomEntity]
    }
}

private struct RoomEntity: Decodable {
    let tableName: String
    /// Room's own DDL, with `${TABLE_NAME}` still unresolved. This is what `v1Statements` copies.
    let createSql: String
    let fields: [RoomField]
    let primaryKey: RoomPrimaryKey
    /// Absent in the JSON for a table that declares no index.
    let indices: [RoomIndex]?
    /// Absent in the JSON for a table that declares no foreign key.
    let foreignKeys: [RoomForeignKey]?
}

private struct RoomField: Decodable {
    let columnName: String
    /// `TEXT` / `INTEGER` / `REAL` — Room writes the affinity, which is also the declared type
    /// it emits into `CREATE TABLE`, so `PRAGMA table_info`'s `type` answers with the same word.
    let affinity: String
    /// Room omits the key entirely for a nullable column rather than writing `false`.
    let notNull: Bool?
}

private struct RoomPrimaryKey: Decodable {
    /// Ordered: position in this array is the column's position in the primary key.
    let columnNames: [String]
}

private struct RoomIndex: Decodable {
    let name: String
    let unique: Bool
    let columnNames: [String]
    let createSql: String
}

extension RoomEntity {
    /// The entity's DDL followed by its indices', with Room's placeholder resolved — the exact
    /// sequence `SalusMigrations.v1Statements` is expected to be.
    var resolvedCreateStatements: [String] {
        ([createSql] + (indices ?? []).map(\.createSql))
            .map { $0.replacingOccurrences(of: "${TABLE_NAME}", with: tableName) }
    }
}

private struct RoomForeignKey: Decodable {
    let table: String
    let onDelete: String
    let columns: [String]
    let referencedColumns: [String]
}

// MARK: - What SQLite actually has

private struct ActualColumn: Equatable, CustomStringConvertible {
    let type: String
    let notNull: Bool
    /// 0 when the column is not part of the primary key, otherwise its 1-based position in it.
    let primaryKeyPosition: Int

    var description: String {
        "\(type) notNull=\(notNull) pk=\(primaryKeyPosition)"
    }
}

private struct ActualIndex: Equatable, Comparable, CustomStringConvertible {
    let name: String
    let unique: Bool
    let columns: [String]

    var description: String {
        "\(name) unique=\(unique) (\(columns.joined(separator: ", ")))"
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.name < rhs.name
    }
}

private struct ActualForeignKey: Equatable, Comparable, CustomStringConvertible {
    let table: String
    let from: [String]
    let to: [String]
    let onDelete: String

    var description: String {
        "(\(from.joined(separator: ", "))) -> \(table)(\(to.joined(separator: ", "))) ON DELETE \(onDelete)"
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.description < rhs.description
    }
}

// MARK: - Suite

@Suite("Room schema parity")
struct RoomSchemaParityTests {
    /// Bookkeeping tables that exist on one platform or the other and describe no app data:
    /// Room's identity-hash row, SQLite's own AUTOINCREMENT counter, GRDB's applied-migration log.
    private static let bookkeepingTables: Set = [
        "room_master_table",
        "sqlite_sequence",
        "grdb_migrations"
    ]

    @Test("the migrated schema matches Room's export", arguments: [1, 2, 3])
    func migratedSchemaMatchesRoomExport(version: Int) throws {
        let expected = try Self.loadRoomSchema(version: version)
        #expect(expected.database.version == version)

        let queue = try DatabaseQueue()
        let migrator = SalusMigrations.makeMigrator(clock: FixedSalusClock(now: Date(timeIntervalSince1970: 0)))
        try migrator.migrate(queue, upTo: "v\(version)")

        try queue.read { db in
            let expectedTables = Set(expected.database.entities.map(\.tableName))
            let actualTables = try Self.tableNames(db)
            #expect(actualTables == expectedTables, "table set differs at v\(version)")

            for entity in expected.database.entities {
                try Self.checkColumns(db, entity: entity, version: version)
                try Self.checkIndices(db, entity: entity, version: version)
                try Self.checkForeignKeys(db, entity: entity, version: version)
            }
        }
    }

    /// The pragma comparison above would still pass if the DDL had been re-typed by hand and
    /// happened to mean the same thing. This one would not: `v1Statements` must be Room's
    /// `createSql` strings character for character, which is the only version of "1:1" that
    /// cannot rot quietly. Same for the 2 → 3 statement, whose Kotlin twin carries the same
    /// promise (`Migrations.kt:23-24`).
    @Test("the v1 and v3 DDL is Room's own, character for character")
    func migrationStatementsAreRoomsOwn() throws {
        let v1 = try Self.loadRoomSchema(version: 1)
        let expectedV1 = v1.database.entities.flatMap(\.resolvedCreateStatements)
        #expect(SalusMigrations.v1Statements == expectedV1)

        let v3 = try Self.loadRoomSchema(version: 3)
        let aiSummaries = try #require(v3.database.entities.first { $0.tableName == "ai_summaries" })
        #expect(SalusMigrations.v3Statement == aiSummaries.resolvedCreateStatements[0])
    }

    /// The records exist so every feature finds its table already proven. This is the cheap half
    /// of that promise: the column names a record encodes are exactly the table's columns — no
    /// typo in a `CodingKeys` case, no column a record silently forgets.
    @Test("every record's columns are exactly its table's columns")
    func recordColumnsMatchRoomExport() throws {
        let expected = try Self.loadRoomSchema(version: 3)
        let columnsByTable = Dictionary(
            uniqueKeysWithValues: expected.database.entities.map { entity in
                (entity.tableName, Set(entity.fields.map(\.columnName)))
            }
        )

        // Set equality, not a count: two records pointing at the same table and none at another
        // keeps the counts matching while leaving a table unproven.
        #expect(Set(SampleRecords.all.map(\.tableName)) == Set(columnsByTable.keys))

        for sample in SampleRecords.all {
            let tableColumns = try #require(
                columnsByTable[sample.tableName],
                "record for table \(sample.tableName), which 3.json does not declare"
            )
            let encoded = try sample.encodedColumns()
            #expect(
                encoded == tableColumns,
                "\(sample.tableName): record encodes \(encoded.sorted()), table has \(tableColumns.sorted())"
            )
        }
    }

    /// The expensive half: every record actually round-trips through its real table. Catches what
    /// a name check cannot — a column typed `String` that the schema declares `INTEGER NOT NULL`,
    /// a non-null Swift property over a column that stores NULL, a wrong `databaseTableName`.
    @Test("every record round-trips through its real table")
    func recordsRoundTripThroughTheirTables() throws {
        let database = try SalusDatabase.inMemory(clock: FixedSalusClock(now: Date(timeIntervalSince1970: 0)))
        try database.writer.write { db in
            // The seeded default profile owns the whole graph below, so the foreign keys hold.
            for sample in SampleRecords.all {
                try sample.insertAndReadBack(db)
            }
        }
    }

    // MARK: - Fixture loading

    private static func loadRoomSchema(version: Int) throws -> RoomSchemaExport {
        // Fail loudly: a missing fixture must never read as "nothing to compare".
        let url = try #require(
            Bundle.module.url(forResource: "\(version)", withExtension: "json", subdirectory: "RoomSchemas"),
            "Resources/RoomSchemas/\(version).json is not in the test bundle"
        )
        return try JSONDecoder().decode(RoomSchemaExport.self, from: Data(contentsOf: url))
    }

    // MARK: - Pragmas

    private static func tableNames(_ db: Database) throws -> Set<String> {
        let names = try String.fetchSet(
            db,
            sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
        )
        return names.subtracting(bookkeepingTables)
    }

    private static func checkColumns(_ db: Database, entity: RoomEntity, version: Int) throws {
        // Keyed by name, never by ordinal, and on purpose: `ALTER TABLE … ADD COLUMN` appends
        // `health_notes` to the end of `profiles`, while Room's v2 `createSql` writes it between
        // `height_cm` and `is_default`. Both are the same schema to SQLite — column order is not
        // part of what a table is — and Room's own validator compares a name-keyed map too.
        var actual: [String: ActualColumn] = [:]
        for row in try Row.fetchAll(db, sql: "PRAGMA table_info(\(entity.tableName.quotedDatabaseIdentifier))") {
            actual[row["name"]] = ActualColumn(
                type: row["type"],
                notNull: row["notnull"],
                primaryKeyPosition: row["pk"]
            )
        }

        var wanted: [String: ActualColumn] = [:]
        for field in entity.fields {
            let pkIndex = entity.primaryKey.columnNames.firstIndex(of: field.columnName)
            wanted[field.columnName] = ActualColumn(
                type: field.affinity,
                notNull: field.notNull ?? false,
                primaryKeyPosition: pkIndex.map { $0 + 1 } ?? 0
            )
        }

        #expect(Set(actual.keys) == Set(wanted.keys), "\(entity.tableName) columns differ at v\(version)")
        for (name, expectedColumn) in wanted.sorted(by: { $0.key < $1.key }) {
            #expect(actual[name] == expectedColumn, "\(entity.tableName).\(name) differs at v\(version)")
        }
    }

    private static func checkIndices(_ db: Database, entity: RoomEntity, version: Int) throws {
        var actual: [ActualIndex] = []
        for row in try Row.fetchAll(db, sql: "PRAGMA index_list(\(entity.tableName.quotedDatabaseIdentifier))") {
            let name: String = row["name"]
            // SQLite's own indices behind a PRIMARY KEY / UNIQUE constraint. Room does not
            // declare them and does not export them; they are an artefact of the DDL.
            guard !name.hasPrefix("sqlite_autoindex_") else { continue }
            let columns = try Row
                .fetchAll(db, sql: "PRAGMA index_info(\(name.quotedDatabaseIdentifier))")
                .map { $0["name"] as String }
            actual.append(ActualIndex(name: name, unique: row["unique"], columns: columns))
        }

        let wanted = (entity.indices ?? []).map {
            ActualIndex(name: $0.name, unique: $0.unique, columns: $0.columnNames)
        }
        #expect(actual.sorted() == wanted.sorted(), "\(entity.tableName) indices differ at v\(version)")
    }

    private static func checkForeignKeys(_ db: Database, entity: RoomEntity, version: Int) throws {
        // `foreign_key_list` returns one row per column, grouped by the `id` of the constraint
        // and ordered within it by `seq`; a two-column foreign key is two rows sharing an `id`.
        var grouped: [Int: [Row]] = [:]
        for row in try Row.fetchAll(db, sql: "PRAGMA foreign_key_list(\(entity.tableName.quotedDatabaseIdentifier))") {
            grouped[row["id"], default: []].append(row)
        }
        let actual = grouped.values.map { rows -> ActualForeignKey in
            let ordered = rows.sorted { ($0["seq"] as Int) < ($1["seq"] as Int) }
            return ActualForeignKey(
                table: ordered[0]["table"],
                from: ordered.map { $0["from"] as String },
                to: ordered.map { $0["to"] as String },
                onDelete: ordered[0]["on_delete"]
            )
        }

        let wanted = (entity.foreignKeys ?? []).map {
            ActualForeignKey(table: $0.table, from: $0.columns, to: $0.referencedColumns, onDelete: $0.onDelete)
        }
        #expect(actual.sorted() == wanted.sorted(), "\(entity.tableName) foreign keys differ at v\(version)")
    }
}

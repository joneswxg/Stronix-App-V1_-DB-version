import Foundation
import SQLite

struct DatabaseEnvironment {
    let documentsDirectory: URL
    let databaseFilename: String
    let sourceDatabaseURL: URL?

    var databaseURL: URL {
        documentsDirectory.appendingPathComponent(databaseFilename)
    }

    static func application() -> DatabaseEnvironment {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let sourceDatabaseURL = Bundle.main.url(
            forResource: "database_stronix",
            withExtension: "db"
        )

        return DatabaseEnvironment(
            documentsDirectory: documentsDirectory,
            databaseFilename: "database_stronix.db",
            sourceDatabaseURL: sourceDatabaseURL
        )
    }
}

enum DatabasePreparation: Equatable {
    case initialized
    case alreadyReady
    case rebuilt
}

struct DatabaseMigration {
    let id: String
    let apply: (Connection) throws -> Void
    let validate: (Connection) throws -> Void

    init(
        id: String,
        apply: @escaping (Connection) throws -> Void,
        validate: @escaping (Connection) throws -> Void = { _ in }
    ) {
        self.id = id
        self.apply = apply
        self.validate = validate
    }
}

struct DatabaseMigrationCatalog {
    let migrations: [DatabaseMigration]

    static let production = DatabaseMigrationCatalog(migrations: [
        DatabaseMigration(id: "20260721_0001_baseline") { _ in },
        DatabaseMigration(id: "20260721_0002_protect_schema_ledger") { connection in
            try connection.run(
                """
                CREATE TRIGGER IF NOT EXISTS schema_migrations_prevent_update
                BEFORE UPDATE ON schema_migrations
                BEGIN
                    SELECT RAISE(ABORT, 'schema_migrations is append-only');
                END
                """
            )
            try connection.run(
                """
                CREATE TRIGGER IF NOT EXISTS schema_migrations_prevent_delete
                BEFORE DELETE ON schema_migrations
                BEGIN
                    SELECT RAISE(ABORT, 'schema_migrations is append-only');
                END
                """
            )
        }
    ])
}

struct DatabaseSchemaIncompatibility: Error, Equatable {
    let appliedMigrationIDs: [String]
    let supportedMigrationID: String
}

struct ReadyDatabase {
    let connection: Connection
    let databaseURL: URL
    let preparation: DatabasePreparation
    let appliedMigrationIDs: [String]
    let schemaMigrationID: String
}

enum DatabasePreparationResult: CustomStringConvertible {
    case ready(ReadyDatabase)
    case incompatible(DatabaseSchemaIncompatibility)
    case failed(DatabasePreparationFailure)

    var description: String {
        switch self {
        case .ready(let database):
            return "ready(\(database.databaseURL.path))"
        case .incompatible(let incompatibility):
            return "incompatible(\(incompatibility.supportedMigrationID))"
        case .failed(let failure):
            return "failed(\(failure.message))"
        }
    }
}

struct DatabasePreparationFailure: Error, Equatable {
    let message: String
}

final class DatabaseLifecycle {
    private static let baselineMigrationID = "20260721_0001_baseline"
    private static let requiredTableNames = [
        "schema_migrations",
        "body_part",
        "target_muscle",
        "equipment",
        "action",
        "action_target_muscle_link",
        "user",
        "training_plans",
        "plan_actions",
        "plan_sets",
        "training_sessions",
        "training_plan_executions",
        "execution_actions",
        "execution_sets",
        "training_history",
        "training_history_details",
        "body_measurements",
        "password_reset_codes"
    ]
    private static let expectedSeedCounts = [
        "body_part": 10,
        "target_muscle": 19,
        "equipment": 28,
        "action": 272,
        "action_target_muscle_link": 272
    ]

    private let environment: DatabaseEnvironment
    private let fileManager: FileManager
    private let migrationCatalog: DatabaseMigrationCatalog
    private let preparationQueue: DispatchQueue
    private var readyDatabase: ReadyDatabase?
    private var failure: DatabasePreparationFailure?
    private var incompatibility: DatabaseSchemaIncompatibility?

    init(
        environment: DatabaseEnvironment,
        fileManager: FileManager = .default,
        migrationCatalog: DatabaseMigrationCatalog = .production
    ) {
        self.environment = environment
        self.fileManager = fileManager
        self.migrationCatalog = migrationCatalog
        self.preparationQueue = DispatchQueue(
            label: "database.lifecycle.prepare.\(UUID().uuidString)",
            qos: .userInitiated
        )
    }

    func prepare() -> DatabasePreparationResult {
        preparationQueue.sync {
            prepareLocked()
        }
    }

    func retry() -> DatabasePreparationResult {
        preparationQueue.sync {
            failure = nil
            incompatibility = nil
            return prepareLocked()
        }
    }

    func rebuildFromSource() -> DatabasePreparationResult {
        preparationQueue.sync {
            rebuildFromSourceLocked()
        }
    }

    func readyConnection() -> Connection? {
        preparationQueue.sync {
            readyDatabase?.connection
        }
    }

    private func prepareLocked() -> DatabasePreparationResult {
        if let readyDatabase {
            return .ready(
                ReadyDatabase(
                    connection: readyDatabase.connection,
                    databaseURL: readyDatabase.databaseURL,
                    preparation: .alreadyReady,
                    appliedMigrationIDs: [],
                    schemaMigrationID: readyDatabase.schemaMigrationID
                )
            )
        }

        if let incompatibility {
            return .incompatible(incompatibility)
        }

        if let failure {
            return .failed(failure)
        }

        var preparation: DatabasePreparation?
        do {
            preparation = try prepareDatabaseFile()
            let database = try openReadyDatabase(
                preparation: preparation ?? .alreadyReady
            )
            readyDatabase = database
            return .ready(database)
        } catch let databaseIncompatibility as DatabaseSchemaIncompatibility {
            incompatibility = databaseIncompatibility
            return .incompatible(databaseIncompatibility)
        } catch let preparationFailure as DatabasePreparationFailure {
            if preparation == .initialized {
                removeDatabaseArtifacts(at: environment.databaseURL)
            }
            failure = preparationFailure
            return .failed(preparationFailure)
        } catch {
            if preparation == .initialized {
                removeDatabaseArtifacts(at: environment.databaseURL)
            }
            let preparationFailure = DatabasePreparationFailure(
                message: error.localizedDescription
            )
            failure = preparationFailure
            return .failed(preparationFailure)
        }
    }

    private func rebuildFromSourceLocked() -> DatabasePreparationResult {
        guard readyDatabase == nil else {
            return .failed(
                DatabasePreparationFailure(
                    message: "数据库已在使用中，无法执行整改重建"
                )
            )
        }

        do {
            try fileManager.createDirectory(
                at: environment.documentsDirectory,
                withIntermediateDirectories: true
            )
            let stagingURL = try makeValidatedStagingDatabase()
            defer {
                removeDatabaseArtifacts(at: stagingURL)
            }
            try promoteStagingDatabase(
                at: stagingURL,
                replacingDatabaseAt: environment.databaseURL
            )

            let database = try openReadyDatabase(preparation: .rebuilt)
            failure = nil
            readyDatabase = database
            return .ready(database)
        } catch let rebuildFailure as DatabasePreparationFailure {
            failure = rebuildFailure
            return .failed(rebuildFailure)
        } catch {
            let rebuildFailure = DatabasePreparationFailure(
                message: error.localizedDescription
            )
            failure = rebuildFailure
            return .failed(rebuildFailure)
        }
    }

    private func openReadyDatabase(
        preparation: DatabasePreparation
    ) throws -> ReadyDatabase {
        let connection = try Connection(environment.databaseURL.path)
        try configure(connection)
        let appliedMigrationIDs = try runPendingMigrations(on: connection)
        try validateReadyDatabase(connection)
        return ReadyDatabase(
            connection: connection,
            databaseURL: environment.databaseURL,
            preparation: preparation,
            appliedMigrationIDs: appliedMigrationIDs,
            schemaMigrationID: try targetMigrationID()
        )
    }

    private func configure(_ connection: Connection) throws {
        try connection.execute("PRAGMA foreign_keys = ON")
        try connection.execute("PRAGMA busy_timeout = 5000")
    }

    private func runPendingMigrations(on connection: Connection) throws -> [String] {
        let migrations = try validatedMigrations()
        let completedMigrationIDs = try recordedMigrationIDs(from: connection)
        try validateRecordedMigrationIDs(completedMigrationIDs, against: migrations)

        let pendingMigrations = migrations.dropFirst(completedMigrationIDs.count)
        for migration in pendingMigrations {
            try connection.transaction(.immediate) {
                try migration.apply(connection)
                try migration.validate(connection)
                try validateMigrationState(connection)
                try connection.run(
                    "INSERT INTO schema_migrations (migration_id, applied_at) VALUES (?, datetime('now'))",
                    migration.id
                )
            }
        }
        return pendingMigrations.map(\.id)
    }

    private func validatedMigrations() throws -> [DatabaseMigration] {
        let migrations = migrationCatalog.migrations
        guard migrations.first?.id == Self.baselineMigrationID else {
            throw DatabasePreparationFailure(message: "migration catalog 缺少 baseline")
        }

        let migrationIDs = migrations.map(\.id)
        guard Set(migrationIDs).count == migrationIDs.count else {
            throw DatabasePreparationFailure(message: "migration catalog 包含重复 ID")
        }
        guard migrationIDs == migrationIDs.sorted() else {
            throw DatabasePreparationFailure(message: "migration catalog 顺序无效")
        }
        return migrations
    }

    private func targetMigrationID() throws -> String {
        try validatedMigrations().last!.id
    }

    private func recordedMigrationIDs(from connection: Connection) throws -> [String] {
        var migrationIDs: [String] = []
        for row in try connection.prepare(
            "SELECT migration_id FROM schema_migrations ORDER BY migration_id"
        ) {
            guard let migrationID = row[0] as? String else {
                throw DatabasePreparationFailure(message: "migration ledger 记录无效")
            }
            migrationIDs.append(migrationID)
        }
        return migrationIDs
    }

    private func validateRecordedMigrationIDs(
        _ completedMigrationIDs: [String],
        against migrations: [DatabaseMigration]
    ) throws {
        let supportedMigrationIDs = migrations.map(\.id)
        if completedMigrationIDs.contains(where: { !supportedMigrationIDs.contains($0) }) {
            throw DatabaseSchemaIncompatibility(
                appliedMigrationIDs: completedMigrationIDs,
                supportedMigrationID: supportedMigrationIDs.last!
            )
        }
        guard completedMigrationIDs == Array(supportedMigrationIDs.prefix(completedMigrationIDs.count)) else {
            throw DatabasePreparationFailure(message: "migration ledger 顺序无效")
        }
    }

    private func validateMigrationState(_ connection: Connection) throws {
        let integrityResult = try connection.scalar("PRAGMA integrity_check") as? String
        guard integrityResult == "ok" else {
            throw DatabasePreparationFailure(message: "数据库完整性检查失败")
        }
        guard try rowCount(for: "PRAGMA foreign_key_check", connection: connection) == 0 else {
            throw DatabasePreparationFailure(message: "数据库外键检查失败")
        }
    }

    private func validateReadyDatabase(_ connection: Connection) throws {
        try validateMigrationState(connection)

        for tableName in Self.requiredTableNames {
            guard try tableExists(tableName, connection: connection) else {
                throw DatabasePreparationFailure(
                    message: "数据库缺少必要表: \(tableName)"
                )
            }
        }

        let migrationIDs = try recordedMigrationIDs(from: connection)
        try validateRecordedMigrationIDs(migrationIDs, against: try validatedMigrations())
        guard migrationIDs.count == migrationCatalog.migrations.count else {
            throw DatabasePreparationFailure(message: "数据库 migration 未完成")
        }

        for tableName in Self.expectedSeedCounts.keys.sorted() {
            let expectedCount = Self.expectedSeedCounts[tableName] ?? 0
            let actualCount = try scalarCount(
                "SELECT COUNT(*) FROM \(tableName)",
                connection: connection
            )
            guard actualCount == expectedCount else {
                throw DatabasePreparationFailure(
                    message: "数据库种子校验失败: \(tableName)"
                )
            }
        }
    }

    private func tableExists(
        _ tableName: String,
        connection: Connection
    ) throws -> Bool {
        try scalarCount(
            "SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = ?",
            bindings: [tableName],
            connection: connection
        ) == 1
    }

    private func scalarCount(
        _ query: String,
        bindings: [Binding?] = [],
        connection: Connection
    ) throws -> Int64 {
        let statement = try connection.prepare(query)
        for row in try statement.run(bindings) {
            if let count = row[0] as? Int64 {
                return count
            }
            if let count = row[0] as? Int {
                return Int64(count)
            }
        }
        return 0
    }

    private func rowCount(
        for query: String,
        connection: Connection
    ) throws -> Int {
        var count = 0
        for _ in try connection.prepare(query) {
            count += 1
        }
        return count
    }

    private func prepareDatabaseFile() throws -> DatabasePreparation {
        try fileManager.createDirectory(
            at: environment.documentsDirectory,
            withIntermediateDirectories: true
        )

        guard !fileManager.fileExists(atPath: environment.databaseURL.path) else {
            return .alreadyReady
        }

        let stagingURL = try makeValidatedStagingDatabase()
        defer {
            removeDatabaseArtifacts(at: stagingURL)
        }

        try fileManager.moveItem(at: stagingURL, to: environment.databaseURL)
        return .initialized
    }

    private func makeValidatedStagingDatabase() throws -> URL {
        guard let sourceDatabaseURL = environment.sourceDatabaseURL else {
            throw DatabasePreparationFailure(
                message: "找不到数据库初始化源文件"
            )
        }

        let stagingURL = environment.documentsDirectory.appendingPathComponent(
            ".\(environment.databaseFilename).staging-\(UUID().uuidString)"
        )
        do {
            try fileManager.copyItem(at: sourceDatabaseURL, to: stagingURL)
            try validateDatabase(at: stagingURL)
            return stagingURL
        } catch {
            removeDatabaseArtifacts(at: stagingURL)
            throw error
        }
    }

    private func promoteStagingDatabase(
        at stagingURL: URL,
        replacingDatabaseAt databaseURL: URL
    ) throws {
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            try fileManager.moveItem(at: stagingURL, to: databaseURL)
            return
        }

        let backupName = ".\(environment.databaseFilename).backup-\(UUID().uuidString)"
        try checkpointDatabaseIfNeeded(at: databaseURL)
        try removeSidecars(for: databaseURL)
        _ = try fileManager.replaceItemAt(
            databaseURL,
            withItemAt: stagingURL,
            backupItemName: backupName,
            options: []
        )

        let backupURL = environment.documentsDirectory.appendingPathComponent(backupName)
        do {
            try validateDatabase(at: databaseURL)
            removeDatabaseArtifacts(at: backupURL)
        } catch {
            removeDatabaseArtifacts(at: databaseURL)
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.moveItem(at: backupURL, to: databaseURL)
            }
            throw error
        }
    }

    private func validateDatabase(at databaseURL: URL) throws {
        try withConnection(at: databaseURL) { connection in
            try configure(connection)
            try validateBundledBaseline(connection)
        }
    }

    private func validateBundledBaseline(_ connection: Connection) throws {
        try validateMigrationState(connection)

        for tableName in Self.requiredTableNames {
            guard try tableExists(tableName, connection: connection) else {
                throw DatabasePreparationFailure(
                    message: "数据库缺少必要表: \(tableName)"
                )
            }
        }

        guard try scalarCount(
            "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = ?",
            bindings: [Self.baselineMigrationID],
            connection: connection
        ) == 1 else {
            throw DatabasePreparationFailure(
                message: "数据库缺少 baseline migration 记录"
            )
        }

        for tableName in Self.expectedSeedCounts.keys.sorted() {
            let expectedCount = Self.expectedSeedCounts[tableName] ?? 0
            let actualCount = try scalarCount(
                "SELECT COUNT(*) FROM \(tableName)",
                connection: connection
            )
            guard actualCount == expectedCount else {
                throw DatabasePreparationFailure(
                    message: "数据库种子校验失败: \(tableName)"
                )
            }
        }
    }

    private func checkpointDatabaseIfNeeded(at databaseURL: URL) throws {
        try withConnection(at: databaseURL) { connection in
            let journalMode = try connection.scalar("PRAGMA journal_mode") as? String
            if journalMode?.lowercased() == "wal" {
                try connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
            }
        }
    }

    private func withConnection<T>(
        at databaseURL: URL,
        operation: (Connection) throws -> T
    ) throws -> T {
        var connection: Connection? = try Connection(databaseURL.path)
        defer { connection = nil }
        return try operation(connection!)
    }

    private func removeDatabaseArtifacts(at databaseURL: URL) {
        for url in databaseArtifactURLs(for: databaseURL) {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    private func removeSidecars(for databaseURL: URL) throws {
        for url in databaseArtifactURLs(for: databaseURL).dropFirst() {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            try fileManager.removeItem(at: url)
        }
    }

    private func databaseArtifactURLs(for databaseURL: URL) -> [URL] {
        [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm"),
            URL(fileURLWithPath: databaseURL.path + "-journal")
        ]
    }
}

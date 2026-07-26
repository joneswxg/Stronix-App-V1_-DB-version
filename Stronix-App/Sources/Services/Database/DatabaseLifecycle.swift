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
    case migrated
    case recovered
}

enum DatabaseRecoveryStatus: String, Equatable {
    case notNeeded
    case restored
    case restorationFailed
}

struct DatabaseLifecycleDiagnostic: Equatable {
    let databaseLocation: String?
    let schemaVersion: String?
    let supportedSchemaVersion: String?
    let foreignKeysEnabled: Bool?
    let busyTimeoutMilliseconds: Int?
    let journalMode: String?
    let migrationIDs: [String]
    let appliedMigrationIDs: [String]
    let recoveryStatus: DatabaseRecoveryStatus
    let preparation: DatabasePreparation?

    /// A log-safe operational summary that excludes storage paths and database-derived identifiers.
    var summary: String {
        let fields = [
            foreignKeysEnabled.map { "foreignKeys=\($0)" },
            busyTimeoutMilliseconds.map { "busyTimeoutMs=\($0)" },
            journalMode.map { "journalMode=\($0)" },
            "migrations=\(migrationIDs.count)",
            "appliedMigrations=\(appliedMigrationIDs.count)",
            "recovery=\(recoveryStatus.rawValue)",
            preparation.map { "preparation=\(String(describing: $0))" }
        ]
        return fields.compactMap { $0 }.joined(separator: " ")
    }
}

private struct DatabaseConnectionConfiguration: Equatable {
    let foreignKeysEnabled: Bool
    let busyTimeoutMilliseconds: Int
    let journalMode: String
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

    // Existing entries must remain unchanged; future schema changes append a migration.
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
        },
        DatabaseMigration(
            id: "20260722_0003_split_template_and_user_plans",
            apply: TemplatePlanMigration.apply,
            validate: TemplatePlanMigration.validate
        )
    ])
}

struct DatabaseSchemaIncompatibility: Error, Equatable {
    let appliedMigrationIDs: [String]
    let supportedMigrationID: String
    let databaseLocation: String?

    init(
        appliedMigrationIDs: [String],
        supportedMigrationID: String,
        databaseLocation: String? = nil
    ) {
        self.appliedMigrationIDs = appliedMigrationIDs
        self.supportedMigrationID = supportedMigrationID
        self.databaseLocation = databaseLocation
    }
}

struct ReadyDatabase {
    let connection: Connection
    let databaseURL: URL
    let preparation: DatabasePreparation
    let appliedMigrationIDs: [String]
    let diagnostic: DatabaseLifecycleDiagnostic
}

enum DatabasePreparationResult: CustomStringConvertible {
    case ready(ReadyDatabase)
    case recovered(ReadyDatabase, DatabasePreparationFailure)
    case incompatible(DatabaseSchemaIncompatibility)
    case failed(DatabasePreparationFailure)
    case unrecoverable(DatabaseRecoveryFailure)

    var diagnostic: DatabaseLifecycleDiagnostic {
        switch self {
        case .ready(let database), .recovered(let database, _):
            return database.diagnostic
        case .incompatible(let incompatibility):
            return DatabaseLifecycleDiagnostic(
                databaseLocation: incompatibility.databaseLocation,
                schemaVersion: incompatibility.appliedMigrationIDs.last,
                supportedSchemaVersion: incompatibility.supportedMigrationID,
                foreignKeysEnabled: nil,
                busyTimeoutMilliseconds: nil,
                journalMode: nil,
                migrationIDs: incompatibility.appliedMigrationIDs,
                appliedMigrationIDs: [],
                recoveryStatus: .notNeeded,
                preparation: nil
            )
        case .failed(let failure):
            return failure.diagnostic
        case .unrecoverable(let failure):
            let diagnostic = failure.restorationFailure.diagnostic
            return DatabaseLifecycleDiagnostic(
                databaseLocation: diagnostic.databaseLocation,
                schemaVersion: diagnostic.schemaVersion,
                supportedSchemaVersion: diagnostic.supportedSchemaVersion,
                foreignKeysEnabled: diagnostic.foreignKeysEnabled,
                busyTimeoutMilliseconds: diagnostic.busyTimeoutMilliseconds,
                journalMode: diagnostic.journalMode,
                migrationIDs: diagnostic.migrationIDs,
                appliedMigrationIDs: diagnostic.appliedMigrationIDs,
                recoveryStatus: .restorationFailed,
                preparation: diagnostic.preparation
            )
        }
    }

    var description: String {
        diagnostic.summary
    }
}

struct DatabasePreparationFailure: Error, Equatable {
    let message: String
    let diagnostic: DatabaseLifecycleDiagnostic

    init(
        message: String,
        diagnostic: DatabaseLifecycleDiagnostic = DatabaseLifecycleDiagnostic(
            databaseLocation: nil,
            schemaVersion: nil,
            supportedSchemaVersion: nil,
            foreignKeysEnabled: nil,
            busyTimeoutMilliseconds: nil,
            journalMode: nil,
            migrationIDs: [],
            appliedMigrationIDs: [],
            recoveryStatus: .notNeeded,
            preparation: nil
        )
    ) {
        self.message = message
        self.diagnostic = diagnostic
    }
}

struct DatabaseRecoveryFailure: Error, Equatable {
    let migrationFailure: DatabasePreparationFailure
    let restorationFailure: DatabasePreparationFailure
}

private struct DatabaseRecoverySucceeded: Error {
    let database: ReadyDatabase
    let migrationFailure: DatabasePreparationFailure
}

protocol DatabaseSnapshotStore {
    func createSnapshot(
        from sourceConnection: Connection,
        at snapshotURL: URL
    ) throws

    func restoreSnapshot(
        at snapshotURL: URL,
        replacing databaseURL: URL
    ) throws

    func discardSnapshot(at snapshotURL: URL)
}

final class SQLiteDatabaseSnapshotStore: DatabaseSnapshotStore {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func createSnapshot(
        from sourceConnection: Connection,
        at snapshotURL: URL
    ) throws {
        let snapshotConnection = try Connection(snapshotURL.path)
        let backup = try sourceConnection.backup(usingConnection: snapshotConnection)
        try backup.step(pagesToCopy: .all)
    }

    func restoreSnapshot(
        at snapshotURL: URL,
        replacing databaseURL: URL
    ) throws {
        let stagingURL = databaseURL.deletingLastPathComponent().appendingPathComponent(
            ".\(databaseURL.lastPathComponent).restore-\(UUID().uuidString)"
        )
        defer { removeArtifacts(for: stagingURL) }

        try fileManager.copyItem(at: snapshotURL, to: stagingURL)
        try removeSidecars(for: databaseURL)

        guard fileManager.fileExists(atPath: databaseURL.path) else {
            try fileManager.moveItem(at: stagingURL, to: databaseURL)
            return
        }

        let backupName = ".\(databaseURL.lastPathComponent).restore-backup-\(UUID().uuidString)"
        _ = try fileManager.replaceItemAt(
            databaseURL,
            withItemAt: stagingURL,
            backupItemName: backupName,
            options: []
        )
        removeArtifacts(
            for: databaseURL.deletingLastPathComponent().appendingPathComponent(backupName)
        )
    }

    func discardSnapshot(at snapshotURL: URL) {
        removeArtifacts(for: snapshotURL)
    }

    private func removeSidecars(for databaseURL: URL) throws {
        for url in [
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm"),
            URL(fileURLWithPath: databaseURL.path + "-journal")
        ] where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func removeArtifacts(for databaseURL: URL) {
        for url in [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm"),
            URL(fileURLWithPath: databaseURL.path + "-journal")
        ] where fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
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
        "template_plans",
        "template_plan_actions",
        "template_plan_sets",
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
    private static let requiredIndexNames = [
        "idx_action_bodypart_id",
        "idx_action_equipment_id",
        "idx_action_target_muscle_target",
        "idx_user_account_type",
        "idx_user_external_id",
        "idx_user_wechat_open_id",
        "idx_user_apple_id",
        "idx_template_plans_external_id",
        "idx_template_plan_actions_plan_order",
        "idx_template_plan_sets_plan_action",
        "idx_training_plans_user",
        "idx_training_plans_source_template",
        "idx_plan_actions_plan_order",
        "idx_plan_sets_plan_action",
        "idx_training_sessions_plan_id",
        "idx_training_sessions_user_id",
        "idx_training_plan_executions_plan_id",
        "idx_execution_actions_execution_order",
        "idx_execution_sets_action_set",
        "idx_training_history_user_date",
        "idx_training_history_plan_id",
        "idx_training_history_session_id",
        "idx_training_history_details_history",
        "idx_training_history_details_action",
        "idx_body_measurements_user_timestamp",
        "idx_password_reset_codes_email_created"
    ]
    private static let expectedSeedCounts = [
        "body_part": 10,
        "target_muscle": 19,
        "equipment": 28,
        "action": 272,
        "action_target_muscle_link": 272,
        "template_plans": 2,
        "template_plan_actions": 3,
        "template_plan_sets": 6
    ]

    private let environment: DatabaseEnvironment
    private let fileManager: FileManager
    private let migrationCatalog: DatabaseMigrationCatalog
    private let snapshotStore: DatabaseSnapshotStore
    private let preparationQueue: DispatchQueue
    private var readyDatabase: ReadyDatabase?
    private var failure: DatabasePreparationFailure?
    private var recoveryFailure: DatabaseRecoveryFailure?
    private var recoveredFailure: DatabasePreparationFailure?
    private var incompatibility: DatabaseSchemaIncompatibility?

    init(
        environment: DatabaseEnvironment,
        fileManager: FileManager = .default,
        migrationCatalog: DatabaseMigrationCatalog = .production,
        snapshotStore: DatabaseSnapshotStore? = nil
    ) {
        self.environment = environment
        self.fileManager = fileManager
        self.migrationCatalog = migrationCatalog
        self.snapshotStore = snapshotStore ?? SQLiteDatabaseSnapshotStore(fileManager: fileManager)
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
            guard recoveryFailure == nil else {
                return .unrecoverable(recoveryFailure!)
            }
            readyDatabase = nil
            failure = nil
            recoveredFailure = nil
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
        if let readyDatabase, let recoveredFailure {
            return .recovered(
                ReadyDatabase(
                    connection: readyDatabase.connection,
                    databaseURL: readyDatabase.databaseURL,
                    preparation: .recovered,
                    appliedMigrationIDs: [],
                    diagnostic: makeDiagnostic(
                        connection: readyDatabase.connection,
                        preparation: .recovered,
                        appliedMigrationIDs: [],
                        recoveryStatus: .restored
                    )
                ),
                recoveredFailure
            )
        }

        if let readyDatabase {
            return .ready(
                ReadyDatabase(
                    connection: readyDatabase.connection,
                    databaseURL: readyDatabase.databaseURL,
                    preparation: .alreadyReady,
                    appliedMigrationIDs: [],
                    diagnostic: makeDiagnostic(
                        connection: readyDatabase.connection,
                        preparation: .alreadyReady,
                        appliedMigrationIDs: [],
                        recoveryStatus: .notNeeded
                    )
                )
            )
        }

        if let recoveryFailure {
            return .unrecoverable(recoveryFailure)
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
        } catch let recovery as DatabaseRecoverySucceeded {
            readyDatabase = recovery.database
            recoveredFailure = recovery.migrationFailure
            return .recovered(recovery.database, recovery.migrationFailure)
        } catch let recoveryFailure as DatabaseRecoveryFailure {
            self.recoveryFailure = recoveryFailure
            return .unrecoverable(recoveryFailure)
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
                message: error.localizedDescription,
                diagnostic: unavailableDiagnostic(preparation: preparation)
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
        var connection: Connection? = try Connection(environment.databaseURL.path)
        let configuration = try configure(connection!)

        try validateMigrationState(connection!)
        let migrationPlan = try migrationPlan(for: connection!)
        guard !migrationPlan.pendingMigrations.isEmpty else {
            try validateReadyDatabase(connection!)
            return makeReadyDatabase(
                connection: connection!,
                configuration: configuration,
                preparation: preparation,
                appliedMigrationIDs: []
            )
        }

        let snapshotURL = migrationSnapshotURL()
        do {
            try snapshotStore.createSnapshot(from: connection!, at: snapshotURL)
        } catch {
            connection = nil
            snapshotStore.discardSnapshot(at: snapshotURL)
            throw error
        }

        do {
            let appliedMigrationIDs = try apply(
                migrationPlan.pendingMigrations,
                on: connection!
            )
            try validateReadyDatabase(connection!)
            let database = makeReadyDatabase(
                connection: connection!,
                configuration: configuration,
                preparation: preparation == .alreadyReady ? .migrated : preparation,
                appliedMigrationIDs: appliedMigrationIDs
            )
            snapshotStore.discardSnapshot(at: snapshotURL)
            return database
        } catch {
            let migrationFailure = databasePreparationFailure(from: error)
            connection = nil
            do {
                try snapshotStore.restoreSnapshot(
                    at: snapshotURL,
                    replacing: environment.databaseURL
                )
                let restoredConnection = try Connection(environment.databaseURL.path)
                let restoredConfiguration = try configure(restoredConnection)
                try validateRecoveryDatabase(restoredConnection)
                let database = makeReadyDatabase(
                    connection: restoredConnection,
                    configuration: restoredConfiguration,
                    preparation: .recovered,
                    appliedMigrationIDs: [],
                    recoveryStatus: .restored
                )
                snapshotStore.discardSnapshot(at: snapshotURL)
                throw DatabaseRecoverySucceeded(
                    database: database,
                    migrationFailure: migrationFailure
                )
            } catch let recovery as DatabaseRecoverySucceeded {
                throw recovery
            } catch {
                throw DatabaseRecoveryFailure(
                    migrationFailure: migrationFailure,
                    restorationFailure: databasePreparationFailure(from: error)
                )
            }
        }
    }

    private func makeReadyDatabase(
        connection: Connection,
        configuration: DatabaseConnectionConfiguration,
        preparation: DatabasePreparation,
        appliedMigrationIDs: [String],
        recoveryStatus: DatabaseRecoveryStatus = .notNeeded
    ) -> ReadyDatabase {
        ReadyDatabase(
            connection: connection,
            databaseURL: environment.databaseURL,
            preparation: preparation,
            appliedMigrationIDs: appliedMigrationIDs,
            diagnostic: makeDiagnostic(
                connection: connection,
                configuration: configuration,
                preparation: preparation,
                appliedMigrationIDs: appliedMigrationIDs,
                recoveryStatus: recoveryStatus
            )
        )
    }

    private func makeDiagnostic(
        connection: Connection,
        configuration: DatabaseConnectionConfiguration? = nil,
        preparation: DatabasePreparation,
        appliedMigrationIDs: [String],
        recoveryStatus: DatabaseRecoveryStatus
    ) -> DatabaseLifecycleDiagnostic {
        let observedConfiguration = configuration ?? (try? readAndValidateConfiguration(from: connection))
        return DatabaseLifecycleDiagnostic(
            databaseLocation: environment.databaseURL.path,
            schemaVersion: (try? recordedMigrationIDs(from: connection))?.last,
            supportedSchemaVersion: migrationCatalog.migrations.last?.id,
            foreignKeysEnabled: observedConfiguration?.foreignKeysEnabled,
            busyTimeoutMilliseconds: observedConfiguration?.busyTimeoutMilliseconds,
            journalMode: observedConfiguration?.journalMode,
            migrationIDs: (try? recordedMigrationIDs(from: connection)) ?? [],
            appliedMigrationIDs: appliedMigrationIDs,
            recoveryStatus: recoveryStatus,
            preparation: preparation
        )
    }

    private func unavailableDiagnostic(
        preparation: DatabasePreparation? = nil
    ) -> DatabaseLifecycleDiagnostic {
        DatabaseLifecycleDiagnostic(
            databaseLocation: environment.databaseURL.path,
            schemaVersion: nil,
            supportedSchemaVersion: migrationCatalog.migrations.last?.id,
            foreignKeysEnabled: nil,
            busyTimeoutMilliseconds: nil,
            journalMode: nil,
            migrationIDs: [],
            appliedMigrationIDs: [],
            recoveryStatus: .notNeeded,
            preparation: preparation
        )
    }

    private func migrationPlan(for connection: Connection) throws -> (
        migrations: [DatabaseMigration],
        pendingMigrations: [DatabaseMigration]
    ) {
        let migrations = try validatedMigrations()
        let completedMigrationIDs = try recordedMigrationIDs(from: connection)
        guard completedMigrationIDs.first == Self.baselineMigrationID else {
            throw DatabasePreparationFailure(message: "数据库缺少 baseline migration 记录")
        }
        try validateRecordedMigrationIDs(completedMigrationIDs, against: migrations)
        return (
            migrations,
            Array(migrations.dropFirst(completedMigrationIDs.count))
        )
    }

    private func apply(
        _ pendingMigrations: [DatabaseMigration],
        on connection: Connection
    ) throws -> [String] {
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

    private func validateExistingDatabaseBeforeMigration(_ connection: Connection) throws {
        try validateMigrationState(connection)

        let appliedMigrationIDs = try recordedMigrationIDs(from: connection)
        let hasSplitPlanMigration = appliedMigrationIDs.contains(
            "20260722_0003_split_template_and_user_plans"
        )
        let requiredTables = hasSplitPlanMigration
            ? Self.requiredTableNames
            : Self.requiredTableNames.filter {
                !["template_plans", "template_plan_actions", "template_plan_sets"].contains($0)
            }
        let requiredIndexes = hasSplitPlanMigration
            ? Self.requiredIndexNames
            : Self.requiredIndexNames.filter {
                ![
                    "idx_template_plans_external_id",
                    "idx_template_plan_actions_plan_order",
                    "idx_template_plan_sets_plan_action",
                    "idx_training_plans_user",
                    "idx_training_plans_source_template"
                ].contains($0)
            }

        for tableName in requiredTables {
            guard try tableExists(tableName, connection: connection) else {
                throw DatabasePreparationFailure(
                    message: "数据库缺少必要表: \(tableName)"
                )
            }
        }

        for indexName in requiredIndexes {
            guard try indexExists(indexName, connection: connection) else {
                throw DatabasePreparationFailure(
                    message: "数据库缺少必要索引: \(indexName)"
                )
            }
        }
    }

    private func validateRecoveryDatabase(_ connection: Connection) throws {
        try validateExistingDatabaseBeforeMigration(connection)
        let plan = try migrationPlan(for: connection)
        if plan.pendingMigrations.isEmpty {
            try validateExpectedSeedCounts(connection)
        }
    }

    private func validateExpectedSeedCounts(_ connection: Connection) throws {
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

    private func migrationSnapshotURL() -> URL {
        environment.documentsDirectory.appendingPathComponent(
            ".\(environment.databaseFilename).migration-backup-\(UUID().uuidString)"
        )
    }

    private func databasePreparationFailure(from error: Error) -> DatabasePreparationFailure {
        if let failure = error as? DatabasePreparationFailure {
            return failure
        }
        return DatabasePreparationFailure(
            message: error.localizedDescription,
            diagnostic: unavailableDiagnostic()
        )
    }

    @discardableResult
    private func configure(_ connection: Connection) throws -> DatabaseConnectionConfiguration {
        try connection.execute("PRAGMA foreign_keys = ON")
        try connection.execute("PRAGMA busy_timeout = 5000")
        try connection.execute("PRAGMA journal_mode = WAL")
        return try readAndValidateConfiguration(from: connection)
    }

    private func readAndValidateConfiguration(
        from connection: Connection
    ) throws -> DatabaseConnectionConfiguration {
        let foreignKeysEnabled = (try connection.scalar("PRAGMA foreign_keys") as? Int64) == 1
        let timeoutValue = try connection.scalar("PRAGMA busy_timeout") as? Int64
        let busyTimeoutMilliseconds = Int(timeoutValue ?? 0)
        let journalMode = (try connection.scalar("PRAGMA journal_mode") as? String)?.lowercased() ?? ""
        let configuration = DatabaseConnectionConfiguration(
            foreignKeysEnabled: foreignKeysEnabled,
            busyTimeoutMilliseconds: busyTimeoutMilliseconds,
            journalMode: journalMode
        )
        guard configuration.foreignKeysEnabled,
              configuration.busyTimeoutMilliseconds == 5000,
              configuration.journalMode == "wal" else {
            throw DatabasePreparationFailure(
                message: "数据库连接配置校验失败",
                diagnostic: unavailableDiagnostic()
            )
        }
        return configuration
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
                supportedMigrationID: supportedMigrationIDs.last!,
                databaseLocation: environment.databaseURL.path
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

        for indexName in Self.requiredIndexNames {
            guard try indexExists(indexName, connection: connection) else {
                throw DatabasePreparationFailure(
                    message: "数据库缺少必要索引: \(indexName)"
                )
            }
        }

        let migrationIDs = try recordedMigrationIDs(from: connection)
        try validateRecordedMigrationIDs(migrationIDs, against: try validatedMigrations())
        guard migrationIDs.count == migrationCatalog.migrations.count else {
            throw DatabasePreparationFailure(message: "数据库 migration 未完成")
        }

        try validateExpectedSeedCounts(connection)
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

    private func indexExists(
        _ indexName: String,
        connection: Connection
    ) throws -> Bool {
        try scalarCount(
            "SELECT COUNT(*) FROM sqlite_schema WHERE type = 'index' AND name = ?",
            bindings: [indexName],
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

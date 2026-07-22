import XCTest
import SQLite
@testable import Stronix

final class DatabaseLifecycleTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
    }

    func testBundledBaselineInitializesWithCleanSchemaAndDeterministicSeeds() throws {
        let sourceDatabaseURL = try XCTUnwrap(
            DatabaseEnvironment.application().sourceDatabaseURL,
            "Expected the generated baseline database in the app bundle"
        )
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: temporaryRoot.appendingPathComponent(
                    "Documents",
                    isDirectory: true
                ),
                databaseFilename: "baseline.db",
                sourceDatabaseURL: sourceDatabaseURL
            )
        )

        guard case .ready(let readyDatabase) = lifecycle.prepare() else {
            return XCTFail("Expected the bundled baseline to initialize successfully")
        }

        XCTAssertEqual(readyDatabase.preparation, .initialized)
        XCTAssertEqual(
            readyDatabase.appliedMigrationIDs,
            ["20260721_0002_protect_schema_ledger"]
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar("PRAGMA integrity_check") as? String,
            "ok"
        )
        XCTAssertEqual(try rowCount("PRAGMA foreign_key_check", in: readyDatabase.connection), 0)
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = '20260721_0001_baseline'"
            ) as? Int64,
            1
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = '20260721_0002_protect_schema_ledger'"
            ) as? Int64,
            1
        )

        let expectedSeedCounts: [(String, Int64)] = [
            ("body_part", 10),
            ("target_muscle", 19),
            ("equipment", 28),
            ("action", 272),
            ("action_target_muscle_link", 272)
        ]
        for (table, expectedCount) in expectedSeedCounts {
            XCTAssertEqual(
                try readyDatabase.connection.scalar("SELECT COUNT(*) FROM \(table)") as? Int64,
                expectedCount,
                "Unexpected seed count for \(table)"
            )
        }

        for table in [
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
        ] {
            XCTAssertEqual(
                try readyDatabase.connection.scalar("SELECT COUNT(*) FROM \(table)") as? Int64,
                0,
                "Expected \(table) to start empty"
            )
        }
    }

    func testBundledBaselineLedgerRejectsMutation() throws {
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: temporaryRoot.appendingPathComponent(
                    "Documents",
                    isDirectory: true
                ),
                databaseFilename: "baseline.db",
                sourceDatabaseURL: try bundledBaselineURL()
            )
        )

        guard case .ready(let readyDatabase) = lifecycle.prepare() else {
            return XCTFail("Expected the baseline database to be ready")
        }

        XCTAssertThrowsError(
            try readyDatabase.connection.run(
                "UPDATE schema_migrations SET applied_at = 'changed' WHERE migration_id = '20260721_0001_baseline'"
            )
        )
        XCTAssertThrowsError(
            try readyDatabase.connection.run(
                "DELETE FROM schema_migrations WHERE migration_id = '20260721_0001_baseline'"
            )
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = '20260721_0001_baseline'"
            ) as? Int64,
            1
        )
    }

    func testFreshInstallAndExplicitRebuildProduceSameBaselineState() throws {
        let sourceDatabaseURL = try bundledBaselineURL()
        let freshLifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: temporaryRoot.appendingPathComponent(
                    "FreshDocuments",
                    isDirectory: true
                ),
                databaseFilename: "baseline.db",
                sourceDatabaseURL: sourceDatabaseURL
            )
        )
        guard case .ready(let freshDatabase) = freshLifecycle.prepare() else {
            return XCTFail("Expected fresh initialization to succeed")
        }

        let rebuildDocumentsURL = temporaryRoot.appendingPathComponent(
            "RebuildDocuments",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: rebuildDocumentsURL,
            withIntermediateDirectories: true
        )
        let rebuildDatabaseURL = rebuildDocumentsURL.appendingPathComponent("baseline.db")
        let dirtyConnection = try makeBaselineConnectionWithFixtureTable(at: rebuildDatabaseURL)
        try insertRepresentativeBusinessRows(in: dirtyConnection)

        let rebuildLifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: rebuildDocumentsURL,
                databaseFilename: "baseline.db",
                sourceDatabaseURL: sourceDatabaseURL
            )
        )
        guard case .ready(let rebuiltDatabase) = rebuildLifecycle.rebuildFromSource() else {
            return XCTFail("Expected explicit remediation rebuild to succeed")
        }

        XCTAssertEqual(rebuiltDatabase.preparation, .rebuilt)
        XCTAssertEqual(
            try baselineFingerprint(in: rebuiltDatabase.connection),
            try baselineFingerprint(in: freshDatabase.connection)
        )
    }

    func testReadyBaselineSupportsCurrentAuthenticationAndActionQueries() throws {
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: temporaryRoot.appendingPathComponent(
                    "Documents",
                    isDirectory: true
                ),
                databaseFilename: "baseline.db",
                sourceDatabaseURL: try bundledBaselineURL()
            )
        )
        guard case .ready(let readyDatabase) = lifecycle.prepare() else {
            return XCTFail("Expected the baseline database to be ready")
        }

        try readyDatabase.connection.run(
            """
            INSERT INTO user (
                username, email, password_hash, gender, height, weight,
                role, is_admin, created_at, account_type, external_id
            ) VALUES (
                'baseline-user', 'baseline@example.com', 'test-hash', 'male',
                175, 70, 'regular', 0, '2026-07-21T00:00:00Z', 'email', NULL
            )
            """
        )
        let loginRowCount = try readyDatabase.connection.scalar(
            """
            SELECT COUNT(*)
            FROM user
            WHERE email = 'baseline@example.com'
              AND username = 'baseline-user'
              AND password_hash = 'test-hash'
            """
        ) as? Int64
        XCTAssertEqual(loginRowCount, 1)
        XCTAssertThrowsError(
            try readyDatabase.connection.run(
                """
                INSERT INTO user (username, email, created_at)
                VALUES ('other-user', 'baseline@example.com', '2026-07-21T00:00:00Z')
                """
            )
        )

        let browseQuery = """
            SELECT a.id, a.external_id, a.name, b.display_name, e.display_name,
                   GROUP_CONCAT(l.target_muscle_id)
            FROM action a
            JOIN body_part b ON b.id = a.bodypart_id
            LEFT JOIN equipment e ON e.id = a.equipment_id
            JOIN action_target_muscle_link l ON l.action_id = a.id
            GROUP BY a.id
            ORDER BY a.id
        """
        var browsableActionCount = 0
        for row in try readyDatabase.connection.prepare(browseQuery) {
            XCTAssertNotNil(row[0])
            XCTAssertNotNil(row[1])
            XCTAssertNotNil(row[2])
            XCTAssertNotNil(row[3])
            XCTAssertNotNil(row[5])
            browsableActionCount += 1
        }
        XCTAssertEqual(browsableActionCount, 272)
    }

    func testPrepareReturnsReadyConnectionThatSupportsReadAndWrite() throws {
        let sourceDatabaseURL = try makeSourceDatabase()

        let isolatedDocumentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: isolatedDocumentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: sourceDatabaseURL
            )
        )

        let result = lifecycle.prepare()
        guard case .ready(let readyDatabase) = result else {
            return XCTFail("Expected a ready database, received \(result)")
        }

        XCTAssertEqual(readyDatabase.preparation, .initialized)
        XCTAssertEqual(
            readyDatabase.databaseURL.standardizedFileURL,
            isolatedDocumentsURL.appendingPathComponent("fixture.db").standardizedFileURL
        )

        try readyDatabase.connection.run(
            "INSERT INTO fixture_values (id, value) VALUES (1, 'ready')"
        )
        let storedValue = try readyDatabase.connection.scalar(
            "SELECT value FROM fixture_values WHERE id = 1"
        ) as? String

        XCTAssertEqual(storedValue, "ready")
        XCTAssertEqual(
            try readyDatabase.connection.scalar("PRAGMA foreign_keys") as? Int64,
            1
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar("PRAGMA busy_timeout") as? Int64,
            5000
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar("PRAGMA journal_mode") as? String,
            "wal"
        )
    }

    func testPrepareMigratesBaselineDatabaseAndPreservesSyntheticUserData() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let existingConnection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try insertRepresentativeBusinessRows(in: existingConnection)

        let migrationID = "20260722_0001_fixture_upgrade"
        let catalog = DatabaseMigrationCatalog(migrations: [
            DatabaseMigration(id: "20260721_0001_baseline") { _ in },
            DatabaseMigration(id: migrationID) { connection in
                try connection.run(
                    "CREATE TABLE migration_fixture (id INTEGER PRIMARY KEY, value TEXT NOT NULL)"
                )
                try connection.run(
                    "INSERT INTO migration_fixture (id, value) VALUES (1, 'upgraded')"
                )
            }
        ])
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: try bundledBaselineURL()
            ),
            migrationCatalog: catalog
        )

        guard case .ready(let readyDatabase) = lifecycle.prepare() else {
            return XCTFail("Expected the baseline database to upgrade successfully")
        }

        XCTAssertEqual(readyDatabase.appliedMigrationIDs, [migrationID])
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT value FROM migration_fixture WHERE id = 1"
            ) as? String,
            "upgraded"
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = ?",
                migrationID
            ) as? Int64,
            1
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT username FROM user WHERE id = 9001"
            ) as? String,
            "legacy-user"
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT name FROM training_plans WHERE id = 9001"
            ) as? String,
            "Legacy Plan"
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT plan_name FROM training_history WHERE id = 9001"
            ) as? String,
            "Legacy Plan"
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT weight_kg FROM body_measurements WHERE id = 9001"
            ) as? Double,
            70
        )
    }

    func testPrepareDoesNotReplayAppliedMigrationAfterRestart() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        _ = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        let catalog = fixtureMigrationCatalog { connection in
            try connection.run(
                "CREATE TABLE migration_fixture (id INTEGER PRIMARY KEY, value TEXT NOT NULL)"
            )
            try connection.run(
                "INSERT INTO migration_fixture (id, value) VALUES (1, 'upgraded')"
            )
        }

        let firstLifecycle = try makeLifecycle(
            documentsURL: documentsURL,
            catalog: catalog
        )
        guard case .ready(let firstDatabase) = firstLifecycle.prepare() else {
            return XCTFail("Expected the first preparation to apply the migration")
        }
        XCTAssertEqual(firstDatabase.appliedMigrationIDs, [fixtureMigrationID])

        let restartedLifecycle = try makeLifecycle(
            documentsURL: documentsURL,
            catalog: catalog
        )
        guard case .ready(let restartedDatabase) = restartedLifecycle.prepare() else {
            return XCTFail("Expected the upgraded database to be ready after restart")
        }

        XCTAssertEqual(restartedDatabase.appliedMigrationIDs, [])
        XCTAssertEqual(
            try restartedDatabase.connection.scalar(
                "SELECT COUNT(*) FROM migration_fixture"
            ) as? Int64,
            1
        )
        XCTAssertEqual(
            try restartedDatabase.connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = ?",
                fixtureMigrationID
            ) as? Int64,
            1
        )
    }

    func testPrepareRollsBackFailedMigrationAndDoesNotRecordIt() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        _ = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        let catalog = fixtureMigrationCatalog { connection in
            try connection.run(
                "CREATE TABLE failed_migration_fixture (id INTEGER PRIMARY KEY)"
            )
            throw DatabasePreparationFailure(message: "injected migration failure")
        }
        let lifecycle = try makeLifecycle(documentsURL: documentsURL, catalog: catalog)

        guard case .recovered = lifecycle.prepare() else {
            return XCTFail("Expected the failing migration to restore the existing database")
        }

        XCTAssertNotNil(lifecycle.readyConnection())
        let connection = try Connection(databaseURL.path)
        XCTAssertEqual(
            try connection.scalar(
                "SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = 'failed_migration_fixture'"
            ) as? Int64,
            0
        )
        XCTAssertEqual(
            try connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = ?",
                fixtureMigrationID
            ) as? Int64,
            0
        )
    }

    func testPrepareRollsBackMigrationThatFailsValidation() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        _ = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        let catalog = DatabaseMigrationCatalog(migrations: [
            DatabaseMigration(id: "20260721_0001_baseline") { _ in },
            DatabaseMigration(
                id: fixtureMigrationID,
                apply: { connection in
                    try connection.run(
                        "CREATE TABLE validation_failure_fixture (id INTEGER PRIMARY KEY)"
                    )
                },
                validate: { _ in
                    throw DatabasePreparationFailure(message: "injected validation failure")
                }
            )
        ])
        let lifecycle = try makeLifecycle(documentsURL: documentsURL, catalog: catalog)

        guard case .recovered(let recoveredDatabase, _) = lifecycle.prepare() else {
            return XCTFail("Expected a failed migration validation to restore the existing database")
        }

        XCTAssertNotNil(lifecycle.readyConnection())
        XCTAssertEqual(
            try recoveredDatabase.connection.scalar(
                "SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = 'validation_failure_fixture'"
            ) as? Int64,
            0
        )
        XCTAssertEqual(
            try recoveredDatabase.connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = ?",
                fixtureMigrationID
            ) as? Int64,
            0
        )
    }

    func testPrepareRunsMultiplePendingMigrationsInCatalogOrder() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        _ = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        let firstMigrationID = "20260722_0001_create_order_fixture"
        let secondMigrationID = "20260722_0002_populate_order_fixture"
        let catalog = DatabaseMigrationCatalog(migrations: [
            DatabaseMigration(id: "20260721_0001_baseline") { _ in },
            DatabaseMigration(id: firstMigrationID) { connection in
                try connection.run(
                    "CREATE TABLE migration_order_fixture (step INTEGER PRIMARY KEY, value TEXT NOT NULL)"
                )
                try connection.run(
                    "INSERT INTO migration_order_fixture (step, value) VALUES (1, 'created')"
                )
            },
            DatabaseMigration(id: secondMigrationID) { connection in
                try connection.run(
                    "INSERT INTO migration_order_fixture (step, value) VALUES (2, 'populated')"
                )
            }
        ])
        let lifecycle = try makeLifecycle(documentsURL: documentsURL, catalog: catalog)

        guard case .ready(let readyDatabase) = lifecycle.prepare() else {
            return XCTFail("Expected pending migrations to complete in order")
        }

        XCTAssertEqual(
            readyDatabase.appliedMigrationIDs,
            [firstMigrationID, secondMigrationID]
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT GROUP_CONCAT(value, '|') FROM (SELECT value FROM migration_order_fixture ORDER BY step)"
            ) as? String,
            "created|populated"
        )
    }

    func testMissingBaselineLedgerPreventsMigrationExecution() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let connection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try connection.run("DROP TRIGGER schema_migrations_prevent_update")
        try connection.run("DROP TRIGGER schema_migrations_prevent_delete")
        try connection.run(
            "DELETE FROM schema_migrations WHERE migration_id = '20260721_0001_baseline'"
        )
        let catalog = fixtureMigrationCatalog { connection in
            try connection.run(
                "INSERT INTO fixture_values (id, value) VALUES (2, 'must-not-run')"
            )
        }
        let lifecycle = try makeLifecycle(documentsURL: documentsURL, catalog: catalog)

        guard case .failed = lifecycle.prepare() else {
            return XCTFail("Expected a missing baseline ledger record to fail")
        }

        XCTAssertNil(lifecycle.readyConnection())
        XCTAssertEqual(
            try connection.scalar(
                "SELECT COUNT(*) FROM fixture_values WHERE id = 2"
            ) as? Int64,
            0
        )
    }

    func testPrepareRejectsInvalidMigrationCatalogBeforeChangingDatabase() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let connection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try connection.run(
            "INSERT INTO fixture_values (id, value) VALUES (1, 'preserve-me')"
        )
        let catalog = DatabaseMigrationCatalog(migrations: [
            DatabaseMigration(id: "20260721_0001_baseline") { _ in },
            DatabaseMigration(id: "20260722_0002_later") { _ in },
            DatabaseMigration(id: "20260722_0001_earlier") { _ in }
        ])
        let lifecycle = try makeLifecycle(documentsURL: documentsURL, catalog: catalog)

        guard case .failed = lifecycle.prepare() else {
            return XCTFail("Expected an unordered migration catalog to fail")
        }

        XCTAssertNil(lifecycle.readyConnection())
        XCTAssertEqual(
            try connection.scalar(
                "SELECT value FROM fixture_values WHERE id = 1"
            ) as? String,
            "preserve-me"
        )
        XCTAssertEqual(
            try connection.scalar("SELECT COUNT(*) FROM schema_migrations") as? Int64,
            1
        )
    }

    func testPrepareRejectsGappedKnownMigrationLedger() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let connection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        let firstMigrationID = "20260722_0001_first_fixture"
        let secondMigrationID = "20260722_0002_second_fixture"
        try connection.run(
            "INSERT INTO schema_migrations (migration_id, applied_at) VALUES (?, datetime('now'))",
            secondMigrationID
        )
        let catalog = DatabaseMigrationCatalog(migrations: [
            DatabaseMigration(id: "20260721_0001_baseline") { _ in },
            DatabaseMigration(id: firstMigrationID) { _ in
                XCTFail("A gapped migration must not be applied")
            },
            DatabaseMigration(id: secondMigrationID) { _ in }
        ])
        let lifecycle = try makeLifecycle(documentsURL: documentsURL, catalog: catalog)

        guard case .failed = lifecycle.prepare() else {
            return XCTFail("Expected a gapped migration ledger to fail")
        }

        XCTAssertNil(lifecycle.readyConnection())
        XCTAssertEqual(
            try connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = ?",
                firstMigrationID
            ) as? Int64,
            0
        )
    }

    func testPrepareRejectsNewerSchemaWithoutModifyingDatabase() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let connection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try connection.run(
            "INSERT INTO fixture_values (id, value) VALUES (1, 'preserve-me')"
        )
        try connection.run(
            "INSERT INTO schema_migrations (migration_id, applied_at) VALUES (?, datetime('now'))",
            "20260723_0001_future_schema"
        )
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: try bundledBaselineURL()
            )
        )

        guard case .incompatible(let incompatibility) = lifecycle.prepare() else {
            return XCTFail("Expected a newer schema to be reported as incompatible")
        }

        XCTAssertEqual(
            incompatibility.supportedMigrationID,
            "20260721_0002_protect_schema_ledger"
        )
        XCTAssertNil(lifecycle.readyConnection())
        XCTAssertEqual(
            try connection.scalar(
                "SELECT value FROM fixture_values WHERE id = 1"
            ) as? String,
            "preserve-me"
        )
        XCTAssertEqual(
            try connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = '20260723_0001_future_schema'"
            ) as? Int64,
            1
        )
    }

    func testMissingRequiredIndexPreventsDatabaseReadiness() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let connection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try connection.run("DROP INDEX idx_training_history_user_date")
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: try bundledBaselineURL()
            )
        )

        guard case .unrecoverable = lifecycle.prepare() else {
            return XCTFail("Expected a missing required index to prevent readiness")
        }

        XCTAssertNil(lifecycle.readyConnection())
    }

    func testPreparePreservesExistingDocumentsDatabase() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let existingConnection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try existingConnection.run(
            "INSERT INTO fixture_values (id, value) VALUES (1, 'keep-me')"
        )

        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: try makeSourceDatabase()
            )
        )

        guard case .ready(let readyDatabase) = lifecycle.prepare() else {
            return XCTFail("Expected the existing database to be ready")
        }

        XCTAssertEqual(readyDatabase.preparation, .migrated)
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT value FROM fixture_values WHERE id = 1"
            ) as? String,
            "keep-me"
        )
    }

    func testForeignKeyViolationsPreventDatabaseReadiness() throws {
        let sourceDatabaseURL = temporaryRoot.appendingPathComponent("invalid-foreign-key.db")
        let sourceConnection = try Connection(sourceDatabaseURL.path)
        try sourceConnection.execute("PRAGMA foreign_keys = OFF")
        try sourceConnection.run(
            "CREATE TABLE parents (id INTEGER PRIMARY KEY)"
        )
        try sourceConnection.run(
            "CREATE TABLE children (id INTEGER PRIMARY KEY, parent_id INTEGER NOT NULL REFERENCES parents(id))"
        )
        try sourceConnection.run(
            "INSERT INTO children (id, parent_id) VALUES (1, 999)"
        )
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: sourceDatabaseURL
            )
        )

        guard case .failed = lifecycle.prepare() else {
            return XCTFail("Expected a foreign-key-invalid source to fail readiness")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: databaseURL.path))
        XCTAssertNil(lifecycle.readyConnection())
    }

    func testInvalidSourceDoesNotLeavePartiallyInitializedDatabase() throws {
        let sourceDatabaseURL = temporaryRoot.appendingPathComponent("invalid-source.db")
        try Data("not a sqlite database".utf8).write(to: sourceDatabaseURL)
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: sourceDatabaseURL
            )
        )

        guard case .failed = lifecycle.prepare() else {
            return XCTFail("Expected invalid source preparation to fail")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: databaseURL.path))
        XCTAssertNil(lifecycle.readyConnection())
    }

    func testExplicitRebuildClearsExistingDataAndReinitializes() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let existingConnection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try existingConnection.run(
            "INSERT INTO fixture_values (id, value) VALUES (1, 'old-marker')"
        )
        let sourceDatabaseURL = try makeSourceDatabase()
        do {
            let sourceConnection = try Connection(sourceDatabaseURL.path)
            try sourceConnection.run(
                "INSERT INTO fixture_values (id, value) VALUES (2, 'clean-seed')"
            )
        }
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: sourceDatabaseURL
            )
        )

        guard case .ready(let readyDatabase) = lifecycle.rebuildFromSource() else {
            return XCTFail("Expected explicit rebuild to produce a ready database")
        }

        XCTAssertEqual(readyDatabase.preparation, .rebuilt)
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT COUNT(*) FROM fixture_values WHERE value = 'old-marker'"
            ) as? Int64,
            0
        )
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT value FROM fixture_values WHERE id = 2"
            ) as? String,
            "clean-seed"
        )
    }

    func testFailedExplicitRebuildPreservesExistingDatabase() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        do {
            let existingConnection = try Connection(databaseURL.path)
            try createFixtureTable(in: existingConnection)
            try existingConnection.run(
                "INSERT INTO fixture_values (id, value) VALUES (1, 'keep-marker')"
            )
        }
        let invalidSourceURL = temporaryRoot.appendingPathComponent("invalid-rebuild.db")
        try Data("not a sqlite database".utf8).write(to: invalidSourceURL)
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: invalidSourceURL
            )
        )

        guard case .failed = lifecycle.rebuildFromSource() else {
            return XCTFail("Expected explicit rebuild to fail")
        }

        let preservedConnection = try Connection(databaseURL.path)
        XCTAssertEqual(
            try preservedConnection.scalar(
                "SELECT value FROM fixture_values WHERE id = 1"
            ) as? String,
            "keep-marker"
        )
        XCTAssertNil(lifecycle.readyConnection())
    }

    func testStartupPreparationUsesNonDestructivePathByDefault() throws {
        let sourceDatabaseURL = try makeSourceDatabase()
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let connection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try connection.run(
            "INSERT INTO fixture_values (id, value) VALUES (1, 'startup-marker')"
        )
        let manager = DatabaseManager(
            lifecycle: DatabaseLifecycle(
                environment: DatabaseEnvironment(
                    documentsDirectory: documentsURL,
                    databaseFilename: "fixture.db",
                    sourceDatabaseURL: sourceDatabaseURL
                )
            )
        )

        guard case .ready(let readyDatabase) = manager.prepareForStartup(arguments: []) else {
            return XCTFail("Expected ordinary startup preparation to succeed")
        }

        XCTAssertEqual(readyDatabase.preparation, .migrated)
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT value FROM fixture_values WHERE id = 1"
            ) as? String,
            "startup-marker"
        )
    }

#if DEBUG
    func testStartupPreparationRequiresExplicitDebugArgumentForRemediation() throws {
        let sourceDatabaseURL = try makeSourceDatabase()
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let connection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try connection.run(
            "INSERT INTO fixture_values (id, value) VALUES (1, 'old-marker')"
        )
        let manager = DatabaseManager(
            lifecycle: DatabaseLifecycle(
                environment: DatabaseEnvironment(
                    documentsDirectory: documentsURL,
                    databaseFilename: "fixture.db",
                    sourceDatabaseURL: sourceDatabaseURL
                )
            )
        )

        guard case .ready(let readyDatabase) = manager.prepareForStartup(
            arguments: ["-StronixRebuildLocalDatabase"]
        ) else {
            return XCTFail("Expected explicit DEBUG remediation to succeed")
        }

        XCTAssertEqual(readyDatabase.preparation, .rebuilt)
        XCTAssertEqual(
            try readyDatabase.connection.scalar(
                "SELECT COUNT(*) FROM fixture_values WHERE value = 'old-marker'"
            ) as? Int64,
            0
        )
    }
#endif

    func testConcurrentPreparationInitializesDatabaseOnce() throws {
        let sourceDatabaseURL = try makeSourceDatabase()

        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: temporaryRoot.appendingPathComponent(
                    "Documents",
                    isDirectory: true
                ),
                databaseFilename: "fixture.db",
                sourceDatabaseURL: sourceDatabaseURL
            )
        )
        let resultLock = NSLock()
        var preparations: [DatabasePreparation] = []

        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            guard case .ready(let readyDatabase) = lifecycle.prepare() else {
                return
            }
            resultLock.lock()
            preparations.append(readyDatabase.preparation)
            resultLock.unlock()
        }

        XCTAssertEqual(preparations.count, 8)
        XCTAssertEqual(preparations.filter { $0 == .initialized }.count, 1)
        XCTAssertEqual(preparations.filter { $0 == .alreadyReady }.count, 7)
    }

    func testFailedExplicitRebuildPreservesCommittedWalData() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        var existingConnection: Connection? = try Connection(databaseURL.path)
        try createFixtureTable(in: existingConnection!)
        try existingConnection!.execute("PRAGMA journal_mode = WAL")
        try existingConnection!.execute("PRAGMA wal_autocheckpoint = 0")
        try existingConnection!.run(
            "INSERT INTO fixture_values (id, value) VALUES (1, 'wal-marker')"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path + "-wal"))

        let invalidSourceURL = temporaryRoot.appendingPathComponent("invalid-wal-rebuild.db")
        try Data("not a sqlite database".utf8).write(to: invalidSourceURL)
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: invalidSourceURL
            )
        )

        guard case .failed = lifecycle.rebuildFromSource() else {
            return XCTFail("Expected explicit rebuild to fail")
        }

        existingConnection = nil
        let preservedConnection = try Connection(databaseURL.path)
        XCTAssertEqual(
            try preservedConnection.scalar(
                "SELECT value FROM fixture_values WHERE id = 1"
            ) as? String,
            "wal-marker"
        )
    }

    func testInvalidExistingDatabaseIsNotMarkedReady() throws {
        let documentsURL = temporaryRoot.appendingPathComponent(
            "Documents",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: documentsURL,
            withIntermediateDirectories: true
        )
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        try Data("not a sqlite database".utf8).write(to: databaseURL)
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: nil
            )
        )

        guard case .failed = lifecycle.prepare() else {
            return XCTFail("Expected invalid database preparation to fail")
        }

        XCTAssertNil(lifecycle.readyConnection())
    }

    func testPreparationFailureDoesNotExposeAConnection() {
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: temporaryRoot.appendingPathComponent(
                    "Documents",
                    isDirectory: true
                ),
                databaseFilename: "fixture.db",
                sourceDatabaseURL: nil
            )
        )

        guard case .failed(let failure) = lifecycle.prepare() else {
            return XCTFail("Expected preparation to fail")
        }

        XCTAssertEqual(failure.message, "找不到数据库初始化源文件")
        XCTAssertNil(lifecycle.readyConnection())
    }

    func testRetryCanRecoverAfterPreparationFailure() throws {
        let sourceDatabaseURL = temporaryRoot.appendingPathComponent("source.db")
        let lifecycle = DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: temporaryRoot.appendingPathComponent(
                    "Documents",
                    isDirectory: true
                ),
                databaseFilename: "fixture.db",
                sourceDatabaseURL: sourceDatabaseURL
            )
        )

        guard case .failed = lifecycle.prepare() else {
            return XCTFail("Expected the first preparation to fail")
        }

        try FileManager.default.copyItem(
            at: try bundledBaselineURL(),
            to: sourceDatabaseURL
        )

        guard case .ready(let readyDatabase) = lifecycle.retry() else {
            return XCTFail("Expected retry to recover after the source became available")
        }

        XCTAssertEqual(readyDatabase.preparation, .initialized)
    }

    func testNoPendingMigrationDoesNotCreateSnapshot() throws {
        let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        _ = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        let lifecycle = try makeLifecycle(
            documentsURL: documentsURL,
            catalog: DatabaseMigrationCatalog(migrations: [
                DatabaseMigration(id: "20260721_0001_baseline") { _ in }
            ]),
            snapshotStore: FaultInjectingSnapshotStore(failSnapshotCreation: true)
        )

        guard case .ready(let database) = lifecycle.prepare() else {
            return XCTFail("Expected current database to start without a snapshot")
        }

        XCTAssertEqual(database.preparation, .alreadyReady)
    }

    func testBackupFailurePreventsMigrationAndPreservesDatabase() throws {
        let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let connection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try insertRepresentativeBusinessRows(in: connection)
        var migrationStarted = false
        let lifecycle = try makeLifecycle(
            documentsURL: documentsURL,
            catalog: fixtureMigrationCatalog { _ in
                migrationStarted = true
            },
            snapshotStore: FaultInjectingSnapshotStore(failSnapshotCreation: true)
        )

        guard case .failed = lifecycle.prepare() else {
            return XCTFail("Expected backup failure to block migration")
        }

        XCTAssertFalse(migrationStarted)
        XCTAssertNil(lifecycle.readyConnection())
        XCTAssertEqual(
            try connection.scalar("SELECT username FROM user WHERE id = 9001") as? String,
            "legacy-user"
        )
        XCTAssertEqual(
            try connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = ?",
                fixtureMigrationID
            ) as? Int64,
            0
        )
    }

    func testFailedMigrationRestoresCommittedWalData() throws {
        let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let connection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try connection.execute("PRAGMA journal_mode = WAL")
        try connection.execute("PRAGMA wal_autocheckpoint = 0")
        try insertRepresentativeBusinessRows(in: connection)
        try connection.run("INSERT INTO fixture_values (id, value) VALUES (1, 'wal-marker')")
        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path + "-wal"))

        let lifecycle = try makeLifecycle(
            documentsURL: documentsURL,
            catalog: fixtureMigrationCatalog { migrationConnection in
                try migrationConnection.run("CREATE TABLE failed_migration_fixture (id INTEGER PRIMARY KEY)")
                throw DatabasePreparationFailure(message: "injected migration failure")
            }
        )

        guard case .recovered(let database, _) = lifecycle.prepare() else {
            return XCTFail("Expected failed migration to restore the snapshot")
        }

        XCTAssertEqual(database.preparation, .recovered)
        XCTAssertEqual(
            try database.connection.scalar("SELECT value FROM fixture_values WHERE id = 1") as? String,
            "wal-marker"
        )
        XCTAssertEqual(
            try database.connection.scalar("SELECT username FROM user WHERE id = 9001") as? String,
            "legacy-user"
        )
        XCTAssertEqual(
            try database.connection.scalar("SELECT plan_name FROM training_history WHERE id = 9001") as? String,
            "Legacy Plan"
        )
        XCTAssertEqual(
            try database.connection.scalar("SELECT weight_kg FROM body_measurements WHERE id = 9001") as? Double,
            70
        )
        XCTAssertEqual(
            try database.connection.scalar(
                "SELECT COUNT(*) FROM sqlite_schema WHERE type = 'table' AND name = 'failed_migration_fixture'"
            ) as? Int64,
            0
        )
        XCTAssertEqual(
            try database.connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = ?",
                fixtureMigrationID
            ) as? Int64,
            0
        )
    }

    func testPostMigrationReadinessFailureRestoresOriginalDatabase() throws {
        let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        let connection = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        try insertRepresentativeBusinessRows(in: connection)
        let lifecycle = try makeLifecycle(
            documentsURL: documentsURL,
            catalog: fixtureMigrationCatalog { migrationConnection in
                try migrationConnection.run("DROP INDEX idx_training_history_user_date")
            }
        )

        guard case .recovered(let database, _) = lifecycle.prepare() else {
            return XCTFail("Expected failed readiness validation to restore the snapshot")
        }

        XCTAssertEqual(
            try database.connection.scalar(
                "SELECT COUNT(*) FROM sqlite_schema WHERE type = 'index' AND name = 'idx_training_history_user_date'"
            ) as? Int64,
            1
        )
        XCTAssertEqual(
            try database.connection.scalar("SELECT username FROM user WHERE id = 9001") as? String,
            "legacy-user"
        )
        XCTAssertEqual(
            try database.connection.scalar(
                "SELECT COUNT(*) FROM schema_migrations WHERE migration_id = ?",
                fixtureMigrationID
            ) as? Int64,
            0
        )
    }

    func testRestorationFailureLeavesDatabaseUnavailableAndPreservesSnapshot() throws {
        let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        _ = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        let lifecycle = try makeLifecycle(
            documentsURL: documentsURL,
            catalog: fixtureMigrationCatalog { _ in
                throw DatabasePreparationFailure(message: "injected migration failure")
            },
            snapshotStore: FaultInjectingSnapshotStore(failRestoration: true)
        )

        guard case .unrecoverable = lifecycle.prepare() else {
            return XCTFail("Expected restore failure to be unrecoverable")
        }

        XCTAssertNil(lifecycle.readyConnection())
        XCTAssertTrue(lifecycle.retry().description.starts(with: "unrecoverable"))
        XCTAssertNil(lifecycle.readyConnection())
        let artifacts = try FileManager.default.contentsOfDirectory(atPath: documentsURL.path)
        XCTAssertTrue(artifacts.contains { $0.contains("migration-backup") })
    }

    func testSuccessfulMigrationRemovesSnapshotArtifacts() throws {
        let documentsURL = temporaryRoot.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let databaseURL = documentsURL.appendingPathComponent("fixture.db")
        _ = try makeBaselineConnectionWithFixtureTable(at: databaseURL)
        let lifecycle = try makeLifecycle(
            documentsURL: documentsURL,
            catalog: fixtureMigrationCatalog { migrationConnection in
                try migrationConnection.run("CREATE TABLE migration_fixture (id INTEGER PRIMARY KEY)")
            }
        )

        guard case .ready(let database) = lifecycle.prepare() else {
            return XCTFail("Expected migration to succeed")
        }

        XCTAssertEqual(database.preparation, .migrated)
        let artifacts = try FileManager.default.contentsOfDirectory(atPath: documentsURL.path)
        XCTAssertFalse(artifacts.contains { $0.contains("migration-backup") })

        let restartedLifecycle = try makeLifecycle(
            documentsURL: documentsURL,
            catalog: fixtureMigrationCatalog { _ in
                XCTFail("Applied migration must not run again")
            }
        )
        guard case .ready(let restartedDatabase) = restartedLifecycle.prepare() else {
            return XCTFail("Expected migrated database to remain ready")
        }
        XCTAssertEqual(restartedDatabase.appliedMigrationIDs, [])
    }

    private let fixtureMigrationID = "20260722_0001_fixture_upgrade"

    private func fixtureMigrationCatalog(
        apply: @escaping (Connection) throws -> Void
    ) -> DatabaseMigrationCatalog {
        DatabaseMigrationCatalog(migrations: [
            DatabaseMigration(id: "20260721_0001_baseline") { _ in },
            DatabaseMigration(id: fixtureMigrationID, apply: apply)
        ])
    }

    private func makeLifecycle(
        documentsURL: URL,
        catalog: DatabaseMigrationCatalog,
        snapshotStore: DatabaseSnapshotStore? = nil
    ) throws -> DatabaseLifecycle {
        DatabaseLifecycle(
            environment: DatabaseEnvironment(
                documentsDirectory: documentsURL,
                databaseFilename: "fixture.db",
                sourceDatabaseURL: try bundledBaselineURL()
            ),
            migrationCatalog: catalog,
            snapshotStore: snapshotStore
        )
    }

    private final class FaultInjectingSnapshotStore: DatabaseSnapshotStore {
        private let store = SQLiteDatabaseSnapshotStore()
        private let failSnapshotCreation: Bool
        private let failRestoration: Bool

        init(failSnapshotCreation: Bool = false, failRestoration: Bool = false) {
            self.failSnapshotCreation = failSnapshotCreation
            self.failRestoration = failRestoration
        }

        func createSnapshot(from sourceConnection: Connection, at snapshotURL: URL) throws {
            if failSnapshotCreation {
                throw DatabasePreparationFailure(message: "injected backup failure")
            }
            try store.createSnapshot(from: sourceConnection, at: snapshotURL)
        }

        func restoreSnapshot(at snapshotURL: URL, replacing databaseURL: URL) throws {
            if failRestoration {
                throw DatabasePreparationFailure(message: "injected restoration failure")
            }
            try store.restoreSnapshot(at: snapshotURL, replacing: databaseURL)
        }

        func discardSnapshot(at snapshotURL: URL) {
            store.discardSnapshot(at: snapshotURL)
        }
    }

    private func rowCount(_ query: String, in connection: Connection) throws -> Int {
        var count = 0
        for _ in try connection.prepare(query) {
            count += 1
        }
        return count
    }

    private func baselineFingerprint(in connection: Connection) throws -> [String] {
        var fingerprint: [String] = []
        for table in [
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
            "training_history",
            "training_history_details",
            "body_measurements"
        ] {
            let count = try connection.scalar("SELECT COUNT(*) FROM \(table)") as? Int64 ?? -1
            fingerprint.append("\(table):\(count)")
        }
        let actionRelationshipFingerprint = try connection.scalar(
            """
            SELECT GROUP_CONCAT(value, '|')
            FROM (
                SELECT a.id || ':' || a.external_id || ':' || a.bodypart_id || ':' ||
                       COALESCE(a.equipment_id, '') || ':' || l.target_muscle_id AS value
                FROM action a
                JOIN action_target_muscle_link l ON l.action_id = a.id
                ORDER BY a.id, l.target_muscle_id
            )
            """
        ) as? String
        fingerprint.append(actionRelationshipFingerprint ?? "")
        return fingerprint
    }

    private func insertRepresentativeBusinessRows(in connection: Connection) throws {
        try connection.run(
            """
            INSERT INTO user (id, username, email, password_hash, created_at)
            VALUES (9001, 'legacy-user', 'legacy@example.com', 'legacy-hash', '2026-07-20T00:00:00Z')
            """
        )
        try connection.run(
            """
            INSERT INTO training_plans (
                id, name, description, difficulty, duration, created_at,
                updated_at, user_id, is_template
            ) VALUES (
                9001, 'Legacy Plan', '', '', 0, '2026-07-20T00:00:00Z',
                '2026-07-20T00:00:00Z', 9001, 0
            )
            """
        )
        try connection.run(
            """
            INSERT INTO training_history (
                id, user_id, plan_id, session_id, plan_name, training_date
            ) VALUES (9001, 9001, 9001, 9001, 'Legacy Plan', '2026-07-20T00:00:00Z')
            """
        )
        try connection.run(
            """
            INSERT INTO body_measurements (
                id, user_id, measurement_timestamp, weight_kg, height_cm,
                body_fat_percentage, skeletal_muscle_mass_kg, visceral_fat_level
            ) VALUES (9001, 9001, '2026-07-20T00:00:00Z', 70, 175, 15, 32, 8)
            """
        )
    }

    private func bundledBaselineURL() throws -> URL {
        try XCTUnwrap(
            DatabaseEnvironment.application().sourceDatabaseURL,
            "Expected the generated baseline database in the app bundle"
        )
    }

    private func makeBaselineConnectionWithFixtureTable(
        at databaseURL: URL
    ) throws -> Connection {
        try FileManager.default.copyItem(
            at: try bundledBaselineURL(),
            to: databaseURL
        )
        let connection = try Connection(databaseURL.path)
        try createFixtureTable(in: connection)
        return connection
    }

    private func makeSourceDatabase() throws -> URL {
        let sourceDatabaseURL = temporaryRoot.appendingPathComponent("source.db")
        try FileManager.default.copyItem(
            at: try bundledBaselineURL(),
            to: sourceDatabaseURL
        )
        let connection = try Connection(sourceDatabaseURL.path)
        try createFixtureTable(in: connection)
        return sourceDatabaseURL
    }

    private func createFixtureTable(in connection: Connection) throws {
        try connection.run(
            "CREATE TABLE fixture_values (id INTEGER PRIMARY KEY, value TEXT NOT NULL)"
        )
    }
}

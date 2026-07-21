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

        XCTAssertEqual(readyDatabase.preparation, .alreadyReady)
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

        XCTAssertEqual(readyDatabase.preparation, .alreadyReady)
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

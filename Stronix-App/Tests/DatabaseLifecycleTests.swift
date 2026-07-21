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
        let existingConnection = try Connection(databaseURL.path)
        try createFixtureTable(in: existingConnection)
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
        do {
            let existingConnection = try Connection(databaseURL.path)
            try createFixtureTable(in: existingConnection)
            try existingConnection.run(
                "INSERT INTO fixture_values (id, value) VALUES (1, 'old-marker')"
            )
        }
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
        do {
            let connection = try Connection(databaseURL.path)
            try createFixtureTable(in: connection)
            try connection.run(
                "INSERT INTO fixture_values (id, value) VALUES (1, 'startup-marker')"
            )
        }
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
        do {
            let connection = try Connection(databaseURL.path)
            try createFixtureTable(in: connection)
            try connection.run(
                "INSERT INTO fixture_values (id, value) VALUES (1, 'old-marker')"
            )
        }
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

        let sourceConnection = try Connection(sourceDatabaseURL.path)
        try createFixtureTable(in: sourceConnection)

        guard case .ready(let readyDatabase) = lifecycle.retry() else {
            return XCTFail("Expected retry to recover after the source became available")
        }

        XCTAssertEqual(readyDatabase.preparation, .initialized)
    }

    private func makeSourceDatabase() throws -> URL {
        let sourceDatabaseURL = temporaryRoot.appendingPathComponent("source.db")
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

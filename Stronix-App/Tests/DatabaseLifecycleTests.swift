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
    }

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

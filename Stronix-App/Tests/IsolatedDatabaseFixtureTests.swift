import SQLite
import XCTest
@testable import Stronix

final class IsolatedDatabaseFixtureTests: XCTestCase {
    func testPreparedDatabaseUsesUniqueFixtureRootAndLeavesBundledBaselineUnchanged() throws {
        let fixture = try IsolatedDatabaseFixture()
        defer { fixture.tearDown() }
        let baselineUserCount = try scalarCount(at: fixture.baselineSourceURL, table: "user")

        do {
            let connection = try fixture.prepareRepositoryDatabase(named: "repository.db")
            let databaseURL = fixture.preparedDatabaseURL
            try TestUserFixture(username: "isolated", email: "isolated@example.com").insert(into: connection)

            XCTAssertTrue(fixture.contains(databaseURL))
            XCTAssertNotEqual(databaseURL.standardizedFileURL, fixture.baselineSourceURL.standardizedFileURL)
            XCTAssertNotEqual(databaseURL.standardizedFileURL, DatabaseEnvironment.application().databaseURL.standardizedFileURL)
            XCTAssertEqual(try connection.scalar("SELECT COUNT(*) FROM user") as? Int64, baselineUserCount + 1)
            XCTAssertEqual(try scalarCount(at: fixture.baselineSourceURL, table: "user"), baselineUserCount)
        }
    }

    func testLifecycleWritesOnlyToFixtureDocumentsDirectory() throws {
        let fixture = try IsolatedDatabaseFixture()
        defer { fixture.tearDown() }
        do {
            let lifecycle = fixture.makeLifecycle(databaseFilename: "lifecycle.db")

            guard case .ready(let database) = lifecycle.prepare() else {
                return XCTFail("Expected isolated lifecycle preparation to succeed")
            }

            XCTAssertEqual(database.databaseURL, fixture.documentsURL.appendingPathComponent("lifecycle.db"))
            XCTAssertTrue(fixture.contains(database.databaseURL))
            XCTAssertNotEqual(database.databaseURL.standardizedFileURL, DatabaseEnvironment.application().databaseURL.standardizedFileURL)
        }
    }

    func testFreshFixturesDoNotShareMutableDatabaseState() throws {
        let first = try IsolatedDatabaseFixture()
        defer { first.tearDown() }
        do {
            let firstConnection = try first.prepareRepositoryDatabase()
            try TestUserFixture(username: "first", email: "first@example.com").insert(into: firstConnection)
        }

        let second = try IsolatedDatabaseFixture()
        defer { second.tearDown() }
        do {
            let secondConnection = try second.prepareRepositoryDatabase()
            XCTAssertEqual(try secondConnection.scalar("SELECT COUNT(*) FROM user") as? Int64, 0)
            XCTAssertNotEqual(first.rootURL, second.rootURL)
        }
    }

    func testInMemorySessionStoreDoesNotDependOnKeychainState() throws {
        let store = InMemoryLocalSessionStore()

        try store.save(LocalSessionReference(userID: 42))
        XCTAssertEqual(try store.load(), LocalSessionReference(userID: 42))
        try store.clear()
        XCTAssertNil(try store.load())
    }

    func testTemporaryDefaultsAreRemovedOnTearDown() throws {
        let fixture = TestUserDefaultsFixture()
        fixture.defaults.set(42, forKey: "current_user_id")
        XCTAssertEqual(fixture.defaults.integer(forKey: "current_user_id"), 42)

        fixture.tearDown()

        XCTAssertNil(UserDefaults(suiteName: fixture.suiteName)?.object(forKey: "current_user_id"))
    }

    private func scalarCount(at databaseURL: URL, table: String) throws -> Int64 {
        let connection = try Connection(databaseURL.path, readonly: true)
        return try XCTUnwrap(connection.scalar("SELECT COUNT(*) FROM \(table)") as? Int64)
    }
}

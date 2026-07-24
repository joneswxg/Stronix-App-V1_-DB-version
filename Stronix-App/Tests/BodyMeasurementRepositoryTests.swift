import XCTest
import SQLite
@testable import Stronix

final class BodyMeasurementRepositoryTests: XCTestCase {
    private var root: URL!
    private var connection: Connection!
    private var currentUser: TestCurrentUser!
    private var repository: SQLiteBodyMeasurementRepository!
    private var ownerID: Int!
    private var otherID: Int!
    private let now = Date(timeIntervalSince1970: 1_784_959_200.987)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let databaseURL = root.appendingPathComponent("measurements.db")
        try FileManager.default.copyItem(at: try XCTUnwrap(DatabaseEnvironment.application().sourceDatabaseURL), to: databaseURL)
        connection = try Connection(databaseURL.path)
        try connection.execute("PRAGMA foreign_keys = ON")
        ownerID = try insertUser("owner")
        otherID = try insertUser("other")
        currentUser = TestCurrentUser(id: ownerID)
        repository = SQLiteBodyMeasurementRepository(connectionProvider: { self.connection }, currentUserProvider: currentUser, now: { self.now })
    }

    override func tearDownWithError() throws {
        repository = nil
        connection = nil
        try? FileManager.default.removeItem(at: root)
        root = nil
    }

    func testListIsOwnerScopedAndDeterministicallyOrdered() throws {
        let oldest = try insertMeasurement(ownerID: ownerID, timestamp: "2026-07-20T00:00:00.000Z", createdAt: "2026-07-20T00:00:00.000Z")
        let sameTimestampOlder = try insertMeasurement(ownerID: ownerID, timestamp: "2026-07-22T00:00:00.000Z", createdAt: "2026-07-22T01:00:00.000Z")
        let newest = try insertMeasurement(ownerID: ownerID, timestamp: "2026-07-22T00:00:00.000Z", createdAt: "2026-07-22T02:00:00.000Z")
        _ = try insertMeasurement(ownerID: otherID, timestamp: "2026-07-23T00:00:00.000Z")

        XCTAssertEqual(try repository.list().map(\.id), [newest, sameTimestampOlder, oldest])
    }

    func testListOrdersMixedLegacyAndCanonicalTimestampsByInstant() throws {
        let canonical = try insertMeasurement(ownerID: ownerID, timestamp: "2026-07-22T00:00:00.000Z")
        let laterLegacy = try insertMeasurement(ownerID: ownerID, timestamp: "2026-07-22 23:00:00")

        XCTAssertEqual(try repository.list().map(\.id), [laterLegacy, canonical])
    }

    func testDeleteRemovesOwnedRecord() throws {
        let id = try insertMeasurement(ownerID: ownerID, timestamp: "2026-07-22T00:00:00.000Z")

        try repository.delete(id: id)

        XCTAssertEqual(try countMeasurements(id: id), 0)
    }
    func testForeignAndMissingRecordsHaveSameNonDisclosingFailure() throws {
        let foreign = try insertMeasurement(ownerID: otherID, timestamp: "2026-07-22T00:00:00.000Z")
        for id in [foreign, 999_999] {
            XCTAssertThrowsError(try repository.measurement(id: id)) { XCTAssertEqual($0 as? BodyMeasurementRepositoryError, .notFoundOrUnauthorized) }
            XCTAssertThrowsError(try repository.update(id: id, with: draft())) { XCTAssertEqual($0 as? BodyMeasurementRepositoryError, .notFoundOrUnauthorized) }
            XCTAssertThrowsError(try repository.delete(id: id)) { XCTAssertEqual($0 as? BodyMeasurementRepositoryError, .notFoundOrUnauthorized) }
        }
        currentUser.id = otherID
        XCTAssertNoThrow(try repository.measurement(id: foreign))
    }

    func testUpdatePreservesIdentityAndCreatedTimestampWhileChangingDate() throws {
        let id = try insertMeasurement(ownerID: ownerID, timestamp: "2026-07-20T00:00:00.000Z", createdAt: "2026-07-20T01:00:00.000Z")
        let updated = try repository.update(id: id, with: draft(timestamp: Date(timeIntervalSince1970: 1_784_678_400.789)))

        XCTAssertEqual(updated.id, id)
        XCTAssertEqual(BodyMeasurementDateFormatting.storageString(from: updated.createdAt), "2026-07-20T01:00:00.000Z")
        XCTAssertEqual(BodyMeasurementDateFormatting.storageString(from: updated.updatedAt), BodyMeasurementDateFormatting.storageString(from: now))
        XCTAssertEqual(try countMeasurements(id: id), 1)
        XCTAssertEqual(
            try rawTimestamp(id: id),
            BodyMeasurementDateFormatting.storageString(
                from: BodyMeasurementDateFormatting.localCalendarDay(from: Date(timeIntervalSince1970: 1_784_678_400.789))
            )
        )
    }

    func testCreateUsesAuthenticatedOwnerAndCanonicalTimestamps() throws {
        let created = try repository.create(draft(timestamp: Date(timeIntervalSince1970: 1_784_959_200.9879)))
        XCTAssertEqual(try rawOwner(id: created.id), ownerID)
        XCTAssertEqual(
            try rawTimestamp(id: created.id),
            BodyMeasurementDateFormatting.storageString(
                from: BodyMeasurementDateFormatting.localCalendarDay(from: Date(timeIntervalSince1970: 1_784_959_200.9879))
            )
        )
        XCTAssertEqual(try rawCreatedAt(id: created.id), BodyMeasurementDateFormatting.storageString(from: now))
    }

    func testValidationAndUnauthenticatedFailuresAreTyped() throws {
        XCTAssertThrowsError(try repository.create(BodyMeasurementDraft(measurementTimestamp: Date(), weightKg: .nan, heightCm: 170, bodyFatPercentage: 20, skeletalMuscleMassKg: 35, visceralFatLevel: 5))) {
            XCTAssertEqual($0 as? BodyMeasurementRepositoryError, .invalidWeight)
        }
        XCTAssertThrowsError(try repository.create(BodyMeasurementDraft(measurementTimestamp: Date(timeIntervalSinceReferenceDate: .infinity), weightKg: 70, heightCm: 170, bodyFatPercentage: 20, skeletalMuscleMassKg: 35, visceralFatLevel: 5))) {
            XCTAssertEqual($0 as? BodyMeasurementRepositoryError, .invalidMeasurementTimestamp)
        }
        currentUser.id = nil
        XCTAssertThrowsError(try repository.list()) { XCTAssertEqual($0 as? BodyMeasurementRepositoryError, .unauthenticated) }
    }

    func testExplicitLegacyFormatsUseUTCAndInvalidDatesFail() throws {
        let sqlite = try insertMeasurement(ownerID: ownerID, timestamp: "2026-07-22 12:30:00")
        let dateOnly = try insertMeasurement(ownerID: ownerID, timestamp: "2026-07-21")
        let invalid = try insertMeasurement(ownerID: ownerID, timestamp: "not-a-date")
        XCTAssertEqual(try repository.measurement(id: sqlite).measurementTimestamp.timeIntervalSince1970, DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0), year: 2026, month: 7, day: 22, hour: 12, minute: 30).date!.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(try repository.measurement(id: dateOnly).measurementTimestamp.timeIntervalSince1970, DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0), year: 2026, month: 7, day: 21).date!.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertThrowsError(try repository.measurement(id: invalid)) { XCTAssertEqual($0 as? BodyMeasurementRepositoryError, .malformedStoredTimestamp) }
    }

    private func draft(timestamp: Date = Date(timeIntervalSince1970: 1_784_764_800)) -> BodyMeasurementDraft {
        BodyMeasurementDraft(measurementTimestamp: timestamp, weightKg: 72.5, heightCm: 175, bodyFatPercentage: 18, skeletalMuscleMassKg: 34, visceralFatLevel: 5)
    }

    private func insertUser(_ username: String) throws -> Int {
        try connection.run("INSERT INTO user (username, email, password_hash, created_at) VALUES (?, ?, 'hash', '2026-07-20T00:00:00Z')", username, "\(username)@example.com")
        return Int(connection.lastInsertRowid)
    }

    private func insertMeasurement(ownerID: Int, timestamp: String, createdAt: String = "2026-07-20T00:00:00.000Z") throws -> Int {
        try connection.run(
            "INSERT INTO body_measurements (user_id, measurement_timestamp, weight_kg, height_cm, body_fat_percentage, skeletal_muscle_mass_kg, visceral_fat_level, created_at, updated_at) VALUES (?, ?, 70, 170, 20, 30, 5, ?, ?)",
            ownerID,
            timestamp,
            createdAt,
            createdAt
        )
        return Int(connection.lastInsertRowid)
    }

    private func rawOwner(id: Int) throws -> Int { try integer("SELECT user_id FROM body_measurements WHERE id = ?", id) }
    private func rawTimestamp(id: Int) throws -> String { try string("SELECT measurement_timestamp FROM body_measurements WHERE id = ?", id) }
    private func rawCreatedAt(id: Int) throws -> String { try string("SELECT created_at FROM body_measurements WHERE id = ?", id) }
    private func countMeasurements(id: Int) throws -> Int { try integer("SELECT COUNT(*) FROM body_measurements WHERE id = ?", id) }

    private func integer(_ sql: String, _ id: Int) throws -> Int {
        guard let value = try connection.prepare(sql, id).makeIterator().next()?[0] else { throw NSError(domain: "Test", code: 1) }
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(value) }
        throw NSError(domain: "Test", code: 1)
    }

    private func string(_ sql: String, _ id: Int) throws -> String {
        guard let value = try connection.prepare(sql, id).makeIterator().next()?[0] as? String else { throw NSError(domain: "Test", code: 1) }
        return value
    }
}

private final class TestCurrentUser: CurrentUserProviding {
    var currentUser: User? { nil }
    var currentUserID: Int? { id }
    var id: Int?

    init(id: Int?) { self.id = id }
}

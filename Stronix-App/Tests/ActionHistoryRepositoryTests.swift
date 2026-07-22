import XCTest
import SQLite
@testable import Stronix

final class ActionHistoryRepositoryTests: XCTestCase {
    private var temporaryRoot: URL!
    private var connection: Connection!
    private var repository: SQLiteActionHistoryRepository!
    private var userID: Int!
    private var targetActionID: Int!
    private var otherActionID: Int!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let databaseURL = temporaryRoot.appendingPathComponent("action-history.db")
        try FileManager.default.copyItem(at: try bundledBaselineURL(), to: databaseURL)
        connection = try Connection(databaseURL.path)
        try connection.execute("PRAGMA foreign_keys = ON")
        userID = try insertUser()
        targetActionID = try insertAction(externalID: "target-action", name: "Target")
        otherActionID = try insertAction(externalID: "other-action", name: "Other")
        repository = SQLiteActionHistoryRepository(connection: connection)
    }

    override func tearDownWithError() throws {
        repository = nil
        connection = nil
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
    }

    func testActionHistoryOrdersLimitsMapsSetsAndCalculatesCompletedVolume() throws {
        let oldestID = try insertHistory(date: "2026-07-01", planName: "Oldest")
        try insertDetail(historyID: oldestID, actionID: targetActionID, setNumber: 1, weight: 10, reps: 10, isCompleted: true)

        let julyThirdID = try insertHistory(date: "2026-07-03", planName: "Third")
        try insertDetail(historyID: julyThirdID, actionID: targetActionID, setNumber: 1, weight: 20, reps: 5, isCompleted: true)

        let julySecondID = try insertHistory(date: "2026-07-02", planName: "Second")
        try insertDetail(historyID: julySecondID, actionID: targetActionID, setNumber: 1, weight: 15, reps: 5, isCompleted: true)

        let julySixthID = try insertHistory(date: "2026-07-06", planName: "Sixth")
        try insertDetail(historyID: julySixthID, actionID: targetActionID, setNumber: 1, weight: 30, reps: 5, isCompleted: true)

        let julyFourthID = try insertHistory(date: "2026-07-04", planName: "Fourth")
        try insertDetail(historyID: julyFourthID, actionID: targetActionID, setNumber: 2, weight: 22.9, reps: 3, isCompleted: false)
        try insertDetail(historyID: julyFourthID, actionID: targetActionID, setNumber: 1, weight: 21.8, reps: 4, isCompleted: true)

        let julyFifthID = try insertHistory(date: "2026-07-05", planName: "Fifth")
        try insertDetail(historyID: julyFifthID, actionID: targetActionID, setNumber: 1, weight: 25, reps: 5, isCompleted: true)
        try insertDetail(historyID: julyFifthID, actionID: otherActionID, setNumber: 1, weight: 99, reps: 99, isCompleted: true)

        let otherOnlyID = try insertHistory(date: "2026-07-07", planName: "Other action")
        try insertDetail(historyID: otherOnlyID, actionID: otherActionID, setNumber: 1, weight: 99, reps: 99, isCompleted: true)

        let history = try repository.actionHistory(for: targetActionID)

        XCTAssertEqual(history.map(\.date), ["2026-07-06", "2026-07-05", "2026-07-04", "2026-07-03", "2026-07-02"])
        XCTAssertEqual(history.map(\.planName), ["Sixth", "Fifth", "Fourth", "Third", "Second"])
        XCTAssertEqual(history.first { $0.planName == "Fourth" }?.sets, [
            ActionHistorySet(setNumber: 1, weight: 21, reps: 4, isCompleted: true),
            ActionHistorySet(setNumber: 2, weight: 22, reps: 3, isCompleted: false)
        ])
        XCTAssertEqual(history.first { $0.planName == "Fourth" }?.totalVolume, 84)
        XCTAssertFalse(history.contains { $0.planName == "Oldest" || $0.planName == "Other action" })
    }

    func testActionHistoryMapsMissingConnectionToDatabaseError() {
        let repository = SQLiteActionHistoryRepository(connectionProvider: { nil })

        XCTAssertThrowsError(try repository.actionHistory(for: 42)) { error in
            guard case .notReady = error as? DatabaseError else {
                return XCTFail("Expected DatabaseError.notReady, got \(error)")
            }
        }
    }

    private func bundledBaselineURL() throws -> URL {
        try XCTUnwrap(DatabaseEnvironment.application().sourceDatabaseURL)
    }

    private func insertUser() throws -> Int {
        try connection.run(
            """
            INSERT INTO user (username, email, password_hash, created_at)
            VALUES ('history-user', 'history@example.com', 'test-hash', '2026-07-22T00:00:00Z')
            """
        )
        return Int(connection.lastInsertRowid)
    }

    private func insertAction(externalID: String, name: String) throws -> Int {
        try connection.run(
            """
            INSERT INTO action (external_id, name, bodypart_id)
            VALUES (?, ?, 1)
            """,
            externalID,
            name
        )
        return Int(connection.lastInsertRowid)
    }

    private func insertHistory(date: String, planName: String) throws -> Int {
        try connection.run(
            """
            INSERT INTO training_history (user_id, session_id, plan_name, training_date)
            VALUES (?, ?, ?, ?)
            """,
            userID,
            Int(connection.lastInsertRowid) + 1,
            planName,
            date
        )
        return Int(connection.lastInsertRowid)
    }

    private func insertDetail(
        historyID: Int,
        actionID: Int,
        setNumber: Int,
        weight: Double,
        reps: Int,
        isCompleted: Bool
    ) throws {
        try connection.run(
            """
            INSERT INTO training_history_details (history_id, action_id, set_number, weight, reps, is_completed)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            historyID,
            actionID,
            setNumber,
            weight,
            reps,
            isCompleted ? 1 : 0
        )
    }
}

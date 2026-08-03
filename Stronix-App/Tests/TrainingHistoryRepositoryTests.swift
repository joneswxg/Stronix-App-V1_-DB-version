import XCTest
import SQLite
@testable import Stronix

final class TrainingHistoryRepositoryTests: XCTestCase {
    private var fixture: IsolatedDatabaseFixture!
    private var connection: Connection!
    private var repository: SQLiteTrainingHistoryRepository!
    private var ownerID: Int!
    private var otherUserID: Int!
    private var ownerPlanID: Int!
    private var otherPlanID: Int!
    private var squatID: Int!
    private var pressID: Int!

    override func setUpWithError() throws {
        fixture = try IsolatedDatabaseFixture()
        connection = try fixture.prepareRepositoryDatabase(named: "training-history.db")
        ownerID = try TestUserFixture(username: "owner", email: "owner@example.com").insert(into: connection).id
        otherUserID = try TestUserFixture(username: "other", email: "other@example.com").insert(into: connection).id
        ownerPlanID = try insertPlan(ownerID: ownerID, name: "Owner plan")
        otherPlanID = try insertPlan(ownerID: ownerID, name: "Other plan")
        squatID = try insertAction(externalID: "squat", name: "Squat")
        pressID = try insertAction(externalID: "press", name: "Press")
        repository = SQLiteTrainingHistoryRepository(connection: connection)
    }

    override func tearDownWithError() throws {
        repository = nil
        connection = nil
        fixture.tearDown()
        fixture = nil
    }

    func testListOrdersByTrainingDateThenCreatedAtAndIncludesPagination() throws {
        let older = try insertHistory(ownerID: ownerID, planID: ownerPlanID, planName: "Older", trainingDate: "2026-07-20T10:00:00Z", createdAt: "2026-07-20T10:00:00Z")
        let sameDateOlder = try insertHistory(ownerID: ownerID, planID: ownerPlanID, planName: "Same date older", trainingDate: "2026-07-22T09:00:00Z", createdAt: "2026-07-22T09:00:00Z")
        let sameDateNewer = try insertHistory(ownerID: ownerID, planID: ownerPlanID, planName: "Same date newer", trainingDate: "2026-07-22T09:00:00Z", createdAt: "2026-07-22T11:00:00Z")
        let newest = try insertHistory(ownerID: ownerID, planID: ownerPlanID, planName: "Newest", trainingDate: "2026-07-23T09:00:00Z", createdAt: "2026-07-23T09:00:00Z")

        let page = try repository.trainingHistory(query(page: 1, pageSize: 2))
        let nextPage = try repository.trainingHistory(query(page: 2, pageSize: 2))

        XCTAssertEqual(page.histories.map(\.id), [newest, sameDateNewer])
        XCTAssertEqual(nextPage.histories.map(\.id), [sameDateOlder, older])
        XCTAssertEqual(page.pagination, TrainingHistoryPagination(page: 1, pageSize: 2, total: 4, pageCount: 2))
        XCTAssertEqual(nextPage.pagination, TrainingHistoryPagination(page: 2, pageSize: 2, total: 4, pageCount: 2))
    }

    func testListFiltersDatesAndUserPlanAndScopesToOwner() throws {
        let included = try insertHistory(ownerID: ownerID, planID: ownerPlanID, planName: "Included", trainingDate: "2026-07-22T12:00:00Z")
        _ = try insertHistory(ownerID: ownerID, planID: ownerPlanID, planName: "Wrong date", trainingDate: "2026-07-23T12:00:00Z")
        _ = try insertHistory(ownerID: ownerID, planID: otherPlanID, planName: "Wrong plan", trainingDate: "2026-07-22T12:00:00Z")
        _ = try insertHistory(ownerID: otherUserID, planID: nil, planName: "Other user", trainingDate: "2026-07-22T12:00:00Z")

        let result = try repository.trainingHistory(
            TrainingHistoryListQuery(
                ownerID: ownerID,
                page: TrainingHistoryPageRequest(page: 1, pageSize: 20),
                filter: TrainingHistoryFilter(
                    userPlanID: ownerPlanID,
                    dateRange: TrainingHistoryDateRange(startDate: "2026-07-22", endDate: "2026-07-22")
                )
            )
        )

        XCTAssertEqual(result.histories.map(\.id), [included])
        XCTAssertEqual(result.pagination.total, 1)
    }

    func testDatesAreDistinctAscendingAndOwnerScoped() throws {
        _ = try insertHistory(ownerID: ownerID, planID: ownerPlanID, planName: "First", trainingDate: "2026-07-20T08:00:00Z")
        _ = try insertHistory(ownerID: ownerID, planID: ownerPlanID, planName: "Second", trainingDate: "2026-07-20T12:00:00Z")
        _ = try insertHistory(ownerID: ownerID, planID: ownerPlanID, planName: "Third", trainingDate: "2026-07-22T12:00:00Z")
        _ = try insertHistory(ownerID: otherUserID, planID: nil, planName: "Other", trainingDate: "2026-07-21T12:00:00Z")
        let range = TrainingHistoryDateRange(startDate: "2026-07-20", endDate: "2026-07-22")

        let dates = try repository.trainingDates(ownerID: ownerID, in: range)

        XCTAssertEqual(dates, TrainingHistoryDates(dates: ["2026-07-20", "2026-07-22"], range: range))
    }

    func testEmptyResultsAndOutOfRangePageAreSuccessful() throws {
        _ = try insertHistory(ownerID: ownerID, planID: ownerPlanID, planName: "Only", trainingDate: "2026-07-22T12:00:00Z")

        let outOfRange = try repository.trainingHistory(query(page: 2, pageSize: 20))
        let emptyDates = try repository.trainingDates(
            ownerID: ownerID,
            in: TrainingHistoryDateRange(startDate: "2026-07-01", endDate: "2026-07-02")
        )

        XCTAssertEqual(outOfRange.histories, [])
        XCTAssertEqual(outOfRange.pagination, TrainingHistoryPagination(page: 2, pageSize: 20, total: 1, pageCount: 1))
        XCTAssertEqual(emptyDates.dates, [])
    }

    func testInvalidQueryValuesFailExplicitly() {
        XCTAssertThrowsError(try repository.trainingHistory(query(page: 0, pageSize: 1))) {
            XCTAssertEqual($0 as? TrainingHistoryRepositoryError, .invalidPage)
        }
        XCTAssertThrowsError(try repository.trainingHistory(query(page: 1, pageSize: 0))) {
            XCTAssertEqual($0 as? TrainingHistoryRepositoryError, .invalidPageSize)
        }
        XCTAssertThrowsError(try repository.trainingHistory(query(page: 1, pageSize: 101))) {
            XCTAssertEqual($0 as? TrainingHistoryRepositoryError, .invalidPageSize)
        }
        XCTAssertThrowsError(try repository.trainingHistory(
            TrainingHistoryListQuery(
                ownerID: ownerID,
                page: TrainingHistoryPageRequest(page: 1, pageSize: 1),
                filter: TrainingHistoryFilter(userPlanID: 0)
            )
        )) {
            XCTAssertEqual($0 as? TrainingHistoryRepositoryError, .invalidPlanID)
        }
        XCTAssertThrowsError(try repository.trainingDates(
            ownerID: ownerID,
            in: TrainingHistoryDateRange(startDate: "2026-07-32", endDate: "2026-07-01")
        )) {
            XCTAssertEqual($0 as? TrainingHistoryRepositoryError, .invalidDateRange)
        }
    }

    func testDetailMapsHeaderOrderedActionsSetsAndBilateralWeights() throws {
        let historyID = try insertHistory(
            ownerID: ownerID,
            planID: ownerPlanID,
            planName: "Strength",
            trainingDate: "2026-07-22T12:00:00Z",
            volume: 987.5,
            duration: 45
        )
        try insertDetail(historyID: historyID, actionID: pressID, setNumber: 2, weight: 40, reps: 8, isCompleted: false)
        try insertDetail(historyID: historyID, actionID: squatID, setNumber: 2, weight: nil, reps: 10, leftWeight: 50, rightWeight: 55, isCompleted: true, isBilateral: true)
        try insertDetail(historyID: historyID, actionID: squatID, setNumber: 1, weight: nil, reps: 8, leftWeight: 45, rightWeight: 50, isCompleted: true, isBilateral: true)
        try insertDetail(historyID: historyID, actionID: pressID, setNumber: 1, weight: 35, reps: 10, isCompleted: true)

        let detail = try repository.trainingHistoryDetail(id: historyID, ownerID: ownerID)

        XCTAssertEqual(detail.history.id, historyID)
        XCTAssertEqual(detail.history.volume, 987.5)
        XCTAssertEqual(detail.actions.map(\.actionID), [squatID, pressID])
        XCTAssertEqual(detail.actions.map(\.name), ["Squat", "Press"])
        XCTAssertEqual(detail.actions[0].sets.map(\.setNumber), [1, 2])
        XCTAssertEqual(detail.actions[0].sets.map(\.leftWeight), [45, 50])
        XCTAssertEqual(detail.actions[0].sets.map(\.rightWeight), [50, 55])
        XCTAssertTrue(detail.actions[0].sets.allSatisfy(\.isBilateral))
        XCTAssertEqual(detail.actions[1].sets.map(\.setNumber), [1, 2])
        XCTAssertEqual(detail.actions[1].sets.map(\.weight), [35, 40])
    }

    func testDetailPreservesOptionalRIRValues() throws {
        let historyID = try insertHistory(
            ownerID: ownerID,
            planID: ownerPlanID,
            planName: "RIR",
            trainingDate: "2026-08-03T12:00:00Z"
        )
        try insertDetail(historyID: historyID, actionID: squatID, setNumber: 1, weight: 40, reps: 8, isCompleted: true, rir: nil)
        try insertDetail(historyID: historyID, actionID: squatID, setNumber: 2, weight: 42.5, reps: 8, isCompleted: true, rir: 0)
        try insertDetail(historyID: historyID, actionID: squatID, setNumber: 3, weight: 45, reps: 8, isCompleted: true, rir: 1)
        try insertDetail(historyID: historyID, actionID: squatID, setNumber: 4, weight: 47.5, reps: 8, isCompleted: true, rir: 2)
        try insertDetail(historyID: historyID, actionID: squatID, setNumber: 5, weight: 50, reps: 8, isCompleted: true, rir: 3)

        let detail = try repository.trainingHistoryDetail(id: historyID, ownerID: ownerID)

        XCTAssertEqual(detail.actions[0].sets.map(\.rir), [nil, .zero, .one, .two, .threeOrMore])
        XCTAssertEqual(
            detail.actions[0].sets.map { $0.rir.historyDisplayLabel },
            ["未记录余力", "RIR 0", "RIR 1", "RIR 2", "RIR 3+"]
        )
        XCTAssertThrowsError(try connection.run(
            "UPDATE training_history_details SET rir = 4 WHERE history_id = ? AND set_number = 1",
            historyID
        ))
        XCTAssertThrowsError(try connection.run(
            "UPDATE training_history_details SET rir = -1 WHERE history_id = ? AND set_number = 1",
            historyID
        ))
    }

    func testDetailDoesNotRevealForeignOrMissingHistory() throws {
        let foreignHistoryID = try insertHistory(ownerID: otherUserID, planID: nil, planName: "Foreign", trainingDate: "2026-07-22T12:00:00Z")

        for id in [foreignHistoryID, 999_999] {
            XCTAssertThrowsError(try repository.trainingHistoryDetail(id: id, ownerID: ownerID)) {
                XCTAssertEqual($0 as? TrainingHistoryRepositoryError, .notFoundOrUnauthorized)
            }
        }
    }

    func testMissingConnectionMapsToDatabaseNotReady() {
        let unavailable = SQLiteTrainingHistoryRepository(connectionProvider: { nil })

        XCTAssertThrowsError(try unavailable.trainingHistory(query(page: 1, pageSize: 1))) {
            guard case .notReady = $0 as? DatabaseError else {
                return XCTFail("Expected DatabaseError.notReady, got \($0)")
            }
        }
    }

    private func query(page: Int, pageSize: Int) -> TrainingHistoryListQuery {
        TrainingHistoryListQuery(
            ownerID: ownerID,
            page: TrainingHistoryPageRequest(page: page, pageSize: pageSize),
            filter: TrainingHistoryFilter()
        )
    }

    private func insertPlan(ownerID: Int, name: String) throws -> Int {
        try connection.run(
            """
            INSERT INTO training_plans (user_id, name, description, difficulty, duration)
            VALUES (?, ?, '', 'normal', 30)
            """,
            ownerID,
            name
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

    private func insertHistory(
        ownerID: Int,
        planID: Int?,
        planName: String,
        trainingDate: String,
        createdAt: String = "2026-07-22T12:00:00Z",
        volume: Double = 0,
        duration: Int = 0
    ) throws -> Int {
        try connection.run(
            """
            INSERT INTO training_history (
                user_id, plan_id, session_id, plan_name, training_date, volume, duration, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            ownerID,
            planID,
            Int(connection.lastInsertRowid) + 1,
            planName,
            trainingDate,
            volume,
            duration,
            createdAt
        )
        return Int(connection.lastInsertRowid)
    }

    private func insertDetail(
        historyID: Int,
        actionID: Int,
        setNumber: Int,
        weight: Double?,
        reps: Int,
        leftWeight: Double? = nil,
        rightWeight: Double? = nil,
        isCompleted: Bool,
        isBilateral: Bool = false,
        rir: Int? = nil
    ) throws {
        try connection.run(
            """
            INSERT INTO training_history_details (
                history_id, action_id, set_number, weight, reps, left_weight, right_weight,
                is_completed, history_record_bilateral, rir
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            historyID,
            actionID,
            setNumber,
            weight,
            reps,
            leftWeight,
            rightWeight,
            isCompleted ? 1 : 0,
            isBilateral ? 1 : 0,
            rir
        )
    }
}

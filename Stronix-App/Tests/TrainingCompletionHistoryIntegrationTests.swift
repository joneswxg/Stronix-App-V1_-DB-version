import Combine
import SQLite
import XCTest
@testable import Stronix

final class TrainingCompletionHistoryIntegrationTests: XCTestCase {
    private var fixture: IsolatedDatabaseFixture!
    private var connection: Connection!
    private var owner: User!
    private var otherUser: User!
    private var currentUser: TestCurrentUser!
    private var planID: Int!
    private var squatID: Int!
    private var pressID: Int!

    override func setUpWithError() throws {
        fixture = try IsolatedDatabaseFixture()
        connection = try fixture.prepareRepositoryDatabase(named: "training-completion-history.db")
        owner = try TestUserFixture(username: "owner", email: "owner@example.com").insert(into: connection)
        otherUser = try TestUserFixture(username: "other", email: "other@example.com").insert(into: connection)
        currentUser = TestCurrentUser(user: owner)
        planID = try insertPlan(ownerID: owner.id, name: "Owner strength")
        squatID = try insertAction(externalID: "completion-squat", name: "Squat")
        pressID = try insertAction(externalID: "completion-press", name: "Press")
        try insertPlanContent()
    }

    override func tearDownWithError() throws {
        currentUser = nil
        connection = nil
        fixture.tearDown()
        fixture = nil
    }

    func testCompletedUserPlanBecomesReadableOwnerScopedHistory() async throws {
        let session = TrainingSessionManager()
        session.startTraining(with: makeTrainingPlan())
        var actions = session.editingActions
        actions[0].sets[0].rir = .one
        actions[0].sets[1].rir = .two
        actions[1].sets[0].rir = .threeOrMore
        session.updateActions(actions)
        session.completedSets = ["\(squatID!)_101", "\(pressID!)_201"]
        let viewModel = await makeViewModel(session: session, planWriter: ResultUserPlanWriter())

        let completed = await viewModel.saveHistoryOnly()

        XCTAssertTrue(completed)
        XCTAssertFalse(session.isTrainingActive)

        let reader = SQLiteTrainingHistoryRepository(connection: connection)
        let ownerPage = try reader.trainingHistory(query(ownerID: owner.id))
        XCTAssertEqual(ownerPage.histories.count, 1)

        let history = try XCTUnwrap(ownerPage.histories.first)
        XCTAssertEqual(history.plan_id, planID)
        XCTAssertEqual(history.plan_name, "Owner strength")
        XCTAssertEqual(history.volume, 652.5)
        XCTAssertEqual(history.duration, 0)

        let detail = try reader.trainingHistoryDetail(id: history.id, ownerID: owner.id)
        XCTAssertEqual(detail.actions.map(\.actionID), [squatID, pressID])
        XCTAssertEqual(detail.actions.map(\.name), ["Squat", "Press"])
        XCTAssertEqual(detail.actions[0].sets.map(\.leftWeight), [40, 45])
        XCTAssertEqual(detail.actions[0].sets.map(\.rightWeight), [42.5, 47.5])
        XCTAssertEqual(detail.actions[0].sets.map(\.isCompleted), [true, false])
        XCTAssertTrue(detail.actions[0].sets.allSatisfy(\.isBilateral))
        XCTAssertEqual(detail.actions[1].sets.map(\.weight), [30])
        XCTAssertEqual(detail.actions[1].sets.map(\.reps), [8])
        XCTAssertEqual(detail.actions[0].sets.map(\.rir), [.one, .two])
        XCTAssertEqual(detail.actions[1].sets.map(\.rir), [.threeOrMore])
        XCTAssertEqual(detail.actions[1].sets.map(\.isCompleted), [true])

        let otherPage = try reader.trainingHistory(query(ownerID: otherUser.id))
        XCTAssertTrue(otherPage.histories.isEmpty)
        XCTAssertThrowsError(try reader.trainingHistoryDetail(id: history.id, ownerID: otherUser.id)) {
            XCTAssertEqual($0 as? TrainingHistoryRepositoryError, .notFoundOrUnauthorized)
        }
    }

    func testHistoryWriteFailurePreservesActiveTrainingAndRetryCompletesOnce() async throws {
        let session = TrainingSessionManager()
        session.startTraining(with: makeTrainingPlan())
        session.completedSets = ["\(squatID!)_101"]
        try installHistoryDetailFailureTrigger()
        let viewModel = await makeViewModel(session: session, planWriter: ResultUserPlanWriter())

        let failed = await viewModel.saveHistoryOnly()

        XCTAssertFalse(failed)
        XCTAssertTrue(session.isTrainingActive)
        let failedCanRetry = await MainActor.run { viewModel.canRetryPlanUpdate }
        let failedError = await MainActor.run { viewModel.completionError }
        XCTAssertFalse(failedCanRetry)
        XCTAssertTrue(failedError?.hasPrefix("保存训练记录失败") == true)
        XCTAssertTrue(try SQLiteTrainingHistoryRepository(connection: connection).trainingHistory(query(ownerID: owner.id)).histories.isEmpty)

        try removeHistoryDetailFailureTrigger()
        let recovered = await viewModel.saveHistoryOnly()

        XCTAssertTrue(recovered)
        XCTAssertFalse(session.isTrainingActive)
        XCTAssertEqual(try SQLiteTrainingHistoryRepository(connection: connection).trainingHistory(query(ownerID: owner.id)).histories.count, 1)
    }

    func testPlanUpdateFailureRecoversAfterReconstructingCompletionCompositionWithoutDuplicateHistory() async throws {
        let session = TrainingSessionManager()
        session.startTraining(with: makeTrainingPlan())
        let editedActions = [
            MutableTrainingAction(
                id: squatID,
                name: "Squat",
                imageUrl: "",
                sets: [MutableTrainingSet(id: 101, weight: 0, reps: 6, leftWeight: 50, rightWeight: 52.5)],
                restTime: 120,
                recordBilateral: true
            )
        ]
        session.updateActions(editedActions)
        session.completedSets = ["\(squatID!)_101"]
        try installPlanSetFailureTrigger()
        let firstViewModel = await makeViewModel(session: session, planWriter: realPlanWriter())

        let failed = await firstViewModel.saveHistoryAndUpdatePlan()

        XCTAssertFalse(failed)
        XCTAssertTrue(session.isTrainingActive)
        let canRetryPlanUpdate = await MainActor.run { firstViewModel.canRetryPlanUpdate }
        let planUpdateError = await MainActor.run { firstViewModel.completionError }
        XCTAssertTrue(canRetryPlanUpdate)
        XCTAssertTrue(planUpdateError?.hasPrefix("训练记录已保存，更新训练计划失败") == true)
        let reader = SQLiteTrainingHistoryRepository(connection: connection)
        let historiesAfterFailure = try reader.trainingHistory(query(ownerID: owner.id)).histories
        XCTAssertEqual(historiesAfterFailure.count, 1)
        let planReader = LocalPlanService(
            connectionProvider: { [connection] in connection },
            authenticatedUserIDProvider: { [currentUser] in currentUser?.currentUserID }
        )
        let unchangedPlan = try await planReader.userPlanDetail(id: planID)
        XCTAssertEqual(unchangedPlan.actions?.flatMap(\.sets).map(\.reps), [5, 5, 8])

        try removePlanSetFailureTrigger()
        let reconstructedViewModel = await makeViewModel(session: session, planWriter: realPlanWriter())
        let recovered = await reconstructedViewModel.saveHistoryAndUpdatePlan()

        XCTAssertTrue(recovered)
        XCTAssertFalse(session.isTrainingActive)
        let historiesAfterRecovery = try reader.trainingHistory(query(ownerID: owner.id)).histories
        XCTAssertEqual(historiesAfterRecovery.map(\.id), historiesAfterFailure.map(\.id))
        let recoveredPlan = try await planReader.userPlanDetail(id: planID)
        XCTAssertEqual(recoveredPlan.actions?.map(\.id), [squatID])
        XCTAssertEqual(recoveredPlan.actions?.flatMap(\.sets).map(\.reps), [6])
        let detail = try reader.trainingHistoryDetail(id: try XCTUnwrap(historiesAfterRecovery.first).id, ownerID: owner.id)
        XCTAssertEqual(detail.actions.count, 1)
        XCTAssertEqual(detail.actions[0].sets.map(\.reps), [6])
    }

    func testSeparateTrainingSessionsForSamePlanCreateSeparateHistoryRecords() async throws {
        let firstSession = TrainingSessionManager()
        firstSession.startTraining(with: makeTrainingPlan())
        firstSession.completedSets = ["\(squatID!)_101"]
        let firstViewModel = await makeViewModel(session: firstSession, planWriter: ResultUserPlanWriter())
        let firstCompleted = await firstViewModel.saveHistoryOnly()
        XCTAssertTrue(firstCompleted)

        let secondSession = TrainingSessionManager()
        secondSession.startTraining(with: makeTrainingPlan())
        secondSession.completedSets = ["\(pressID!)_201"]
        let secondViewModel = await makeViewModel(session: secondSession, planWriter: ResultUserPlanWriter())
        let secondCompleted = await secondViewModel.saveHistoryOnly()
        XCTAssertTrue(secondCompleted)

        let histories = try SQLiteTrainingHistoryRepository(connection: connection).trainingHistory(query(ownerID: owner.id)).histories
        XCTAssertEqual(histories.count, 2)
        XCTAssertNotEqual(histories[0].id, histories[1].id)
    }

    private func makeUseCase(planWriter: any UserPlanWriting = ResultUserPlanWriter()) -> CompleteTrainingUseCase {
        let localService = LocalTrainingHistoryService(
            connectionProvider: { [connection] in connection },
            currentUserProvider: currentUser
        )
        return CompleteTrainingUseCase(
            historyPersistence: TrainingHistoryService(localService: localService),
            planWriter: planWriter
        )
    }

    @MainActor
    private func makeViewModel(
        session: any TrainingSessionManaging,
        planWriter: any UserPlanWriting
    ) -> TrainingViewModel {
        TrainingViewModel(session: session, completionUseCase: makeUseCase(planWriter: planWriter))
    }

    private func realPlanWriter() -> UserPlanWriter {
        UserPlanWriter(repository: LocalPlanService(
            connectionProvider: { [connection] in connection },
            authenticatedUserIDProvider: { [currentUser] in currentUser?.currentUserID }
        ))
    }

    private func makeTrainingPlan() -> TrainingPlan {
        TrainingPlan(
            id: planID,
            name: "Owner strength",
            creator: "User",
            createdDate: "2026-07-26T00:00:00Z",
            lastTraining: "2026-07-26T00:00:00Z",
            volume: 0,
            description: "Integrated completion",
            difficulty: "normal",
            duration: 45,
            actions: [
                TrainingAction(
                    id: squatID,
                    name: "Squat",
                    sets: [
                        TrainingSet(id: 101, weight: 0, reps: 5, leftWeight: 40, rightWeight: 42.5),
                        TrainingSet(id: 102, weight: 0, reps: 5, leftWeight: 45, rightWeight: 47.5)
                    ],
                    restTime: 90,
                    recordBilateral: true,
                    imageUrl: ""
                ),
                TrainingAction(
                    id: pressID,
                    name: "Press",
                    sets: [TrainingSet(id: 201, weight: 30, reps: 8)],
                    restTime: 60,
                    recordBilateral: false,
                    imageUrl: ""
                )
            ]
        )
    }

    private func query(ownerID: Int) -> TrainingHistoryListQuery {
        TrainingHistoryListQuery(
            ownerID: ownerID,
            page: TrainingHistoryPageRequest(page: 1, pageSize: 20),
            filter: TrainingHistoryFilter()
        )
    }

    private func insertPlan(ownerID: Int, name: String) throws -> Int {
        try connection.run(
            """
            INSERT INTO training_plans (user_id, name, description, difficulty, duration)
            VALUES (?, ?, 'Integrated completion', 'normal', 45)
            """,
            ownerID,
            name
        )
        return Int(connection.lastInsertRowid)
    }

    private func insertPlanContent() throws {
        try connection.run(
            """
            INSERT INTO plan_actions (plan_id, action_id, "order", sets, weight, rest, note, record_bilateral)
            VALUES (?, ?, 1, 2, 0, 90, NULL, 1), (?, ?, 2, 1, 30, 60, NULL, 0)
            """,
            planID,
            squatID,
            planID,
            pressID
        )
        try connection.run(
            """
            INSERT INTO plan_sets (plan_id, action_id, set_number, weight, reps, left_weight, right_weight)
            VALUES (?, ?, 1, 0, 5, 40, 42.5), (?, ?, 2, 0, 5, 45, 47.5), (?, ?, 1, 30, 8, 0, 0)
            """,
            planID,
            squatID,
            planID,
            squatID,
            planID,
            pressID
        )
    }

    private func installHistoryDetailFailureTrigger() throws {
        try connection.run(
            """
            CREATE TEMP TRIGGER fail_training_history_details_insert
            BEFORE INSERT ON training_history_details
            BEGIN
                SELECT RAISE(ABORT, 'forced history detail failure');
            END
            """
        )
    }

    private func removeHistoryDetailFailureTrigger() throws {
        try connection.run("DROP TRIGGER IF EXISTS fail_training_history_details_insert")
    }

    private func installPlanSetFailureTrigger() throws {
        try connection.run(
            """
            CREATE TEMP TRIGGER fail_plan_sets_insert
            BEFORE INSERT ON plan_sets
            BEGIN
                SELECT RAISE(ABORT, 'forced plan set failure');
            END
            """
        )
    }

    private func removePlanSetFailureTrigger() throws {
        try connection.run("DROP TRIGGER IF EXISTS fail_plan_sets_insert")
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

    private func assertCompleted(
        _ result: TrainingCompletionResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .completed = result else {
            return XCTFail("Expected completed result", file: file, line: line)
        }
    }
}

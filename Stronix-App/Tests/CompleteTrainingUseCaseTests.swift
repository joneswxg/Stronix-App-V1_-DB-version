import XCTest
@testable import Stronix

final class CompleteTrainingUseCaseTests: XCTestCase {
    func testHistoryOnlySavesHistoryWithoutUpdatingPlan() async {
        let history = ResultTrainingHistoryPersistence()
        let planUpdater = ResultUserPlanWriter()
        let useCase = CompleteTrainingUseCase(historyPersistence: history, planWriter: planUpdater)

        let result = await useCase.execute(snapshot: makeSnapshot(), choice: .historyOnly)

        XCTAssertCompleted(result)
        XCTAssertEqual(history.requests.count, 1)
        XCTAssertTrue(planUpdater.calls.isEmpty)
    }

    func testSaveHistoryAndUpdatePlanWritesHistoryBeforePlan() async {
        var events: [String] = []
        let history = ResultTrainingHistoryPersistence(onSave: { events.append("history") })
        let planUpdater = ResultUserPlanWriter(onWrite: { events.append("plan") })
        let useCase = CompleteTrainingUseCase(historyPersistence: history, planWriter: planUpdater)
        let snapshot = makeSnapshot()

        let result = await useCase.execute(snapshot: snapshot, choice: .saveHistoryAndUpdatePlan)

        XCTAssertCompleted(result)
        XCTAssertEqual(events, ["history", "plan"])
        XCTAssertEqual(planUpdater.calls.map(\.planID), [9])
        XCTAssertEqual(planUpdater.calls.first?.draft.name, "计划")
    }

    func testHistoryFailureDoesNotUpdatePlan() async {
        let history = ResultTrainingHistoryPersistence(result: .failure(TestError.failed))
        let planUpdater = ResultUserPlanWriter()
        let useCase = CompleteTrainingUseCase(historyPersistence: history, planWriter: planUpdater)

        let result = await useCase.execute(snapshot: makeSnapshot(), choice: .saveHistoryAndUpdatePlan)

        XCTAssertHistorySaveFailed(result)
        XCTAssertTrue(planUpdater.calls.isEmpty)
    }

    func testPlanFailureReturnsRecoverableResultAfterHistorySaved() async {
        let history = ResultTrainingHistoryPersistence()
        let planUpdater = ResultUserPlanWriter(result: .failure(TestError.failed))
        let useCase = CompleteTrainingUseCase(historyPersistence: history, planWriter: planUpdater)

        let result = await useCase.execute(snapshot: makeSnapshot(), choice: .saveHistoryAndUpdatePlan)

        XCTAssertPlanUpdateFailed(result)
        XCTAssertEqual(history.requests.count, 1)
        XCTAssertEqual(planUpdater.calls.count, 1)
    }

    func testHistoryOnlyDoesNotUpdateAvailablePlanDraft() async {
        let history = ResultTrainingHistoryPersistence()
        let planUpdater = ResultUserPlanWriter()
        let useCase = CompleteTrainingUseCase(historyPersistence: history, planWriter: planUpdater)

        let result = await useCase.execute(snapshot: makeSnapshot(), choice: .historyOnly)

        XCTAssertCompleted(result)
        XCTAssertTrue(planUpdater.calls.isEmpty)
    }

    func testRetryAfterPlanFailureDoesNotSaveHistoryAgain() async {
        let history = ResultTrainingHistoryPersistence()
        let planUpdater = ResultUserPlanWriter(results: [.failure(TestError.failed), .success(())])
        let useCase = CompleteTrainingUseCase(historyPersistence: history, planWriter: planUpdater)
        let snapshot = makeSnapshot()

        let firstResult = await useCase.execute(snapshot: snapshot, choice: .saveHistoryAndUpdatePlan)
        let retryResult = await useCase.execute(snapshot: snapshot, choice: .saveHistoryAndUpdatePlan)

        XCTAssertPlanUpdateFailed(firstResult)
        XCTAssertCompleted(retryResult)
        XCTAssertEqual(history.requests.count, 1)
        XCTAssertEqual(planUpdater.calls.count, 2)
    }

    private func makeSnapshot() -> TrainingCompletionSnapshot {
        TrainingCompletionSnapshot(
            historyRequest: SaveTrainingHistoryRequest(
                plan_id: 9,
                session_id: 1,
                plan_name: "计划",
                plan_description: nil,
                training_date: "2026-07-23T00:00:00Z",
                volume: 0,
                duration: 0,
                note: nil,
                details: []
            ),
            planID: 9,
            planDraft: PlanDraft(
                name: "计划",
                description: nil,
                difficulty: nil,
                duration: nil,
                actions: [
                    PlanActionDraft(
                        actionID: 1,
                        rest: 60,
                        note: nil,
                        recordBilateral: false,
                        sets: [PlanSetDraft(weight: 10, reps: 10, leftWeight: nil, rightWeight: nil, notes: nil)]
                    )
                ]
            )
        )
    }

    private func makePlan() -> TrainingPlan {
        TrainingPlan(id: 9, name: "计划", creator: "User", createdDate: "", lastTraining: "", volume: 0, description: nil, difficulty: nil, duration: nil, actions: [])
    }

    private func XCTAssertCompleted(_ result: TrainingCompletionResult, file: StaticString = #filePath, line: UInt = #line) {
        guard case .completed = result else {
            return XCTFail("Expected completion", file: file, line: line)
        }
    }

    private func XCTAssertHistorySaveFailed(_ result: TrainingCompletionResult, file: StaticString = #filePath, line: UInt = #line) {
        guard case .historySaveFailed = result else {
            return XCTFail("Expected history save failure", file: file, line: line)
        }
    }

    private func XCTAssertPlanUpdateFailed(_ result: TrainingCompletionResult, file: StaticString = #filePath, line: UInt = #line) {
        guard case .historySavedPlanUpdateFailed = result else {
            return XCTFail("Expected recoverable plan update failure", file: file, line: line)
        }
    }
}

private enum TestError: Error {
    case failed
}

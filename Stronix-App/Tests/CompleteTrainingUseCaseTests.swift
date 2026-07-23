import XCTest
@testable import Stronix

final class CompleteTrainingUseCaseTests: XCTestCase {
    func testHistoryOnlySavesHistoryWithoutUpdatingPlan() async {
        let history = HistoryPersistenceStub()
        let planUpdater = PlanWriterStub()
        let useCase = CompleteTrainingUseCase(historyPersistence: history, planWriter: planUpdater)

        let result = await useCase.execute(snapshot: makeSnapshot(), choice: .historyOnly)

        XCTAssertCompleted(result)
        XCTAssertEqual(history.requests.count, 1)
        XCTAssertTrue(planUpdater.calls.isEmpty)
    }

    func testSaveHistoryAndUpdatePlanWritesHistoryBeforePlan() async {
        var events: [String] = []
        let history = HistoryPersistenceStub { events.append("history") }
        let planUpdater = PlanWriterStub { events.append("plan") }
        let useCase = CompleteTrainingUseCase(historyPersistence: history, planWriter: planUpdater)
        let snapshot = makeSnapshot()

        let result = await useCase.execute(snapshot: snapshot, choice: .saveHistoryAndUpdatePlan)

        XCTAssertCompleted(result)
        XCTAssertEqual(events, ["history", "plan"])
        XCTAssertEqual(planUpdater.calls.map(\.planID), [9])
        XCTAssertEqual(planUpdater.calls.first?.draft.name, "计划")
    }

    func testHistoryFailureDoesNotUpdatePlan() async {
        let history = HistoryPersistenceStub(result: .failure(TestError.failed))
        let planUpdater = PlanWriterStub()
        let useCase = CompleteTrainingUseCase(historyPersistence: history, planWriter: planUpdater)

        let result = await useCase.execute(snapshot: makeSnapshot(), choice: .saveHistoryAndUpdatePlan)

        XCTAssertHistorySaveFailed(result)
        XCTAssertTrue(planUpdater.calls.isEmpty)
    }

    func testPlanFailureReturnsRecoverableResultAfterHistorySaved() async {
        let history = HistoryPersistenceStub()
        let planUpdater = PlanWriterStub(result: .failure(TestError.failed))
        let useCase = CompleteTrainingUseCase(historyPersistence: history, planWriter: planUpdater)

        let result = await useCase.execute(snapshot: makeSnapshot(), choice: .saveHistoryAndUpdatePlan)

        XCTAssertPlanUpdateFailed(result)
        XCTAssertEqual(history.requests.count, 1)
        XCTAssertEqual(planUpdater.calls.count, 1)
    }

    func testHistoryOnlyDoesNotUpdateAvailablePlanDraft() async {
        let history = HistoryPersistenceStub()
        let planUpdater = PlanWriterStub()
        let useCase = CompleteTrainingUseCase(historyPersistence: history, planWriter: planUpdater)

        let result = await useCase.execute(snapshot: makeSnapshot(), choice: .historyOnly)

        XCTAssertCompleted(result)
        XCTAssertTrue(planUpdater.calls.isEmpty)
    }

    func testRetryAfterPlanFailureDoesNotSaveHistoryAgain() async {
        let history = HistoryPersistenceStub()
        let planUpdater = PlanWriterStub(results: [.failure(TestError.failed), .success(())])
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

private final class HistoryPersistenceStub: TrainingHistoryPersisting {
    var requests: [SaveTrainingHistoryRequest] = []
    private let result: Result<SaveTrainingHistoryResponse, Error>
    private let onSave: () -> Void

    init(
        result: Result<SaveTrainingHistoryResponse, Error> = .success(SaveTrainingHistoryResponse(history_id: 1)),
        onSave: @escaping () -> Void = {}
    ) {
        self.result = result
        self.onSave = onSave
    }

    func saveTrainingHistory(_ request: SaveTrainingHistoryRequest) async throws -> SaveTrainingHistoryResponse {
        requests.append(request)
        onSave()
        return try result.get()
    }
}

private final class PlanWriterStub: UserPlanWriting {
    struct Call {
        let planID: Int
        let draft: PlanDraft
    }

    var calls: [Call] = []
    private var results: [Result<Void, Error>]
    private let onExecute: () -> Void

    init(
        result: Result<Void, Error> = .success(()),
        onExecute: @escaping () -> Void = {}
    ) {
        results = [result]
        self.onExecute = onExecute
    }

    init(results: [Result<Void, Error>]) {
        self.results = results
        onExecute = {}
    }

    func write(planID: Int, draft: PlanDraft) async throws {
        calls.append(Call(planID: planID, draft: draft))
        onExecute()
        try results.removeFirst().get()
    }
}

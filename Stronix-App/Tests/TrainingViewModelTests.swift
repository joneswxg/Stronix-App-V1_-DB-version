import XCTest
import Combine
@testable import Stronix

@MainActor
final class TrainingViewModelTests: XCTestCase {
    func testActionAndSetUpdatesRefreshSessionState() {
        let session = TrainingSessionMock(actions: [makeAction(id: 1, sets: [makeSet(id: 10)])])
        let viewModel = TrainingViewModel(session: session, completionUseCase: CompletionUseCaseStub())
        var updated = makeAction(id: 1, sets: [makeSet(id: 10, weight: 80), makeSet(id: 11)])
        updated.restTime = 90

        viewModel.updateActions([updated])
        viewModel.deleteAction(updated)

        XCTAssertEqual(session.updatedActionBatches.count, 1)
        XCTAssertEqual(session.updatedActionBatches[0][0].sets.count, 2)
        XCTAssertEqual(session.deletedActionIDs, [1])
    }

    func testSetCompletionAndVolumeSupportSingleAndBilateralActions() {
        let single = makeAction(id: 1, sets: [makeSet(id: 10, weight: 50, reps: 8)])
        let bilateral = MutableTrainingAction(
            id: 2,
            name: "哑铃划船",
            imageUrl: "",
            sets: [makeSet(id: 20, reps: 10, leftWeight: 20, rightWeight: 25)],
            restTime: 60,
            recordBilateral: true
        )
        let session = TrainingSessionMock(actions: [single, bilateral])
        let viewModel = TrainingViewModel(session: session, completionUseCase: CompletionUseCaseStub())

        viewModel.toggleSetCompletion(setID: "1_10", restTime: 60)
        viewModel.toggleSetCompletion(setID: "2_20", restTime: 60)

        XCTAssertEqual(session.completedSets, ["1_10", "2_20"])
        XCTAssertEqual(session.completedVolume(), 850)
        XCTAssertEqual(viewModel.volumeText, "850/850 kg")

        viewModel.toggleSetCompletion(setID: "1_10", restTime: 60)

        XCTAssertFalse(session.completedSets.contains("1_10"))
        XCTAssertNil(session.setRestTimers["1_10"])
        XCTAssertEqual(viewModel.volumeText, "450/850 kg")
    }

    func testPlanChangeAndRestStateAreForwarded() {
        let session = TrainingSessionMock(actions: [])
        session.planHasChanges = true
        session.showRestTimer = true
        session.currentRestTime = 45
        session.isRestTimerPaused = true
        let viewModel = TrainingViewModel(session: session, completionUseCase: CompletionUseCaseStub())

        viewModel.showRestTimer(for: "1_10", restTime: 60)
        viewModel.toggleRestTimer()
        viewModel.resetRestTimer()
        viewModel.addRestTime(10)
        viewModel.subtractRestTime(10)
        viewModel.skipRestTimer()
        viewModel.closeRestTimer()

        XCTAssertTrue(viewModel.hasPlanChanges())
        XCTAssertEqual(session.restTimerTappedIDs, ["1_10"])
        XCTAssertEqual(session.restControlCalls, ["toggle", "reset", "add:10", "subtract:10", "skip", "close"])
    }

    func testTerminalCompletionFinishesSession() async {
        let session = TrainingSessionMock(actions: [])
        let completionUseCase = CompletionUseCaseStub(results: [.completed])
        let viewModel = TrainingViewModel(session: session, completionUseCase: completionUseCase)

        let completed = await viewModel.saveHistoryOnly()

        XCTAssertTrue(completed)
        XCTAssertEqual(session.completeTrainingCalls, 1)
        XCTAssertEqual(completionUseCase.calls.map(\.choice), [.historyOnly])
    }

    func testHistoryFailurePreservesActiveSession() async {
        let session = TrainingSessionMock(actions: [])
        let completionUseCase = CompletionUseCaseStub(results: [.historySaveFailed(TestError.failed)])
        let viewModel = TrainingViewModel(session: session, completionUseCase: completionUseCase)

        let completed = await viewModel.saveHistoryOnly()

        XCTAssertFalse(completed)
        XCTAssertTrue(session.isTrainingActive)
        XCTAssertEqual(session.completeTrainingCalls, 0)
        XCTAssertNotNil(viewModel.completionError)
        XCTAssertFalse(viewModel.canRetryPlanUpdate)
    }

    func testPartialFailureRetriesStoredSnapshotBeforeFinishing() async {
        let session = TrainingSessionMock(actions: [])
        let completionUseCase = CompletionUseCaseStub(results: [
            .historySavedPlanUpdateFailed(TestError.failed),
            .completed
        ])
        let viewModel = TrainingViewModel(session: session, completionUseCase: completionUseCase)

        let firstCompletion = await viewModel.saveHistoryAndUpdatePlan()
        XCTAssertFalse(firstCompletion)
        XCTAssertTrue(viewModel.canRetryPlanUpdate)

        let retryCompletion = await viewModel.retryCompletion()

        XCTAssertTrue(retryCompletion)
        XCTAssertFalse(viewModel.canRetryPlanUpdate)
        XCTAssertEqual(session.completeTrainingCalls, 1)
        XCTAssertEqual(completionUseCase.calls.map(\.choice), [.saveHistoryAndUpdatePlan, .saveHistoryAndUpdatePlan])
        XCTAssertEqual(completionUseCase.calls[0].snapshot.id, completionUseCase.calls[1].snapshot.id)
    }

    private func makeAction(id: Int, sets: [MutableTrainingSet]) -> MutableTrainingAction {
        MutableTrainingAction(id: id, name: "深蹲", imageUrl: "", sets: sets, restTime: 60, recordBilateral: false)
    }

    private func makeSet(id: Int, weight: Double = 0, reps: Int = 10, leftWeight: Double = 0, rightWeight: Double = 0) -> MutableTrainingSet {
        MutableTrainingSet(id: id, weight: weight, reps: reps, leftWeight: leftWeight, rightWeight: rightWeight)
    }
}

private enum TestError: Error {
    case failed
}

@MainActor
private final class TrainingSessionMock: TrainingSessionManaging, ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    var isTrainingActive = true
    var currentPlan: TrainingPlan? = TrainingPlan(id: 9, name: "计划", creator: "User", createdDate: "", lastTraining: "", volume: 0, actions: [])
    var editingActions: [MutableTrainingAction]
    var completedSets: Set<String> = []
    var setNotes: [String: String] = [:]
    var planName = "计划"
    var setRestTimers: [String: Int] = [:]
    var showRestTimer = false
    var currentRestTime = 0
    var isRestTimerPaused = false
    var planHasChanges = false
    var updatedActionBatches: [[MutableTrainingAction]] = []
    var deletedActionIDs: [Int] = []
    var restTimerTappedIDs: [String] = []
    var restControlCalls: [String] = []
    var completeTrainingCalls = 0
    var completionSnapshot: TrainingCompletionSnapshot

    init(actions: [MutableTrainingAction]) {
        editingActions = actions
        completionSnapshot = TrainingCompletionSnapshot(
            historyRequest: SaveTrainingHistoryRequest(plan_id: 9, session_id: 1, plan_name: "计划", plan_description: nil, training_date: "2026-07-23T00:00:00Z", volume: 0, duration: 0, note: nil, details: []),
            planID: 9,
            planDraft: PlanDraft(name: "计划", actions: [PlanActionDraft(actionID: 1, sets: [PlanSetDraft(weight: 10, reps: 10)])])
        )
    }

    func startTraining(with plan: TrainingPlan) { currentPlan = plan; isTrainingActive = true }
    func stopTraining() { isTrainingActive = false }
    func completeTraining() { completeTrainingCalls += 1; isTrainingActive = false }
    func updateActions(_ actions: [MutableTrainingAction]) { editingActions = actions; updatedActionBatches.append(actions); objectWillChange.send() }
    func deleteAction(_ action: MutableTrainingAction) { deletedActionIDs.append(action.id); editingActions.removeAll { $0.id == action.id }; objectWillChange.send() }
    func toggleSetCompletion(setID: String, restTime: Int) {
        if !completedSets.insert(setID).inserted {
            completedSets.remove(setID)
            setRestTimers[setID] = nil
        } else {
            setRestTimers[setID] = restTime
        }
        objectWillChange.send()
    }
    func handleRestTimerTapped(setId: String, restTime: Int) { restTimerTappedIDs.append(setId); showRestTimer = true; currentRestTime = restTime; objectWillChange.send() }
    func toggleRestTimer() { restControlCalls.append("toggle") }
    func resetRestTimer() { restControlCalls.append("reset") }
    func skipRestTimer() { restControlCalls.append("skip") }
    func closeRestTimer() { restControlCalls.append("close") }
    func addRestTime(_ seconds: Int) { restControlCalls.append("add:\(seconds)") }
    func subtractRestTime(_ seconds: Int) { restControlCalls.append("subtract:\(seconds)") }
    func formattedTrainingTime() -> String { "00:00" }
    func completedVolume() -> Double { volume(completedOnly: true) }
    func totalVolume() -> Double { volume(completedOnly: false) }
    func captureCompletionSnapshot() -> TrainingCompletionSnapshot? { completionSnapshot }
    func hasChangesFromOriginalPlan() -> Bool { planHasChanges }

    private func volume(completedOnly: Bool) -> Double {
        editingActions.reduce(0) { total, action in
            total + action.sets.reduce(0) { subtotal, set in
                if completedOnly && !completedSets.contains("\(action.id)_\(set.id)") { return subtotal }
                return subtotal + (action.recordBilateral ? set.leftWeight + set.rightWeight : set.weight) * Double(set.reps)
            }
        }
    }
}

@MainActor
private final class CompletionUseCaseStub: CompleteTrainingExecuting {
    struct Call {
        let snapshot: TrainingCompletionSnapshot
        let choice: TrainingCompletionChoice
    }

    var calls: [Call] = []
    private var results: [TrainingCompletionResult]

    init(results: [TrainingCompletionResult] = [.completed]) {
        self.results = results
    }

    func execute(snapshot: TrainingCompletionSnapshot, choice: TrainingCompletionChoice) async -> TrainingCompletionResult {
        calls.append(Call(snapshot: snapshot, choice: choice))
        return results.removeFirst()
    }
}

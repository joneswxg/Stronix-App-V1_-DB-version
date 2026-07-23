import XCTest
import Combine
@testable import Stronix

@MainActor
final class TrainingViewModelTests: XCTestCase {
    func testActionAndSetUpdatesRefreshSessionState() {
        let session = TrainingSessionMock(actions: [makeAction(id: 1, sets: [makeSet(id: 10)])])
        let viewModel = TrainingViewModel(session: session, historySaver: TrainingHistorySaverStub())
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
        let viewModel = TrainingViewModel(session: session, historySaver: TrainingHistorySaverStub())

        viewModel.toggleSetCompletion(setID: "1_10", restTime: 60)
        viewModel.toggleSetCompletion(setID: "2_20", restTime: 60)

        XCTAssertEqual(session.completedSets, ["1_10", "2_20"])
        XCTAssertEqual(session.completedVolume(), 850)
        XCTAssertEqual(viewModel.volumeText, "850/850 kg")
    }

    func testPlanChangeAndRestStateAreForwarded() {
        let session = TrainingSessionMock(actions: [])
        session.planHasChanges = true
        session.showRestTimer = true
        session.currentRestTime = 45
        session.isRestTimerPaused = true
        let viewModel = TrainingViewModel(session: session, historySaver: TrainingHistorySaverStub())

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

    func testCompletionSavesHistoryUpdatesPlanAndFinishesSession() async {
        let session = TrainingSessionMock(actions: [])
        session.historyRequest = makeHistoryRequest()
        session.planUpdateRequest = makePlanUpdateRequest()
        let saver = TrainingHistorySaverStub()
        let viewModel = TrainingViewModel(session: session, historySaver: saver)

        let completed = await viewModel.saveHistoryAndUpdatePlan(planID: 9)

        XCTAssertTrue(completed)
        XCTAssertEqual(saver.savedRequests.count, 1)
        XCTAssertEqual(saver.updatedPlanIDs, [9])
        XCTAssertEqual(session.completeTrainingCalls, 1)
    }

    private func makeAction(id: Int, sets: [MutableTrainingSet]) -> MutableTrainingAction {
        MutableTrainingAction(id: id, name: "深蹲", imageUrl: "", sets: sets, restTime: 60, recordBilateral: false)
    }

    private func makeSet(id: Int, weight: Double = 0, reps: Int = 10, leftWeight: Double = 0, rightWeight: Double = 0) -> MutableTrainingSet {
        MutableTrainingSet(id: id, weight: weight, reps: reps, leftWeight: leftWeight, rightWeight: rightWeight)
    }

    private func makeHistoryRequest() -> SaveTrainingHistoryRequest {
        SaveTrainingHistoryRequest(plan_id: 9, session_id: 1, plan_name: "计划", plan_description: nil, training_date: "2026-07-23T00:00:00Z", volume: 0, duration: 0, note: nil, details: [])
    }

    private func makePlanUpdateRequest() -> UpdatePlanFromTrainingRequest {
        UpdatePlanFromTrainingRequest(name: "计划", description: nil, difficulty: nil, duration: nil, actions: [])
    }
}

@MainActor
private final class TrainingSessionMock: TrainingSessionManaging, ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    var isTrainingActive = true
    var currentPlan: TrainingPlan?
    var editingActions: [MutableTrainingAction]
    var completedSets: Set<String> = []
    var setNotes: [String: String] = [:]
    var planName = "计划"
    var setRestTimers: [String: Int] = [:]
    var showRestTimer = false
    var currentRestTime = 0
    var isRestTimerPaused = false
    var planHasChanges = false
    var historyRequest: SaveTrainingHistoryRequest?
    var planUpdateRequest: UpdatePlanFromTrainingRequest?
    var updatedActionBatches: [[MutableTrainingAction]] = []
    var deletedActionIDs: [Int] = []
    var restTimerTappedIDs: [String] = []
    var restControlCalls: [String] = []
    var completeTrainingCalls = 0

    init(actions: [MutableTrainingAction]) {
        editingActions = actions
    }

    func startTraining(with plan: TrainingPlan) { currentPlan = plan; isTrainingActive = true }
    func stopTraining() { isTrainingActive = false }
    func completeTraining() { completeTrainingCalls += 1; isTrainingActive = false }
    func updateActions(_ actions: [MutableTrainingAction]) { editingActions = actions; updatedActionBatches.append(actions); objectWillChange.send() }
    func deleteAction(_ action: MutableTrainingAction) { deletedActionIDs.append(action.id); editingActions.removeAll { $0.id == action.id }; objectWillChange.send() }
    func handleSetCompleted(setId: String, restTime: Int) { setRestTimers[setId] = restTime; objectWillChange.send() }
    func toggleSetCompletion(setID: String, restTime: Int) { if !completedSets.insert(setID).inserted { completedSets.remove(setID) }; objectWillChange.send() }
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
    func prepareTrainingHistoryData() -> SaveTrainingHistoryRequest? { historyRequest }
    func preparePlanUpdateData() -> UpdatePlanFromTrainingRequest? { planUpdateRequest }
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

private final class TrainingHistorySaverStub: TrainingHistorySaving {
    var savedRequests: [SaveTrainingHistoryRequest] = []
    var updatedPlanIDs: [Int] = []

    func saveTrainingHistory(_ request: SaveTrainingHistoryRequest) async throws -> SaveTrainingHistoryResponse {
        savedRequests.append(request)
        return SaveTrainingHistoryResponse(history_id: 1)
    }

    func updatePlanFromTraining(planId: Int, request: UpdatePlanFromTrainingRequest) async throws {
        updatedPlanIDs.append(planId)
    }
}

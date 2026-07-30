import XCTest
import Combine
@testable import Stronix

@MainActor
final class TrainingViewModelTests: XCTestCase {
    func testBilateralRecordingCopiesScalarWeightsAndRestoresLeftWeightWithoutErasingSides() {
        var action = makeAction(id: 1, sets: [
            makeSet(id: 10, weight: 50, leftWeight: 5, rightWeight: 6),
            makeSet(id: 11, weight: 60, leftWeight: 7, rightWeight: 8)
        ])

        action.setRecordBilateral(true)

        XCTAssertTrue(action.recordBilateral)
        XCTAssertEqual(action.sets.map(\.weight), [50, 60])
        XCTAssertEqual(action.sets.map(\.leftWeight), [50, 60])
        XCTAssertEqual(action.sets.map(\.rightWeight), [50, 60])

        action.sets[0].leftWeight = 55
        action.sets[0].rightWeight = 65
        action.setRecordBilateral(false)

        XCTAssertFalse(action.recordBilateral)
        XCTAssertEqual(action.sets[0].weight, 55)
        XCTAssertEqual(action.sets[0].leftWeight, 55)
        XCTAssertEqual(action.sets[0].rightWeight, 65)
    }

    func testKeyboardCommandsStayScopedToTheSelectedActionAndPreserveCompletionAndNotes() {
        let first = makeAction(id: 1, sets: [makeSet(id: 10, weight: 20, reps: 8), makeSet(id: 11, weight: 30, reps: 10)])
        let second = makeAction(id: 2, sets: [makeSet(id: 20, weight: 80, reps: 5)])
        let session = TrainingSessionMock(actions: [first, second])
        session.completedSets = ["1_10"]
        session.setNotes = ["1_10": "keep"]
        let viewModel = TrainingViewModel(session: session, completionUseCase: CompletionUseCaseStub())

        viewModel.selectField(id: "weight_1_10", inAction: 1)
        viewModel.fillCurrentAction()

        XCTAssertEqual(viewModel.editingActions[0].sets.map(\.weight), [20, 20])
        XCTAssertEqual(viewModel.editingActions[1].sets.map(\.weight), [80])
        XCTAssertEqual(session.completedSets, ["1_10"])
        XCTAssertEqual(session.setNotes, ["1_10": "keep"])
        XCTAssertEqual(session.updatedActionBatches.count, 1)
    }

    func testBilateralFillCopiesBothSidesAndRepetitionsFillIndependently() {
        var action = makeAction(id: 1, sets: [
            makeSet(id: 10, reps: 8, leftWeight: 20, rightWeight: 25),
            makeSet(id: 11, reps: 10, leftWeight: 30, rightWeight: 35)
        ])
        action.recordBilateral = true
        let session = TrainingSessionMock(actions: [action])
        let viewModel = TrainingViewModel(session: session, completionUseCase: CompletionUseCaseStub())

        viewModel.selectField(id: "left_1_10", inAction: 1)
        viewModel.fillCurrentAction()
        XCTAssertEqual(viewModel.editingActions[0].sets.map(\.leftWeight), [20, 20])
        XCTAssertEqual(viewModel.editingActions[0].sets.map(\.rightWeight), [25, 25])

        viewModel.selectField(id: "reps_1_11", inAction: 1)
        viewModel.fillCurrentAction()
        XCTAssertEqual(viewModel.editingActions[0].sets.map(\.reps), [10, 10])
    }

    func testKeyboardAddSetClonesActiveActionFinalSetAndSelectsIt() {
        var action = makeAction(id: 1, sets: [makeSet(id: 10, weight: 50, reps: 8, leftWeight: 22, rightWeight: 25)])
        action.recordBilateral = true
        let other = makeAction(id: 2, sets: [makeSet(id: 20, weight: 80)])
        let session = TrainingSessionMock(actions: [action, other])
        let viewModel = TrainingViewModel(session: session, completionUseCase: CompletionUseCaseStub())

        viewModel.selectField(id: "right_1_10", inAction: 1)
        viewModel.addSetToCurrentAction()

        let added = try! XCTUnwrap(viewModel.editingActions[0].sets.last)
        XCTAssertEqual(viewModel.editingActions[0].sets.count, 2)
        XCTAssertEqual(added.weight, 50)
        XCTAssertEqual(added.reps, 8)
        XCTAssertEqual(added.leftWeight, 22)
        XCTAssertEqual(added.rightWeight, 25)
        XCTAssertEqual(viewModel.editingActions[1].sets.count, 1)
        XCTAssertEqual(viewModel.currentFieldID, "right_1_21")
        XCTAssertFalse(session.completedSets.contains("1_\(added.id)"))
        XCTAssertNil(session.setNotes["1_\(added.id)"])
    }

    func testKeyboardAddSetUsesDefaultsForAnEmptyAction() {
        let action = makeAction(id: 1, sets: [])
        let session = TrainingSessionMock(actions: [action])
        let viewModel = TrainingViewModel(session: session, completionUseCase: CompletionUseCaseStub())

        viewModel.selectField(id: "weight_1_0", inAction: 1)
        viewModel.addSetToCurrentAction()

        XCTAssertEqual(viewModel.editingActions[0].sets.map(\.weight), [10])
        XCTAssertEqual(viewModel.editingActions[0].sets.map(\.reps), [12])
        XCTAssertEqual(viewModel.currentFieldID, "weight_1_1")
    }

    func testTrainingDisplayUnitPersistsDuringSessionAndConvertsInputBackToKilograms() {
        let session = TrainingSessionMock(actions: [makeAction(id: 1, sets: [makeSet(id: 10, weight: 10)]), makeAction(id: 2, sets: [makeSet(id: 20, weight: 20)])])
        let viewModel = TrainingViewModel(session: session, completionUseCase: CompletionUseCaseStub())

        viewModel.toggleTrainingDisplayUnit()
        let pounds = viewModel.displayValue(forKilograms: 10)
        viewModel.selectField(id: "weight_2_20", inAction: 2)

        XCTAssertEqual(viewModel.trainingDisplayUnit, .pounds)
        XCTAssertEqual(pounds, 22.0462, accuracy: 0.00001)
        XCTAssertEqual(viewModel.kilogramsValue(fromDisplay: pounds), 10, accuracy: 0.0000001)

        session.trainingDisplayUnit = .kilograms
        viewModel.updateActions(session.editingActions)
        XCTAssertEqual(viewModel.trainingDisplayUnit, .kilograms)
    }

    func testTrainingSessionResetsDisplayUnitWhenItEndsAndRestarts() {
        let manager = TrainingSessionManager()
        let plan = TrainingPlan(id: 9, name: "计划", creator: "User", createdDate: "", lastTraining: "", volume: 0, isTemplate: false, actions: [TrainingAction(id: 1, name: "深蹲", sets: [TrainingSet(id: 10, weight: 10, reps: 10)], restTime: 60, notes: nil, recordBilateral: false, imageUrl: "")])

        manager.startTraining(with: plan)
        manager.trainingDisplayUnit = .pounds
        manager.stopTraining()

        XCTAssertEqual(manager.trainingDisplayUnit, .kilograms)

        manager.startTraining(with: plan)
        XCTAssertEqual(manager.trainingDisplayUnit, .kilograms)
    }

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

    func testSelectingActionsAndFieldsMaintainsAnExclusiveEditingTarget() {
        var first = makeAction(id: 1, sets: [makeSet(id: 10, weight: 50, reps: 8)])
        var second = makeAction(id: 2, sets: [makeSet(id: 20, weight: 80, reps: 5)])
        first.restTime = 45
        second.restTime = 90
        let session = TrainingSessionMock(actions: [first, second])
        session.completedSets = ["1_10"]
        session.setNotes = ["1_10": "控制节奏"]
        let viewModel = TrainingViewModel(session: session, completionUseCase: CompletionUseCaseStub())

        XCTAssertEqual(viewModel.currentActionID, 1)
        XCTAssertNil(viewModel.currentFieldID)

        viewModel.selectField(id: "weight_2_20", inAction: 2)

        XCTAssertEqual(viewModel.currentActionID, 2)
        XCTAssertEqual(viewModel.currentFieldID, "weight_2_20")
        XCTAssertEqual(viewModel.editingActions.map(\.id), [1, 2])
        XCTAssertEqual(viewModel.editingActions.map(\.sets.first?.weight), [50, 80])
        XCTAssertEqual(viewModel.editingActions.map(\.restTime), [45, 90])
        XCTAssertEqual(viewModel.completedSets, ["1_10"])
        XCTAssertEqual(viewModel.setNotes, ["1_10": "控制节奏"])

        viewModel.selectAction(id: 1)

        XCTAssertEqual(viewModel.currentActionID, 1)
        XCTAssertNil(viewModel.currentFieldID)
        XCTAssertEqual(viewModel.editingActions.map(\.id), [1, 2])
        XCTAssertEqual(viewModel.editingActions.map(\.sets.first?.weight), [50, 80])
        XCTAssertEqual(viewModel.editingActions.map(\.restTime), [45, 90])

        viewModel.selectField(id: "weight_99_99", inAction: 99)

        XCTAssertEqual(viewModel.currentActionID, 1)
        XCTAssertNil(viewModel.currentFieldID)
    }

    func testDeletingCurrentActionSelectsFirstRemainingAction() {
        let first = makeAction(id: 1, sets: [makeSet(id: 10)])
        let second = makeAction(id: 2, sets: [makeSet(id: 20)])
        let session = TrainingSessionMock(actions: [first, second])
        let viewModel = TrainingViewModel(session: session, completionUseCase: CompletionUseCaseStub())

        viewModel.selectField(id: "weight_2_20", inAction: 2)
        viewModel.deleteAction(second)

        XCTAssertEqual(viewModel.currentActionID, 1)
        XCTAssertNil(viewModel.currentFieldID)
    }

    func testKeyboardViewportPrefersTheFollowingActionHeaderWhenAvailable() {
        XCTAssertEqual(
            TrainingKeyboardViewportTarget(actionIDs: [1, 2, 3], activeActionID: 2, activeInputID: "weight_2_20"),
            .actionHeader(3)
        )
    }

    func testKeyboardViewportKeepsTheActiveInputVisibleForTheFinalAction() {
        XCTAssertEqual(
            TrainingKeyboardViewportTarget(actionIDs: [1, 2], activeActionID: 2, activeInputID: "reps_2_20"),
            .input("reps_2_20")
        )
    }

    func testKeyboardViewportFallsBackToTheActiveInputWhenTheActionIsUnknown() {
        XCTAssertEqual(
            TrainingKeyboardViewportTarget(actionIDs: [1, 2], activeActionID: 3, activeInputID: "weight_3_30"),
            .input("weight_3_30")
        )
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
    var trainingDisplayUnit: TrainingDisplayUnit = .kilograms
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

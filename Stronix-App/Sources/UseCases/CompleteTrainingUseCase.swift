import Foundation

protocol TrainingHistoryPersisting {
    func saveTrainingHistory(_ request: SaveTrainingHistoryRequest) async throws -> SaveTrainingHistoryResponse
}

struct TrainingCompletionSnapshot: Identifiable {
    let id: UUID
    let historyRequest: SaveTrainingHistoryRequest
    let planID: Int
    let planDraft: PlanDraft?

    init(
        id: UUID = UUID(),
        historyRequest: SaveTrainingHistoryRequest,
        planID: Int,
        planDraft: PlanDraft?
    ) {
        self.id = id
        self.historyRequest = historyRequest
        self.planID = planID
        self.planDraft = planDraft
    }
}

enum TrainingCompletionChoice {
    case historyOnly
    case saveHistoryAndUpdatePlan
}

enum TrainingCompletionResult {
    case completed
    case historySaveFailed(Error)
    case historySavedPlanUpdateFailed(Error)
    case planUpdateUnavailable
}

protocol CompleteTrainingExecuting: AnyObject {
    func execute(
        snapshot: TrainingCompletionSnapshot,
        choice: TrainingCompletionChoice
    ) async -> TrainingCompletionResult
}

final class CompleteTrainingUseCase: CompleteTrainingExecuting {
    private let historyPersistence: any TrainingHistoryPersisting
    private let planUpdater: any UpdatePlanExecuting
    private var savedHistorySnapshotIDs: Set<UUID> = []

    init(
        historyPersistence: any TrainingHistoryPersisting,
        planUpdater: any UpdatePlanExecuting
    ) {
        self.historyPersistence = historyPersistence
        self.planUpdater = planUpdater
    }

    func execute(
        snapshot: TrainingCompletionSnapshot,
        choice: TrainingCompletionChoice
    ) async -> TrainingCompletionResult {
        if !savedHistorySnapshotIDs.contains(snapshot.id) {
            do {
                _ = try await historyPersistence.saveTrainingHistory(snapshot.historyRequest)
                savedHistorySnapshotIDs.insert(snapshot.id)
            } catch {
                return .historySaveFailed(error)
            }
        }

        guard choice == .saveHistoryAndUpdatePlan else {
            return .completed
        }

        guard let planDraft = snapshot.planDraft else {
            return .planUpdateUnavailable
        }

        do {
            _ = try await planUpdater.execute(planID: snapshot.planID, draft: planDraft)
            return .completed
        } catch {
            return .historySavedPlanUpdateFailed(error)
        }
    }
}

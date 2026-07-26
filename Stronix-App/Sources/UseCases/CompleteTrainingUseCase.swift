import Foundation

protocol TrainingHistoryPersisting {
    /// Persists history idempotently for the authenticated owner and request session_id.
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
        self.historyRequest = historyRequest.withSessionID(Self.sessionID(for: id))
        self.planID = planID
        self.planDraft = planDraft
    }

    static func sessionID(for id: UUID) -> Int {
        let offsetBasis: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211
        let hash = id.uuidString.utf8.reduce(offsetBasis) { partial, byte in
            (partial ^ UInt64(byte)) &* prime
        }
        return Int(hash & 0x3FFF_FFFF_FFFF_FFFF) + 10_000
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

protocol UserPlanWriting {
    func write(planID: Int, draft: PlanDraft) async throws
}

struct UserPlanWriter: UserPlanWriting {
    private let repository: any PlanRepository

    init(repository: any PlanRepository) {
        self.repository = repository
    }

    func write(planID: Int, draft: PlanDraft) async throws {
        try draft.validate()
        try await repository.updateUserPlan(id: planID, planData: UpdatePlanRequest(draft: draft))
    }
}

protocol CompleteTrainingExecuting: AnyObject {
    func execute(
        snapshot: TrainingCompletionSnapshot,
        choice: TrainingCompletionChoice
    ) async -> TrainingCompletionResult
}

final class CompleteTrainingUseCase: CompleteTrainingExecuting {
    private let historyPersistence: any TrainingHistoryPersisting
    private let planWriter: any UserPlanWriting

    init(
        historyPersistence: any TrainingHistoryPersisting,
        planWriter: any UserPlanWriting
    ) {
        self.historyPersistence = historyPersistence
        self.planWriter = planWriter
    }

    func execute(
        snapshot: TrainingCompletionSnapshot,
        choice: TrainingCompletionChoice
    ) async -> TrainingCompletionResult {
        do {
            _ = try await historyPersistence.saveTrainingHistory(snapshot.historyRequest)
        } catch {
            return .historySaveFailed(error)
        }

        guard choice == .saveHistoryAndUpdatePlan else {
            return .completed
        }

        guard let planDraft = snapshot.planDraft else {
            return .planUpdateUnavailable
        }

        do {
            try await planWriter.write(planID: snapshot.planID, draft: planDraft)
            return .completed
        } catch {
            return .historySavedPlanUpdateFailed(error)
        }
    }
}

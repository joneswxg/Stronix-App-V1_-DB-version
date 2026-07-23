import Foundation

protocol UpdatePlanExecuting {
    func execute(planID: Int, draft: PlanDraft) async throws -> TrainingPlan
}

struct UpdatePlanUseCase: UpdatePlanExecuting {
    private let repository: any PlanRepository

    init(repository: any PlanRepository) {
        self.repository = repository
    }

    func execute(planID: Int, draft: PlanDraft) async throws -> TrainingPlan {
        try draft.validate()
        try await repository.updateUserPlan(
            id: planID,
            planData: UpdatePlanRequest(draft: draft)
        )
        return try await repository.userPlanDetail(id: planID)
    }
}

extension UpdatePlanRequest {
    init(draft: PlanDraft) {
        self.init(
            name: draft.name,
            description: draft.description,
            difficulty: draft.difficulty,
            duration: draft.duration,
            actions: draft.actions.enumerated().map { actionIndex, action in
                UpdatePlanAction(
                    action_id: action.actionID,
                    order: actionIndex + 1,
                    rest: action.rest,
                    note: action.note,
                    record_bilateral: action.recordBilateral,
                    sets: action.sets.enumerated().map { setIndex, set in
                        UpdatePlanSet(
                            order: setIndex + 1,
                            weight: set.weight,
                            reps: set.reps,
                            left_weight: set.leftWeight,
                            right_weight: set.rightWeight,
                            notes: set.notes
                        )
                    }
                )
            }
        )
    }
}

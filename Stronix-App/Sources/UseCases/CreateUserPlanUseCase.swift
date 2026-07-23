import Foundation

final class CreateUserPlanUseCase {
    private let repository: any PlanRepository

    init(repository: any PlanRepository) {
        self.repository = repository
    }

    func execute(_ draft: PlanDraft) async throws -> CreatePlanResponse {
        try await repository.createUserPlan(draft)
    }
}

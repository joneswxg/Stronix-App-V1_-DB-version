import Foundation

final class CopyTemplatePlanUseCase {
    private let repository: any PlanRepository

    init(repository: any PlanRepository) {
        self.repository = repository
    }

    func execute(templatePlanID: Int) async throws -> CreatePlanResponse {
        try await repository.copyTemplatePlan(id: templatePlanID)
    }
}

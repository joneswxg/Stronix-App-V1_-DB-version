import XCTest
@testable import Stronix

final class CopyTemplatePlanUseCaseTests: XCTestCase {
    func testExecuteCopiesRequestedTemplateAndReturnsCreatedPlanID() async throws {
        let repository = CopyTemplatePlanRepositorySpy(
            copyResult: .success(CreatePlanResponse(plan_id: 42))
        )
        let useCase = CopyTemplatePlanUseCase(repository: repository)

        let result = try await useCase.execute(templatePlanID: 7)

        XCTAssertEqual(repository.copiedTemplateIDs, [7])
        XCTAssertEqual(result.plan_id, 42)
    }
}

private final class CopyTemplatePlanRepositorySpy: PlanRepository {
    let copyResult: Result<CreatePlanResponse, Error>
    private(set) var copiedTemplateIDs: [Int] = []

    init(copyResult: Result<CreatePlanResponse, Error>) {
        self.copyResult = copyResult
    }

    func templatePlans() async throws -> [TrainingPlan] { [] }
    func templatePlanDetail(id: Int) async throws -> TrainingPlan { fatalError("Not used by this test") }
    func userPlans() async throws -> [TrainingPlan] { [] }
    func userPlanDetail(id: Int) async throws -> TrainingPlan { fatalError("Not used by this test") }

    func copyTemplatePlan(id: Int) async throws -> CreatePlanResponse {
        copiedTemplateIDs.append(id)
        return try copyResult.get()
    }

    func createUserPlan(_ draft: PlanDraft) async throws -> CreatePlanResponse { fatalError("Not used by this test") }
    func updateUserPlan(id: Int, planData: UpdatePlanRequest) async throws { fatalError("Not used by this test") }
    func deleteUserPlan(id: Int) async throws { fatalError("Not used by this test") }
}

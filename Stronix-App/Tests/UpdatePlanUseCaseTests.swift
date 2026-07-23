import XCTest
@testable import Stronix

final class UpdatePlanUseCaseTests: XCTestCase {
    func testExecutePersistsOrderedDraftAndReturnsCanonicalUserPlan() async throws {
        let savedPlan = makePlan(id: 42, name: "保存后的计划")
        let repository = UpdatePlanRepositoryStub(detailResult: .success(savedPlan))
        let useCase = UpdatePlanUseCase(repository: repository)
        let draft = PlanDraft(
            name: "修改后的计划",
            description: "新的描述",
            difficulty: "高级",
            duration: 45,
            actions: [
                PlanActionDraft(
                    actionID: 11,
                    rest: 90,
                    note: "动作备注",
                    recordBilateral: false,
                    sets: [
                        PlanSetDraft(weight: 60, reps: 8),
                        PlanSetDraft(weight: 65, reps: 6)
                    ]
                )
            ]
        )

        let result = try await useCase.execute(planID: 42, draft: draft)

        XCTAssertEqual(result.id, savedPlan.id)
        XCTAssertEqual(result.name, savedPlan.name)
        XCTAssertEqual(repository.updatedPlanID, 42)
        XCTAssertEqual(repository.detailPlanID, 42)
        XCTAssertEqual(repository.updatedRequest?.name, "修改后的计划")
        XCTAssertEqual(repository.updatedRequest?.description, "新的描述")
        XCTAssertEqual(repository.updatedRequest?.difficulty, "高级")
        XCTAssertEqual(repository.updatedRequest?.duration, 45)
        XCTAssertEqual(repository.updatedRequest?.actions.count, 1)
        XCTAssertEqual(repository.updatedRequest?.actions.first?.action_id, 11)
        XCTAssertEqual(repository.updatedRequest?.actions.first?.order, 1)
        XCTAssertEqual(repository.updatedRequest?.actions.first?.rest, 90)
        XCTAssertEqual(repository.updatedRequest?.actions.first?.sets.map(\.order), [1, 2])
        XCTAssertEqual(repository.updatedRequest?.actions.first?.sets.map(\.weight), [60, 65])
        XCTAssertEqual(repository.updatedRequest?.actions.first?.sets.map(\.reps), [8, 6])
    }

    func testExecuteRejectsInvalidDraftWithoutUpdatingRepository() async {
        let repository = UpdatePlanRepositoryStub(detailResult: .failure(TestError.unused))
        let useCase = UpdatePlanUseCase(repository: repository)
        let draft = PlanDraft(name: "", actions: [])

        do {
            _ = try await useCase.execute(planID: 42, draft: draft)
            XCTFail("Expected validation failure")
        } catch let error as LocalPlanError {
            guard case .planNameEmpty = error else {
                return XCTFail("Expected empty plan name error, got \(error)")
            }
        } catch {
            XCTFail("Expected LocalPlanError, got \(error)")
        }

        XCTAssertNil(repository.updatedPlanID)
        XCTAssertNil(repository.detailPlanID)
    }

    func testExecutePropagatesRepositoryUpdateFailureWithoutLoadingDetail() async {
        let repository = UpdatePlanRepositoryStub(detailResult: .failure(TestError.unused))
        repository.updateResult = .failure(DatabaseError.notReady)
        let useCase = UpdatePlanUseCase(repository: repository)
        let draft = PlanDraft(
            name: "有效计划",
            actions: [PlanActionDraft(actionID: 1, sets: [PlanSetDraft(weight: 10, reps: 10)])]
        )

        do {
            _ = try await useCase.execute(planID: 42, draft: draft)
            XCTFail("Expected repository failure")
        } catch is DatabaseError {
        } catch {
            XCTFail("Expected DatabaseError, got \(error)")
        }

        XCTAssertEqual(repository.updatedPlanID, 42)
        XCTAssertNil(repository.detailPlanID)
    }

    private func makePlan(id: Int, name: String) -> TrainingPlan {
        TrainingPlan(
            id: id,
            name: name,
            creator: "我",
            createdDate: "2026-07-23T00:00:00Z",
            lastTraining: "未开始",
            volume: 0,
            description: nil,
            isTemplate: false,
            templateId: nil,
            difficulty: nil,
            duration: nil,
            actions: []
        )
    }
}

private enum TestError: Error {
    case unused
}

private final class UpdatePlanRepositoryStub: PlanRepository {
    var detailResult: Result<TrainingPlan, Error>
    var updateResult: Result<Void, Error> = .success(())
    private(set) var updatedPlanID: Int?
    private(set) var updatedRequest: UpdatePlanRequest?
    private(set) var detailPlanID: Int?

    init(detailResult: Result<TrainingPlan, Error>) {
        self.detailResult = detailResult
    }

    func templatePlans() async throws -> [TrainingPlan] { [] }
    func templatePlanDetail(id: Int) async throws -> TrainingPlan { throw TestError.unused }
    func userPlans() async throws -> [TrainingPlan] { [] }

    func userPlanDetail(id: Int) async throws -> TrainingPlan {
        detailPlanID = id
        return try detailResult.get()
    }

    func createUserPlan(_ draft: PlanDraft) async throws -> CreatePlanResponse { throw TestError.unused }
    func copyTemplatePlan(id: Int) async throws -> CreatePlanResponse { throw TestError.unused }

    func updateUserPlan(id: Int, planData: UpdatePlanRequest) async throws {
        updatedPlanID = id
        updatedRequest = planData
        try updateResult.get()
    }

    func deleteUserPlan(id: Int) async throws { throw TestError.unused }
}

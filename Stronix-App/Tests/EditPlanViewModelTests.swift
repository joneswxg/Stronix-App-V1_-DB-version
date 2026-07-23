import XCTest
@testable import Stronix

@MainActor
final class EditPlanViewModelTests: XCTestCase {
    func testSaveReturnsSafeErrorAndPreservesEditableDraft() async {
        let source = makePlan(id: 7, name: "原计划")
        let useCase = UpdatePlanUseCaseStub(result: .failure(DatabaseError.notReady))
        let viewModel = EditPlanViewModel(plan: source, updatePlan: useCase)
        viewModel.name = "修改后的计划"
        viewModel.actions = [
            EditPlanAction(
                id: 99,
                actionId: 3,
                name: "深蹲",
                imageUrl: "",
                restTime: 120,
                note: "保留输入",
                recordBilateral: false,
                isExpanded: false,
                sets: [EditPlanSet(id: 100, order: 1, weight: 80, reps: 5, leftWeight: 0, rightWeight: 0)]
            )
        ]

        await viewModel.save()

        XCTAssertFalse(viewModel.isSaving)
        XCTAssertNil(viewModel.savedPlan)
        XCTAssertEqual(viewModel.errorMessage, "数据暂时无法读取，请稍后重试")
        XCTAssertEqual(viewModel.name, "修改后的计划")
        XCTAssertEqual(viewModel.actions.count, 1)
        XCTAssertEqual(viewModel.actions[0].actionId, 3)
        XCTAssertEqual(viewModel.actions[0].restTime, 120)
        XCTAssertEqual(viewModel.actions[0].sets[0].weight, 80)
        XCTAssertEqual(useCase.receivedPlanID, source.id)
        XCTAssertEqual(useCase.receivedDraft?.actions.count, 1)
    }

    func testSaveReturnsCanonicalPlanAfterActionRemovalAndSetChanges() async {
        let source = makePlan(id: 7, name: "原计划")
        let saved = makePlan(id: 7, name: "已保存计划")
        let useCase = UpdatePlanUseCaseStub(result: .success(saved))
        let viewModel = EditPlanViewModel(plan: source, updatePlan: useCase)
        viewModel.name = "新名称"
        viewModel.actions = [
            EditPlanAction(
                id: 99,
                actionId: 3,
                name: "深蹲",
                imageUrl: "",
                restTime: 75,
                note: "",
                recordBilateral: true,
                isExpanded: false,
                sets: [
                    EditPlanSet(id: 100, order: 1, weight: 0, reps: 8, leftWeight: 40, rightWeight: 45),
                    EditPlanSet(id: 101, order: 2, weight: 0, reps: 6, leftWeight: 50, rightWeight: 55)
                ]
            )
        ]

        await viewModel.save()

        XCTAssertEqual(viewModel.savedPlan?.name, "已保存计划")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(useCase.receivedDraft?.name, "新名称")
        XCTAssertEqual(useCase.receivedDraft?.actions.map(\.actionID), [3])
        XCTAssertEqual(useCase.receivedDraft?.actions.first?.rest, 75)
        XCTAssertEqual(useCase.receivedDraft?.actions.first?.sets.map(\.reps), [8, 6])
        XCTAssertEqual(useCase.receivedDraft?.actions.first?.sets.map(\.leftWeight), [40, 50])
        XCTAssertEqual(useCase.receivedDraft?.actions.first?.sets.map(\.rightWeight), [45, 55])
    }

    func testSaveMapsMissingPlanToSafeErrorWithoutLosingInput() async {
        let source = makePlan(id: 7, name: "原计划")
        let useCase = UpdatePlanUseCaseStub(
            result: .failure(LocalPlanError.planNotFound("SELECT * FROM training_plans WHERE id = 7"))
        )
        let viewModel = EditPlanViewModel(plan: source, updatePlan: useCase)
        viewModel.name = "仍需保留的名称"

        await viewModel.save()

        XCTAssertEqual(viewModel.errorMessage, "请求的数据不存在")
        XCTAssertFalse(viewModel.errorMessage?.contains("SELECT") ?? true)
        XCTAssertEqual(viewModel.name, "仍需保留的名称")
        XCTAssertNil(viewModel.savedPlan)
    }

    func testFailedResaveClearsPreviousSavedPlanAndRetainsInput() async {
        let source = makePlan(id: 7, name: "原计划")
        let saved = makePlan(id: 7, name: "已保存计划")
        let useCase = UpdatePlanUseCaseStub(result: .success(saved))
        let viewModel = EditPlanViewModel(plan: source, updatePlan: useCase)

        await viewModel.save()
        useCase.result = .failure(LocalPlanError.permissionDenied("forbidden"))
        viewModel.name = "失败后保留的名称"
        await viewModel.save()

        XCTAssertNil(viewModel.savedPlan)
        XCTAssertEqual(viewModel.errorMessage, "无权限执行此操作")
        XCTAssertEqual(viewModel.name, "失败后保留的名称")
    }

    private func makePlan(id: Int, name: String) -> TrainingPlan {
        TrainingPlan(
            id: id,
            name: name,
            creator: "我",
            createdDate: "2026-07-23T00:00:00Z",
            lastTraining: "未开始",
            volume: 0,
            description: "描述",
            isTemplate: false,
            templateId: nil,
            difficulty: "初级",
            duration: 30,
            actions: []
        )
    }
}

private final class UpdatePlanUseCaseStub: UpdatePlanExecuting {
    var result: Result<TrainingPlan, Error>
    private(set) var receivedPlanID: Int?
    private(set) var receivedDraft: PlanDraft?

    init(result: Result<TrainingPlan, Error>) {
        self.result = result
    }

    func execute(planID: Int, draft: PlanDraft) async throws -> TrainingPlan {
        receivedPlanID = planID
        receivedDraft = draft
        return try result.get()
    }
}

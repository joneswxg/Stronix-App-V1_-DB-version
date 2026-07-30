import XCTest
@testable import Stronix

@MainActor
final class CreatePlanViewModelTests: XCTestCase {
    func testSaveSubmitsTypedDraftAndPublishesResult() async {
        let repository = CreatePlanMockRepository(createResult: .success(CreatePlanResponse(plan_id: 42)))
        let viewModel = CreatePlanViewModel(useCase: CreateUserPlanUseCase(repository: repository))
        populateValidForm(on: viewModel)

        await viewModel.save()

        XCTAssertEqual(repository.createdDraft, makeExpectedDraft())
        XCTAssertEqual(viewModel.savedPlanID, 42)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isSaving)
    }

    func testSaveMapsFailuresAndPreservesFormState() async {
        let cases: [(Error, String)] = [
            (LocalPlanError.planNameEmpty("内部校验信息"), "提交的数据无效，请检查后重试"),
            (LocalPlanError.unauthorized("SQLite at /tmp/stronix.db"), "请先登录后重试"),
            (LocalPlanError.permissionDenied("用户不属于此计划"), "无权限执行此操作"),
            (DatabaseError.notReady, "数据暂时无法读取，请稍后重试"),
            (CreatePlanTestError.repositoryFailure, "暂时无法完成请求，请稍后重试")
        ]

        for (error, expectedMessage) in cases {
            let repository = CreatePlanMockRepository(createResult: .failure(error))
            let viewModel = CreatePlanViewModel(useCase: CreateUserPlanUseCase(repository: repository))
            populateValidForm(on: viewModel)
            let expectedDraft = makeExpectedDraft()

            await viewModel.save()

            XCTAssertEqual(repository.createdDraft, expectedDraft)
            XCTAssertEqual(viewModel.errorMessage, expectedMessage)
            XCTAssertNil(viewModel.savedPlanID)
            XCTAssertFalse(viewModel.isSaving)
            XCTAssertEqual(viewModel.planName, "力量计划")
            XCTAssertEqual(viewModel.planNote, "每周三次")
            XCTAssertEqual(viewModel.selectedActions.count, 2)
        }
    }

    func testSaveCanRetryPreservedFormState() async {
        let repository = CreatePlanMockRepository(createResult: .failure(LocalPlanError.unauthorized("未登录")))
        let viewModel = CreatePlanViewModel(useCase: CreateUserPlanUseCase(repository: repository))
        populateValidForm(on: viewModel)
        let expectedDraft = makeExpectedDraft()

        await viewModel.save()
        repository.createResult = .success(CreatePlanResponse(plan_id: 43))

        await viewModel.save()

        XCTAssertEqual(repository.createdDrafts, [expectedDraft, expectedDraft])
        XCTAssertEqual(viewModel.savedPlanID, 43)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testCustomKeyboardHideCommitsValueAndClearsActiveState() {
        let manager = CustomKeyboardManager()
        var receivedValues: [Double] = []
        manager.showKeyboard(inputId: "reps_1", initialValue: 8, isInteger: true) {
            receivedValues.append($0)
        }
        manager.updateValue(12)

        manager.hideKeyboard()

        XCTAssertEqual(receivedValues, [12, 12])
        XCTAssertEqual(manager.activeInputId, "")
        XCTAssertFalse(manager.isValueSelected)
        XCTAssertFalse(manager.isShowing)
    }

    func testCustomKeyboardCancelClearsTrainingRail() {
        let manager = CustomKeyboardManager()
        manager.showKeyboard(
            inputId: "weight_1_10",
            initialValue: 10,
            trainingKeyboardRail: TrainingKeyboardRail(
                isBilateralRecording: { false },
                displayUnit: { .kilograms },
                onToggleBilateral: {},
                onFill: {},
                onToggleDisplayUnit: {},
                onAddSet: {}
            ),
            onValueChanged: { _ in }
        )

        manager.cancelKeyboard()

        XCTAssertNil(manager.trainingKeyboardRail)
        XCTAssertFalse(manager.isShowing)
    }

    private func populateValidForm(on viewModel: CreatePlanViewModel) {
        viewModel.planName = "力量计划"
        viewModel.planNote = "每周三次"
        viewModel.selectedActions = [
            PlanAction(
                id: 1,
                actionId: 7,
                name: "深蹲",
                imageUrl: "squat.gif",
                nameEn: "Squat",
                bodyPartId: 1,
                equipmentId: 2,
                targetMuscleIds: [3],
                sets: [
                    PlanSet(weight: 80, reps: 5, notes: "热身"),
                    PlanSet(leftWeight: 12, rightWeight: 14, reps: 8)
                ],
                restTime: 90,
                notes: "保持动作标准",
                isLeftRightMode: false
            ),
            PlanAction(
                id: 2,
                actionId: 9,
                name: "单臂划船",
                imageUrl: "row.gif",
                nameEn: "Row",
                bodyPartId: 4,
                equipmentId: 5,
                targetMuscleIds: [6],
                sets: [PlanSet(leftWeight: 20, rightWeight: 22, reps: 10, notes: "双侧")],
                restTime: 60,
                notes: "控制节奏",
                isLeftRightMode: true
            )
        ]
    }

    private func makeExpectedDraft() -> PlanDraft {
        PlanDraft(
            name: "力量计划",
            description: "每周三次",
            actions: [
                PlanActionDraft(
                    actionID: 7,
                    rest: 90,
                    note: "保持动作标准",
                    recordBilateral: false,
                    sets: [
                        PlanSetDraft(weight: 80, reps: 5, notes: "热身"),
                        PlanSetDraft(weight: 0, reps: 8)
                    ]
                ),
                PlanActionDraft(
                    actionID: 9,
                    rest: 60,
                    note: "控制节奏",
                    recordBilateral: true,
                    sets: [PlanSetDraft(reps: 10, leftWeight: 20, rightWeight: 22, notes: "双侧")]
                )
            ]
        )
    }
}

private enum CreatePlanTestError: Error {
    case repositoryFailure
}

private final class CreatePlanMockRepository: PlanRepository {
    var createResult: Result<CreatePlanResponse, Error>
    var createdDraft: PlanDraft?
    var createdDrafts: [PlanDraft] = []

    init(createResult: Result<CreatePlanResponse, Error>) {
        self.createResult = createResult
    }

    func templatePlans() async throws -> [TrainingPlan] { [] }
    func templatePlanDetail(id: Int) async throws -> TrainingPlan { fatalError("Not used by this test") }
    func userPlans() async throws -> [TrainingPlan] { [] }
    func userPlanDetail(id: Int) async throws -> TrainingPlan { fatalError("Not used by this test") }
    func copyTemplatePlan(id: Int) async throws -> CreatePlanResponse { fatalError("Not used by this test") }

    func createUserPlan(_ draft: PlanDraft) async throws -> CreatePlanResponse {
        createdDraft = draft
        createdDrafts.append(draft)
        return try createResult.get()
    }

    func updateUserPlan(id: Int, planData: UpdatePlanRequest) async throws { fatalError("Not used by this test") }
    func deleteUserPlan(id: Int) async throws { fatalError("Not used by this test") }
}

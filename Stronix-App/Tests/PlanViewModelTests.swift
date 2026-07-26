import XCTest
@testable import Stronix

@MainActor
final class PlanViewModelTests: XCTestCase {
    func testInitialLoadPopulatesTemplateAndUserPlans() async {
        let template = makePlan(id: 1, name: "模板计划", isTemplate: true)
        let userPlan = makePlan(id: 2, name: "我的计划", isTemplate: false)
        let repository = MockPlanRepository(
            templatePlansResult: .success([template]),
            userPlansResult: .success([userPlan])
        )
        let viewModel = PlanViewModel(repository: repository)

        XCTAssertEqual(repository.templatePlansCallCount, 0)
        XCTAssertEqual(repository.userPlansCallCount, 0)

        await viewModel.loadInitialData()

        XCTAssertEqual(viewModel.templatePlans.map(\.id), [template.id])
        XCTAssertEqual(viewModel.personalPlans.map(\.id), [userPlan.id])
        XCTAssertEqual(repository.templatePlansCallCount, 1)
        XCTAssertEqual(repository.userPlansCallCount, 1)
        XCTAssertFalse(viewModel.isLoadingTemplates)
        XCTAssertFalse(viewModel.isLoadingPersonal)
        XCTAssertFalse(viewModel.showError)
    }

    func testInitialLoadDoesNotReloadAfterSuccessfulLoad() async {
        let repository = MockPlanRepository(
            templatePlansResult: .success([]),
            userPlansResult: .success([])
        )
        let viewModel = PlanViewModel(repository: repository)

        await viewModel.loadInitialData()
        await viewModel.loadInitialData()

        XCTAssertEqual(repository.templatePlansCallCount, 1)
        XCTAssertEqual(repository.userPlansCallCount, 1)
    }

    func testReturningToPlanListKeepsLoadedPlansWithoutReloading() async {
        let template = makePlan(id: 1, name: "模板计划", isTemplate: true)
        let userPlan = makePlan(id: 2, name: "我的计划", isTemplate: false)
        let repository = MockPlanRepository(
            templatePlansResult: .success([template]),
            userPlansResult: .success([userPlan])
        )
        let viewModel = PlanViewModel(repository: repository)

        await viewModel.loadInitialData()
        await viewModel.loadInitialData()

        XCTAssertEqual(viewModel.templatePlans.map(\.id), [template.id])
        XCTAssertEqual(viewModel.personalPlans.map(\.id), [userPlan.id])
        XCTAssertEqual(repository.templatePlansCallCount, 1)
        XCTAssertEqual(repository.userPlansCallCount, 1)
    }

    func testConcurrentInitialLoadsShareOneRepositoryRequest() async {
        let repository = MockPlanRepository(
            templatePlansResult: .success([]),
            userPlansResult: .success([]),
            delayNanoseconds: 100_000_000
        )
        let viewModel = PlanViewModel(repository: repository)

        async let firstLoad: Void = viewModel.loadInitialData()
        async let secondLoad: Void = viewModel.loadInitialData()
        await firstLoad
        await secondLoad

        XCTAssertEqual(repository.templatePlansCallCount, 1)
        XCTAssertEqual(repository.userPlansCallCount, 1)
    }

    func testInitialLoadSupportsEmptyPlans() async {
        let repository = MockPlanRepository(
            templatePlansResult: .success([]),
            userPlansResult: .success([])
        )
        let viewModel = PlanViewModel(repository: repository)

        await viewModel.loadInitialData()

        XCTAssertTrue(viewModel.templatePlans.isEmpty)
        XCTAssertTrue(viewModel.personalPlans.isEmpty)
        XCTAssertFalse(viewModel.showError)
    }

    func testInitialLoadShowsUserSafeErrorForUnauthorizedUserPlans() async {
        let template = makePlan(id: 1, name: "模板计划", isTemplate: true)
        let repository = MockPlanRepository(
            templatePlansResult: .success([template]),
            userPlansResult: .failure(LocalPlanError.unauthorized("未登录"))
        )
        let viewModel = PlanViewModel(repository: repository)

        await viewModel.loadInitialData()

        XCTAssertEqual(viewModel.templatePlans.map(\.id), [template.id])
        XCTAssertTrue(viewModel.personalPlans.isEmpty)
        XCTAssertTrue(viewModel.showError)
        XCTAssertEqual(viewModel.errorMessage, "加载个人计划失败: 请先登录后重试")
    }

    func testInitialLoadMapsUnauthorizedPlanErrorToCanonicalMessage() async {
        let repository = MockPlanRepository(
            templatePlansResult: .success([]),
            userPlansResult: .failure(LocalPlanError.unauthorized("SQLite error near SELECT at /tmp/stronix.db from LocalPlanService"))
        )
        let viewModel = PlanViewModel(repository: repository)

        await viewModel.loadInitialData()

        XCTAssertEqual(viewModel.errorMessage, "加载个人计划失败: 请先登录后重试")
        XCTAssertFalse(viewModel.errorMessage?.contains("SQLite") ?? true)
        XCTAssertFalse(viewModel.errorMessage?.contains("SELECT") ?? true)
        XCTAssertFalse(viewModel.errorMessage?.contains("/tmp/stronix.db") ?? true)
        XCTAssertFalse(viewModel.errorMessage?.contains("LocalPlanService") ?? true)
    }

    func testInitialLoadMapsDatabaseErrorToSafeMessage() async {
        let repository = MockPlanRepository(
            templatePlansResult: .failure(DatabaseError.notReady),
            userPlansResult: .success([])
        )
        let viewModel = PlanViewModel(repository: repository)

        await viewModel.loadInitialData()

        XCTAssertEqual(viewModel.errorMessage, "加载模板计划失败: 数据暂时无法读取，请稍后重试")
    }

    func testClearDataIgnoresACompletedCancelledLoad() async {
        let template = makePlan(id: 1, name: "模板计划", isTemplate: true)
        let userPlan = makePlan(id: 2, name: "我的计划", isTemplate: false)
        let repository = SuspendingPlanRepository(
            templatePlans: [template],
            userPlans: [userPlan]
        )
        let viewModel = PlanViewModel(repository: repository)

        let load = Task { @MainActor in
            await viewModel.loadInitialData()
        }
        await fulfillment(
            of: [repository.templateRequestStarted, repository.userRequestStarted],
            timeout: 1
        )
        viewModel.clearData()
        repository.completeRequests()
        await load.value

        XCTAssertTrue(viewModel.templatePlans.isEmpty)
        XCTAssertTrue(viewModel.personalPlans.isEmpty)
    }

    func testInitialLoadHidesRepositoryImplementationErrors() async {
        let repository = MockPlanRepository(
            templatePlansResult: .failure(TestError.repositoryFailure),
            userPlansResult: .success([])
        )
        let viewModel = PlanViewModel(repository: repository)

        await viewModel.loadInitialData()

        XCTAssertTrue(viewModel.showError)
        XCTAssertEqual(viewModel.errorMessage, "加载模板计划失败: 暂时无法完成请求，请稍后重试")
        XCTAssertFalse(viewModel.isLoadingTemplates)
        XCTAssertFalse(viewModel.isLoadingPersonal)
    }

    func testRefreshReloadsBothPlanLists() async {
        let firstTemplate = makePlan(id: 1, name: "旧模板", isTemplate: true)
        let firstUserPlan = makePlan(id: 2, name: "旧计划", isTemplate: false)
        let refreshedTemplate = makePlan(id: 3, name: "新模板", isTemplate: true)
        let refreshedUserPlan = makePlan(id: 4, name: "新计划", isTemplate: false)
        let repository = MockPlanRepository(
            templatePlansResult: .success([firstTemplate]),
            userPlansResult: .success([firstUserPlan])
        )
        let viewModel = PlanViewModel(repository: repository)

        await viewModel.loadInitialData()
        repository.templatePlansResult = .success([refreshedTemplate])
        repository.userPlansResult = .success([refreshedUserPlan])

        await viewModel.refresh()

        XCTAssertEqual(viewModel.templatePlans.map(\.id), [refreshedTemplate.id])
        XCTAssertEqual(viewModel.personalPlans.map(\.id), [refreshedUserPlan.id])
        XCTAssertEqual(repository.templatePlansCallCount, 2)
        XCTAssertEqual(repository.userPlansCallCount, 2)
    }

    func testCopyTemplateRefreshesPersonalPlans() async {
        let template = makePlan(id: 1, name: "模板计划", isTemplate: true)
        let copiedPlan = makePlan(id: 2, name: "模板计划 - 副本", isTemplate: false)
        let repository = MockPlanRepository(
            templatePlansResult: .success([template]),
            userPlansResult: .success([]),
            copyTemplatePlanResult: .success(CreatePlanResponse(plan_id: copiedPlan.id))
        )
        let viewModel = PlanViewModel(repository: repository)
        repository.userPlansResult = .success([copiedPlan])

        await viewModel.copyTemplatePlan(template)

        XCTAssertEqual(repository.copiedTemplateIDs, [template.id])
        XCTAssertEqual(viewModel.lastCopiedUserPlanID, copiedPlan.id)
        XCTAssertEqual(viewModel.personalPlans.map(\.id), [copiedPlan.id])
        XCTAssertEqual(repository.userPlansCallCount, 1)
    }

    func testCopyTemplateMapsFailuresToUserSafeStateWithoutRefreshingPlans() async {
        let template = makePlan(id: 1, name: "模板计划", isTemplate: true)
        let failures: [(Error, String)] = [
            (LocalPlanError.templateNotFound("missing"), "请求的数据不存在"),
            (LocalPlanError.unauthorized("SQLite failure at /tmp/stronix.db"), "请先登录后重试"),
            (LocalPlanError.permissionDenied("forbidden"), "无权限执行此操作"),
            (DatabaseError.notReady, "数据暂时无法读取，请稍后重试"),
            (TestError.repositoryFailure, "暂时无法完成请求，请稍后重试")
        ]

        for (error, message) in failures {
            let repository = MockPlanRepository(
                templatePlansResult: .success([template]),
                userPlansResult: .success([]),
                copyTemplatePlanResult: .failure(error)
            )
            let viewModel = PlanViewModel(repository: repository)

            await viewModel.copyTemplatePlan(template)

            XCTAssertEqual(viewModel.errorMessage, "复制模板计划失败: \(message)")
            XCTAssertTrue(viewModel.showError)
            XCTAssertNil(viewModel.lastCopiedUserPlanID)
            XCTAssertEqual(repository.userPlansCallCount, 0)
        }
    }
    func testCopyPersonalPlanSubmitsTypedDraft() async {
        let source = TrainingPlan(
            id: 7,
            name: "原计划",
            creator: "我",
            createdDate: "2026-07-22T00:00:00Z",
            lastTraining: "未开始",
            volume: 0,
            description: "描述",
            isTemplate: false,
            templateId: nil,
            difficulty: "advanced",
            duration: 45,
            actions: [
                TrainingAction(
                    id: 2,
                    name: "双侧动作",
                    sets: [TrainingSet(id: 1, weight: 0, reps: 8, leftWeight: 10, rightWeight: 12, notes: "组备注")],
                    restTime: 75,
                    notes: "备注",
                    recordBilateral: true,
                    imageUrl: ""
                )
            ]
        )
        let repository = MockPlanRepository(
            templatePlansResult: .success([]),
            userPlansResult: .success([]),
            userPlanDetailResult: .success(source),
            createUserPlanResult: .success(CreatePlanResponse(plan_id: 8))
        )
        let viewModel = PlanViewModel(repository: repository)

        await viewModel.copyPersonalPlan(source, newName: "副本")

        XCTAssertEqual(
            repository.createdDraft,
            PlanDraft(
                name: "副本",
                description: "描述",
                difficulty: "advanced",
                duration: 45,
                actions: [
                    PlanActionDraft(
                        actionID: 2,
                        rest: 75,
                        note: "备注",
                        recordBilateral: true,
                        sets: [PlanSetDraft(weight: 0, reps: 8, leftWeight: 10, rightWeight: 12, notes: "组备注")]
                    )
                ]
            )
        )
    }

    private func makePlan(id: Int, name: String, isTemplate: Bool) -> TrainingPlan {
        TrainingPlan(
            id: id,
            name: name,
            creator: isTemplate ? "系统模板" : "我",
            createdDate: "2026-07-22T00:00:00Z",
            lastTraining: "未开始",
            volume: 0,
            description: nil,
            isTemplate: isTemplate,
            templateId: nil,
            difficulty: nil,
            duration: nil,
            actions: []
        )
    }
}

private enum TestError: Error {
    case repositoryFailure
}

private final class SuspendingPlanRepository: PlanRepository, @unchecked Sendable {
    let templateRequestStarted = XCTestExpectation(description: "template plans request started")
    let userRequestStarted = XCTestExpectation(description: "user plans request started")

    private let storedTemplatePlans: [TrainingPlan]
    private let storedUserPlans: [TrainingPlan]
    private let lock = NSLock()
    private var templateContinuation: CheckedContinuation<[TrainingPlan], Error>?
    private var userContinuation: CheckedContinuation<[TrainingPlan], Error>?

    init(templatePlans: [TrainingPlan], userPlans: [TrainingPlan]) {
        storedTemplatePlans = templatePlans
        storedUserPlans = userPlans
    }

    func templatePlans() async throws -> [TrainingPlan] {
        templateRequestStarted.fulfill()
        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock { templateContinuation = continuation }
        }
    }

    func userPlans() async throws -> [TrainingPlan] {
        userRequestStarted.fulfill()
        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock { userContinuation = continuation }
        }
    }

    func completeRequests() {
        let continuations = lock.withLock { () -> (
            CheckedContinuation<[TrainingPlan], Error>?,
            CheckedContinuation<[TrainingPlan], Error>?
        ) in
            defer {
                templateContinuation = nil
                userContinuation = nil
            }
            return (templateContinuation, userContinuation)
        }
        continuations.0?.resume(returning: storedTemplatePlans)
        continuations.1?.resume(returning: storedUserPlans)
    }

    func templatePlanDetail(id: Int) async throws -> TrainingPlan { storedTemplatePlans[0] }
    func userPlanDetail(id: Int) async throws -> TrainingPlan { storedUserPlans[0] }
    func copyTemplatePlan(id: Int) async throws -> CreatePlanResponse { CreatePlanResponse(plan_id: 0) }
    func createUserPlan(_ draft: PlanDraft) async throws -> CreatePlanResponse { CreatePlanResponse(plan_id: 0) }
    func updateUserPlan(id: Int, planData: UpdatePlanRequest) async throws {}
    func deleteUserPlan(id: Int) async throws {}
}

private final class MockPlanRepository: PlanRepository {
    var templatePlansResult: Result<[TrainingPlan], Error>
    var userPlansResult: Result<[TrainingPlan], Error>
    var copyTemplatePlanResult: Result<CreatePlanResponse, Error>
    var userPlanDetailResult: Result<TrainingPlan, Error>
    var createUserPlanResult: Result<CreatePlanResponse, Error>
    var createdDraft: PlanDraft?
    var templatePlansCallCount = 0
    var userPlansCallCount = 0
    var copiedTemplateIDs: [Int] = []
    var delayNanoseconds: UInt64

    init(
        templatePlansResult: Result<[TrainingPlan], Error>,
        userPlansResult: Result<[TrainingPlan], Error>,
        copyTemplatePlanResult: Result<CreatePlanResponse, Error> = .success(CreatePlanResponse(plan_id: 0)),
        userPlanDetailResult: Result<TrainingPlan, Error> = .failure(TestError.repositoryFailure),
        createUserPlanResult: Result<CreatePlanResponse, Error> = .success(CreatePlanResponse(plan_id: 0)),
        delayNanoseconds: UInt64 = 0
    ) {
        self.templatePlansResult = templatePlansResult
        self.userPlansResult = userPlansResult
        self.copyTemplatePlanResult = copyTemplatePlanResult
        self.userPlanDetailResult = userPlanDetailResult
        self.createUserPlanResult = createUserPlanResult
        self.delayNanoseconds = delayNanoseconds
    }

    func templatePlans() async throws -> [TrainingPlan] {
        templatePlansCallCount += 1
        await waitIfNeeded()
        return try templatePlansResult.get()
    }

    func userPlans() async throws -> [TrainingPlan] {
        userPlansCallCount += 1
        await waitIfNeeded()
        return try userPlansResult.get()
    }

    func templatePlanDetail(id: Int) async throws -> TrainingPlan {
        fatalError("Not used by this test")
    }

    func userPlanDetail(id: Int) async throws -> TrainingPlan {
        try userPlanDetailResult.get()
    }

    func copyTemplatePlan(id: Int) async throws -> CreatePlanResponse {
        copiedTemplateIDs.append(id)
        return try copyTemplatePlanResult.get()
    }

    func createUserPlan(_ draft: PlanDraft) async throws -> CreatePlanResponse {
        createdDraft = draft
        return try createUserPlanResult.get()
    }

    func updateUserPlan(id: Int, planData: UpdatePlanRequest) async throws {
        fatalError("Not used by this test")
    }

    func deleteUserPlan(id: Int) async throws {
        fatalError("Not used by this test")
    }

    private func waitIfNeeded() async {
        guard delayNanoseconds > 0 else { return }
        try? await Task.sleep(nanoseconds: delayNanoseconds)
    }
}

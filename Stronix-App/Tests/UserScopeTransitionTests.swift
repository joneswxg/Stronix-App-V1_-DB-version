import XCTest
@testable import Stronix

@MainActor
final class UserScopeTransitionTests: XCTestCase {
    override func tearDown() async throws {
        CurrentUserContext.shared.update(nil)
    }

    func testUserAToLogoutToUserBClearsAllNamedProtectedStateBeforeNewScopeLoads() async throws {
        let userA = scopeUser(id: 101, email: "user-a@example.com")
        let userB = scopeUser(id: 202, email: "user-b@example.com")
        let operations = ScopeAuthenticationOperations(restoredUser: userA, loggedInUser: userB)

        let planViewModel = PlanViewModel(
            repository: ScopePlanRepository(
                templatePlans: [scopePlan(id: 1, name: "Template A", isTemplate: true)],
                userPlans: [scopePlan(id: 2, name: "User A Plan", isTemplate: false)]
            )
        )
        let bodyViewModel = BodyMeasurementViewModel(
            operations: ScopeBodyMeasurementOperations(measurements: [scopeMeasurement(id: 3)])
        )
        let trainingManager = TrainingSessionManager()
        let historyRepository = ScopeHistoryRepository(
            dates: TrainingHistoryDates(
                dates: ["2026-07-26"],
                range: TrainingHistoryDateRange(startDate: "2026-07-01", endDate: "2026-07-31")
            ),
            page: scopeHistoryPage(),
            detail: scopeHistoryDetail()
        )
        let calendarViewModel = HistoryCalendarViewModel(repository: historyRepository)
        let listViewModel = HistoryListViewModel(repository: historyRepository)
        let detailViewModel = TrainingHistoryDetailViewModel(repository: historyRepository)
        let orderingResetter = ScopeOrderingResetter()
        let session = UserSession(
            operations: operations,
            resetters: [
                orderingResetter,
                planViewModel,
                trainingManager,
                calendarViewModel,
                listViewModel,
                detailViewModel,
                bodyViewModel
            ]
        )
        orderingResetter.session = session

        await session.restore()
        await planViewModel.loadInitialData()
        await bodyViewModel.loadMeasurements()
        bodyViewModel.showAddSheet()
        trainingManager.startTraining(with: scopePlan(id: 2, name: "User A Plan", isTemplate: false))
        await calendarViewModel.load(date: scopeDate(), ownerID: userA.id)
        await listViewModel.load(query: scopeHistoryQuery(ownerID: userA.id))
        await detailViewModel.load(historyID: 50, ownerID: userA.id)

        let scopeBeforeLogout = session.scopeID
        try await session.logout()

        XCTAssertEqual(orderingResetter.observedUserIDsDuringReset, [userA.id])
        XCTAssertEqual(session.state, .unauthenticated)
        XCTAssertNil(CurrentUserContext.shared.currentUserID)
        XCTAssertEqual(session.scopeID, scopeBeforeLogout + 1)
        assertCleared(
            planViewModel: planViewModel,
            bodyViewModel: bodyViewModel,
            trainingManager: trainingManager,
            calendarViewModel: calendarViewModel,
            listViewModel: listViewModel,
            detailViewModel: detailViewModel
        )

        try await session.login(email: userB.email, password: "secure-password")

        XCTAssertEqual(session.state, .authenticated(userB))
        XCTAssertEqual(CurrentUserContext.shared.currentUserID, userB.id)
        XCTAssertEqual(session.scopeID, scopeBeforeLogout + 1)
        assertCleared(
            planViewModel: planViewModel,
            bodyViewModel: bodyViewModel,
            trainingManager: trainingManager,
            calendarViewModel: calendarViewModel,
            listViewModel: listViewModel,
            detailViewModel: detailViewModel
        )
    }

    private func assertCleared(
        planViewModel: PlanViewModel,
        bodyViewModel: BodyMeasurementViewModel,
        trainingManager: TrainingSessionManager,
        calendarViewModel: HistoryCalendarViewModel,
        listViewModel: HistoryListViewModel,
        detailViewModel: TrainingHistoryDetailViewModel
    ) {
        XCTAssertTrue(planViewModel.templatePlans.isEmpty)
        XCTAssertTrue(planViewModel.personalPlans.isEmpty)
        XCTAssertNil(planViewModel.selectedPlan)
        XCTAssertNil(planViewModel.errorMessage)
        XCTAssertFalse(planViewModel.showError)

        XCTAssertFalse(trainingManager.isTrainingActive)
        XCTAssertNil(trainingManager.currentPlan)
        XCTAssertTrue(trainingManager.editingActions.isEmpty)
        XCTAssertTrue(trainingManager.completedSets.isEmpty)
        XCTAssertTrue(trainingManager.setNotes.isEmpty)
        XCTAssertTrue(trainingManager.setRestTimers.isEmpty)
        XCTAssertFalse(trainingManager.showRestTimer)

        XCTAssertTrue(calendarViewModel.trainingDatesInMonth.isEmpty)
        XCTAssertEqual(calendarViewModel.phase, .idle)
        XCTAssertEqual(listViewModel.phase, .idle)
        XCTAssertEqual(detailViewModel.phase, .idle)

        XCTAssertTrue(bodyViewModel.measurements.isEmpty)
        XCTAssertTrue(bodyViewModel.chartData.isEmpty)
        XCTAssertNil(bodyViewModel.selectedDataPoint)
        XCTAssertFalse(bodyViewModel.showingAddSheet)
        XCTAssertNil(bodyViewModel.errorMessage)
    }
}

@MainActor
private final class ScopeOrderingResetter: UserScopedStateResetting {
    weak var session: UserSession?
    private(set) var observedUserIDsDuringReset: [Int?] = []

    func resetUserScopedState() {
        observedUserIDsDuringReset.append(session?.currentUserID)
    }
}

private final class ScopeAuthenticationOperations: AuthenticationOperating {
    let restoredUser: User
    let loggedInUser: User

    init(restoredUser: User, loggedInUser: User) {
        self.restoredUser = restoredUser
        self.loggedInUser = loggedInUser
    }

    func register(_ registration: AuthRegistration) async throws -> User { loggedInUser }
    func login(email: String, password: String) async throws -> User { loggedInUser }
    func restoreSession() async throws -> User? { restoredUser }
    func logout() async throws {}
}

private final class ScopePlanRepository: PlanRepository {
    let storedTemplatePlans: [TrainingPlan]
    let storedUserPlans: [TrainingPlan]

    init(templatePlans: [TrainingPlan], userPlans: [TrainingPlan]) {
        storedTemplatePlans = templatePlans
        storedUserPlans = userPlans
    }

    func templatePlans() async throws -> [TrainingPlan] { storedTemplatePlans }
    func userPlans() async throws -> [TrainingPlan] { storedUserPlans }
    func templatePlanDetail(id: Int) async throws -> TrainingPlan { storedTemplatePlans[0] }
    func userPlanDetail(id: Int) async throws -> TrainingPlan { storedUserPlans[0] }
    func copyTemplatePlan(id: Int) async throws -> CreatePlanResponse { CreatePlanResponse(plan_id: 99) }
    func createUserPlan(_ draft: PlanDraft) async throws -> CreatePlanResponse { CreatePlanResponse(plan_id: 99) }
    func updateUserPlan(id: Int, planData: UpdatePlanRequest) async throws {}
    func deleteUserPlan(id: Int) async throws {}
}

private final class ScopeBodyMeasurementOperations: BodyMeasurementOperating, @unchecked Sendable {
    let measurements: [BodyMeasurement]

    init(measurements: [BodyMeasurement]) {
        self.measurements = measurements
    }

    func listMeasurements() async throws -> [BodyMeasurement] { measurements }
    func measurement(id: Int) async throws -> BodyMeasurement { measurements[0] }
    func createMeasurement(_ draft: BodyMeasurementDraft) async throws -> BodyMeasurement { measurements[0] }
    func updateMeasurement(id: Int, with draft: BodyMeasurementDraft) async throws -> BodyMeasurement { measurements[0] }
    func deleteMeasurement(id: Int) async throws {}
}

private final class ScopeHistoryRepository: TrainingHistoryRepository, @unchecked Sendable {
    let dates: TrainingHistoryDates
    let page: TrainingHistoryPage
    let detail: TrainingHistoryReadDetail

    init(dates: TrainingHistoryDates, page: TrainingHistoryPage, detail: TrainingHistoryReadDetail) {
        self.dates = dates
        self.page = page
        self.detail = detail
    }

    func trainingDates(ownerID: Int, in range: TrainingHistoryDateRange) throws -> TrainingHistoryDates { dates }
    func trainingHistory(_ query: TrainingHistoryListQuery) throws -> TrainingHistoryPage { page }
    func trainingHistoryDetail(id: Int, ownerID: Int) throws -> TrainingHistoryReadDetail { detail }
}

private func scopeUser(id: Int, email: String) -> User {
    User(
        id: id,
        username: "member-\(id)",
        email: email,
        gender: nil,
        height: nil,
        weight: nil,
        role: "regular",
        isAdmin: false,
        createdAt: "2026-07-26",
        accountType: "email",
        externalId: email,
        wechatOpenId: nil,
        wechatUnionId: nil,
        appleId: nil
    )
}

private func scopePlan(id: Int, name: String, isTemplate: Bool) -> TrainingPlan {
    TrainingPlan(
        id: id,
        name: name,
        creator: isTemplate ? "Template" : "User A",
        createdDate: "2026-07-26T00:00:00Z",
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

private func scopeMeasurement(id: Int) -> BodyMeasurement {
    let date = Date(timeIntervalSince1970: 2_000)
    return BodyMeasurement(
        id: id,
        measurementTimestamp: date,
        weightKg: 70,
        heightCm: 175,
        bodyFatPercentage: 20,
        skeletalMuscleMassKg: 35,
        visceralFatLevel: 5,
        createdAt: date,
        updatedAt: date
    )
}

private func scopeDate() -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = 2026
    components.month = 7
    components.day = 26
    return components.date!
}

private func scopeHistoryQuery(ownerID: Int) -> TrainingHistoryListQuery {
    TrainingHistoryListQuery(
        ownerID: ownerID,
        page: TrainingHistoryPageRequest(page: 1, pageSize: 20),
        filter: TrainingHistoryFilter(userPlanID: nil, dateRange: nil)
    )
}

private func scopeHistoryPage() -> TrainingHistoryPage {
    TrainingHistoryPage(
        histories: [scopeHistoryItem()],
        pagination: TrainingHistoryPagination(page: 1, pageSize: 20, total: 1, pageCount: 1)
    )
}

private func scopeHistoryDetail() -> TrainingHistoryReadDetail {
    TrainingHistoryReadDetail(
        history: scopeHistoryItem(),
        actions: [
            TrainingHistoryDetailAction(
                actionID: 1,
                name: "Squat",
                sets: [
                    TrainingHistoryDetailSet(
                        setNumber: 1,
                        weight: 40,
                        weightUnit: "kg",
                        reps: 10,
                        difficulty: nil,
                        leftWeight: nil,
                        rightWeight: nil,
                        isCompleted: true,
                        isBilateral: false
                    )
                ]
            )
        ]
    )
}

private func scopeHistoryItem() -> TrainingHistoryItem {
    TrainingHistoryItem(
        id: 50,
        plan_id: 2,
        plan_name: "User A Plan",
        training_date: "2026-07-26T12:00:00Z",
        volume: 400,
        duration: 45,
        note: nil,
        created_at: "2026-07-26T12:00:00Z"
    )
}

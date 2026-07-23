import XCTest
import SQLite
@testable import Stronix

final class PlanRepositoryTests: XCTestCase {
    private var temporaryRoot: URL!
    private var connection: Connection!
    private var repository: SQLitePlanRepository!
    private var ownerID: Int!
    private var otherOwnerID: Int!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        let databaseURL = temporaryRoot.appendingPathComponent("plans.db")
        try FileManager.default.copyItem(at: try bundledBaselineURL(), to: databaseURL)
        connection = try Connection(databaseURL.path)
        try connection.execute("PRAGMA foreign_keys = ON")
        ownerID = try insertUser(username: "owner", email: "owner@example.com")
        otherOwnerID = try insertUser(username: "other", email: "other@example.com")
        repository = SQLitePlanRepository(connection: connection)
    }

    override func tearDownWithError() throws {
        repository = nil
        connection = nil
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
    }

    func testBrowseTemplatePlansReturnsSeededOrderedContent() throws {
        let templates = try repository.templatePlans()
        XCTAssertEqual(templates.map(\.id).sorted(), [1, 2])

        let template = try repository.templatePlanDetail(id: 1)
        XCTAssertTrue(template.isTemplate)
        XCTAssertNil(template.templateId)
        XCTAssertEqual(template.actions?.map(\.id), [2, 3])
        XCTAssertEqual(template.actions?.first?.sets.map(\.reps), [10, 10])
        XCTAssertEqual(template.actions?.first?.restTime, 75)
        XCTAssertEqual(template.actions?.first?.notes, "动作全程保持稳定。")
    }

    func testCopyTemplatePreservesContentAndRecordsRealOwnership() throws {
        let template = try repository.templatePlanDetail(id: 2)
        let result = try repository.copyTemplatePlan(id: template.id, ownerID: ownerID)
        let copy = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)

        XCTAssertFalse(copy.isTemplate)
        XCTAssertEqual(copy.templateId, template.id)
        XCTAssertEqual(copy.actions?.map(\.id), template.actions?.map(\.id))
        XCTAssertEqual(copy.actions?.map(\.restTime), template.actions?.map(\.restTime))
        XCTAssertEqual(copy.actions?.map(\.notes), template.actions?.map(\.notes))
        XCTAssertEqual(copy.actions?.map(\.recordBilateral), template.actions?.map(\.recordBilateral))
        XCTAssertEqual(copy.actions?.first?.sets.map(\.reps), template.actions?.first?.sets.map(\.reps))
        XCTAssertEqual(copy.actions?.first?.sets.map(\.leftWeight), template.actions?.first?.sets.map(\.leftWeight))
        XCTAssertEqual(copy.actions?.first?.sets.map(\.rightWeight), template.actions?.first?.sets.map(\.rightWeight))
        XCTAssertEqual(
            try connection.scalar("SELECT user_id FROM training_plans WHERE id = ?", result.plan_id) as? Int64,
            Int64(ownerID)
        )
        XCTAssertEqual(
            try connection.scalar("SELECT source_template_id FROM training_plans WHERE id = ?", result.plan_id) as? Int64,
            Int64(template.id)
        )
    }

    func testCopyRejectsPseudoAndMissingOwners() throws {
        XCTAssertThrowsError(try repository.copyTemplatePlan(id: 1, ownerID: 0)) { error in
            XCTAssertEqual((error as? LocalPlanError)?.code, 401)
        }
        XCTAssertThrowsError(try repository.copyTemplatePlan(id: 1, ownerID: 999_999)) { error in
            XCTAssertEqual((error as? LocalPlanError)?.code, 401)
        }
        XCTAssertEqual(try connection.scalar("SELECT COUNT(*) FROM training_plans") as? Int64, 0)
    }

    func testEditingCopiedUserPlanLeavesTemplateUnchanged() throws {
        let templateBefore = try repository.templatePlanDetail(id: 1)
        let result = try repository.copyTemplatePlan(id: 1, ownerID: ownerID)
        let copy = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        let copiedAction = try XCTUnwrap(copy.actions?.first)

        try repository.updateUserPlan(
            id: result.plan_id,
            planData: UpdatePlanRequest(
                name: "已编辑的副本",
                description: "仅限用户副本",
                difficulty: "advanced",
                duration: 50,
                actions: [
                    UpdatePlanAction(
                        action_id: copiedAction.id,
                        order: 1,
                        rest: 120,
                        note: "编辑后的备注",
                        record_bilateral: false,
                        sets: [
                            UpdatePlanSet(order: 1, weight: 30, reps: 8, notes: "编辑后的组")
                        ]
                    )
                ]
            ),
            ownerID: ownerID
        )

        let templateAfter = try repository.templatePlanDetail(id: 1)
        let editedCopy = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        XCTAssertEqual(templateAfter.name, templateBefore.name)
        XCTAssertEqual(templateAfter.actions?.map(\.id), templateBefore.actions?.map(\.id))
        XCTAssertEqual(templateAfter.actions?.first?.sets.map(\.reps), templateBefore.actions?.first?.sets.map(\.reps))
        XCTAssertEqual(editedCopy.name, "已编辑的副本")
        XCTAssertEqual(editedCopy.actions?.first?.restTime, 120)
        XCTAssertEqual(editedCopy.actions?.first?.sets.first?.weight, 30)
        XCTAssertThrowsError(try repository.userPlanDetail(id: result.plan_id, ownerID: otherOwnerID))
    }

    func testUserPlanListIncludesEveryActionAndMatchesDetail() throws {
        let source = try repository.templatePlanDetail(id: 1)
        let actionID = try XCTUnwrap(source.actions?.first?.id)
        let result = try repository.createUserPlan(
            PlanDraft(
                name: "四动作计划",
                actions: (1...4).map { order in
                    PlanActionDraft(
                        actionID: actionID + order - 1,
                        sets: [PlanSetDraft(weight: Double(order * 10), reps: 10)]
                    )
                }
            ),
            ownerID: ownerID
        )

        let listedPlan = try XCTUnwrap(try repository.userPlans(ownerID: ownerID).first { $0.id == result.plan_id })
        let detailedPlan = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        XCTAssertEqual(listedPlan.actions?.count, 4)
        XCTAssertEqual(listedPlan.actions?.count, detailedPlan.actions?.count)
        XCTAssertEqual(listedPlan.actions?.map(\.id), detailedPlan.actions?.map(\.id))
    }

    func testCreateTypedDraftPreservesOrderedContent() throws {
        let source = try repository.templatePlanDetail(id: 1)
        let actionIDs = try XCTUnwrap(source.actions?.map(\.id))
        let result = try repository.createUserPlan(
            PlanDraft(
                name: "完整计划",
                description: "计划备注",
                difficulty: "advanced",
                duration: 45,
                actions: [
                    PlanActionDraft(
                        actionID: actionIDs[1],
                        rest: 75,
                        note: "双侧动作",
                        recordBilateral: true,
                        sets: [
                            PlanSetDraft(reps: 8, leftWeight: 10, rightWeight: 12, notes: "第一组"),
                            PlanSetDraft(reps: 10, leftWeight: 11, rightWeight: 13, notes: "第二组")
                        ]
                    ),
                    PlanActionDraft(
                        actionID: actionIDs[0],
                        rest: 60,
                        note: "普通动作",
                        sets: [PlanSetDraft(weight: 20, reps: 12, notes: "第三组")]
                    )
                ]
            ),
            ownerID: ownerID
        )

        let plan = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        XCTAssertEqual(plan.name, "完整计划")
        XCTAssertEqual(plan.description, "计划备注")
        XCTAssertEqual(plan.difficulty, "advanced")
        XCTAssertEqual(plan.duration, 45)
        XCTAssertEqual(plan.actions?.map(\.id), [actionIDs[1], actionIDs[0]])
        XCTAssertEqual(plan.actions?.map(\.restTime), [75, 60])
        XCTAssertEqual(plan.actions?.map(\.notes), ["双侧动作", "普通动作"])
        XCTAssertEqual(plan.actions?.map(\.recordBilateral), [true, false])
        XCTAssertEqual(plan.actions?.first?.sets.map(\.reps), [8, 10])
        XCTAssertEqual(plan.actions?.first?.sets.map(\.leftWeight), [10, 11])
        XCTAssertEqual(plan.actions?.first?.sets.map(\.rightWeight), [12, 13])
        XCTAssertEqual(plan.actions?.last?.sets.first?.weight, 20)
        XCTAssertEqual(
            try connection.scalar("SELECT notes FROM plan_sets WHERE plan_id = ? AND action_id = ? AND set_number = 1", result.plan_id, actionIDs[1]) as? String,
            "第一组"
        )
    }

    func testCreateTypedDraftRejectsEachValidationOutcomeWithoutWriting() throws {
        let actionID = try XCTUnwrap(try repository.templatePlanDetail(id: 1).actions?.first?.id)

        XCTAssertThrowsError(
            try repository.createUserPlan(
                PlanDraft(name: " \n", actions: [PlanActionDraft(actionID: actionID, sets: [PlanSetDraft()])]),
                ownerID: ownerID
            )
        ) { error in
            guard case .planNameEmpty = error as? LocalPlanError else {
                return XCTFail("Expected planNameEmpty, got \(error)")
            }
        }
        XCTAssertThrowsError(try repository.createUserPlan(PlanDraft(name: "无动作"), ownerID: ownerID)) { error in
            guard case .noActions = error as? LocalPlanError else {
                return XCTFail("Expected noActions, got \(error)")
            }
        }
        XCTAssertThrowsError(
            try repository.createUserPlan(
                PlanDraft(name: "空组", actions: [PlanActionDraft(actionID: actionID)]),
                ownerID: ownerID
            )
        ) { error in
            guard case .invalidSetData = error as? LocalPlanError else {
                return XCTFail("Expected invalidSetData, got \(error)")
            }
        }
        XCTAssertThrowsError(
            try repository.createUserPlan(
                PlanDraft(
                    name: "无效数值",
                    actions: [PlanActionDraft(actionID: actionID, rest: -1, sets: [PlanSetDraft(weight: -1, reps: 0)])]
                ),
                ownerID: ownerID
            )
        ) { error in
            guard case .invalidSetData = error as? LocalPlanError else {
                return XCTFail("Expected invalidSetData, got \(error)")
            }
        }
        XCTAssertEqual(try connection.scalar("SELECT COUNT(*) FROM training_plans") as? Int64, 0)
    }

    func testUpdateRejectsEmptySetsWithoutMutatingExistingPlan() throws {
        let result = try repository.copyTemplatePlan(id: 1, ownerID: ownerID)
        let before = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        let actionID = try XCTUnwrap(before.actions?.first?.id)

        XCTAssertThrowsError(
            try repository.updateUserPlan(
                id: result.plan_id,
                planData: UpdatePlanRequest(
                    name: "无效更新",
                    actions: [UpdatePlanAction(action_id: actionID)]
                ),
                ownerID: ownerID
            )
        ) { error in
            XCTAssertEqual((error as? LocalPlanError)?.code, 400)
        }

        let after = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        XCTAssertEqual(after.name, before.name)
        XCTAssertEqual(after.actions?.map(\.id), before.actions?.map(\.id))
    }

    func testServiceRejectsAnotherUsersID() async throws {
        let service = LocalPlanService(
            connectionProvider: { self.connection },
            authenticatedUserIDProvider: { self.ownerID }
        )

        do {
            _ = try await service.getPersonalPlans(user_id: otherOwnerID)
            XCTFail("Expected a cross-user request to be rejected")
        } catch let error as LocalPlanError {
            XCTAssertEqual(error.code, 401)
        }
    }

    func testServiceAdapterReadsAndCopiesPlansWithInjectedAuthenticatedUser() async throws {
        let service = LocalPlanService(
            connectionProvider: { self.connection },
            authenticatedUserIDProvider: { self.ownerID }
        )

        let templates = try await service.templatePlans()
        let template = try XCTUnwrap(templates.first)
        let templateDetail = try await service.templatePlanDetail(id: template.id)
        let initialUserPlans = try await service.userPlans()
        XCTAssertTrue(templateDetail.isTemplate)
        XCTAssertTrue(initialUserPlans.isEmpty)

        let copied = try await service.copyTemplatePlan(id: template.id)
        let userPlan = try await service.userPlanDetail(id: copied.plan_id)
        let copiedUserPlans = try await service.userPlans()

        XCTAssertEqual(userPlan.templateId, template.id)
        XCTAssertEqual(userPlan.actions?.map(\.id), templateDetail.actions?.map(\.id))
        XCTAssertEqual(copiedUserPlans.map(\.id), [copied.plan_id])
    }

    func testServiceAdapterRejectsMissingAuthenticatedUser() async throws {
        let service = LocalPlanService(
            connectionProvider: { self.connection },
            authenticatedUserIDProvider: { nil }
        )

        do {
            _ = try await service.userPlans()
            XCTFail("Expected an unauthenticated user-plan request to fail")
        } catch let error as LocalPlanError {
            XCTAssertEqual(error.code, 401)
        }
    }

    func testUserPlanListActionCountMatchesDetailAndCopyStartsTraining() throws {
        let result = try repository.copyTemplatePlan(id: 1, ownerID: ownerID)
        let listedPlan = try XCTUnwrap(try repository.userPlans(ownerID: ownerID).first)
        let detailedPlan = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        XCTAssertEqual(listedPlan.id, result.plan_id)
        XCTAssertEqual(listedPlan.actions?.count, detailedPlan.actions?.count)

        let manager = TrainingSessionManager.shared
        manager.stopTraining()
        manager.startTraining(with: detailedPlan)
        XCTAssertTrue(manager.isTrainingActive)
        XCTAssertEqual(manager.currentPlan?.id, detailedPlan.id)
        XCTAssertEqual(manager.editingActions.count, detailedPlan.actions?.count)
        manager.stopTraining()
    }

    func testServiceMapsMissingConnectionToDatabaseError() async {
        let service = LocalPlanService(
            connectionProvider: { nil },
            authenticatedUserIDProvider: { self.ownerID }
        )

        do {
            _ = try await service.templatePlans()
            XCTFail("Expected DatabaseError.notReady")
        } catch {
            guard case .notReady = error as? DatabaseError else {
                return XCTFail("Expected DatabaseError.notReady, got \(error)")
            }
        }
    }

    func testServiceMapsPlanQueryFailureToDatabaseError() async throws {
        let service = LocalPlanService(
            connectionProvider: { self.connection },
            authenticatedUserIDProvider: { self.ownerID }
        )
        try connection.execute("DROP TABLE template_plans")

        do {
            _ = try await service.templatePlans()
            XCTFail("Expected DatabaseError.operationFailed")
        } catch {
            guard case .operationFailed = error as? DatabaseError else {
                return XCTFail("Expected DatabaseError.operationFailed, got \(error)")
            }
        }
    }

    private func bundledBaselineURL() throws -> URL {
        try XCTUnwrap(DatabaseEnvironment.application().sourceDatabaseURL)
    }

    private func insertUser(username: String, email: String) throws -> Int {
        try connection.run(
            """
            INSERT INTO user (username, email, password_hash, created_at)
            VALUES (?, ?, 'test-hash', '2026-07-22T00:00:00Z')
            """,
            [username, email]
        )
        return Int(connection.lastInsertRowid)
    }
}

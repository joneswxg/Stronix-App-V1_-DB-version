import XCTest
import SQLite
@testable import Stronix

final class PlanRepositoryTests: XCTestCase {
    private var fixture: IsolatedDatabaseFixture!
    private var connection: Connection!
    private var repository: SQLitePlanRepository!
    private var ownerID: Int!
    private var otherOwnerID: Int!

    override func setUpWithError() throws {
        fixture = try IsolatedDatabaseFixture()
        connection = try fixture.prepareRepositoryDatabase(named: "plans.db")
        ownerID = try TestUserFixture(username: "owner", email: "owner@example.com").insert(into: connection).id
        otherOwnerID = try TestUserFixture(username: "other", email: "other@example.com").insert(into: connection).id
        repository = SQLitePlanRepository(connection: connection)
    }

    override func tearDownWithError() throws {
        repository = nil
        connection = nil
        fixture.tearDown()
        fixture = nil
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
        let copiedActionIDs = try XCTUnwrap(copy.actions?.map(\.id))

        try repository.updateUserPlan(
            id: result.plan_id,
            planData: UpdatePlanRequest(
                name: "已编辑的副本",
                description: "仅限用户副本",
                difficulty: "advanced",
                duration: 50,
                actions: [
                    UpdatePlanAction(
                        action_id: copiedActionIDs[1],
                        order: 1,
                        rest: 120,
                        note: "编辑后的备注",
                        record_bilateral: false,
                        sets: [
                            UpdatePlanSet(order: 1, weight: 30, reps: 8, notes: "编辑后的第一组"),
                            UpdatePlanSet(order: 2, weight: 35, reps: 6, notes: "编辑后的第二组")
                        ]
                    ),
                    UpdatePlanAction(
                        action_id: copiedActionIDs[0],
                        order: 2,
                        rest: 90,
                        note: "保留的第二动作",
                        record_bilateral: true,
                        sets: [
                            UpdatePlanSet(order: 1, reps: 10, left_weight: 12, right_weight: 14, notes: "双侧组")
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
        XCTAssertEqual(editedCopy.actions?.map(\.id), [copiedActionIDs[1], copiedActionIDs[0]])
        XCTAssertEqual(editedCopy.actions?.map(\.restTime), [120, 90])
        XCTAssertEqual(editedCopy.actions?.map(\.notes), ["编辑后的备注", "保留的第二动作"])
        XCTAssertEqual(editedCopy.actions?.map(\.recordBilateral), [false, true])
        XCTAssertEqual(editedCopy.actions?.first?.sets.map(\.weight), [30, 35])
        XCTAssertEqual(editedCopy.actions?.first?.sets.map(\.reps), [8, 6])
        XCTAssertEqual(editedCopy.actions?.last?.sets.map(\.leftWeight), [12])
        XCTAssertEqual(editedCopy.actions?.last?.sets.map(\.rightWeight), [14])
        XCTAssertEqual(try rowCount(in: "plan_actions", planID: result.plan_id), 2)
        XCTAssertEqual(try rowCount(in: "plan_sets", planID: result.plan_id), 3)
        XCTAssertThrowsError(try repository.userPlanDetail(id: result.plan_id, ownerID: otherOwnerID))
    }

    func testOtherUserCannotMutateCopiedPlan() throws {
        let templateBefore = try repository.templatePlanDetail(id: 1)
        let result = try repository.copyTemplatePlan(id: templateBefore.id, ownerID: ownerID)
        let copiedPlanBefore = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        let actionID = try XCTUnwrap(copiedPlanBefore.actions?.first?.id)

        XCTAssertThrowsError(
            try repository.updateUserPlan(
                id: result.plan_id,
                planData: UpdatePlanRequest(
                    name: "另一用户的编辑",
                    actions: [
                        UpdatePlanAction(
                            action_id: actionID,
                            order: 1,
                            sets: [UpdatePlanSet(order: 1, weight: 20, reps: 8)]
                        )
                    ]
                ),
                ownerID: otherOwnerID
            )
        )
        XCTAssertThrowsError(try repository.deleteUserPlan(id: result.plan_id, ownerID: otherOwnerID))

        let copiedPlanAfter = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        let templateAfter = try repository.templatePlanDetail(id: templateBefore.id)
        XCTAssertEqual(copiedPlanAfter.name, copiedPlanBefore.name)
        XCTAssertEqual(copiedPlanAfter.actions?.map(\.id), copiedPlanBefore.actions?.map(\.id))
        XCTAssertEqual(templateAfter.name, templateBefore.name)
        XCTAssertEqual(templateAfter.actions?.map(\.id), templateBefore.actions?.map(\.id))
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

    func testDeleteOwnedUserPlanRemovesItFromReadsAndCascadesOwnedContent() throws {
        let templateBefore = try repository.templatePlanDetail(id: 1)
        let result = try repository.copyTemplatePlan(id: templateBefore.id, ownerID: ownerID)

        XCTAssertGreaterThan(try rowCount(in: "plan_actions", planID: result.plan_id), 0)
        XCTAssertGreaterThan(try rowCount(in: "plan_sets", planID: result.plan_id), 0)

        try repository.deleteUserPlan(id: result.plan_id, ownerID: ownerID)

        XCTAssertFalse(try repository.userPlans(ownerID: ownerID).contains { $0.id == result.plan_id })
        XCTAssertThrowsError(try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)) { error in
            XCTAssertEqual((error as? LocalPlanError)?.code, 404)
        }
        XCTAssertEqual(try rowCount(in: "training_plans", planID: result.plan_id), 0)
        XCTAssertEqual(try rowCount(in: "plan_actions", planID: result.plan_id), 0)
        XCTAssertEqual(try rowCount(in: "plan_sets", planID: result.plan_id), 0)

        let templateAfter = try repository.templatePlanDetail(id: templateBefore.id)
        assertPlanContent(templateAfter, equals: templateBefore)
    }

    func testCreateRollsBackPlanAndOwnedContentWhenSetPersistenceFails() throws {
        let draft = try makeValidDraft(name: "创建回滚")
        try installPlanSetInsertFailureTrigger()

        XCTAssertThrowsError(try repository.createUserPlan(draft, ownerID: ownerID))

        XCTAssertEqual(try connection.scalar("SELECT COUNT(*) FROM training_plans WHERE user_id = ?", ownerID) as? Int64, 0)
        XCTAssertEqual(try connection.scalar("SELECT COUNT(*) FROM plan_actions") as? Int64, 0)
        XCTAssertEqual(try connection.scalar("SELECT COUNT(*) FROM plan_sets") as? Int64, 0)
    }

    func testCopyRollsBackPlanAndOwnedContentWhenSetPersistenceFails() throws {
        let templateBefore = try repository.templatePlanDetail(id: 1)
        try installPlanSetInsertFailureTrigger()

        XCTAssertThrowsError(try repository.copyTemplatePlan(id: templateBefore.id, ownerID: ownerID))

        XCTAssertEqual(try connection.scalar("SELECT COUNT(*) FROM training_plans WHERE user_id = ?", ownerID) as? Int64, 0)
        XCTAssertEqual(try connection.scalar("SELECT COUNT(*) FROM plan_actions") as? Int64, 0)
        XCTAssertEqual(try connection.scalar("SELECT COUNT(*) FROM plan_sets") as? Int64, 0)
        assertPlanContent(try repository.templatePlanDetail(id: templateBefore.id), equals: templateBefore)
    }

    func testUpdateRollsBackPriorPlanAndOwnedContentWhenSetPersistenceFails() throws {
        let result = try repository.copyTemplatePlan(id: 1, ownerID: ownerID)
        let before = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        let actionID = try XCTUnwrap(before.actions?.last?.id)
        let actionCountBefore = try rowCount(in: "plan_actions", planID: result.plan_id)
        let setCountBefore = try rowCount(in: "plan_sets", planID: result.plan_id)
        try installPlanSetInsertFailureTrigger()

        XCTAssertThrowsError(
            try repository.updateUserPlan(
                id: result.plan_id,
                planData: UpdatePlanRequest(
                    name: "不应保存的更新",
                    description: "事务失败",
                    difficulty: "advanced",
                    duration: 99,
                    actions: [
                        UpdatePlanAction(
                            action_id: actionID,
                            order: 1,
                            rest: 180,
                            note: "不应保存",
                            sets: [UpdatePlanSet(order: 1, weight: 99, reps: 3)]
                        )
                    ]
                ),
                ownerID: ownerID
            )
        )

        let after = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        assertPlanContent(after, equals: before)
        XCTAssertEqual(try rowCount(in: "plan_actions", planID: result.plan_id), actionCountBefore)
        XCTAssertEqual(try rowCount(in: "plan_sets", planID: result.plan_id), setCountBefore)
    }

    func testServiceRejectsForgedOwnerIDsAcrossPlanMutationsWithoutChangingData() async throws {
        let existing = try repository.copyTemplatePlan(id: 1, ownerID: ownerID)
        let before = try repository.userPlanDetail(id: existing.plan_id, ownerID: ownerID)
        let draft = try makeValidDraft(name: "伪造创建")
        let actionID = try XCTUnwrap(before.actions?.first?.id)
        let service = LocalPlanService(
            connectionProvider: { self.connection },
            authenticatedUserIDProvider: { self.ownerID }
        )

        await assertUnauthorized {
            try await service.createPlan(draft, user_id: self.otherOwnerID)
        }
        await assertUnauthorized {
            try await service.copyTemplatePlan(templateId: 1, user_id: self.otherOwnerID)
        }
        await assertUnauthorized {
            try await service.updatePlan(
                planId: existing.plan_id,
                planData: UpdatePlanRequest(
                    name: "伪造更新",
                    actions: [
                        UpdatePlanAction(
                            action_id: actionID,
                            order: 1,
                            sets: [UpdatePlanSet(order: 1, weight: 1, reps: 1)]
                        )
                    ]
                ),
                user_id: self.otherOwnerID
            )
        }
        await assertUnauthorized {
            try await service.deletePlan(planId: existing.plan_id, user_id: self.otherOwnerID)
        }

        XCTAssertEqual(try connection.scalar("SELECT COUNT(*) FROM training_plans") as? Int64, 1)
        assertPlanContent(try repository.userPlanDetail(id: existing.plan_id, ownerID: ownerID), equals: before)
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

    func testOnlyEligibleUserPlanStartsPersonalTraining() throws {
        let result = try repository.copyTemplatePlan(id: 1, ownerID: ownerID)
        let listedPlan = try XCTUnwrap(try repository.userPlans(ownerID: ownerID).first)
        let detailedPlan = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        let templatePlan = try repository.templatePlanDetail(id: 1)
        let emptyUserPlan = TrainingPlan(
            id: result.plan_id,
            name: "空用户计划",
            creator: "我",
            createdDate: "",
            lastTraining: "",
            volume: 0,
            actions: []
        )
        XCTAssertEqual(listedPlan.id, result.plan_id)
        XCTAssertEqual(listedPlan.actions?.count, detailedPlan.actions?.count)

        let manager = TrainingSessionManager.shared
        manager.stopTraining()
        defer { manager.stopTraining() }

        manager.startTraining(with: templatePlan)
        XCTAssertFalse(manager.isTrainingActive)
        XCTAssertNil(manager.currentPlan)
        XCTAssertTrue(manager.editingActions.isEmpty)

        manager.startTraining(with: emptyUserPlan)
        XCTAssertFalse(manager.isTrainingActive)
        XCTAssertNil(manager.currentPlan)
        XCTAssertTrue(manager.editingActions.isEmpty)

        manager.startTraining(with: detailedPlan)
        XCTAssertTrue(manager.isTrainingActive)
        XCTAssertEqual(manager.currentPlan?.id, detailedPlan.id)
        XCTAssertEqual(manager.editingActions.count, detailedPlan.actions?.count)
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

    private func makeValidDraft(name: String) throws -> PlanDraft {
        let actionIDs = try XCTUnwrap(try repository.templatePlanDetail(id: 1).actions?.map(\.id))
        return PlanDraft(
            name: name,
            description: "事务验证",
            difficulty: "intermediate",
            duration: 30,
            actions: [
                PlanActionDraft(
                    actionID: actionIDs[0],
                    rest: 60,
                    note: "第一动作",
                    sets: [PlanSetDraft(weight: 20, reps: 10, notes: "第一组")]
                ),
                PlanActionDraft(
                    actionID: actionIDs[1],
                    rest: 75,
                    note: "第二动作",
                    recordBilateral: true,
                    sets: [PlanSetDraft(reps: 8, leftWeight: 10, rightWeight: 12, notes: "第二组")]
                )
            ]
        )
    }

    private func installPlanSetInsertFailureTrigger() throws {
        try connection.execute(
            """
            CREATE TEMP TRIGGER phase_8_4_fail_plan_set_insert
            BEFORE INSERT ON plan_sets
            BEGIN
                SELECT RAISE(ABORT, 'phase 8.4 injected plan set failure');
            END
            """
        )
    }

    private func rowCount(in table: String, planID: Int) throws -> Int64 {
        let column = table == "training_plans" ? "id" : "plan_id"
        return try XCTUnwrap(try connection.scalar("SELECT COUNT(*) FROM \(table) WHERE \(column) = ?", planID) as? Int64)
    }

    private func assertPlanContent(
        _ actual: TrainingPlan,
        equals expected: TrainingPlan,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.id, expected.id, file: file, line: line)
        XCTAssertEqual(actual.name, expected.name, file: file, line: line)
        XCTAssertEqual(actual.description, expected.description, file: file, line: line)
        XCTAssertEqual(actual.difficulty, expected.difficulty, file: file, line: line)
        XCTAssertEqual(actual.duration, expected.duration, file: file, line: line)
        XCTAssertEqual(actual.isTemplate, expected.isTemplate, file: file, line: line)
        XCTAssertEqual(actual.templateId, expected.templateId, file: file, line: line)
        XCTAssertEqual(actual.actions?.map(\.id), expected.actions?.map(\.id), file: file, line: line)
        XCTAssertEqual(actual.actions?.map(\.restTime), expected.actions?.map(\.restTime), file: file, line: line)
        XCTAssertEqual(actual.actions?.map(\.notes), expected.actions?.map(\.notes), file: file, line: line)
        XCTAssertEqual(actual.actions?.map(\.recordBilateral), expected.actions?.map(\.recordBilateral), file: file, line: line)
        XCTAssertEqual(actual.actions?.map { $0.sets.map(\.weight) }, expected.actions?.map { $0.sets.map(\.weight) }, file: file, line: line)
        XCTAssertEqual(actual.actions?.map { $0.sets.map(\.reps) }, expected.actions?.map { $0.sets.map(\.reps) }, file: file, line: line)
        XCTAssertEqual(actual.actions?.map { $0.sets.map(\.leftWeight) }, expected.actions?.map { $0.sets.map(\.leftWeight) }, file: file, line: line)
        XCTAssertEqual(actual.actions?.map { $0.sets.map(\.rightWeight) }, expected.actions?.map { $0.sets.map(\.rightWeight) }, file: file, line: line)
        XCTAssertEqual(actual.actions?.map { $0.sets.map(\.notes) }, expected.actions?.map { $0.sets.map(\.notes) }, file: file, line: line)
    }

    private func assertUnauthorized<T>(
        _ operation: () async throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected an unauthorized plan mutation", file: file, line: line)
        } catch let error as LocalPlanError {
            XCTAssertEqual(error.code, 401, file: file, line: line)
        } catch {
            XCTFail("Expected LocalPlanError.unauthorized, got \(error)", file: file, line: line)
        }
    }
}

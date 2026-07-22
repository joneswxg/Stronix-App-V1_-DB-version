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
            [
                "name": "四动作计划",
                "actions": (1...4).map { order in
                    [
                        "action_id": actionID + order - 1,
                        "order": order,
                        "rest": 60,
                        "sets": [["set_number": 1, "weight": Double(order * 10), "reps": 10]]
                    ]
                }
            ],
            ownerID: ownerID
        )

        let listedPlan = try XCTUnwrap(try repository.userPlans(ownerID: ownerID).first { $0.id == result.plan_id })
        let detailedPlan = try repository.userPlanDetail(id: result.plan_id, ownerID: ownerID)
        XCTAssertEqual(listedPlan.actions?.count, 4)
        XCTAssertEqual(listedPlan.actions?.count, detailedPlan.actions?.count)
        XCTAssertEqual(listedPlan.actions?.map(\.id), detailedPlan.actions?.map(\.id))
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

    private func bundledBaselineURL() throws -> URL {
        try XCTUnwrap(DatabaseEnvironment.application().sourceDatabaseURL)
    }

    private func insertUser(username: String, email: String) throws -> Int {
        Int(try connection.run(
            """
            INSERT INTO user (username, email, password_hash, created_at)
            VALUES (?, ?, 'test-hash', '2026-07-22T00:00:00Z')
            """,
            username,
            email
        ))
    }
}

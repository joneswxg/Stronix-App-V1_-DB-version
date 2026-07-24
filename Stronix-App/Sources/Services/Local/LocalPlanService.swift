import Foundation
import SQLite

protocol PlanRepository {
    func templatePlans() async throws -> [TrainingPlan]
    func templatePlanDetail(id: Int) async throws -> TrainingPlan
    func userPlans() async throws -> [TrainingPlan]
    func userPlanDetail(id: Int) async throws -> TrainingPlan
    func createUserPlan(_ draft: PlanDraft) async throws -> CreatePlanResponse
    func copyTemplatePlan(id: Int) async throws -> CreatePlanResponse
    func updateUserPlan(id: Int, planData: UpdatePlanRequest) async throws
    func deleteUserPlan(id: Int) async throws
}

private protocol SQLitePlanStore {
    func templatePlans() throws -> [TrainingPlan]
    func templatePlanDetail(id: Int) throws -> TrainingPlan
    func userPlans(ownerID: Int) throws -> [TrainingPlan]
    func userPlanDetail(id: Int, ownerID: Int) throws -> TrainingPlan
    func createUserPlan(_ draft: PlanDraft, ownerID: Int) throws -> CreatePlanResponse
    func copyTemplatePlan(id: Int, ownerID: Int) throws -> CreatePlanResponse
    func updateUserPlan(id: Int, planData: UpdatePlanRequest, ownerID: Int) throws
    func deleteUserPlan(id: Int, ownerID: Int) throws
}

final class SQLitePlanRepository: SQLitePlanStore {
    private let connection: Connection

    init(connection: Connection) {
        self.connection = connection
    }

    func templatePlans() throws -> [TrainingPlan] {
        try listPlans(
            table: "template_plans",
            actionTable: "template_plan_actions",
            identifier: "template_plan_id",
            isTemplate: true,
            ownerID: nil
        )
    }

    func templatePlanDetail(id: Int) throws -> TrainingPlan {
        try planDetail(
            id: id,
            table: "template_plans",
            actionTable: "template_plan_actions",
            setTable: "template_plan_sets",
            identifier: "template_plan_id",
            isTemplate: true,
            ownerID: nil
        )
    }

    func userPlans(ownerID: Int) throws -> [TrainingPlan] {
        try requireUser(ownerID)
        return try listPlans(
            table: "training_plans",
            actionTable: "plan_actions",
            identifier: "plan_id",
            isTemplate: false,
            ownerID: ownerID
        )
    }

    func userPlanDetail(id: Int, ownerID: Int) throws -> TrainingPlan {
        try requireUser(ownerID)
        return try planDetail(
            id: id,
            table: "training_plans",
            actionTable: "plan_actions",
            setTable: "plan_sets",
            identifier: "plan_id",
            isTemplate: false,
            ownerID: ownerID
        )
    }

    func createUserPlan(_ draft: PlanDraft, ownerID: Int) throws -> CreatePlanResponse {
        try draft.validate()
        try requireUser(ownerID)

        let now = ISO8601DateFormatter().string(from: Date())
        var planID = 0
        try connection.transaction {
            try connection.run(
                """
                INSERT INTO training_plans (
                    name, description, difficulty, duration, created_at, updated_at, user_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    draft.name,
                    draft.description ?? "",
                    draft.difficulty ?? "",
                    draft.duration ?? 0,
                    now,
                    now,
                    ownerID
                ]
            )
            planID = Int(connection.lastInsertRowid)
            try insertActions(planID: planID, actionDrafts: draft.actions, now: now)
        }
        return CreatePlanResponse(plan_id: planID)
    }

    func copyTemplatePlan(id: Int, ownerID: Int) throws -> CreatePlanResponse {
        try requireUser(ownerID)
        let template = try templatePlanDetail(id: id)
        let now = ISO8601DateFormatter().string(from: Date())
        var planID = 0

        try connection.transaction {
            try connection.run(
                """
                INSERT INTO training_plans (
                    name, description, difficulty, duration, created_at, updated_at, user_id, source_template_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    "\(template.name) - 副本",
                    template.description ?? "",
                    template.difficulty ?? "",
                    template.duration ?? 0,
                    now,
                    now,
                    ownerID,
                    id
                ]
            )
            planID = Int(connection.lastInsertRowid)
            try connection.run(
                """
                INSERT INTO plan_actions (plan_id, action_id, "order", sets, reps, rest, weight, note, record_bilateral)
                SELECT ?, action_id, "order", sets, reps, rest, weight, note, record_bilateral
                FROM template_plan_actions
                WHERE template_plan_id = ?
                ORDER BY "order"
                """,
                planID,
                id
            )
            try connection.run(
                """
                INSERT INTO plan_sets (
                    plan_id, action_id, set_number, weight, reps, created_at, left_weight, right_weight, notes
                )
                SELECT ?, action_id, set_number, weight, reps, ?, left_weight, right_weight, notes
                FROM template_plan_sets
                WHERE template_plan_id = ?
                ORDER BY action_id, set_number
                """,
                planID,
                now,
                id
            )
        }
        return CreatePlanResponse(plan_id: planID)
    }

    func updateUserPlan(id: Int, planData: UpdatePlanRequest, ownerID: Int) throws {
        try validate(planData)
        _ = try userPlanDetail(id: id, ownerID: ownerID)
        let now = ISO8601DateFormatter().string(from: Date())
        try connection.transaction {
            try connection.run(
                """
                UPDATE training_plans
                SET name = ?, description = ?, difficulty = ?, duration = ?, updated_at = ?
                WHERE id = ? AND user_id = ?
                """,
                planData.name,
                planData.description ?? "",
                planData.difficulty ?? "",
                planData.duration ?? 0,
                now,
                id,
                ownerID
            )
            try connection.run("DELETE FROM plan_sets WHERE plan_id = ?", id)
            try connection.run("DELETE FROM plan_actions WHERE plan_id = ?", id)
            try insertUpdateActions(planID: id, actions: planData.actions, now: now)
        }
    }

    func deleteUserPlan(id: Int, ownerID: Int) throws {
        _ = try userPlanDetail(id: id, ownerID: ownerID)
        try connection.run("DELETE FROM training_plans WHERE id = ? AND user_id = ?", id, ownerID)
    }

    private func listPlans(
        table: String,
        actionTable: String,
        identifier: String,
        isTemplate: Bool,
        ownerID: Int?
    ) throws -> [TrainingPlan] {
        let ownerClause = ownerID == nil ? "" : "WHERE p.user_id = ?"
        let bindings: [Binding?] = ownerID.map { [$0] } ?? []
        let query = """
        SELECT p.id, p.name, p.description, p.difficulty, p.duration, p.created_at, p.updated_at,
               COALESCE((SELECT SUM(pa.weight) FROM \(actionTable) pa WHERE pa.\(identifier) = p.id), 0),
               (SELECT COUNT(*) FROM \(actionTable) pa WHERE pa.\(identifier) = p.id)
        FROM \(table) p
        \(ownerClause)
        ORDER BY p.created_at DESC, p.id DESC
        """
        return try connection.prepare(query, bindings).map { row in
            TrainingPlan(
                id: int(row[0]),
                name: string(row[1]),
                creator: isTemplate ? "系统模板" : "我",
                createdDate: string(row[5]),
                lastTraining: string(row[6]),
                volume: Int(double(row[7])),
                description: string(row[2]),
                isTemplate: isTemplate,
                templateId: isTemplate ? nil : sourceTemplateID(for: int(row[0])),
                difficulty: string(row[3]),
                duration: int(row[4]),
                actions: try actionSummaries(
                    planID: int(row[0]),
                    actionTable: actionTable,
                    identifier: identifier
                )
            )
        }
    }

    private func planDetail(
        id: Int,
        table: String,
        actionTable: String,
        setTable: String,
        identifier: String,
        isTemplate: Bool,
        ownerID: Int?
    ) throws -> TrainingPlan {
        let ownerClause = ownerID == nil ? "" : " AND user_id = ?"
        let bindings: [Binding?] = ownerID.map { [id, $0] } ?? [id]
        let statement = try connection.prepare(
            """
            SELECT id, name, description, difficulty, duration, created_at, updated_at
            FROM \(table)
            WHERE id = ?\(ownerClause)
            """
        )
        guard let plan = try statement.run(bindings).makeIterator().next() else {
            throw ownerID == nil ? LocalPlanError.templateNotFound(get_error_message("TEMPLATE_NOT_FOUND")) : LocalPlanError.planNotFound(get_error_message("PLAN_NOT_FOUND"))
        }

        let actions = try connection.prepare(
            """
            SELECT pa.action_id, pa.rest, pa.note, pa.record_bilateral, a.name, COALESCE(a."gifUrl", '')
            FROM \(actionTable) pa
            JOIN action a ON a.id = pa.action_id
            WHERE pa.\(identifier) = ?
            ORDER BY pa."order"
            """,
            id
        ).map { action in
            let actionID = int(action[0])
            let sets = try connection.prepare(
                """
                SELECT id, weight, reps, left_weight, right_weight, notes
                FROM \(setTable)
                WHERE \(identifier) = ? AND action_id = ?
                ORDER BY set_number
                """,
                id,
                actionID
            ).map { set in
                TrainingSet(
                    id: int(set[0]),
                    weight: double(set[1]),
                    reps: int(set[2]),
                    leftWeight: double(set[3]),
                    rightWeight: double(set[4]),
                    notes: nullableString(set[5])
                )
            }
            return TrainingAction(
                id: actionID,
                name: string(action[4]),
                sets: sets,
                restTime: int(action[1]),
                notes: nullableString(action[2]),
                recordBilateral: bool(action[3]),
                imageUrl: string(action[5])
            )
        }

        return TrainingPlan(
            id: int(plan[0]),
            name: string(plan[1]),
            creator: isTemplate ? "系统模板" : "我",
            createdDate: string(plan[5]),
            lastTraining: string(plan[6]),
            volume: actions.reduce(0) { $0 + $1.totalVolume },
            description: string(plan[2]),
            isTemplate: isTemplate,
            templateId: isTemplate ? nil : sourceTemplateID(for: id),
            difficulty: string(plan[3]),
            duration: int(plan[4]),
            actions: actions
        )
    }

    private func actionSummaries(
        planID: Int,
        actionTable: String,
        identifier: String
    ) throws -> [TrainingAction] {
        try connection.prepare(
            """
            SELECT pa.action_id, a.name, pa.sets, pa.rest, pa.note, pa.record_bilateral, COALESCE(a."gifUrl", '')
            FROM \(actionTable) pa
            JOIN action a ON a.id = pa.action_id
            WHERE pa.\(identifier) = ?
            ORDER BY pa."order"
            """,
            planID
        ).map { row in
            TrainingAction(
                id: int(row[0]),
                name: string(row[1]),
                totalSets: int(row[2]),
                restTime: int(row[3]),
                notes: nullableString(row[4]),
                recordBilateral: bool(row[5]),
                imageUrl: string(row[6])
            )
        }
    }

    private func insertUpdateActions(
        planID: Int,
        actions: [UpdatePlanAction],
        now: String
    ) throws {
        for action in actions {
            try connection.run(
                """
                INSERT INTO plan_actions (plan_id, action_id, "order", sets, rest, weight, note, record_bilateral)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                planID,
                action.action_id,
                action.order,
                action.sets.count,
                action.rest,
                actionVolume(
                    action.sets.map {
                        PlanSetDraft(
                            weight: $0.weight,
                            reps: $0.reps,
                            leftWeight: $0.left_weight,
                            rightWeight: $0.right_weight
                        )
                    },
                    bilateral: action.record_bilateral
                ),
                action.note,
                action.record_bilateral ? 1 : 0
            )
            for set in action.sets {
                try connection.run(
                    """
                    INSERT INTO plan_sets (
                        plan_id, action_id, set_number, weight, reps, created_at, left_weight, right_weight, notes
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    planID,
                    action.action_id,
                    set.order,
                    action.record_bilateral ? 0 : set.weight ?? 0,
                    set.reps,
                    now,
                    action.record_bilateral ? set.left_weight ?? 0 : 0,
                    action.record_bilateral ? set.right_weight ?? 0 : 0,
                    set.notes
                )
            }
        }
    }

    private func insertActions(
        planID: Int,
        actionDrafts: [PlanActionDraft],
        now: String
    ) throws {
        for (actionIndex, action) in actionDrafts.enumerated() {
            try connection.run(
                """
                INSERT INTO plan_actions (plan_id, action_id, "order", sets, rest, weight, note, record_bilateral)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                planID,
                action.actionID,
                actionIndex + 1,
                action.sets.count,
                action.rest,
                actionVolume(action.sets, bilateral: action.recordBilateral),
                action.note,
                action.recordBilateral ? 1 : 0
            )
            for (setIndex, set) in action.sets.enumerated() {
                try connection.run(
                    """
                    INSERT INTO plan_sets (
                        plan_id, action_id, set_number, weight, reps, created_at, left_weight, right_weight, notes
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    planID,
                    action.actionID,
                    setIndex + 1,
                    action.recordBilateral ? 0 : set.weight ?? 0,
                    set.reps,
                    now,
                    action.recordBilateral ? set.leftWeight ?? 0 : 0,
                    action.recordBilateral ? set.rightWeight ?? 0 : 0,
                    set.notes
                )
            }
        }
    }

    private func validate(_ request: UpdatePlanRequest) throws {
        try PlanDraft(updateRequest: request).validate()
    }

    private func requireUser(_ userID: Int) throws {
        guard (try connection.scalar("SELECT COUNT(*) FROM user WHERE id = ?", userID) as? Int64 ?? 0) == 1 else {
            throw LocalPlanError.unauthorized(get_error_message("UNAUTHORIZED"))
        }
    }

    private func sourceTemplateID(for planID: Int) -> Int? {
        let value = try? connection.scalar("SELECT source_template_id FROM training_plans WHERE id = ?", planID)
        if let value = value as? Int64 { return Int(value) }
        if let value = value as? Int { return value }
        return nil
    }

    private func actionVolume(_ sets: [PlanSetDraft], bilateral: Bool) -> Double {
        sets.reduce(0) { result, set in
            let reps = Double(set.reps)
            if bilateral {
                return result + ((set.leftWeight ?? 0) + (set.rightWeight ?? 0)) * reps
            }
            return result + (set.weight ?? 0) * reps
        }
    }

    private func int(_ value: Binding?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(value) }
        return 0
    }

    private func double(_ value: Binding?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? Int64 { return Double(value) }
        if let value = value as? Int { return Double(value) }
        return 0
    }

    private func string(_ value: Binding?) -> String {
        value as? String ?? ""
    }

    private func nullableString(_ value: Binding?) -> String? {
        value as? String
    }

    private func bool(_ value: Binding?) -> Bool {
        if let value = value as? Bool { return value }
        return int(value) != 0
    }
}

final class LocalPlanService: PlanRepository {
    static let shared = LocalPlanService()

    private let connectionProvider: () -> Connection?
    private let authenticatedUserIDProvider: () -> Int?

    init(
        connectionProvider: @escaping () -> Connection? = { DatabaseManager.shared.getConnection() },
        authenticatedUserIDProvider: @escaping () -> Int? = { CurrentUserContext.shared.currentUserID }
    ) {
        self.connectionProvider = connectionProvider
        self.authenticatedUserIDProvider = authenticatedUserIDProvider
    }

    func getTemplatePlans(language: String = "zh_CN") async throws -> [TrainingPlan] {
        try execute {
            try repository(language: language).templatePlans()
        }
    }

    func getTemplatePlanDetail(planId: Int, language: String = "zh_CN") async throws -> TrainingPlan {
        try execute {
            try repository(language: language).templatePlanDetail(id: planId)
        }
    }

    func getPersonalPlans(user_id: Int? = nil, language: String = "zh_CN") async throws -> [TrainingPlan] {
        try execute {
            try repository(language: language).userPlans(ownerID: try currentUserID(user_id, language: language))
        }
    }

    func getUserPlanDetail(planId: Int, user_id: Int? = nil, language: String = "zh_CN") async throws -> TrainingPlan {
        try execute {
            try repository(language: language).userPlanDetail(
                id: planId,
                ownerID: try currentUserID(user_id, language: language)
            )
        }
    }

    func getPlanDetail(planId: Int, user_id: Int? = nil, language: String = "zh_CN") async throws -> TrainingPlan {
        try execute {
            try repository(language: language).userPlanDetail(
                id: planId,
                ownerID: try currentUserID(user_id, language: language)
            )
        }
    }

    func createPlan(_ draft: PlanDraft, user_id: Int, language: String = "zh_CN") async throws -> CreatePlanResponse {
        try execute {
            try repository(language: language).createUserPlan(
                draft,
                ownerID: try currentUserID(user_id, language: language)
            )
        }
    }

    func copyTemplatePlan(templateId: Int, user_id: Int, language: String = "zh_CN") async throws -> CreatePlanResponse {
        try execute {
            try repository(language: language).copyTemplatePlan(
                id: templateId,
                ownerID: try currentUserID(user_id, language: language)
            )
        }
    }

    func deletePlan(planId: Int, user_id: Int, language: String = "zh_CN") async throws {
        try execute {
            try repository(language: language).deleteUserPlan(
                id: planId,
                ownerID: try currentUserID(user_id, language: language)
            )
        }
    }

    func updatePlan(planId: Int, planData: UpdatePlanRequest, user_id: Int, language: String = "zh_CN") async throws {
        try execute {
            try repository(language: language).updateUserPlan(
                id: planId,
                planData: planData,
                ownerID: try currentUserID(user_id, language: language)
            )
        }
    }

    func templatePlans() async throws -> [TrainingPlan] {
        try await getTemplatePlans()
    }

    func templatePlanDetail(id: Int) async throws -> TrainingPlan {
        try await getTemplatePlanDetail(planId: id)
    }

    func userPlans() async throws -> [TrainingPlan] {
        try await getPersonalPlans()
    }

    func userPlanDetail(id: Int) async throws -> TrainingPlan {
        try await getUserPlanDetail(planId: id)
    }

    func createUserPlan(_ draft: PlanDraft) async throws -> CreatePlanResponse {
        try await createPlan(draft, user_id: try currentUserID(nil, language: "zh_CN"))
    }

    func copyTemplatePlan(id: Int) async throws -> CreatePlanResponse {
        try await copyTemplatePlan(templateId: id, user_id: try currentUserID(nil, language: "zh_CN"))
    }

    func updateUserPlan(id: Int, planData: UpdatePlanRequest) async throws {
        try await updatePlan(planId: id, planData: planData, user_id: try currentUserID(nil, language: "zh_CN"))
    }

    func deleteUserPlan(id: Int) async throws {
        try await deletePlan(planId: id, user_id: try currentUserID(nil, language: "zh_CN"))
    }

    private func execute<T>(_ operation: () throws -> T) throws -> T {
        do {
            return try operation()
        } catch let error as LocalPlanError {
            throw error
        } catch let error as DatabaseError {
            throw error
        } catch {
            throw DatabaseError.operationFailed(underlying: error)
        }
    }

    private func repository(language: String) throws -> SQLitePlanRepository {
        guard let connection = connectionProvider() else {
            throw DatabaseError.notReady
        }
        return SQLitePlanRepository(connection: connection)
    }

    private func currentUserID(_ providedID: Int?, language: String) throws -> Int {
        guard let currentUserID = authenticatedUserIDProvider() else {
            throw LocalPlanError.unauthorized(get_error_message("UNAUTHORIZED", language: language))
        }
        guard providedID == nil || providedID == currentUserID else {
            throw LocalPlanError.unauthorized(get_error_message("UNAUTHORIZED", language: language))
        }
        return currentUserID
    }
}

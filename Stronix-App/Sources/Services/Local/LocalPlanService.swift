import Foundation
import SQLite

/// 本地训练计划服务类
/// 迁移自 Backend-Reference/src/stronix/services/PlanService.py
/// 替换 Services/Network/ 中计划相关的网络调用

class LocalPlanService {
    static let shared = LocalPlanService()
    private let dbManager = DatabaseManager.shared
    
    // MARK: - 数据库表定义（与Python代码保持一致）
    private let training_plans = Table("training_plans")
    private let plan_actions = Table("plan_actions")
    private let plan_sets = Table("plan_sets")
    private let action = Table("action")
    
    // training_plans 表字段
    private let tp_id = Expression<Int>("id")
    private let tp_name = Expression<String>("name")
    private let tp_description = Expression<String>("description")
    private let tp_difficulty = Expression<String>("difficulty")
    private let tp_duration = Expression<Int>("duration")
    private let tp_user_id = Expression<Int?>("user_id")
    private let tp_is_template = Expression<Bool>("is_template")
    private let tp_template_id = Expression<Int?>("template_id")
    private let tp_created_at = Expression<String>("created_at")
    private let tp_updated_at = Expression<String>("updated_at")
    
    // plan_actions 表字段
    private let pa_plan_id = Expression<Int>("plan_id")
    private let pa_action_id = Expression<Int>("action_id")
    private let pa_user_id = Expression<Int?>("user_id")
    private let pa_order = Expression<Int>("order")
    private let pa_sets = Expression<Int>("sets")
    private let pa_rest = Expression<Int>("rest")
    private let pa_note = Expression<String?>("note")
    private let pa_record_bilateral = Expression<Bool>("record_bilateral")
    private let pa_weight = Expression<Double>("weight")
    
    // plan_sets 表字段
    private let ps_id = Expression<Int>("id")
    private let ps_plan_id = Expression<Int>("plan_id")
    private let ps_action_id = Expression<Int>("action_id")
    private let ps_set_number = Expression<Int>("set_number")
    private let ps_weight = Expression<Double>("weight")
    private let ps_reps = Expression<Int>("reps")
    private let ps_left_weight = Expression<Double>("left_weight")
    private let ps_right_weight = Expression<Double>("right_weight")
    private let ps_created_at = Expression<String>("created_at")
    
    // action 表字段
    private let a_id = Expression<Int>("id")
    private let a_name = Expression<String>("name")
    private let a_name_en = Expression<String?>("name_en")
    private let a_gifUrl = Expression<String>("gifUrl")
    private let a_description = Expression<String?>("description")
    private let a_bodypart_id = Expression<Int>("bodypart_id")
    private let a_equipment_id = Expression<Int>("equipment_id")
    private let a_is_bilateral = Expression<Bool>("is_bilateral")
    
    private init() {}
    
    // MARK: - 容量计算（与Python代码保持一致）
    private func calculate_action_volume(_ sets: [[String: Any]], record_bilateral: Bool = false) -> Double {
        var total_volume = 0.0
        
        for set_data in sets {
            if record_bilateral {
                // 双侧训练：(左重量 + 右重量) × 次数
                let left_weight = set_data["left_weight"] as? Double ?? 0
                let right_weight = set_data["right_weight"] as? Double ?? 0
                let reps = set_data["reps"] as? Int ?? 0
                total_volume += (left_weight + right_weight) * Double(reps)
            } else {
                // 普通训练：重量 × 次数
                let weight = set_data["weight"] as? Double ?? 0
                let reps = set_data["reps"] as? Int ?? 0
                total_volume += weight * Double(reps)
            }
        }
        
        return total_volume
    }
    
    // MARK: - 获取模板计划列表
    func getTemplatePlans(language: String = "zh_CN") async throws -> [TrainingPlan] {
        guard let db = dbManager.getConnection() else {
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
        
        do {
            // 查询模板计划（is_template = 1 或 user_id = 0）
            let query = training_plans
                .select(tp_id, tp_name, tp_description, tp_difficulty, tp_duration, tp_created_at, tp_updated_at)
                .filter(tp_is_template == true || tp_user_id == 0)
                .order(tp_created_at.desc)
            
            var plans: [TrainingPlan] = []
            
            for row in try db.prepare(query) {
                let plan_dict: [String: Any] = [
                    "id": row[tp_id],
                    "name": row[tp_name],
                    "description": row[tp_description],
                    "difficulty": row[tp_difficulty],
                    "duration": row[tp_duration],
                    "created_at": row[tp_created_at],
                    "updated_at": row[tp_updated_at],
                    "is_template": true
                ]
                
                // 转换为TrainingPlan模型
                let trainingPlan = convertToTrainingPlan(plan_dict)
                plans.append(trainingPlan)
            }
            
            return plans
            
        } catch {
            print("❌ LocalPlanService.getTemplatePlans error: \(error)")
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
    }
    
    // MARK: - 获取用户个人计划列表
    func getPersonalPlans(user_id: Int? = nil, language: String = "zh_CN") async throws -> [TrainingPlan] {
        guard let db = dbManager.getConnection() else {
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
        
        // 获取当前用户ID
        let currentUserId: Int
        if let providedUserId = user_id {
            currentUserId = providedUserId
        } else {
            // 从LocalUserService获取当前用户ID
            guard let currentUser = LocalUserService.shared.currentUser else {
                print("⚠️ LocalPlanService: 用户未登录，无法获取个人计划")
                return []
            }
            currentUserId = currentUser.id
        }
        
        print("🔍 LocalPlanService.getPersonalPlans: 查询用户ID=\(currentUserId) 的个人计划")
        
        do {
            // 查询该用户的个人计划（非模板计划）
            let query = training_plans
                .select(tp_id, tp_name, tp_description, tp_difficulty, tp_duration, tp_created_at, tp_updated_at)
                .filter(tp_user_id == currentUserId && tp_is_template == false)
                .order(tp_created_at.desc)
            
            var plans: [TrainingPlan] = []
            
            for row in try db.prepare(query) {
                let planId = row[tp_id]
                
                print("🔍 LocalPlanService.getPersonalPlans: 计划ID=\(planId), 名称=\(row[tp_name]), 更新时间=\(row[tp_updated_at])")
                
                // 计算总容量：从 plan_actions.weight 字段累加（与Flask架构一致）
                let totalVolume = try db.scalar(plan_actions.filter(pa_plan_id == planId).select(pa_weight.sum)) ?? 0.0
                
                // 查询动作数量（用于显示动作摘要）
                let actionsCount = try db.scalar(plan_actions.filter(pa_plan_id == planId).count)
                
                // 获取前2个动作的名称（用于卡片显示）
                let actionsInfoQuery = plan_actions
                    .select(pa_action_id, pa_sets, a_name)
                    .join(action, on: pa_action_id == a_id)
                    .filter(pa_plan_id == planId)
                    .order(pa_order.asc)
                    .limit(2)
                
                var actionsSummary: [TrainingAction] = []
                for actionRow in try db.prepare(actionsInfoQuery) {
                    let actionSummary = TrainingAction(
                        id: actionRow[pa_action_id],
                        name: actionRow[a_name],
                        totalSets: actionRow[pa_sets],
                        restTime: 60,
                        notes: nil,
                        recordBilateral: false,
                        imageUrl: ""
                    )
                    actionsSummary.append(actionSummary)
                }
                
                print("🔍 LocalPlanService.getPersonalPlans: 计划ID=\(planId) 包含 \(actionsCount) 个动作，总容量=\(Int(totalVolume))kg")
                
                // 创建TrainingPlan对象（与Flask架构保持一致：只包含基本信息和动作摘要）
                let trainingPlan = TrainingPlan(
                    id: planId,
                    name: row[tp_name],
                    creator: "我",
                    createdDate: formatDateForDisplay(row[tp_created_at]),
                    lastTraining: "未开始",
                    volume: Int(totalVolume), // 使用从数据库读取的预计算容量
                    description: row[tp_description],
                    isTemplate: false,
                    templateId: nil,
                    difficulty: row[tp_difficulty],
                    duration: row[tp_duration],
                    actions: actionsSummary.isEmpty ? nil : actionsSummary // 只包含前2个动作的摘要信息
                )
                
                plans.append(trainingPlan)
            }
            
            print("✅ LocalPlanService.getPersonalPlans: 查询到 \(plans.count) 个个人计划")
            return plans
            
        } catch {
            print("❌ LocalPlanService.getPersonalPlans: 查询失败 - \(error)")
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
    }
    
    // MARK: - 获取计划详情
    func getPlanDetail(planId: Int, user_id: Int? = nil, language: String = "zh_CN") async throws -> TrainingPlan {
        guard let db = dbManager.getConnection() else {
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
        
        do {
            // 查询计划基本信息
            let planQuery = training_plans
                .select(tp_id, tp_name, tp_description, tp_difficulty, tp_duration, tp_user_id, tp_is_template, tp_template_id, tp_created_at, tp_updated_at)
                .filter(tp_id == planId)
            
            guard let planRow = try db.pluck(planQuery) else {
                throw LocalPlanError.planNotFound(get_error_message("PLAN_NOT_FOUND", language: language))
            }
            
            // 检查权限（如果不是模板计划，需要验证用户权限）
            let planUserId = planRow[tp_user_id]
            let isTemplate = planRow[tp_is_template]
            if !isTemplate && planUserId != nil && user_id != nil && planUserId != user_id {
                throw LocalPlanError.permissionDenied(get_error_message("PERMISSION_DENIED", language: language))
            }
            
            var plan_dict: [String: Any] = [
                "id": planRow[tp_id],
                "name": planRow[tp_name],
                "description": planRow[tp_description],
                "difficulty": planRow[tp_difficulty],
                "duration": planRow[tp_duration],
                "user_id": planRow[tp_user_id] as Any,
                "is_template": planRow[tp_is_template],
                "template_id": planRow[tp_template_id] as Any,
                "created_at": planRow[tp_created_at],
                "updated_at": planRow[tp_updated_at],
                "actions": []
            ]
            
            // 查询计划的动作
            let actionsQuery = plan_actions
                .select(pa_action_id, pa_order, pa_sets, pa_rest, pa_weight, pa_note, pa_record_bilateral,
                       a_name, a_name_en, a_gifUrl, a_description, a_bodypart_id, a_equipment_id, a_is_bilateral)
                .join(action, on: pa_action_id == a_id)
                .filter(pa_plan_id == planId)
                .order(pa_order.asc)
            
            var actions: [[String: Any]] = []
            
            for actionRow in try db.prepare(actionsQuery) {
                var action_dict: [String: Any] = [
                    "action_id": actionRow[pa_action_id],
                    "order": actionRow[pa_order],
                    "sets_count": actionRow[pa_sets],
                    "rest": actionRow[pa_rest],
                    "weight": actionRow[pa_weight],
                    "note": actionRow[pa_note] ?? "",
                    "record_bilateral": actionRow[pa_record_bilateral],
                    "action_info": [
                        "id": actionRow[pa_action_id],
                        "name": actionRow[a_name],
                        "name_en": actionRow[a_name_en] ?? "",
                        "gifUrl": actionRow[a_gifUrl],
                        "description": actionRow[a_description] ?? "",
                        "bodypart_id": actionRow[a_bodypart_id],
                        "equipment_id": actionRow[a_equipment_id],
                        "is_bilateral": actionRow[a_is_bilateral]
                    ],
                    "sets": []
                ]
                
                // 查询每个动作的组数据
                let setsQuery = plan_sets
                    .select(ps_id, ps_set_number, ps_weight, ps_reps, ps_left_weight, ps_right_weight, ps_created_at)
                    .filter(ps_plan_id == planId && ps_action_id == actionRow[pa_action_id])
                    .order(ps_set_number.asc)
                
                var sets: [[String: Any]] = []
                for setRow in try db.prepare(setsQuery) {
                    let set_dict: [String: Any] = [
                        "id": setRow[ps_id],
                        "set_number": setRow[ps_set_number],
                        "weight": setRow[ps_weight],
                        "reps": setRow[ps_reps],
                        "left_weight": setRow[ps_left_weight],
                        "right_weight": setRow[ps_right_weight],
                        "created_at": setRow[ps_created_at]
                    ]
                    sets.append(set_dict)
                }
                
                action_dict["sets"] = sets
                actions.append(action_dict)
            }
            
            plan_dict["actions"] = actions
            return convertToTrainingPlanDetail(plan_dict)
            
        } catch let error as LocalPlanError {
            throw error
        } catch {
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
    }
    
    // MARK: - 创建计划
    func createPlan(_ planData: [String: Any], user_id: Int, language: String = "zh_CN") async throws -> CreatePlanResponse {
        guard let db = dbManager.getConnection() else {
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
        
        // 验证数据
        guard let name = planData["name"] as? String, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw LocalPlanError.planNameEmpty(get_error_message("PLAN_NAME_EMPTY", language: language))
        }
        
        guard let actionsData = planData["actions"] as? [[String: Any]], !actionsData.isEmpty else {
            throw LocalPlanError.noActions(get_error_message("NO_ACTIONS", language: language))
        }
        
        do {
            // 1. 创建训练计划
            let currentTime = ISO8601DateFormatter().string(from: Date())
            let insertPlan = training_plans.insert(
                tp_name <- name,
                tp_description <- (planData["description"] as? String ?? ""),
                tp_difficulty <- (planData["difficulty"] as? String ?? ""),
                tp_duration <- (planData["duration"] as? Int ?? 0),
                tp_user_id <- user_id,
                tp_is_template <- false,
                tp_created_at <- currentTime,
                tp_updated_at <- currentTime
            )
            
            let plan_id = try db.run(insertPlan)
            
            // 2. 在事务中添加动作和组数据
            try db.transaction { () -> Void in
                for (order, actionData) in actionsData.enumerated() {
                    guard let action_id = actionData["action_id"] as? Int else { continue }
                    let sets_data = actionData["sets"] as? [[String: Any]] ?? []
                    let record_bilateral = actionData["record_bilateral"] as? Bool ?? false
                    
                    // 计算总容量
                    let total_volume = calculate_action_volume(sets_data, record_bilateral: record_bilateral)
                    
                    // 插入plan_actions
                    let insertAction = plan_actions.insert(
                        pa_plan_id <- Int(plan_id),
                        pa_action_id <- action_id,
                        pa_user_id <- user_id,
                        pa_order <- (order + 1),
                        pa_sets <- sets_data.count,
                        pa_rest <- (actionData["rest"] as? Int ?? 60),
                        pa_note <- (actionData["note"] as? String),
                        pa_record_bilateral <- record_bilateral,
                        pa_weight <- total_volume
                    )
                    
                    try db.run(insertAction)
                    
                    // 插入plan_sets
                    for (setIndex, setData) in sets_data.enumerated() {
                        if record_bilateral {
                            // 双侧训练
                            let insertSet = plan_sets.insert(
                                ps_plan_id <- Int(plan_id),
                                ps_action_id <- action_id,
                                ps_set_number <- (setIndex + 1),
                                ps_weight <- 0, // 双侧训练时weight字段设为0
                                ps_reps <- (setData["reps"] as? Int ?? 12),
                                ps_left_weight <- (setData["left_weight"] as? Double ?? 0),
                                ps_right_weight <- (setData["right_weight"] as? Double ?? 0),
                                ps_created_at <- currentTime
                            )
                            try db.run(insertSet)
                        } else {
                            // 普通训练
                            let insertSet = plan_sets.insert(
                                ps_plan_id <- Int(plan_id),
                                ps_action_id <- action_id,
                                ps_set_number <- (setIndex + 1),
                                ps_weight <- (setData["weight"] as? Double ?? 0),
                                ps_reps <- (setData["reps"] as? Int ?? 12),
                                ps_left_weight <- 0, // 普通训练时left_weight设为0
                                ps_right_weight <- 0, // 普通训练时right_weight设为0
                                ps_created_at <- currentTime
                            )
                            try db.run(insertSet)
                        }
                    }
                }
            }
            
            return CreatePlanResponse(plan_id: Int(plan_id))
            
        } catch let error as LocalPlanError {
            throw error
        } catch {
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
    }
    
    // MARK: - 复制模板计划
    func copyTemplatePlan(templateId: Int, user_id: Int, language: String = "zh_CN") async throws -> CreatePlanResponse {
        do {
            // 获取模板计划详情
            let templatePlan = try await getPlanDetail(planId: templateId, user_id: nil, language: language)
            
            // 验证是否为模板计划
            guard templatePlan.isTemplate else {
                throw LocalPlanError.templateNotFound(get_error_message("TEMPLATE_NOT_FOUND", language: language))
            }
            
            // 构造新计划数据
            var newPlanData: [String: Any] = [
                "name": "\(templatePlan.name) - 副本",
                "description": templatePlan.description ?? "",
                "difficulty": templatePlan.difficulty ?? "",
                "duration": templatePlan.duration ?? 0,
                "actions": []
            ]
            
            // 复制动作数据
            var actionsArray: [[String: Any]] = []
            if let actions = templatePlan.actions {
                for action in actions {
                    var actionData: [String: Any] = [
                        "action_id": action.id,
                        "rest": action.restTime,
                        "note": action.notes ?? "",
                        "record_bilateral": action.recordBilateral,
                        "sets": []
                    ]
                    
                    // 复制组数据
                    var setsArray: [[String: Any]] = []
                    for set in action.sets {
                        var newSet: [String: Any] = [
                            "weight": set.weight,
                            "reps": set.reps
                        ]
                        if set.leftWeight != 0 {
                            newSet["left_weight"] = set.leftWeight
                        }
                        if set.rightWeight != 0 {
                            newSet["right_weight"] = set.rightWeight
                        }
                        setsArray.append(newSet)
                    }
                    actionData["sets"] = setsArray
                    actionsArray.append(actionData)
                }
            }
            newPlanData["actions"] = actionsArray
            
            // 创建新计划
            return try await createPlan(newPlanData, user_id: user_id, language: language)
            
        } catch let error as LocalPlanError {
            throw error
        } catch {
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
    }
    
    // MARK: - 删除计划
    func deletePlan(planId: Int, user_id: Int, language: String = "zh_CN") async throws {
        guard let db = dbManager.getConnection() else {
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
        
        do {
            // 验证计划是否存在且属于用户
            let planQuery = training_plans
                .select(tp_id)
                .filter(tp_id == planId && tp_user_id == user_id)
            
            guard try db.pluck(planQuery) != nil else {
                throw LocalPlanError.planNotFound(get_error_message("PLAN_NOT_FOUND", language: language))
            }
            
            try db.transaction { () -> Void in
                // 删除相关数据
                try db.run(plan_sets.filter(ps_plan_id == planId).delete())
                try db.run(plan_actions.filter(pa_plan_id == planId).delete())
                try db.run(training_plans.filter(tp_id == planId && tp_user_id == user_id).delete())
            }
            
        } catch let error as LocalPlanError {
            throw error
        } catch {
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
    }
    
    // MARK: - 更新计划
    func updatePlan(planId: Int, planData: UpdatePlanRequest, user_id: Int, language: String = "zh_CN") async throws {
        print("🔄 LocalPlanService.updatePlan() 开始")
        print("🔄 计划ID: \(planId), 用户ID: \(user_id)")
        print("🔄 计划名称: \(planData.name)")
        print("🔄 计划描述: \(planData.description ?? "无")")
        print("🔄 动作数量: \(planData.actions.count)")
        
        guard let db = dbManager.getConnection() else {
            print("❌ LocalPlanService.updatePlan() 数据库连接失败")
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
        
        print("✅ LocalPlanService.updatePlan() 数据库连接成功")
        
        // 验证数据
        guard !planData.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("❌ LocalPlanService.updatePlan() 计划名称为空")
            throw LocalPlanError.planNameEmpty(get_error_message("PLAN_NAME_EMPTY", language: language))
        }
        
        guard !planData.actions.isEmpty else {
            print("❌ LocalPlanService.updatePlan() 动作列表为空")
            throw LocalPlanError.noActions(get_error_message("NO_ACTIONS", language: language))
        }
        
        print("✅ LocalPlanService.updatePlan() 数据验证通过")
        
        do {
            // 先获取计划详情以验证权限（与Python版本逻辑一致）
            print("🔍 LocalPlanService.updatePlan() 验证计划权限...")
            _ = try await getPlanDetail(planId: planId, user_id: user_id, language: language)
            print("✅ LocalPlanService.updatePlan() 权限验证通过")
            
            print("🔄 LocalPlanService.updatePlan() 开始数据库事务...")
            try db.transaction { () -> Void in
                print("🔄 LocalPlanService.updatePlan() 事务内部 - 开始更新计划基本信息")
                
                // 1. 更新计划基本信息
                let currentTime = ISO8601DateFormatter().string(from: Date())
                print("🔄 当前时间: \(currentTime)")
                
                let updatePlan = training_plans
                    .filter(tp_id == planId)
                    .update(
                        tp_name <- planData.name,
                        tp_description <- (planData.description ?? ""),
                        tp_difficulty <- (planData.difficulty ?? ""),
                        tp_duration <- (planData.duration ?? 0),
                        tp_updated_at <- currentTime
                    )
                
                let updateResult = try db.run(updatePlan)
                print("✅ LocalPlanService.updatePlan() 计划基本信息更新完成，影响行数: \(updateResult)")
                
                // 2. 删除旧的动作和组数据
                print("🔄 LocalPlanService.updatePlan() 删除旧的组数据...")
                let deleteSetsResult = try db.run(plan_sets.filter(ps_plan_id == planId).delete())
                print("✅ 删除旧组数据完成，影响行数: \(deleteSetsResult)")
                
                print("🔄 LocalPlanService.updatePlan() 删除旧的动作数据...")
                let deleteActionsResult = try db.run(plan_actions.filter(pa_plan_id == planId).delete())
                print("✅ 删除旧动作数据完成，影响行数: \(deleteActionsResult)")
                
                // 3. 添加新的动作和组数据
                print("🔄 LocalPlanService.updatePlan() 开始添加新动作数据...")
                for (index, actionData) in planData.actions.enumerated() {
                    print("🔄 处理动作 \(index + 1)/\(planData.actions.count): action_id=\(actionData.action_id)")
                    
                    let sets_data = actionData.sets.map { set in
                        [
                            "weight": set.weight as Any,
                            "reps": set.reps,
                            "left_weight": set.left_weight as Any,
                            "right_weight": set.right_weight as Any
                        ]
                    }
                    
                    // 计算总容量
                    let total_volume = calculate_action_volume(sets_data, record_bilateral: actionData.record_bilateral)
                    print("🔄 动作容量计算: \(total_volume)kg, 双侧训练: \(actionData.record_bilateral)")
                    
                    // 插入plan_actions
                    let insertAction = plan_actions.insert(
                        pa_plan_id <- planId,
                        pa_action_id <- actionData.action_id,
                        pa_user_id <- user_id,
                        pa_order <- actionData.order,
                        pa_sets <- actionData.sets.count,
                        pa_rest <- actionData.rest,
                        pa_note <- actionData.note,
                        pa_record_bilateral <- actionData.record_bilateral,
                        pa_weight <- total_volume
                    )
                    
                    try db.run(insertAction)
                    print("✅ 动作数据插入完成: action_id=\(actionData.action_id)")
                    
                    // 插入plan_sets
                    print("🔄 开始插入组数据，共 \(actionData.sets.count) 组...")
                    for (setIndex, setData) in actionData.sets.enumerated() {
                        if actionData.record_bilateral {
                            // 双侧训练
                            let insertSet = plan_sets.insert(
                                ps_plan_id <- planId,
                                ps_action_id <- actionData.action_id,
                                ps_set_number <- setData.order,
                                ps_weight <- 0, // 双侧训练时weight字段设为0
                                ps_reps <- setData.reps,
                                ps_left_weight <- (setData.left_weight ?? 0),
                                ps_right_weight <- (setData.right_weight ?? 0),
                                ps_created_at <- currentTime
                            )
                            try db.run(insertSet)
                            print("✅ 双侧组数据插入: 组\(setIndex + 1), 左\(setData.left_weight ?? 0)kg, 右\(setData.right_weight ?? 0)kg, \(setData.reps)次")
                        } else {
                            // 普通训练
                            let insertSet = plan_sets.insert(
                                ps_plan_id <- planId,
                                ps_action_id <- actionData.action_id,
                                ps_set_number <- setData.order,
                                ps_weight <- (setData.weight ?? 0),
                                ps_reps <- setData.reps,
                                ps_left_weight <- 0, // 普通训练时left_weight设为0
                                ps_right_weight <- 0, // 普通训练时right_weight设为0
                                ps_created_at <- currentTime
                            )
                            try db.run(insertSet)
                            print("✅ 普通组数据插入: 组\(setIndex + 1), \(setData.weight ?? 0)kg, \(setData.reps)次")
                        }
                    }
                }
                
                print("✅ LocalPlanService.updatePlan() 所有数据插入完成")
            }
            
            print("✅ LocalPlanService.updatePlan() 数据库事务提交成功")
            
            // 验证数据是否真的更新了
            print("🔍 LocalPlanService.updatePlan() 验证更新结果...")
            let verifyQuery = training_plans
                .select(tp_name, tp_description, tp_updated_at)
                .filter(tp_id == planId)
            
            if let verifyRow = try db.pluck(verifyQuery) {
                print("✅ 验证成功 - 更新后的数据:")
                print("  - 计划名称: \(verifyRow[tp_name])")
                print("  - 计划描述: \(verifyRow[tp_description])")
                print("  - 更新时间: \(verifyRow[tp_updated_at])")
            } else {
                print("❌ 验证失败 - 无法找到更新后的计划")
            }
            
            // 验证动作数据
            let verifyActionsQuery = plan_actions
                .select(pa_action_id, pa_order, pa_sets, pa_rest)
                .filter(pa_plan_id == planId)
                .order(pa_order.asc)
            
            print("🔍 验证动作数据:")
            for actionRow in try db.prepare(verifyActionsQuery) {
                print("  - 动作ID: \(actionRow[pa_action_id]), 顺序: \(actionRow[pa_order]), 组数: \(actionRow[pa_sets]), 休息: \(actionRow[pa_rest])秒")
            }
            
        } catch let error as LocalPlanError {
            print("❌ LocalPlanService.updatePlan() LocalPlanError: \(error.message)")
            throw error
        } catch {
            print("❌ LocalPlanService.updatePlan() 未知错误: \(error)")
            print("❌ 错误类型: \(type(of: error))")
            print("❌ 错误描述: \(error.localizedDescription)")
            throw LocalPlanError.serverError(get_error_message("SERVER_ERROR", language: language))
        }
    }
    
    // MARK: - 辅助方法
    private func convertToTrainingPlan(_ plan_dict: [String: Any]) -> TrainingPlan {
        let id = plan_dict["id"] as? Int ?? 0
        let name = plan_dict["name"] as? String ?? ""
        let isTemplate = plan_dict["is_template"] as? Bool ?? false
        let created_at = plan_dict["created_at"] as? String ?? ""
        
        return TrainingPlan(
            id: id,
            name: name,
            creator: isTemplate ? "系统模板" : "我",
            createdDate: formatDate(created_at),
            lastTraining: "未开始",
            volume: 0, // 基础列表不计算容量，详情页才计算
            description: plan_dict["description"] as? String,
            isTemplate: isTemplate,
            templateId: plan_dict["template_id"] as? Int,
            difficulty: plan_dict["difficulty"] as? String,
            duration: plan_dict["duration"] as? Int,
            actions: nil
        )
    }
    
    private func convertToTrainingPlanDetail(_ plan_dict: [String: Any]) -> TrainingPlan {
        let id = plan_dict["id"] as? Int ?? 0
        let name = plan_dict["name"] as? String ?? ""
        let isTemplate = plan_dict["is_template"] as? Bool ?? false
        let created_at = plan_dict["created_at"] as? String ?? ""
        let actionsData = plan_dict["actions"] as? [[String: Any]] ?? []
        
        let trainingActions = actionsData.map { actionData in
            let actionInfo = actionData["action_info"] as? [String: Any] ?? [:]
            let setsData = actionData["sets"] as? [[String: Any]] ?? []
            
            let sets = setsData.map { setData in
                TrainingSet(
                    id: setData["id"] as? Int ?? 0,
                    weight: setData["weight"] as? Double ?? 0,
                    reps: setData["reps"] as? Int ?? 0,
                    isCompleted: false,
                    actualWeight: nil,
                    actualReps: nil,
                    leftWeight: setData["left_weight"] as? Double ?? 0,
                    rightWeight: setData["right_weight"] as? Double ?? 0
                )
            }
            
            return TrainingAction(
                id: actionInfo["id"] as? Int ?? 0,
                name: actionInfo["name"] as? String ?? "",
                sets: sets,
                restTime: actionData["rest"] as? Int ?? 60,
                notes: actionData["note"] as? String,
                recordBilateral: actionData["record_bilateral"] as? Bool ?? false,
                imageUrl: actionInfo["gifUrl"] as? String ?? ""
            )
        }
        
        return TrainingPlan(
            id: id,
            name: name,
            creator: isTemplate ? "系统模板" : "我",
            createdDate: formatDate(created_at),
            lastTraining: "未开始",
            volume: 0, // 会通过calculatedVolume计算
            description: plan_dict["description"] as? String,
            isTemplate: isTemplate,
            templateId: plan_dict["template_id"] as? Int,
            difficulty: plan_dict["difficulty"] as? String,
            duration: plan_dict["duration"] as? Int,
            actions: trainingActions
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func formatDateForDisplay(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
} 
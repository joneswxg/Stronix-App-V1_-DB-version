import Foundation
import SQLite

/// 本地训练计划相关数据模型
/// 迁移自 Backend-Reference/src/stronix/models/PlanModels.py

// MARK: - 训练计划模型（已迁移到LocalTrainingModels.swift）
// LocalTrainingPlan已在LocalTrainingModels.swift中定义，此处不再重复

// MARK: - 计划动作模型
struct LocalPlanAction {
    let plan_id: Int
    let action_id: Int
    let order: Int
    let sets: Int
    let reps: String
    let rest: Int
    let weight: Double
    let user_id: Int?
    let note: String
    let record_bilateral: Bool
    
    init(plan_id: Int, action_id: Int, order: Int = 1, sets: Int = 1,
         reps: String = "12", rest: Int = 60, weight: Double = 0.0,
         user_id: Int? = nil, note: String = "", record_bilateral: Bool = false) {
        self.plan_id = plan_id
        self.action_id = action_id
        self.order = order
        self.sets = sets
        self.reps = reps
        self.rest = rest
        self.weight = weight
        self.user_id = user_id
        self.note = note
        self.record_bilateral = record_bilateral
    }
    
    /// 转换为字典格式
    func to_dict() -> [String: Any] {
        return [
            "plan_id": plan_id,
            "action_id": action_id,
            "order": order,
            "sets": sets,
            "reps": reps,
            "rest": rest,
            "weight": weight,
            "user_id": user_id as Any,
            "note": note,
            "record_bilateral": record_bilateral
        ]
    }
    
    /// 从字典创建实例
    static func from_dict(_ data: [String: Any]) -> LocalPlanAction {
        return LocalPlanAction(
            plan_id: data["plan_id"] as? Int ?? 0,
            action_id: data["action_id"] as? Int ?? 0,
            order: data["order"] as? Int ?? 1,
            sets: data["sets"] as? Int ?? 1,
            reps: data["reps"] as? String ?? "12",
            rest: data["rest"] as? Int ?? 60,
            weight: data["weight"] as? Double ?? 0.0,
            user_id: data["user_id"] as? Int,
            note: data["note"] as? String ?? "",
            record_bilateral: data["record_bilateral"] as? Bool ?? false
        )
    }
}

// MARK: - 计划组数据模型
struct LocalPlanSet {
    let id: Int?
    let plan_id: Int
    let action_id: Int
    let set_number: Int
    let weight: Double
    let reps: Int
    let left_weight: Double?
    let right_weight: Double?
    let notes: String?
    let created_at: Date
    
    init(id: Int? = nil, plan_id: Int = 0, action_id: Int = 0,
         set_number: Int = 1, weight: Double = 0.0, reps: Int = 12,
         left_weight: Double? = nil, right_weight: Double? = nil,
         notes: String? = nil, created_at: Date = Date()) {
        self.id = id
        self.plan_id = plan_id
        self.action_id = action_id
        self.set_number = set_number
        self.weight = weight
        self.reps = reps
        self.left_weight = left_weight
        self.right_weight = right_weight
        self.notes = notes
        self.created_at = created_at
    }
    
    /// 转换为字典格式
    func to_dict() -> [String: Any] {
        return [
            "id": id as Any,
            "plan_id": plan_id,
            "action_id": action_id,
            "set_number": set_number,
            "weight": weight,
            "reps": reps,
            "left_weight": left_weight as Any,
            "right_weight": right_weight as Any,
            "notes": notes as Any,
            "created_at": ISO8601DateFormatter().string(from: created_at)
        ]
    }
    
    /// 从字典创建实例
    static func from_dict(_ data: [String: Any]) -> LocalPlanSet {
        let dateFormatter = ISO8601DateFormatter()
        return LocalPlanSet(
            id: data["id"] as? Int,
            plan_id: data["plan_id"] as? Int ?? 0,
            action_id: data["action_id"] as? Int ?? 0,
            set_number: data["set_number"] as? Int ?? 1,
            weight: data["weight"] as? Double ?? 0.0,
            reps: data["reps"] as? Int ?? 12,
            left_weight: data["left_weight"] as? Double,
            right_weight: data["right_weight"] as? Double,
            notes: data["notes"] as? String,
            created_at: data["created_at"] as? String != nil ?
                dateFormatter.date(from: data["created_at"] as! String) ?? Date() : Date()
        )
    }
}

// MARK: - 动作模型（用于计划中的动作信息）
struct LocalAction {
    let id: Int
    let name: String
    let name_en: String
    let gifUrl: String
    let description: String
    let bodypart_id: Int
    let equipment_id: Int
    let is_bilateral: Bool
    
    init(id: Int, name: String, name_en: String = "", gifUrl: String = "",
         description: String = "", bodypart_id: Int = 0, equipment_id: Int = 0,
         is_bilateral: Bool = false) {
        self.id = id
        self.name = name
        self.name_en = name_en
        self.gifUrl = gifUrl
        self.description = description
        self.bodypart_id = bodypart_id
        self.equipment_id = equipment_id
        self.is_bilateral = is_bilateral
    }
    
    /// 转换为字典格式
    func to_dict() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "name_en": name_en,
            "gifUrl": gifUrl,
            "description": description,
            "bodypart_id": bodypart_id,
            "equipment_id": equipment_id,
            "is_bilateral": is_bilateral
        ]
    }
    
    /// 从字典创建实例
    static func from_dict(_ data: [String: Any]) -> LocalAction {
        return LocalAction(
            id: data["id"] as? Int ?? 0,
            name: data["name"] as? String ?? "",
            name_en: data["name_en"] as? String ?? "",
            gifUrl: data["gifUrl"] as? String ?? "",
            description: data["description"] as? String ?? "",
            bodypart_id: data["bodypart_id"] as? Int ?? 0,
            equipment_id: data["equipment_id"] as? Int ?? 0,
            is_bilateral: data["is_bilateral"] as? Bool ?? false
        )
    }
}

// MARK: - 错误处理
enum LocalPlanError: Error {
    case planNameEmpty(String)
    case noActions(String)
    case unauthorized(String)
    case planNotFound(String)
    case actionNotFound(String)
    case permissionDenied(String)
    case templateNotFound(String)
    case invalidSetData(String)
    case serverError(String)
    case planInUse(String)
    
    var message: String {
        switch self {
        case .planNameEmpty(let msg): return msg
        case .noActions(let msg): return msg
        case .unauthorized(let msg): return msg
        case .planNotFound(let msg): return msg
        case .actionNotFound(let msg): return msg
        case .permissionDenied(let msg): return msg
        case .templateNotFound(let msg): return msg
        case .invalidSetData(let msg): return msg
        case .serverError(let msg): return msg
        case .planInUse(let msg): return msg
        }
    }
    
    var code: Int {
        switch self {
        case .planNameEmpty, .noActions, .invalidSetData: return 400
        case .unauthorized: return 401
        case .permissionDenied: return 403
        case .planNotFound, .actionNotFound, .templateNotFound: return 404
        case .planInUse: return 409
        case .serverError: return 500
        }
    }
}

// MARK: - 错误码常量
struct LocalPlanErrorCode {
    static let SUCCESS = 200
    static let INVALID_REQUEST = 400
    static let UNAUTHORIZED = 401
    static let FORBIDDEN = 403
    static let NOT_FOUND = 404
    static let CONFLICT = 409
    static let SERVER_ERROR = 500
}

// MARK: - 多语言错误信息
let ERROR_MESSAGES: [String: [String: String]] = [
    "zh_CN": [
        "PLAN_NAME_EMPTY": "计划名称不能为空",
        "NO_ACTIONS": "请至少添加一个动作",
        "UNAUTHORIZED": "请先登录",
        "PLAN_NOT_FOUND": "计划不存在",
        "ACTION_NOT_FOUND": "动作不存在",
        "PERMISSION_DENIED": "无权限操作此计划",
        "TEMPLATE_NOT_FOUND": "模板计划不存在",
        "INVALID_SET_DATA": "组数据格式错误",
        "SERVER_ERROR": "服务器错误，请稍后重试",
        "PLAN_IN_USE": "计划正在使用中，无法删除"
    ],
    "en_US": [
        "PLAN_NAME_EMPTY": "Plan name cannot be empty",
        "NO_ACTIONS": "Please add at least one action",
        "UNAUTHORIZED": "Please login first",
        "PLAN_NOT_FOUND": "Plan not found",
        "ACTION_NOT_FOUND": "Action not found",
        "PERMISSION_DENIED": "Permission denied for this plan",
        "TEMPLATE_NOT_FOUND": "Template plan not found",
        "INVALID_SET_DATA": "Invalid set data format",
        "SERVER_ERROR": "Server error, please try again later",
        "PLAN_IN_USE": "Plan is in use, cannot be deleted"
    ]
]

func get_error_message(_ error_key: String, language: String = "zh_CN") -> String {
    return ERROR_MESSAGES[language]?[error_key] ?? ERROR_MESSAGES["zh_CN"]?[error_key] ?? error_key
}

// MARK: - API 请求/响应模型

/// 创建计划响应
struct CreatePlanResponse {
    let plan_id: Int
    
    init(plan_id: Int) {
        self.plan_id = plan_id
    }
}

/// Typed User Plan input used at the persistence boundary.
struct PlanDraft: Equatable {
    let name: String
    let description: String?
    let difficulty: String?
    let duration: Int?
    let actions: [PlanActionDraft]

    init(
        name: String,
        description: String? = nil,
        difficulty: String? = nil,
        duration: Int? = nil,
        actions: [PlanActionDraft] = []
    ) {
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.duration = duration
        self.actions = actions
    }

    func validate(language: String = "zh_CN") throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalPlanError.planNameEmpty(get_error_message("PLAN_NAME_EMPTY", language: language))
        }
        guard !actions.isEmpty else {
            throw LocalPlanError.noActions(get_error_message("NO_ACTIONS", language: language))
        }
        guard actions.allSatisfy({ action in
            !action.sets.isEmpty &&
                action.rest >= 0 &&
                action.sets.allSatisfy { set in
                    set.reps > 0 &&
                        [set.weight, set.leftWeight, set.rightWeight]
                        .compactMap { $0 }
                        .allSatisfy { $0.isFinite && $0 >= 0 }
                }
        }) else {
            throw LocalPlanError.invalidSetData(get_error_message("INVALID_SET_DATA", language: language))
        }
    }
}

struct PlanActionDraft: Equatable {
    let actionID: Int
    let rest: Int
    let note: String?
    let recordBilateral: Bool
    let sets: [PlanSetDraft]

    init(
        actionID: Int,
        rest: Int = 60,
        note: String? = nil,
        recordBilateral: Bool = false,
        sets: [PlanSetDraft] = []
    ) {
        self.actionID = actionID
        self.rest = rest
        self.note = note
        self.recordBilateral = recordBilateral
        self.sets = sets
    }
}

struct PlanSetDraft: Equatable {
    let weight: Double?
    let reps: Int
    let leftWeight: Double?
    let rightWeight: Double?
    let notes: String?

    init(
        weight: Double? = nil,
        reps: Int = 12,
        leftWeight: Double? = nil,
        rightWeight: Double? = nil,
        notes: String? = nil
    ) {
        self.weight = weight
        self.reps = reps
        self.leftWeight = leftWeight
        self.rightWeight = rightWeight
        self.notes = notes
    }
}

/// 创建计划请求
struct CreatePlanRequest {
    let name: String
    let description: String?
    let difficulty: String?
    let duration: Int?
    let actions: [CreatePlanAction]
    
    init(name: String, description: String? = nil, difficulty: String? = nil, 
         duration: Int? = nil, actions: [CreatePlanAction] = []) {
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.duration = duration
        self.actions = actions
    }
}

/// 创建计划动作
struct CreatePlanAction {
    let action_id: Int
    let order: Int
    let rest: Int
    let note: String?
    let record_bilateral: Bool
    let sets: [CreatePlanSet]
    
    init(action_id: Int, order: Int = 1, rest: Int = 60, note: String? = nil, 
         record_bilateral: Bool = false, sets: [CreatePlanSet] = []) {
        self.action_id = action_id
        self.order = order
        self.rest = rest
        self.note = note
        self.record_bilateral = record_bilateral
        self.sets = sets
    }
}

/// 创建计划组
struct CreatePlanSet {
    let set_number: Int
    let weight: Double?
    let reps: Int
    let left_weight: Double?
    let right_weight: Double?
    let notes: String?
    
    init(set_number: Int = 1, weight: Double? = nil, reps: Int = 12,
         left_weight: Double? = nil, right_weight: Double? = nil, notes: String? = nil) {
        self.set_number = set_number
        self.weight = weight
        self.reps = reps
        self.left_weight = left_weight
        self.right_weight = right_weight
        self.notes = notes
    }
}

/// 更新计划请求
struct UpdatePlanRequest {
    let name: String
    let description: String?
    let difficulty: String?
    let duration: Int?
    let actions: [UpdatePlanAction]

    init(name: String, description: String? = nil, difficulty: String? = nil,
         duration: Int? = nil, actions: [UpdatePlanAction] = []) {
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.duration = duration
        self.actions = actions
    }
}

extension PlanDraft {
    init(updateRequest: UpdatePlanRequest) {
        self.init(
            name: updateRequest.name,
            description: updateRequest.description,
            difficulty: updateRequest.difficulty,
            duration: updateRequest.duration,
            actions: updateRequest.actions
                .sorted { $0.order < $1.order }
                .map { action in
                    PlanActionDraft(
                        actionID: action.action_id,
                        rest: action.rest,
                        note: action.note,
                        recordBilateral: action.record_bilateral,
                        sets: action.sets
                            .sorted { $0.order < $1.order }
                            .map { set in
                                PlanSetDraft(
                                    weight: set.weight,
                                    reps: set.reps,
                                    leftWeight: set.left_weight,
                                    rightWeight: set.right_weight,
                                    notes: set.notes
                                )
                            }
                    )
                }
        )
    }
}

/// 更新计划动作
struct UpdatePlanAction {
    let action_id: Int
    let order: Int
    let rest: Int
    let note: String?
    let record_bilateral: Bool
    let sets: [UpdatePlanSet]
    
    init(action_id: Int, order: Int = 1, rest: Int = 60, note: String? = nil,
         record_bilateral: Bool = false, sets: [UpdatePlanSet] = []) {
        self.action_id = action_id
        self.order = order
        self.rest = rest
        self.note = note
        self.record_bilateral = record_bilateral
        self.sets = sets
    }
}

/// 更新计划组
struct UpdatePlanSet {
    let order: Int
    let weight: Double?
    let reps: Int
    let left_weight: Double?
    let right_weight: Double?
    let notes: String?
    
    init(order: Int = 1, weight: Double? = nil, reps: Int = 12,
         left_weight: Double? = nil, right_weight: Double? = nil, notes: String? = nil) {
        self.order = order
        self.weight = weight
        self.reps = reps
        self.left_weight = left_weight
        self.right_weight = right_weight
        self.notes = notes
    }
}
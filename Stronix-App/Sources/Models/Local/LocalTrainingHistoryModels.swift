import Foundation
import SQLite

/// 本地训练历史相关数据模型
/// 迁移自 Backend-Reference/src/stronix/models/TrainingHistoryModels.py

// TODO: 迁移TrainingHistoryDetail、TrainingHistoryOverview等模型
// TODO: 替换现有的TrainingHistoryModels.swift中的网络模型 

// MARK: - 本地训练历史错误处理
/// 本地训练历史错误类型
/// 迁移自 Backend-Reference/src/stronix/models/TrainingHistoryModels.py
enum LocalTrainingHistoryError: Error {
    case databaseNotInitialized
    case invalidTrainingData(String)
    case planNotFound(String)
    case historyNotFound(String)
    case unauthorized(String)
    case serverError(String)
    
    var message: String {
        switch self {
        case .databaseNotInitialized:
            return "数据库未初始化"
        case .invalidTrainingData(let msg):
            return "训练数据无效: \(msg)"
        case .planNotFound(let msg):
            return "训练计划未找到: \(msg)"
        case .historyNotFound(let msg):
            return "训练历史未找到: \(msg)"
        case .unauthorized(let msg):
            return "未授权访问: \(msg)"
        case .serverError(let msg):
            return "服务器错误: \(msg)"
        }
    }
}

// MARK: - 本地训练历史详情数据模型
/// 训练历史详情数据模型（用于本地数据库操作）
/// 迁移自 Backend-Reference TrainingHistoryDetail
struct LocalTrainingHistoryDetail {
    let action_id: Int
    let set_number: Int
    let weight: Double?
    let weight_unit: String
    let reps: Int?
    let difficulty: String?
    let left_weight: Double?
    let right_weight: Double?
    let is_completed: Bool
    let note: String?
    
    init(action_id: Int, set_number: Int, weight: Double? = nil, weight_unit: String = "kg",
         reps: Int? = nil, difficulty: String? = nil, left_weight: Double? = nil,
         right_weight: Double? = nil, is_completed: Bool = false, note: String? = nil) {
        self.action_id = action_id
        self.set_number = set_number
        self.weight = weight
        self.weight_unit = weight_unit
        self.reps = reps
        self.difficulty = difficulty
        self.left_weight = left_weight
        self.right_weight = right_weight
        self.is_completed = is_completed
        self.note = note
    }
    
    /// 从现有的TrainingHistoryDetail转换
    init(from detail: TrainingHistoryDetail) {
        self.action_id = detail.action_id
        self.set_number = detail.set_number
        self.weight = detail.weight
        self.weight_unit = detail.weight_unit
        self.reps = detail.reps
        self.difficulty = detail.difficulty
        self.left_weight = detail.left_weight
        self.right_weight = detail.right_weight
        self.is_completed = detail.is_completed
        self.note = detail.note
    }
}

// MARK: - 本地训练历史保存请求模型
/// 保存训练历史请求数据模型（用于本地数据库操作）
/// 迁移自 Backend-Reference SaveTrainingHistoryRequest
struct LocalSaveTrainingHistoryRequest {
    let plan_id: Int?
    let session_id: Int
    let plan_name: String
    let plan_description: String?
    let training_date: String // ISO 8601 格式
    let volume: Double
    let duration: Int // 秒
    let note: String?
    let details: [LocalTrainingHistoryDetail]
    
    /// 从现有的SaveTrainingHistoryRequest转换
    init(from request: SaveTrainingHistoryRequest) {
        self.plan_id = request.plan_id
        self.session_id = request.session_id
        self.plan_name = request.plan_name
        self.plan_description = request.plan_description
        self.training_date = request.training_date
        self.volume = request.volume
        self.duration = request.duration
        self.note = request.note
        self.details = request.details.map { LocalTrainingHistoryDetail(from: $0) }
    }
}

// MARK: - 本地训练历史响应模型
/// 训练历史响应数据模型（用于本地数据库查询）
/// 迁移自 Backend-Reference TrainingHistoryResponse
struct LocalTrainingHistoryResponse {
    let id: Int
    let plan_id: Int?
    let plan_name: String
    let training_date: String
    let volume: Double
    let duration: Int
    let note: String?
    let created_at: String?
    
    /// 转换为前端使用的响应格式
    func toSaveTrainingHistoryResponse() -> SaveTrainingHistoryResponse {
        return SaveTrainingHistoryResponse(history_id: id)
    }
}

// MARK: - 本地训练历史详情响应模型
/// 训练历史详情响应数据模型（用于本地数据库查询）
/// 迁移自 Backend-Reference TrainingHistoryDetailResponse
struct LocalTrainingHistoryDetailResponse {
    let history: LocalTrainingHistoryResponse
    let details: [LocalTrainingHistoryDetailData]
}

/// 训练历史详情数据（包含动作名称）
struct LocalTrainingHistoryDetailData {
    let action_id: Int
    let set_number: Int
    let weight: Double?
    let weight_unit: String
    let reps: Int?
    let difficulty: String?
    let left_weight: Double?
    let right_weight: Double?
    let is_completed: Bool
    let action_name: String?
    let note: String?
}

// MARK: - 本地训练历史列表响应模型
/// 训练历史列表响应数据模型
/// 迁移自 Backend-Reference 的分页逻辑
struct LocalTrainingHistoryListResponse {
    let histories: [LocalTrainingHistoryResponse]
    let pagination: LocalPaginationInfo
}

/// 分页信息
struct LocalPaginationInfo {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}

// MARK: - 本地训练日期响应模型
/// 训练日期响应数据模型
/// 迁移自 Backend-Reference get_training_dates
struct LocalTrainingDatesResponse {
    let training_dates: [String]
    let start_date: String
    let end_date: String
    let total_days: Int
}

// MARK: - 本地训练统计响应模型
/// 训练统计响应数据模型
/// 迁移自 Backend-Reference get_training_statistics
struct LocalTrainingStatisticsResponse {
    let core_metrics: LocalCoreMetrics
    let volume_trend: [LocalVolumeTrendData]
    let plan_usage: [LocalPlanUsageData]
    let time_range: String
}

/// 核心统计指标
struct LocalCoreMetrics {
    let training_count: Int
    let total_volume: Double
    let total_duration: Int // 分钟
    let streak_days: Int
}

/// 容量趋势数据
struct LocalVolumeTrendData {
    let date: String
    let volume: Double
}

/// 计划使用数据
struct LocalPlanUsageData {
    let plan_name: String
    let usage_count: Int
    let total_volume: Double
}

// MARK: - 本地计划更新相关模型
/// 从训练更新计划请求数据模型（用于本地数据库操作）
/// 迁移自 Backend-Reference UpdatePlanFromTrainingRequest
struct LocalUpdatePlanFromTrainingRequest {
    let name: String
    let description: String?
    let difficulty: String?
    let duration: Int?
    let actions: [LocalUpdatePlanActionFromTraining]
    
    /// 从现有的UpdatePlanFromTrainingRequest转换
    init(from request: UpdatePlanFromTrainingRequest) {
        self.name = request.name
        self.description = request.description
        self.difficulty = request.difficulty
        self.duration = request.duration
        self.actions = request.actions.map { LocalUpdatePlanActionFromTraining(from: $0) }
    }
}

/// 从训练更新的计划动作模型
struct LocalUpdatePlanActionFromTraining {
    let action_id: Int
    let rest: Int
    let note: String
    let record_bilateral: Bool
    let order: Int
    let sets: [LocalUpdatePlanSetFromTraining]
    
    /// 从现有的UpdatePlanActionFromTraining转换
    init(from action: UpdatePlanActionFromTraining) {
        self.action_id = action.action_id
        self.rest = action.rest
        self.note = action.note
        self.record_bilateral = action.record_bilateral
        self.order = action.order
        self.sets = action.sets.map { LocalUpdatePlanSetFromTraining(from: $0) }
    }
}

/// 从训练更新的计划组数据模型
struct LocalUpdatePlanSetFromTraining {
    let weight: Double?
    let reps: Int
    let left_weight: Double?
    let right_weight: Double?
    let order: Int
    
    /// 从现有的UpdatePlanSetFromTraining转换
    init(from set: UpdatePlanSetFromTraining) {
        self.weight = set.weight
        self.reps = set.reps
        self.left_weight = set.left_weight
        self.right_weight = set.right_weight
        self.order = set.order
    }
}

// MARK: - 动作进步数据模型
/// 动作进步数据模型
/// 迁移自 Backend-Reference get_action_progress
struct LocalActionProgressResponse {
    let action_name: String
    let progress_data: [LocalActionProgressData]
    let current_pr: LocalActionPR?
    let volume_trend: [LocalVolumeTrendData]
}

/// 动作进步数据
struct LocalActionProgressData {
    let date: String
    let max_weight: Double
    let total_volume: Double
    let max_reps: Int
}

/// 动作个人记录
struct LocalActionPR {
    let max_weight: Double
    let max_reps: Int
    let best_volume: Double
    let date: String
}

// MARK: - 辅助函数
/// 获取错误信息（简化版，保持与其他Local服务一致）
func get_local_training_error_message(_ errorKey: String, language: String = "zh_CN") -> String {
    let messages: [String: [String: String]] = [
        "INVALID_REQUEST": [
            "zh_CN": "请求数据无效",
            "en": "Invalid request data"
        ],
        "INVALID_TRAINING_DATA": [
            "zh_CN": "训练数据无效",
            "en": "Invalid training data"
        ],
        "PLAN_NOT_FOUND": [
            "zh_CN": "训练计划未找到",
            "en": "Training plan not found"
        ],
        "HISTORY_NOT_FOUND": [
            "zh_CN": "训练历史未找到",
            "en": "Training history not found"
        ],
        "SERVER_ERROR": [
            "zh_CN": "服务器内部错误",
            "en": "Internal server error"
        ]
    ]
    
    return messages[errorKey]?[language] ?? "未知错误"
}

// MARK: - 前端兼容层模型（来自TrainingHistoryModels.swift）

/// 保存训练历史请求模型（前端兼容层）
struct SaveTrainingHistoryRequest: Codable {
    let plan_id: Int?
    let session_id: Int
    let plan_name: String
    let plan_description: String?
    let training_date: String // ISO 8601 格式
    let volume: Double
    let duration: Int // 秒
    let note: String?
    let details: [TrainingHistoryDetail]
}

/// 训练历史详情模型（前端兼容层）
struct TrainingHistoryDetail: Codable {
    let action_id: Int
    let set_number: Int
    let weight: Double?
    let weight_unit: String
    let reps: Int?
    let difficulty: String?
    let left_weight: Double?
    let right_weight: Double?
    let is_completed: Bool
    let note: String?
    
    init(action_id: Int, set_number: Int, weight: Double? = nil, weight_unit: String = "kg", 
         reps: Int? = nil, difficulty: String? = nil, left_weight: Double? = nil, 
         right_weight: Double? = nil, is_completed: Bool = false, note: String? = nil) {
        self.action_id = action_id
        self.set_number = set_number
        self.weight = weight
        self.weight_unit = weight_unit
        self.reps = reps
        self.difficulty = difficulty
        self.left_weight = left_weight
        self.right_weight = right_weight
        self.is_completed = is_completed
        self.note = note
    }
}

/// 保存训练历史响应模型（前端兼容层）
struct SaveTrainingHistoryResponse: Codable {
    let history_id: Int
}

/// 更新计划请求模型（前端兼容层）
struct UpdatePlanFromTrainingRequest: Codable {
    let name: String
    let description: String?
    let difficulty: String?
    let duration: Int?
    let actions: [UpdatePlanActionFromTraining]
}

/// 从训练更新的计划动作模型（前端兼容层）
struct UpdatePlanActionFromTraining: Codable {
    let action_id: Int
    let rest: Int
    let note: String
    let record_bilateral: Bool
    let order: Int
    let sets: [UpdatePlanSetFromTraining]
}

/// 从训练更新的计划组数据模型（前端兼容层）
struct UpdatePlanSetFromTraining: Codable {
    let weight: Double?
    let reps: Int
    let left_weight: Double?
    let right_weight: Double?
    let order: Int
}

// MARK: - UI 显示相关数据模型（前端兼容层）

/// 训练详情UI数据结构
struct TrainingDetailData {
    let planName: String
    let duration: String
    let totalVolume: String
    let exercises: [ExerciseDetail]
}

/// 动作详情UI结构
struct ExerciseDetail {
    let name: String
    let sets: [SetDetail]
}

/// 组数详情UI结构
struct SetDetail {
    let number: Int
    let weight: Int
    let reps: Int
    let actualReps: Int
    let isCompleted: Bool
}
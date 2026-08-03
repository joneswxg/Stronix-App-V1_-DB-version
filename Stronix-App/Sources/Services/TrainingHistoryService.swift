import Foundation

protocol TrainingHistorySaving: TrainingHistoryPersisting {
    func updatePlanFromTraining(planId: Int, request: UpdatePlanFromTrainingRequest) async throws
}

/// 训练历史服务类（已迁移到本地数据库）
/// 保持原有接口，内部调用LocalTrainingHistoryService
class TrainingHistoryService: ObservableObject, TrainingHistorySaving {
    static let shared = TrainingHistoryService()

    private let localService: LocalTrainingHistoryService

    init(localService: LocalTrainingHistoryService = .shared) {
        self.localService = localService
    }
    
    /// 保存训练历史（本地化）
    func saveTrainingHistory(_ request: SaveTrainingHistoryRequest) async throws -> SaveTrainingHistoryResponse {
        return try await localService.saveTrainingHistory(request)
    }
    
    /// 从训练更新计划（本地化）
    func updatePlanFromTraining(planId: Int, request: UpdatePlanFromTrainingRequest) async throws {
        try await localService.updatePlanFromTraining(planId: planId, request: request)
    }
    
    /// 获取训练历史列表（本地化）
    func getTrainingHistory(page: Int = 1, limit: Int = 20, planId: Int? = nil, startDate: String? = nil, endDate: String? = nil) async throws -> TrainingHistoryListResponse {
        return try await localService.getTrainingHistory(page: page, limit: limit, planId: planId, startDate: startDate, endDate: endDate)
    }
    
    /// 获取指定日期范围内有训练记录的日期列表（本地化）
    func getTrainingDates(startDate: String, endDate: String) async throws -> TrainingDatesResponse {
        return try await localService.getTrainingDates(startDate: startDate, endDate: endDate)
    }
    
    /// 获取训练历史详情（本地化）
    func getTrainingHistoryDetail(historyId: Int) async throws -> TrainingHistoryDetailResponse {
        return try await localService.getTrainingHistoryDetail(historyId: historyId)
    }
    
    /// 更新训练历史（本地化）
    func updateTrainingHistory(historyId: Int, request: UpdateTrainingHistoryRequest) async throws {
        try await localService.updateTrainingHistory(historyId: historyId, request: request)
    }
    
    /// 删除训练历史（本地化）
    func deleteTrainingHistory(historyId: Int) async throws {
        try await localService.deleteTrainingHistory(historyId: historyId)
    }
    
    /// 获取训练统计数据（本地化）
    func getTrainingStatistics(timeRange: String = "week") async throws -> TrainingStatisticsResponse {
        return try await localService.getTrainingStatistics(timeRange: timeRange)
    }
    
    /// 获取动作进步数据（本地化）
    func getActionProgress(actionName: String) async throws -> ActionProgressResponse {
        return try await localService.getActionProgress(actionName: actionName)
    }
    
    /// 获取按身体部位和周统计的训练容量数据（本地化）
    func getWeeklyVolumeByBodyPart(bodyPart: String) async throws -> [VolumeTrendData] {
        return try await localService.getWeeklyVolumeByBodyPart(bodyPart: bodyPart)
    }
    
    /// 获取按身体部位和周统计的训练时长数据（本地化）
    func getWeeklyDurationByBodyPart(bodyPart: String) async throws -> [DurationTrendData] {
        return try await localService.getWeeklyDurationByBodyPart(bodyPart: bodyPart)
    }
    
    /// 获取按身体部位和月统计的训练容量数据（本地化）
    func getMonthlyVolumeByBodyPart(bodyPart: String, year: Int) async throws -> [VolumeTrendData] {
        return try await localService.getMonthlyVolumeByBodyPart(bodyPart: bodyPart, year: year)
    }
    
    /// 获取按身体部位和月统计的训练时长数据（本地化）
    func getMonthlyDurationByBodyPart(bodyPart: String, year: Int) async throws -> [DurationTrendData] {
        return try await localService.getMonthlyDurationByBodyPart(bodyPart: bodyPart, year: year)
    }
}

/// 训练历史API响应包装器
struct TrainingHistoryAPIResponse: Codable {
    let code: Int
    let message: String
    let data: SaveTrainingHistoryResponse?
}

/// 训练历史列表API响应包装器
struct TrainingHistoryListAPIResponse: Codable {
    let code: Int
    let message: String
    let data: TrainingHistoryListResponse?
}

/// 训练历史详情API响应包装器
struct TrainingHistoryDetailAPIResponse: Codable {
    let code: Int
    let message: String
    let data: TrainingHistoryDetailResponse?
}

/// 训练日期API响应包装器
struct TrainingDatesAPIResponse: Codable {
    let code: Int
    let message: String
    let data: TrainingDatesResponse?
}

/// 训练统计API响应包装器
struct TrainingStatisticsAPIResponse: Codable {
    let code: Int
    let message: String
    let data: TrainingStatisticsResponse?
}

/// 动作进步API响应包装器
struct ActionProgressAPIResponse: Codable {
    let code: Int
    let message: String
    let data: ActionProgressResponse?
}

/// API错误响应
struct APIErrorResponse: Codable {
    let code: Int
    let message: String
}

/// 训练历史列表响应
struct TrainingHistoryListResponse: Codable {
    let histories: [TrainingHistoryItem]
    let pagination: PaginationInfo
}

/// 训练历史项目
struct TrainingHistoryItem: Codable, Equatable, Sendable {
    let id: Int
    let plan_id: Int?
    let plan_name: String
    let training_date: String
    let volume: Double
    let duration: Int
    let note: String?
    let created_at: String?
}

/// 分页信息
struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}

/// 训练历史详情响应
struct TrainingHistoryDetailResponse: Codable {
    let history: TrainingHistoryItem
    let details: [TrainingHistoryDetailItem]
}

/// 训练日期响应
struct TrainingDatesResponse: Codable {
    let training_dates: [String]
    let start_date: String
    let end_date: String
    let total_days: Int
}

/// 训练历史详情项目
struct TrainingHistoryDetailItem: Codable {
    let action_id: Int
    let set_number: Int
    let weight: Double?
    let weight_unit: String
    let reps: Int?
    let difficulty: String?
    let rir: SetRIR?
    let left_weight: Double?
    let right_weight: Double?
    let is_completed: Bool
    let action_name: String?
    let history_record_bilateral: Bool
}

/// 训练统计响应
struct TrainingStatisticsResponse: Codable {
    let core_metrics: CoreMetrics
    let volume_trend: [VolumeTrendData]
    let duration_trend: [DurationTrendData]
    let plan_usage: [PlanUsageDataAPI]
    let time_range: String
}

/// 核心指标
struct CoreMetrics: Codable {
    let training_count: Int
    let total_volume: Double
    let total_duration: Int
    let streak_days: Int
}

/// 容量趋势数据
struct VolumeTrendData: Codable {
    let date: String
    let volume: Double
}

/// 训练时长趋势数据
struct DurationTrendData: Codable {
    let date: String
    let duration: Int
}

/// 计划使用数据（API响应）
struct PlanUsageDataAPI: Codable {
    let plan_name: String
    let count: Int
    let percentage: Int
}

/// 动作进步响应
struct ActionProgressResponse: Codable {
    let action_name: String
    let current_record: ActionRecord
    let best_record: ActionRecord
    let progress_data: [ProgressData]
}

/// 动作记录
struct ActionRecord: Codable {
    let max_weight: Double
    let date: String
    let max_reps: Int
}

/// 进步数据
struct ProgressData: Codable {
    let date: String
    let max_weight: Double
    let total_volume: Double
    let max_reps: Int
}

/// 网络错误枚举
enum NetworkError: Error, LocalizedError {
    case invalidResponse
    case decodingError
    case networkUnavailable
    case unauthorized
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应无效"
        case .decodingError:
            return "数据解析失败"
        case .networkUnavailable:
            return "网络不可用"
        case .unauthorized:
            return "未授权，请重新登录"
        case .serverError(let message):
            return message
        }
    }
}
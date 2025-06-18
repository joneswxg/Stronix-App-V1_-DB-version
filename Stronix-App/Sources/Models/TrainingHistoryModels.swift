import Foundation

// MARK: - 训练历史数据模型

/// 保存训练历史请求模型
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

/// 训练历史详情模型
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
    
    init(action_id: Int, set_number: Int, weight: Double? = nil, weight_unit: String = "kg", 
         reps: Int? = nil, difficulty: String? = nil, left_weight: Double? = nil, 
         right_weight: Double? = nil, is_completed: Bool = false) {
        self.action_id = action_id
        self.set_number = set_number
        self.weight = weight
        self.weight_unit = weight_unit
        self.reps = reps
        self.difficulty = difficulty
        self.left_weight = left_weight
        self.right_weight = right_weight
        self.is_completed = is_completed
    }
}

/// 保存训练历史响应模型
struct SaveTrainingHistoryResponse: Codable {
    let history_id: Int
}

/// 更新计划请求模型（用于训练完成后更新计划）
struct UpdatePlanFromTrainingRequest: Codable {
    let name: String
    let description: String?
    let difficulty: String?
    let duration: Int?
    let actions: [UpdatePlanActionFromTraining]
}

/// 从训练更新的计划动作模型
struct UpdatePlanActionFromTraining: Codable {
    let action_id: Int
    let rest: Int
    let note: String
    let record_bilateral: Bool
    let order: Int
    let sets: [UpdatePlanSetFromTraining]
}

/// 从训练更新的计划组数据模型
struct UpdatePlanSetFromTraining: Codable {
    let weight: Double?
    let reps: Int
    let left_weight: Double?
    let right_weight: Double?
    let order: Int
}

// MARK: - UI 显示相关数据模型

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
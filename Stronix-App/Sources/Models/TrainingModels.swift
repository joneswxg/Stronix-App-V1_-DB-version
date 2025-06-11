import Foundation

// MARK: - 训练计划相关模型

/// 训练计划数据模型
struct TrainingPlan: Identifiable {
    let id: Int
    let name: String
    let creator: String
    let createdDate: String
    let lastTraining: String
    let volume: Int
    let description: String?
    let isTemplate: Bool
    let templateId: Int?
    let difficulty: String?
    let duration: Int? // 预计训练时长（分钟）
    let actions: [TrainingAction]?
    
    // MARK: - 兼容性构造函数（保持与旧版本的兼容）
    init(id: Int, name: String, creator: String, createdDate: String, lastTraining: String, volume: Int) {
        self.id = id
        self.name = name
        self.creator = creator
        self.createdDate = createdDate
        self.lastTraining = lastTraining
        self.volume = volume
        self.description = nil
        self.isTemplate = false
        self.templateId = nil
        self.difficulty = nil
        self.duration = nil
        self.actions = nil
    }
    
    // MARK: - 完整构造函数
    init(id: Int, name: String, creator: String, createdDate: String, lastTraining: String, volume: Int, 
         description: String? = nil, isTemplate: Bool = false, templateId: Int? = nil, 
         difficulty: String? = nil, duration: Int? = nil, actions: [TrainingAction]? = nil) {
        self.id = id
        self.name = name
        self.creator = creator
        self.createdDate = createdDate
        self.lastTraining = lastTraining
        self.volume = volume
        self.description = description
        self.isTemplate = isTemplate
        self.templateId = templateId
        self.difficulty = difficulty
        self.duration = duration
        self.actions = actions
    }
}

// MARK: - API响应模型（与后端API保持一致）

/// API返回的计划列表项模型
struct APIPlan: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let difficulty: String?
    let duration: Int?
    let created_at: String
    let updated_at: String
    let is_template: Bool
    let template_id: Int?
    let total_volume: Double? // 新增：总容量
    let actions_count: Int? // 新增：动作数量
    let actions_summary: [APIPlanActionSummary]? // 新增：动作摘要
    
    // 转换为前端使用的TrainingPlan模型
    func toTrainingPlan() -> TrainingPlan {
        // 如果有动作摘要，创建简化的TrainingAction
        let actions: [TrainingAction]? = if let actionsSummary = actions_summary, !actionsSummary.isEmpty {
            actionsSummary.map { summary in
                TrainingAction(
                    id: summary.action_id,
                    name: summary.action_name,
                    totalSets: summary.sets_count,
                    restTime: 60,
                    notes: nil,
                    recordBilateral: false,
                    imageUrl: ""
                )
            }
        } else if let actionsCount = actions_count, actionsCount > 0 {
            // 如果只有动作数量，创建占位动作
            (1...actionsCount).map { index in
                TrainingAction(
                    id: index,
                    name: "动作\(index)",
                    totalSets: 1,
                    restTime: 60,
                    notes: nil,
                    recordBilateral: false,
                    imageUrl: ""
                )
            }
        } else {
            nil
        }
        
        return TrainingPlan(
            id: id,
            name: name,
            creator: is_template ? "系统模板" : "我",
            createdDate: formatDate(created_at),
            lastTraining: "未开始",
            volume: Int(total_volume ?? 0), // 使用后端计算的容量
            description: description,
            isTemplate: is_template,
            templateId: template_id,
            difficulty: difficulty,
            duration: duration,
            actions: actions
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
}

/// API返回的计划详情模型
struct APIPlanDetail: Codable {
    let id: Int
    let name: String
    let description: String?
    let difficulty: String?
    let duration: Int?
    let user_id: Int?
    let is_template: Bool
    let template_id: Int?
    let created_at: String
    let updated_at: String
    let actions: [APIPlanAction]
    
    /// 转换为前端使用的TrainingPlan模型
    func toTrainingPlan() -> TrainingPlan {
        let trainingActions = actions.map { apiAction in
            TrainingAction(
                id: apiAction.action_id,
                name: apiAction.action_info.name,
                sets: apiAction.sets.map { apiSet in
                    TrainingSet(
                        id: apiSet.id ?? 0,
                        weight: apiSet.weight,
                        reps: apiSet.reps,
                        isCompleted: false,
                        actualWeight: nil,
                        actualReps: nil,
                        leftWeight: apiSet.left_weight,  // 直接使用，不再需要nil合并
                        rightWeight: apiSet.right_weight  // 直接使用，不再需要nil合并
                    )
                },
                restTime: apiAction.rest,
                notes: apiAction.note,
                recordBilateral: apiAction.record_bilateral,
                imageUrl: apiAction.action_info.gifUrl
            )
        }
        
        return TrainingPlan(
            id: id,
            name: name,
            creator: is_template ? "系统模板" : "我",
            createdDate: formatDate(created_at),
            lastTraining: "未开始",
            volume: 0, // 会通过calculatedVolume计算
            description: description,
            isTemplate: is_template,
            templateId: template_id,
            difficulty: difficulty,
            duration: duration,
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
}

/// API返回的计划动作模型
struct APIPlanAction: Codable {
    let action_id: Int
    let order: Int
    let sets_count: Int
    let rest: Int
    let weight: Double
    let note: String?
    let record_bilateral: Bool
    let action_info: APIActionInfo
    let sets: [APIPlanSet]
    
    // 添加自定义解码器来处理可能的类型问题
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.action_id = try container.decode(Int.self, forKey: .action_id)
        self.order = try container.decode(Int.self, forKey: .order)
        self.sets_count = try container.decode(Int.self, forKey: .sets_count)
        self.rest = try container.decode(Int.self, forKey: .rest)
        self.weight = try container.decode(Double.self, forKey: .weight)
        self.note = try? container.decode(String.self, forKey: .note)
        self.record_bilateral = try container.decode(Bool.self, forKey: .record_bilateral)
        self.action_info = try container.decode(APIActionInfo.self, forKey: .action_info)
        self.sets = try container.decode([APIPlanSet].self, forKey: .sets)
    }
    
    private enum CodingKeys: String, CodingKey {
        case action_id, order, sets_count, rest, weight, note, record_bilateral, action_info, sets
    }
}

/// API返回的动作信息模型
struct APIActionInfo: Codable {
    let id: Int
    let name: String
    let name_en: String?
    let gifUrl: String
    let description: String?
    let bodypart_id: Int
    let equipment_id: Int
    let is_bilateral: Bool
    
    // 添加自定义解码器来处理可能的类型问题
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.name_en = try? container.decode(String.self, forKey: .name_en)
        self.gifUrl = try container.decode(String.self, forKey: .gifUrl)
        self.description = try? container.decode(String.self, forKey: .description)
        self.bodypart_id = try container.decode(Int.self, forKey: .bodypart_id)
        self.equipment_id = try container.decode(Int.self, forKey: .equipment_id)
        self.is_bilateral = try container.decode(Bool.self, forKey: .is_bilateral)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, name_en, gifUrl, description, bodypart_id, equipment_id, is_bilateral
    }
}

/// API返回的计划组数据模型
struct APIPlanSet: Codable {
    let id: Int?
    let set_number: Int
    let weight: Double
    let reps: Int
    let left_weight: Double  // 改为非可选类型
    let right_weight: Double  // 改为非可选类型
    let created_at: String?
    
    // 添加自定义解码器来处理可能的类型问题
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 处理id字段，可能是Int或String
        if let idInt = try? container.decode(Int.self, forKey: .id) {
            self.id = idInt
        } else if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = Int(idString)
        } else {
            self.id = nil
        }
        
        self.set_number = try container.decode(Int.self, forKey: .set_number)
        // 处理weight字段，如果为null则使用0.0
        self.weight = (try? container.decode(Double.self, forKey: .weight)) ?? 0.0
        self.reps = try container.decode(Int.self, forKey: .reps)
        
        // 处理left_weight和right_weight，如果为null则使用0.0
        self.left_weight = (try? container.decode(Double.self, forKey: .left_weight)) ?? 0.0
        self.right_weight = (try? container.decode(Double.self, forKey: .right_weight)) ?? 0.0
        
        self.created_at = try? container.decode(String.self, forKey: .created_at)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, set_number, weight, reps, left_weight, right_weight, created_at
    }
}

/// 训练动作模型
struct TrainingAction: Identifiable {
    let id: Int
    let name: String
    let sets: [TrainingSet]
    let restTime: Int // 休息时间（秒）
    let notes: String?
    let recordBilateral: Bool // 新增：是否记录双侧重量
    let imageUrl: String // 新增：动作图片URL
    private let _totalSets: Int? // 私有字段，用于列表显示时的组数
    
    // 便利构造函数，保持向后兼容
    init(id: Int, name: String, sets: [TrainingSet], restTime: Int, notes: String? = nil, recordBilateral: Bool = false, imageUrl: String = "") {
        self.id = id
        self.name = name
        self.sets = sets
        self.restTime = restTime
        self.notes = notes
        self.recordBilateral = recordBilateral
        self.imageUrl = imageUrl
        self._totalSets = nil
    }
    
    // 用于列表显示的构造函数
    init(id: Int, name: String, totalSets: Int, restTime: Int, notes: String? = nil, recordBilateral: Bool = false, imageUrl: String = "") {
        self.id = id
        self.name = name
        self.sets = []
        self.restTime = restTime
        self.notes = notes
        self.recordBilateral = recordBilateral
        self.imageUrl = imageUrl
        self._totalSets = totalSets
    }
}

/// 训练组数模型
struct TrainingSet: Identifiable {
    let id: Int
    let weight: Double
    let reps: Int
    let isCompleted: Bool
    let actualWeight: Double?
    let actualReps: Int?
    let leftWeight: Double  // 改为非可选类型
    let rightWeight: Double  // 改为非可选类型
    
    // 便利构造函数，用于创建新的训练组
    init(id: Int, weight: Double, reps: Int, isCompleted: Bool = false, 
         actualWeight: Double? = nil, actualReps: Int? = nil, 
         leftWeight: Double = 0.0, rightWeight: Double = 0.0) {  // 设置默认值为0.0
        self.id = id
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
        self.actualWeight = actualWeight
        self.actualReps = actualReps
        self.leftWeight = leftWeight
        self.rightWeight = rightWeight
    }
}

// MARK: - 训练会话相关模型

/// 训练会话模型（正在进行的训练）
struct TrainingSession: Identifiable {
    let id: Int
    let planId: Int
    let startTime: Date
    let endTime: Date?
    let isCompleted: Bool
    let totalVolume: Int
    let notes: String?
}

/// 训练历史模型
struct TrainingHistory: Identifiable {
    let id: Int
    let planId: Int
    let planName: String
    let date: Date
    let duration: Int // 训练时长（秒）
    let totalVolume: Int
    let completedActions: Int
    let totalActions: Int
    let notes: String?
}

// MARK: - 扩展方法

extension TrainingPlan {
    /// 计算总训练容量（支持双侧训练）
    var calculatedVolume: Int {
        return actions?.reduce(0) { total, action in
            total + action.totalVolume
        } ?? volume
    }
    
    /// 是否为个人创建的计划
    var isPersonalPlan: Bool {
        return !isTemplate && templateId == nil
    }
    
    /// 获取计划的动作描述（用于卡片显示）
    var actionsDescription: [String] {
        guard let actions = actions else { return [] }
        return actions.prefix(3).map { action in
            "\(action.name) x \(action.totalSets)组"
        }
    }
    
    /// 是否有更多动作（超过3个）
    var hasMoreActions: Bool {
        return (actions?.count ?? 0) > 3
    }
}

extension TrainingAction {
    /// 计算该动作的总容量（支持双侧训练）
    var totalVolume: Int {
        return sets.reduce(0) { total, set in
            if recordBilateral {
                // 双侧训练：左重量 + 右重量 × 次数
                return total + Int((set.leftWeight + set.rightWeight) * Double(set.reps))
            } else {
                // 普通训练：重量 × 次数
                return total + Int(set.weight * Double(set.reps))
            }
        }
    }
    
    /// 计算总组数
    var totalSets: Int {
        return _totalSets ?? sets.count
    }
}

extension TrainingHistory {
    /// 完成率
    var completionRate: Double {
        guard totalActions > 0 else { return 0 }
        return Double(completedActions) / Double(totalActions)
    }
    
    /// 格式化的训练时长
    var formattedDuration: String {
        let hours = duration / 60
        let minutes = duration % 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

/// API返回的计划动作摘要模型（用于列表显示）
struct APIPlanActionSummary: Codable {
    let action_id: Int
    let action_name: String
    let sets_count: Int
} 
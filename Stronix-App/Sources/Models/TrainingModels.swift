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

/// 训练动作模型
struct TrainingAction: Identifiable {
    let id: Int
    let name: String
    let sets: [TrainingSet]
    let restTime: Int // 休息时间（秒）
    let notes: String?
}

/// 训练组数模型
struct TrainingSet: Identifiable {
    let id: Int
    let weight: Double
    let reps: Int
    let isCompleted: Bool
    let actualWeight: Double?
    let actualReps: Int?
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
    let duration: Int // 训练时长（分钟）
    let totalVolume: Int
    let completedActions: Int
    let totalActions: Int
    let notes: String?
}

// MARK: - 扩展方法

extension TrainingPlan {
    /// 计算总训练容量
    var calculatedVolume: Int {
        return actions?.reduce(0) { total, action in
            total + action.sets.reduce(0) { setTotal, set in
                setTotal + Int(set.weight * Double(set.reps))
            }
        } ?? volume
    }
    
    /// 是否为个人创建的计划
    var isPersonalPlan: Bool {
        return !isTemplate && templateId == nil
    }
}

extension TrainingAction {
    /// 计算该动作的总容量
    var totalVolume: Int {
        return sets.reduce(0) { total, set in
            total + Int(set.weight * Double(set.reps))
        }
    }
    
    /// 计算总组数
    var totalSets: Int {
        return sets.count
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
import SwiftUI
import Combine
import Foundation

/// 全局训练会话管理器
class TrainingSessionManager: ObservableObject {
    static let shared = TrainingSessionManager()
    
    // MARK: - 训练状态
    @Published var isTrainingActive: Bool = false
    @Published var currentPlan: TrainingPlan?
    @Published var trainingStartTime: Date?
    @Published var totalTrainingTime: TimeInterval = 0
    
    // MARK: - 训练数据
    @Published var editingActions: [MutableTrainingAction] = []
    @Published var completedSets: Set<String> = []
    @Published var setNotes: [String: String] = [:]
    @Published var planName: String = ""
    
    // 计时器
    private var trainingTimer: Timer?
    
    private init() {}
    
    // MARK: - 训练控制方法
    
    /// 开始训练
    func startTraining(with plan: TrainingPlan) {
        guard !isTrainingActive else { return }
        
        currentPlan = plan
        planName = plan.name
        editingActions = plan.actions?.map { MutableTrainingAction(from: $0) } ?? []
        completedSets.removeAll()
        setNotes.removeAll()
        
        isTrainingActive = true
        trainingStartTime = Date()
        totalTrainingTime = 0
        
        startTrainingTimer()
    }
    
    /// 停止训练
    func stopTraining() {
        isTrainingActive = false
        currentPlan = nil
        trainingStartTime = nil
        totalTrainingTime = 0
        planName = ""
        
        editingActions.removeAll()
        completedSets.removeAll()
        setNotes.removeAll()
        
        stopTrainingTimer()
    }
    
    /// 完成训练
    func completeTraining() {
        // 这里可以添加保存训练记录的逻辑
        stopTraining()
    }
    
    // MARK: - 计时器管理
    
    private func startTrainingTimer() {
        trainingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.trainingStartTime else { return }
            self.totalTrainingTime = Date().timeIntervalSince(startTime)
        }
    }
    
    private func stopTrainingTimer() {
        trainingTimer?.invalidate()
        trainingTimer = nil
    }
    
    // MARK: - 辅助方法
    
    /// 格式化训练时间
    func formattedTrainingTime() -> String {
        let hours = Int(totalTrainingTime) / 3600
        let minutes = Int(totalTrainingTime) % 3600 / 60
        let seconds = Int(totalTrainingTime) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// 计算已完成的训练容量
    func completedVolume() -> Double {
        var volume: Double = 0
        for action in editingActions {
            for set in action.sets {
                let setId = "\(action.id)_\(set.id)"
                if completedSets.contains(setId) {
                    if action.recordBilateral {
                        volume += ((set.leftWeight + set.rightWeight) * Double(set.reps))
                    } else {
                        volume += set.weight * Double(set.reps)
                    }
                }
            }
        }
        return volume
    }
    
    /// 计算计划总容量
    func totalVolume() -> Double {
        editingActions.reduce(0) { total, action in
            total + action.sets.reduce(0) { setTotal, set in
                if action.recordBilateral {
                    return setTotal + ((set.leftWeight + set.rightWeight) * Double(set.reps))
                } else {
                    return setTotal + (set.weight * Double(set.reps))
                }
            }
        }
    }
    
    // MARK: - 数据准备方法
    
    /// 准备训练历史保存数据
    func prepareTrainingHistoryData() -> SaveTrainingHistoryRequest? {
        guard let currentPlan = currentPlan else { return nil }
        
        var details: [TrainingHistoryDetail] = []
        
        // 遍历所有动作和组，准备详情数据
        for action in editingActions {
            for (index, set) in action.sets.enumerated() {
                let setId = "\(action.id)_\(set.id)"
                let isCompleted = completedSets.contains(setId)
                
                let detail = TrainingHistoryDetail(
                    action_id: action.id,
                    set_number: index + 1,
                    weight: action.recordBilateral ? nil : set.weight,
                    weight_unit: "kg",
                    reps: set.reps,
                    difficulty: nil,
                    left_weight: action.recordBilateral ? set.leftWeight : 0.0,
                    right_weight: action.recordBilateral ? set.rightWeight : 0.0,
                    is_completed: isCompleted
                )
                details.append(detail)
            }
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let trainingDate = dateFormatter.string(from: trainingStartTime ?? Date())
        
        return SaveTrainingHistoryRequest(
            plan_id: currentPlan.id,
            session_id: Int.random(in: 1000...9999), // 临时生成会话ID
            plan_name: planName,
            plan_description: currentPlan.description,
            training_date: trainingDate,
            volume: completedVolume(),
            duration: Int(totalTrainingTime),
            note: nil,
            details: details
        )
    }
    
    /// 准备计划更新数据
    func preparePlanUpdateData() -> UpdatePlanFromTrainingRequest? {
        guard let currentPlan = currentPlan else { return nil }
        
        var actions: [UpdatePlanActionFromTraining] = []
        
        for (order, action) in editingActions.enumerated() {
            var sets: [UpdatePlanSetFromTraining] = []
            
            for (setOrder, set) in action.sets.enumerated() {
                let planSet = UpdatePlanSetFromTraining(
                    weight: action.recordBilateral ? nil : set.weight,
                    reps: set.reps,
                    left_weight: action.recordBilateral ? set.leftWeight : 0.0,
                    right_weight: action.recordBilateral ? set.rightWeight : 0.0,
                    order: setOrder + 1
                )
                sets.append(planSet)
            }
            
            let planAction = UpdatePlanActionFromTraining(
                action_id: action.id,
                rest: action.restTime,
                note: "", // 可以从setNotes中获取相关备注
                record_bilateral: action.recordBilateral,
                order: order + 1,
                sets: sets
            )
            actions.append(planAction)
        }
        
        return UpdatePlanFromTrainingRequest(
            name: planName,
            description: currentPlan.description,
            difficulty: currentPlan.difficulty,
            duration: currentPlan.duration,
            actions: actions
        )
    }
    
    /// 检查计划是否有变动
    func hasChangesFromOriginalPlan() -> Bool {
        guard let originalPlan = currentPlan else { return false }
        
        // 检查计划名称是否变动
        if planName != originalPlan.name {
            return true
        }
        
        // 检查动作数量是否变动
        let originalActionsCount = originalPlan.actions?.count ?? 0
        if editingActions.count != originalActionsCount {
            return true
        }
        
        // 检查每个动作的详细信息是否变动
        for (index, editingAction) in editingActions.enumerated() {
            guard let originalActions = originalPlan.actions,
                  index < originalActions.count else { return true }
            
            let originalAction = originalActions[index]
            
            // 检查动作ID是否变动
            if editingAction.id != originalAction.id {
                return true
            }
            
            // 检查组数是否变动
            if editingAction.sets.count != originalAction.sets.count {
                return true
            }
            
            // 检查休息时间是否变动
            if editingAction.restTime != originalAction.restTime {
                return true
            }
            
            // 检查是否记录左右是否变动
            if editingAction.recordBilateral != originalAction.recordBilateral {
                return true
            }
            
            // 检查每组的数据是否变动
            for (setIndex, editingSet) in editingAction.sets.enumerated() {
                guard setIndex < originalAction.sets.count else { return true }
                
                let originalSet = originalAction.sets[setIndex]
                
                if editingAction.recordBilateral {
                    // 双侧训练模式
                    if editingSet.leftWeight != originalSet.leftWeight ||
                       editingSet.rightWeight != originalSet.rightWeight ||
                       editingSet.reps != originalSet.reps {
                        return true
                    }
                } else {
                    // 普通训练模式
                    if editingSet.weight != originalSet.weight ||
                       editingSet.reps != originalSet.reps {
                        return true
                    }
                }
            }
        }
        
        return false
    }
} 
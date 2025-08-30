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
    
    // MARK: - 私有属性
    private var trainingTimer: Timer?
    
    // MARK: - 组休息计时器管理
    @Published var setRestTimers: [String: Int] = [:] // 每组的剩余休息时间
    private var setTimers: [String: Timer] = [:] // 每组的计时器
    
    // MARK: - 浮动休息计时器管理
    @Published var showRestTimer = false
    @Published var currentRestTime: Int = 0
    @Published var isRestTimerPaused = false
    @Published var currentSetId: String = ""
    private var restTimer: Timer?
    
    // MARK: - 后台状态管理
    private var backgroundTime: Date?
    private var savedSetTimers: [String: Int] = [:]
    private var savedRestTime: Int = 0
    private var wasRestTimerRunning = false
    
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
        stopAllSetTimers()  // 停止所有组休息计时器
        stopRestTimer()     // 停止浮动休息计时器
        showRestTimer = false  // 隐藏浮动休息计时器
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
    
    // MARK: - 组休息计时器管理
    
    /// 开始组休息计时器
    func startSetRestTimer(setId: String, restTime: Int) {
        // 停止该组之前的计时器
        setTimers[setId]?.invalidate()
        
        // 设置初始时间
        setRestTimers[setId] = restTime
        
        // 开始新的计时器
        setTimers[setId] = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if let currentTime = self.setRestTimers[setId], currentTime > 0 {
                self.setRestTimers[setId] = currentTime - 1
                
                // 倒计时最后三秒提醒
                if currentTime <= 3 && currentTime > 0 {
                    NotificationManager.shared.triggerCountdownAlert()
                }
            } else {
                // 时间到了，停止计时器
                self.setTimers[setId]?.invalidate()
                self.setTimers.removeValue(forKey: setId)
                self.setRestTimers.removeValue(forKey: setId)
                
                // 获取下一组信息并发送通知
                self.handleRestTimerEnd(setId: setId)
            }
        }
    }
    
    /// 停止指定组的计时器
    func stopSetTimer(setId: String) {
        setTimers[setId]?.invalidate()
        setTimers.removeValue(forKey: setId)
        setRestTimers.removeValue(forKey: setId)
    }
    
    /// 停止所有组计时器
    func stopAllSetTimers() {
        for timer in setTimers.values {
            timer.invalidate()
        }
        setTimers.removeAll()
        setRestTimers.removeAll()
    }
    
    // 清理指定setId的计时器
    func invalidateSetTimer(setId: String) {
        if let timer = setTimers[setId] {
            timer.invalidate()
            setTimers.removeValue(forKey: setId)
        }
    }
    
    // MARK: - 浮动休息计时器管理
    
    /// 开始浮动休息计时器
    func startRestTimer() {
        isRestTimerPaused = false
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.currentRestTime > 0 {
                self.currentRestTime -= 1
                // 同步更新组计时器
                self.setRestTimers[self.currentSetId] = self.currentRestTime
                
                // 倒计时最后三秒提醒
                if self.currentRestTime <= 3 && self.currentRestTime > 0 {
                    NotificationManager.shared.triggerCountdownAlert()
                }
            } else {
                // 获取下一组信息并发送通知
                self.handleRestTimerEnd(setId: self.currentSetId)
                self.skipRestTimer()
            }
        }
    }
    
    /// 停止浮动休息计时器
    func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
    }
    
    /// 暂停/恢复浮动休息计时器
    func toggleRestTimer() {
        if isRestTimerPaused {
            startRestTimer()
        } else {
            stopRestTimer()
            isRestTimerPaused = true
        }
    }
    
    /// 重置浮动休息计时器
    func resetRestTimer() {
        stopRestTimer()
        // 重置为原始时间，这里需要从某个地方获取原始时间
        // 暂时设为60秒，实际应该从动作设置中获取
        currentRestTime = 60
        setRestTimers[currentSetId] = currentRestTime
    }
    
    /// 跳过浮动休息计时器
    func skipRestTimer() {
        stopRestTimer()
        stopSetTimer(setId: currentSetId)
        showRestTimer = false
        isRestTimerPaused = false
    }
    
    /// 增加休息时间
    func addRestTime(_ seconds: Int) {
        currentRestTime += seconds
        setRestTimers[currentSetId] = currentRestTime
    }
    
    /// 减少休息时间
    func subtractRestTime(_ seconds: Int) {
        currentRestTime = max(0, currentRestTime - seconds)
        setRestTimers[currentSetId] = currentRestTime
    }
    
    /// 关闭浮动休息计时器
    func closeRestTimer() {
        stopRestTimer()
        // 恢复组计时器
        if let remainingTime = setRestTimers[currentSetId] {
            startSetRestTimer(setId: currentSetId, restTime: remainingTime)
        }
        showRestTimer = false
        isRestTimerPaused = false
    }
    
    /// 处理组完成，开始休息计时器
    func handleSetCompleted(setId: String, restTime: Int) {
        startSetRestTimer(setId: setId, restTime: restTime)
    }
    
    /// 处理休息计时器点击，显示浮动窗口
    func handleRestTimerTapped(setId: String, restTime: Int) {
        currentSetId = setId
        currentRestTime = setRestTimers[setId] ?? restTime
        showRestTimer = true
        
        // 停止组计时器，开始浮动计时器
        stopSetTimer(setId: setId)
        startRestTimer()
    }
    
    /// 处理休息计时器结束
    private func handleRestTimerEnd(setId: String) {
        // 解析setId获取动作ID和组ID
        let components = setId.split(separator: "_")
        guard components.count >= 2,
              let actionId = Int(components[0]),
              let setIdInt = Int(components[1]) else { return }
        
        // 查找对应的动作和下一组
        guard let action = editingActions.first(where: { $0.id == actionId }) else { return }
        
        // 查找当前组的索引
        guard let currentSetIndex = action.sets.firstIndex(where: { $0.id == setIdInt }) else { return }
        
        // 确定下一组信息
        let nextSetIndex = currentSetIndex + 1
        var nextActionName = action.name
        var nextSetNumber = nextSetIndex + 1
        var nextReps = 0
        
        if nextSetIndex < action.sets.count {
            // 同一动作的下一组
            nextReps = action.sets[nextSetIndex].reps
        } else {
            // 查找下一个动作的第一组
            if let currentActionIndex = editingActions.firstIndex(where: { $0.id == actionId }),
               currentActionIndex + 1 < editingActions.count {
                let nextAction = editingActions[currentActionIndex + 1]
                nextActionName = nextAction.name
                nextSetNumber = 1
                nextReps = nextAction.sets.first?.reps ?? 0
            } else {
                // 已经是最后一个动作的最后一组
                nextActionName = "训练完成"
                nextSetNumber = 0
                nextReps = 0
            }
        }
        
        // 发送休息结束通知
        NotificationManager.shared.triggerRestEndAlert(
            actionName: nextActionName,
            setNumber: nextSetNumber,
            reps: nextReps
        )
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
                    is_completed: isCompleted,
                    history_record_bilateral: action.recordBilateral  // 添加这一行
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
            duration: Int(totalTrainingTime / 60), // 转换为分钟
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
    
    // MARK: - 应用生命周期处理
    
    /// 应用进入后台时的处理
    func handleAppDidEnterBackground() {
        guard isTrainingActive else { return }
        
        print("⏰ 保存计时器状态 - 应用进入后台")
        
        // 记录进入后台的时间
        backgroundTime = Date()
        
        // 保存组计时器状态
        savedSetTimers = setRestTimers
        
        // 保存浮动计时器状态
        savedRestTime = currentRestTime
        wasRestTimerRunning = restTimer != nil && !isRestTimerPaused
        
        // 停止所有计时器（系统会自动暂停，但我们主动停止以确保状态一致）
        // 注意：不清除计时器数据，只是暂停
    }
    
    /// 应用回到前台时的处理
    func handleAppDidBecomeActive() {
        guard isTrainingActive, let backgroundTime = backgroundTime else { return }
        
        print("⏰ 恢复计时器状态 - 应用回到前台")
        
        // 计算在后台的时间
        let timeInBackground = Date().timeIntervalSince(backgroundTime)
        let secondsInBackground = Int(timeInBackground)
        
        print("📱 应用在后台运行了 \(secondsInBackground) 秒")
        
        // 更新组计时器
        for (setId, remainingTime) in savedSetTimers {
            let newTime = max(0, remainingTime - secondsInBackground)
            setRestTimers[setId] = newTime
            
            // 如果时间已到，触发结束事件
            if newTime <= 0 && remainingTime > 0 {
                handleRestTimerEnd(setId: setId)
            } else if newTime > 0 {
                // 重新启动计时器
                startSetRestTimer(setId: setId, restTime: newTime)
            }
        }
        
        // 更新浮动计时器
        if wasRestTimerRunning {
            let newRestTime = max(0, savedRestTime - secondsInBackground)
            currentRestTime = newRestTime
            setRestTimers[currentSetId] = newRestTime
            
            if newRestTime <= 0 && savedRestTime > 0 {
                // 时间已到，触发结束事件
                handleRestTimerEnd(setId: currentSetId)
                skipRestTimer()
            } else if newRestTime > 0 {
                // 重新启动浮动计时器
                startRestTimer()
            }
        }
        
        // 清除后台状态
        self.backgroundTime = nil
        savedSetTimers.removeAll()
        savedRestTime = 0
        wasRestTimerRunning = false
    }
}
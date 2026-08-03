import SwiftUI
import Combine
import Foundation

protocol TrainingSessionManaging: AnyObject {
    var objectWillChange: ObservableObjectPublisher { get }
    var isTrainingActive: Bool { get }
    var currentPlan: TrainingPlan? { get }
    var editingActions: [MutableTrainingAction] { get set }
    var completedSets: Set<String> { get set }
    var setNotes: [String: String] { get set }
    var trainingDisplayUnit: TrainingDisplayUnit { get set }
    var planName: String { get }
    var showRestTimer: Bool { get }
    var showRestControls: Bool { get }
    var currentRestTime: Int { get }
    var isRestTimerPaused: Bool { get }

    func startTraining(with plan: TrainingPlan)
    func stopTraining()
    func completeTraining()
    func updateActions(_ actions: [MutableTrainingAction])
    func deleteAction(_ action: MutableTrainingAction)
    func toggleSetCompletion(setID: String, restTime: Int)
    func presentRestControls()
    func toggleRestTimer()
    func resetRestTimer()
    func skipRestTimer()
    func closeRestTimer()
    func addRestTime(_ seconds: Int)
    func subtractRestTime(_ seconds: Int)
    func formattedTrainingTime() -> String
    func completedVolume() -> Double
    func totalVolume() -> Double
    func captureCompletionSnapshot() -> TrainingCompletionSnapshot?
    func hasChangesFromOriginalPlan() -> Bool
}

/// 全局训练会话管理器
final class TrainingSessionManager: ObservableObject, TrainingSessionManaging, UserScopedStateResetting {
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
    @Published var trainingDisplayUnit: TrainingDisplayUnit = .kilograms
    @Published var planName: String = ""
    
    // MARK: - 私有属性
    private var trainingTimer: Timer?
    
    // MARK: - 浮动休息计时器管理
    @Published var showRestTimer = false
    @Published var showRestControls = false
    @Published var currentRestTime: Int = 0
    @Published private(set) var currentRestDuration: Int = 0
    @Published var isRestTimerPaused = false
    @Published var currentSetId: String = ""
    private var restTimer: Timer?
    private var restIntervalAtStart = 0
    private var didDeliverRestEndFeedback = false
    private var didRequestRestReminderPermission = false
    private let restReminderPermissionRequester: RestReminderPermissionRequesting

    // MARK: - 后台状态管理
    private var backgroundTime: Date?
    private var savedRestTime: Int = 0
    private var wasRestTimerRunning = false
    private var completionSnapshotID: UUID?
    
    init(restReminderPermissionRequester: RestReminderPermissionRequesting = NotificationManager.shared) {
        self.restReminderPermissionRequester = restReminderPermissionRequester
    }
    
    // MARK: - 训练控制方法
    
    /// 开始训练
    func startTraining(with plan: TrainingPlan) {
        guard !isTrainingActive,
              !plan.isTemplate,
              let actions = plan.actions,
              !actions.isEmpty else { return }

        currentPlan = plan
        planName = plan.name
        editingActions = actions.map { MutableTrainingAction(from: $0) }
        completedSets.removeAll()
        setNotes.removeAll()
        trainingDisplayUnit = .kilograms
        completionSnapshotID = UUID()

        isTrainingActive = true
        trainingStartTime = Date()
        totalTrainingTime = 0
        
        startTrainingTimer()
    }
    
    func resetUserScopedState() {
        stopTraining()
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
        trainingDisplayUnit = .kilograms
        completionSnapshotID = nil

        stopTrainingTimer()
        dismissRestTimer()
    }
    
    /// 完成训练
    func completeTraining() {
        stopTraining()
    }

    func updateActions(_ actions: [MutableTrainingAction]) {
        editingActions = actions
    }

    func deleteAction(_ action: MutableTrainingAction) {
        editingActions.removeAll { $0.id == action.id }
        completedSets = completedSets.filter { !$0.hasPrefix("\(action.id)_") }
        setNotes = setNotes.filter { !$0.key.hasPrefix("\(action.id)_") }
    }

    func toggleSetCompletion(setID: String, restTime: Int) {
        if completedSets.contains(setID) {
            completedSets.remove(setID)
        } else {
            completedSets.insert(setID)
            startRestCountdown(for: setID, duration: restTime)
        }
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
    
    // MARK: - 休息计时器管理

    private func startRestCountdown(for setID: String, duration: Int) {
        if !didRequestRestReminderPermission {
            didRequestRestReminderPermission = true
            restReminderPermissionRequester.requestPermissionForRestReminderIfNeeded()
        }
        stopRestTimer()
        currentSetId = setID
        restIntervalAtStart = max(0, duration)
        currentRestDuration = restIntervalAtStart
        currentRestTime = restIntervalAtStart
        showRestTimer = true
        showRestControls = false
        isRestTimerPaused = false
        didDeliverRestEndFeedback = false

        if currentRestTime == 0 {
            finishRestCountdown()
        } else {
            startRestTimer()
        }
    }

    private func startRestTimer() {
        guard showRestTimer, !isRestTimerPaused, currentRestTime > 0 else { return }
        stopRestTimer()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.currentRestTime -= 1
            if self.currentRestTime == 0 {
                self.finishRestCountdown()
            }
        }
    }

    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
    }

    private func finishRestCountdown() {
        stopRestTimer()
        currentRestTime = 0
        isRestTimerPaused = false
        guard !didDeliverRestEndFeedback else { return }
        didDeliverRestEndFeedback = true
        handleRestTimerEnd(setId: currentSetId)
    }

    private func dismissRestTimer() {
        stopRestTimer()
        showRestTimer = false
        showRestControls = false
        currentRestTime = 0
        isRestTimerPaused = false
        currentSetId = ""
        restIntervalAtStart = 0
        currentRestDuration = 0
        didDeliverRestEndFeedback = false
    }

    func presentRestControls() {
        guard showRestTimer else { return }
        showRestControls = true
    }

    func toggleRestTimer() {
        guard showRestTimer, currentRestTime > 0 else { return }
        if isRestTimerPaused {
            isRestTimerPaused = false
            startRestTimer()
        } else {
            stopRestTimer()
            isRestTimerPaused = true
        }
    }

    func resetRestTimer() {
        guard showRestTimer else { return }
        currentRestTime = restIntervalAtStart
        didDeliverRestEndFeedback = false
        if currentRestTime == 0 {
            finishRestCountdown()
        } else if !isRestTimerPaused {
            startRestTimer()
        }
    }

    func skipRestTimer() {
        dismissRestTimer()
    }

    func addRestTime(_ seconds: Int) {
        guard showRestTimer else { return }
        currentRestTime = max(0, currentRestTime + seconds)
    }

    func subtractRestTime(_ seconds: Int) {
        guard showRestTimer else { return }
        currentRestTime = max(0, currentRestTime - seconds)
        if currentRestTime == 0 {
            finishRestCountdown()
        }
    }

    func closeRestTimer() {
        dismissRestTimer()
    }

    private func handleRestTimerEnd(setId: String) {
        let components = setId.split(separator: "_")
        guard components.count >= 2,
              let actionId = Int(components[0]),
              let setIdInt = Int(components[1]) else { return }

        guard let action = editingActions.first(where: { $0.id == actionId }) else { return }
        guard let currentSetIndex = action.sets.firstIndex(where: { $0.id == setIdInt }) else { return }

        let nextSetIndex = currentSetIndex + 1
        var nextActionName = action.name
        var nextSetNumber = nextSetIndex + 1
        var nextReps = 0

        if nextSetIndex < action.sets.count {
            nextReps = action.sets[nextSetIndex].reps
        } else if let currentActionIndex = editingActions.firstIndex(where: { $0.id == actionId }),
                  currentActionIndex + 1 < editingActions.count {
            let nextAction = editingActions[currentActionIndex + 1]
            nextActionName = nextAction.name
            nextSetNumber = 1
            nextReps = nextAction.sets.first?.reps ?? 0
        } else {
            nextActionName = "训练完成"
            nextSetNumber = 0
        }

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

    func captureCompletionSnapshot() -> TrainingCompletionSnapshot? {
        guard let currentPlan else { return nil }

        var details: [TrainingHistoryDetail] = []
        for action in editingActions {
            for (index, set) in action.sets.enumerated() {
                let setID = "\(action.id)_\(set.id)"
                details.append(
                    TrainingHistoryDetail(
                        action_id: action.id,
                        set_number: index + 1,
                        weight: action.recordBilateral ? nil : set.weight,
                        weight_unit: "kg",
                        reps: set.reps,
                        difficulty: nil,
                        left_weight: action.recordBilateral ? set.leftWeight : 0.0,
                        right_weight: action.recordBilateral ? set.rightWeight : 0.0,
                        is_completed: completedSets.contains(setID),
                        history_record_bilateral: action.recordBilateral
                    )
                )
            }
        }

        let snapshotID = completionSnapshotID ?? UUID()
        completionSnapshotID = snapshotID

        let historyRequest = SaveTrainingHistoryRequest(
            plan_id: currentPlan.id,
            session_id: TrainingCompletionSnapshot.sessionID(for: snapshotID),
            plan_name: planName,
            plan_description: currentPlan.description,
            training_date: ISO8601DateFormatter().string(from: trainingStartTime ?? Date()),
            volume: completedVolume(),
            duration: Int(totalTrainingTime / 60),
            note: nil,
            details: details
        )

        let planDraft = PlanDraft(
            name: planName,
            description: currentPlan.description,
            difficulty: currentPlan.difficulty,
            duration: currentPlan.duration,
            actions: editingActions.map { action in
                PlanActionDraft(
                    actionID: action.id,
                    rest: action.restTime,
                    recordBilateral: action.recordBilateral,
                    sets: action.sets.map { set in
                        PlanSetDraft(
                            weight: action.recordBilateral ? nil : set.weight,
                            reps: set.reps,
                            leftWeight: action.recordBilateral ? set.leftWeight : nil,
                            rightWeight: action.recordBilateral ? set.rightWeight : nil
                        )
                    }
                )
            }
        )

        return TrainingCompletionSnapshot(
            id: snapshotID,
            historyRequest: historyRequest,
            planID: currentPlan.id,
            planDraft: planDraft
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
    
    func handleAppDidEnterBackground() {
        guard isTrainingActive else { return }

        backgroundTime = Date()
        savedRestTime = currentRestTime
        wasRestTimerRunning = showRestTimer && !isRestTimerPaused && currentRestTime > 0
        stopRestTimer()
    }

    func handleAppDidBecomeActive() {
        guard isTrainingActive, let backgroundTime else { return }
        defer {
            self.backgroundTime = nil
            savedRestTime = 0
            wasRestTimerRunning = false
        }

        guard wasRestTimerRunning else { return }
        currentRestTime = max(0, savedRestTime - Int(Date().timeIntervalSince(backgroundTime)))
        if currentRestTime == 0 {
            finishRestCountdown()
        } else {
            startRestTimer()
        }
    }
}
import Foundation
import SwiftUI

// 确保模型类型可用
// TrainingPlan等类型应该在同一模块中可见

extension Date {
    func ISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

@MainActor
class PlanViewModel: ObservableObject {
    @Published var templatePlans: [TrainingPlan] = []
    @Published var personalPlans: [TrainingPlan] = []
    @Published var selectedPlan: TrainingPlan?
    @Published var isLoadingTemplates = false
    @Published var isLoadingPersonal = false
    @Published var isLoadingPlanDetail = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let planService: LocalPlanService

    init(planService: LocalPlanService = .shared) {
        self.planService = planService
        loadData()
    }
    
    // MARK: - 数据加载
    func loadData() {
        Task {
            await loadTemplatePlans()
            await loadPersonalPlans()
        }
    }
    
    func loadTemplatePlans() async {
        isLoadingTemplates = true
        errorMessage = nil
        
        do {
            templatePlans = try await planService.getTemplatePlans()
        } catch {
            handleError(error, context: "加载模板计划")
        }
        
        isLoadingTemplates = false
    }
    
    func loadPersonalPlans() async {
        isLoadingPersonal = true
        errorMessage = nil
        
        do {
            personalPlans = try await planService.getPersonalPlans()
        } catch {
            handleError(error, context: "加载个人计划")
        }
        
        isLoadingPersonal = false
    }
    
    // MARK: - 计划详情
    func loadTemplatePlanDetail(planId: Int) async {
        isLoadingPlanDetail = true
        errorMessage = nil

        do {
            selectedPlan = try await planService.getTemplatePlanDetail(planId: planId)
        } catch {
            handleError(error, context: "加载模板计划详情")
        }

        isLoadingPlanDetail = false
    }

    func loadUserPlanDetail(planId: Int) async {
        isLoadingPlanDetail = true
        errorMessage = nil

        do {
            selectedPlan = try await planService.getUserPlanDetail(planId: planId)
        } catch {
            handleError(error, context: "加载个人计划详情")
        }

        isLoadingPlanDetail = false
    }

    func loadPlanDetail(planId: Int) async {
        await loadUserPlanDetail(planId: planId)
    }

    // MARK: - 辅助方法
    private func getCurrentUserId() throws -> Int {
        guard let userID = LocalUserService.shared.currentUser?.id else {
            throw LocalPlanError.unauthorized(get_error_message("UNAUTHORIZED"))
        }
        return userID
    }
    
    // MARK: - 计划操作
    func copyTemplatePlan(_ templatePlan: TrainingPlan) async {
        do {
            _ = try await planService.copyTemplatePlan(
                templateId: templatePlan.id,
                user_id: getCurrentUserId()
            )
            await refreshPersonalPlansOnly()
            showSuccessMessage("已将模板计划复制到个人计划")
        } catch {
            handleError(error, context: "复制模板计划")
        }
    }
    
    // MARK: - 复制个人计划
    func copyPersonalPlan(_ plan: TrainingPlan, newName: String) async {
        do {
            // 获取计划详情
            await loadPlanDetail(planId: plan.id)
            
            guard let detailedPlan = selectedPlan else {
                handleError(NSError(domain: "PlanViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取计划详情"]), context: "复制计划")
                return
            }
            
            // 构造新计划数据
            var newPlanData: [String: Any] = [
                "name": newName,
                "description": detailedPlan.description ?? "",
                "difficulty": detailedPlan.difficulty ?? "",
                "duration": detailedPlan.duration ?? 0,
                "actions": []
            ]
            
            // 复制动作数据
            var actionsArray: [[String: Any]] = []
            if let actions = detailedPlan.actions {
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
            let response = try await planService.createPlan(newPlanData, user_id: getCurrentUserId())
            print("复制个人计划成功，新计划ID: \(response.plan_id)")
            
            // 创建新的计划对象并添加到本地数组
            let newPlan = TrainingPlan(
                id: response.plan_id,
                name: newName,
                creator: plan.creator,
                createdDate: Date().ISO8601String(),
                lastTraining: "未开始",
                volume: plan.volume,
                description: plan.description,
                isTemplate: false,
                templateId: nil,
                difficulty: plan.difficulty,
                duration: plan.duration,
                actions: plan.actions
            )
            
            // 将新计划添加到列表开头
            personalPlans.insert(newPlan, at: 0)
            print("🔄 PlanViewModel.copyPersonalPlan() 本地添加完成，现有 \(personalPlans.count) 个计划")
            
            // 显示成功消息
            showSuccessMessage("计划复制成功")
            
        } catch {
            handleError(error, context: "复制计划")
        }
    }
    
    // MARK: - 删除计划
    func deletePlan(_ plan: TrainingPlan) async {
        do {
            try await planService.deletePlan(planId: plan.id, user_id: getCurrentUserId())
            
            // 直接从本地数组中移除，避免API调用
            personalPlans.removeAll { $0.id == plan.id }
            print("🔄 PlanViewModel.deletePlan() 本地删除完成，剩余 \(personalPlans.count) 个计划")
            
            // 显示成功消息
            showSuccessMessage("计划已删除")
            
        } catch {
            handleError(error, context: "删除计划")
        }
    }
    
    // MARK: - 更新计划
    func updatePlan(planId: Int, name: String, description: String?, difficulty: String?, actions: [UpdatePlanAction]) async {
        do {
            let request = UpdatePlanRequest(
                name: name,
                description: description,
                difficulty: difficulty,
                duration: nil,
                actions: actions
            )
            
            try await planService.updatePlan(planId: planId, planData: request, user_id: getCurrentUserId())
            
            // 使用轻量级刷新，减少API调用
            await refreshPersonalPlansOnly()
            
            // 显示成功消息
            showSuccessMessage("计划已更新")
            
        } catch {
            handleError(error, context: "更新计划")
        }
    }
    
    // MARK: - 更新计划（不自动刷新）
    func updatePlanWithoutRefresh(planId: Int, name: String, description: String?, difficulty: String?, actions: [UpdatePlanAction]) async throws {
        let request = UpdatePlanRequest(
            name: name,
            description: description,
            difficulty: difficulty,
            duration: nil,
            actions: actions
        )
        
        try await planService.updatePlan(planId: planId, planData: request, user_id: getCurrentUserId())
    }
    
    // MARK: - 错误处理
    private func handleError(_ error: Error, context: String) {
        print("[\(context)] 错误: \(error.localizedDescription)")
        
        if let localError = error as? LocalPlanError {
            errorMessage = "\(context)失败: \(localError.message)"
        } else {
            errorMessage = "\(context)失败: \(error.localizedDescription)"
        }
        
        showError = true
    }
    
    private func showSuccessMessage(_ message: String) {
        // 这里可以实现成功消息的显示逻辑
        print("成功: \(message)")
    }
    
    // MARK: - 刷新数据
    func refresh() {
        print("🔄 PlanViewModel.refresh() 被调用")
        Task {
            // 只刷新个人计划列表，不重新加载模板计划
            await refreshPersonalPlansOnly()
        }
    }
    
    // 强制刷新：确保UI更新
    @MainActor
    func forceRefresh() {
        print("🔄 PlanViewModel.forceRefresh() 被调用")
        Task {
            await refreshPersonalPlansOnly()
        }
    }
    
    // 轻量级刷新：重新加载个人计划列表，包含完整的动作数据以确保容量计算正确
    func refreshPersonalPlansOnly() async {
        print("🔄 PlanViewModel.refreshPersonalPlansOnly() 开始")
        isLoadingPersonal = true
        errorMessage = nil
        
        do {
            personalPlans = try await planService.getPersonalPlans()
        } catch {
            handleError(error, context: "刷新个人计划")
        }
        
        isLoadingPersonal = false
    }
    
    // MARK: - 清空数据
    func clearData() {
        templatePlans = []
        personalPlans = []
        selectedPlan = nil
        errorMessage = nil
        showError = false
    }
    
    // MARK: - 计算属性
    var hasTemplates: Bool {
        !templatePlans.isEmpty
    }
    
    var hasPersonalPlans: Bool {
        !personalPlans.isEmpty
    }
    
    var hasAnyPlans: Bool {
        hasTemplates || hasPersonalPlans
    }
}
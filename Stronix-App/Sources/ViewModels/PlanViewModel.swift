import Foundation
import SwiftUI

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
    
    private let planService = PlanService.shared
    
    init() {
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
            let plans = try await planService.getTemplatePlans()
            
            // 为每个模板计划加载详情以获取动作信息
            var enrichedPlans: [TrainingPlan] = []
            for plan in plans {
                do {
                    let detailedPlan = try await planService.getPlanDetail(planId: plan.id)
                    
                    // 创建包含动作摘要的计划对象
                    let enrichedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        creator: plan.creator,
                        createdDate: plan.createdDate,
                        lastTraining: plan.lastTraining,
                        volume: detailedPlan.calculatedVolume, // 使用计算后的容量
                        description: plan.description,
                        isTemplate: plan.isTemplate,
                        templateId: plan.templateId,
                        difficulty: plan.difficulty,
                        duration: plan.duration,
                        actions: detailedPlan.actions // 保留所有动作数据用于容量计算
                    )
                    
                    enrichedPlans.append(enrichedPlan)
                } catch {
                    // 如果获取详情失败，使用原始计划
                    enrichedPlans.append(plan)
                }
            }
            
            templatePlans = enrichedPlans
        } catch {
            handleError(error, context: "加载模板计划")
        }
        
        isLoadingTemplates = false
    }
    
    func loadPersonalPlans() async {
        isLoadingPersonal = true
        errorMessage = nil
        
        do {
            let plans = try await planService.getPersonalPlans()
            
            // 为每个计划加载详情以获取动作信息
            var enrichedPlans: [TrainingPlan] = []
            for plan in plans {
                do {
                    let detailedPlan = try await planService.getPlanDetail(planId: plan.id)
                    
                    // 创建包含动作摘要的计划对象
                    let enrichedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        creator: plan.creator,
                        createdDate: plan.createdDate,
                        lastTraining: plan.lastTraining,
                        volume: detailedPlan.calculatedVolume, // 使用计算后的容量
                        description: plan.description,
                        isTemplate: plan.isTemplate,
                        templateId: plan.templateId,
                        difficulty: plan.difficulty,
                        duration: plan.duration,
                        actions: detailedPlan.actions // 保留所有动作数据用于容量计算
                    )
                    
                    enrichedPlans.append(enrichedPlan)
                } catch {
                    // 如果获取详情失败，使用原始计划
                    enrichedPlans.append(plan)
                }
            }
            
            personalPlans = enrichedPlans
        } catch {
            handleError(error, context: "加载个人计划")
        }
        
        isLoadingPersonal = false
    }
    
    // MARK: - 计划详情
    func loadPlanDetail(planId: Int) async {
        isLoadingPlanDetail = true
        errorMessage = nil
        
        do {
            let plan = try await planService.getPlanDetail(planId: planId)
            selectedPlan = plan
        } catch {
            handleError(error, context: "加载计划详情")
        }
        
        isLoadingPlanDetail = false
    }
    
    // MARK: - 计划操作
    func copyTemplatePlan(_ templatePlan: TrainingPlan) async {
        do {
            let response = try await planService.copyTemplatePlan(templateId: templatePlan.id)
            print("复制计划成功，新计划ID: \(response.plan_id)")
            
            // 创建新的计划对象并添加到本地数组，避免API调用
            let newPlan = TrainingPlan(
                id: response.plan_id,
                name: "\(templatePlan.name) - 副本",
                creator: templatePlan.creator,
                createdDate: Date().ISO8601String(),
                lastTraining: "未开始",
                volume: templatePlan.volume,
                description: templatePlan.description,
                isTemplate: false,
                templateId: templatePlan.id,
                difficulty: templatePlan.difficulty,
                duration: templatePlan.duration,
                actions: templatePlan.actions
            )
            
            // 将新计划添加到列表开头
            personalPlans.insert(newPlan, at: 0)
            print("🔄 PlanViewModel.copyTemplatePlan() 本地添加完成，现有 \(personalPlans.count) 个计划")
            
            // 显示成功消息
            showSuccessMessage("已将模板计划复制到个人计划")
            
        } catch {
            handleError(error, context: "复制模板计划")
        }
    }
    
    // MARK: - 删除计划
    func deletePlan(_ plan: TrainingPlan) async {
        do {
            try await planService.deletePlan(planId: plan.id)
            
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
            
            try await planService.updatePlan(planId: planId, planData: request)
            
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
        
        try await planService.updatePlan(planId: planId, planData: request)
    }
    
    // MARK: - 错误处理
    private func handleError(_ error: Error, context: String) {
        print("[\(context)] 错误: \(error.localizedDescription)")
        
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                errorMessage = "登录已过期，请重新登录"
                // 不自动登出，让用户选择
            default:
                errorMessage = "\(context)失败: \(apiError.localizedDescription)"
            }
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
    
    // 轻量级刷新：只刷新个人计划列表，不获取详情
    func refreshPersonalPlansOnly() async {
        print("🔄 PlanViewModel.refreshPersonalPlansOnly() 开始")
        isLoadingPersonal = true
        errorMessage = nil
        
        do {
            let plans = try await planService.getPersonalPlans()
            
            // 简化版本：不为每个计划加载详情，减少API调用
            let simplifiedPlans = plans.map { plan in
                TrainingPlan(
                    id: plan.id,
                    name: plan.name,
                    creator: plan.creator,
                    createdDate: plan.createdDate,
                    lastTraining: plan.lastTraining,
                    volume: plan.volume, // 使用原始容量
                    description: plan.description,
                    isTemplate: plan.isTemplate,
                    templateId: plan.templateId,
                    difficulty: plan.difficulty,
                    duration: plan.duration,
                    actions: plan.actions // 使用原始动作数据
                )
            }
            
            personalPlans = simplifiedPlans
            print("🔄 PlanViewModel.refreshPersonalPlansOnly() 完成，加载了 \(simplifiedPlans.count) 个个人计划。")
            print("🔄 PlanViewModel.refreshPersonalPlansOnly() 实际个人计划数据: \(personalPlans.map { "\($0.name) (ID: \($0.id), isTemplate: \($0.isTemplate))" })")
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
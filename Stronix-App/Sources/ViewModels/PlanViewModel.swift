import Foundation
import SwiftUI

extension Date {
    func ISO8601String() -> String {
        ISO8601DateFormatter().string(from: self)
    }
}

@MainActor
final class PlanViewModel: ObservableObject {
    @Published var templatePlans: [TrainingPlan] = []
    @Published var personalPlans: [TrainingPlan] = []
    @Published var selectedPlan: TrainingPlan?
    @Published var isLoadingTemplates = false
    @Published var isLoadingPersonal = false
    @Published var isLoadingPlanDetail = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let repository: any PlanRepository
    private var hasLoadedInitialData = false
    private var listLoadTask: Task<Void, Never>?
    private var listLoadGeneration = 0

    init(repository: any PlanRepository = LocalPlanService.shared) {
        self.repository = repository
    }

    func loadInitialData() async {
        guard !hasLoadedInitialData else { return }
        await loadLists()
        hasLoadedInitialData = true
    }

    func refresh() async {
        await loadLists()
        hasLoadedInitialData = true
    }

    func loadTemplatePlans() async {
        isLoadingTemplates = true
        clearError()
        defer { isLoadingTemplates = false }

        do {
            templatePlans = try await repository.templatePlans()
        } catch {
            handleError(error, context: "加载模板计划")
        }
    }

    func loadPersonalPlans() async {
        isLoadingPersonal = true
        clearError()
        defer { isLoadingPersonal = false }

        do {
            personalPlans = try await repository.userPlans()
        } catch {
            handleError(error, context: "加载个人计划")
        }
    }

    func loadTemplatePlanDetail(planId: Int) async {
        isLoadingPlanDetail = true
        clearError()
        defer { isLoadingPlanDetail = false }

        do {
            selectedPlan = try await repository.templatePlanDetail(id: planId)
        } catch {
            handleError(error, context: "加载模板计划详情")
        }
    }

    func loadUserPlanDetail(planId: Int) async {
        isLoadingPlanDetail = true
        clearError()
        defer { isLoadingPlanDetail = false }

        do {
            selectedPlan = try await repository.userPlanDetail(id: planId)
        } catch {
            handleError(error, context: "加载个人计划详情")
        }
    }

    func loadPlanDetail(planId: Int) async {
        await loadUserPlanDetail(planId: planId)
    }

    func copyTemplatePlan(_ templatePlan: TrainingPlan) async {
        do {
            _ = try await repository.copyTemplatePlan(id: templatePlan.id)
            await refreshPersonalPlansOnly()
            showSuccessMessage("已将模板计划复制到个人计划")
        } catch {
            handleError(error, context: "复制模板计划")
        }
    }

    func copyPersonalPlan(_ plan: TrainingPlan, newName: String) async {
        await loadPlanDetail(planId: plan.id)
        guard let detailedPlan = selectedPlan else { return }

        let draft = PlanDraft(
            name: newName,
            description: detailedPlan.description,
            difficulty: detailedPlan.difficulty,
            duration: detailedPlan.duration,
            actions: detailedPlan.actions?.map { action in
                PlanActionDraft(
                    actionID: action.id,
                    rest: action.restTime,
                    note: action.notes,
                    recordBilateral: action.recordBilateral,
                    sets: action.sets.map { set in
                        PlanSetDraft(
                            weight: set.weight,
                            reps: set.reps,
                            leftWeight: set.leftWeight,
                            rightWeight: set.rightWeight,
                            notes: set.notes
                        )
                    }
                )
            } ?? []
        )

        do {
            let response = try await repository.createUserPlan(draft)
            personalPlans.insert(
                TrainingPlan(
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
                ),
                at: 0
            )
            showSuccessMessage("计划复制成功")
        } catch {
            handleError(error, context: "复制计划")
        }
    }

    func deletePlan(_ plan: TrainingPlan) async {
        do {
            try await repository.deleteUserPlan(id: plan.id)
            personalPlans.removeAll { $0.id == plan.id }
            showSuccessMessage("计划已删除")
        } catch {
            handleError(error, context: "删除计划")
        }
    }

    func updatePlan(planId: Int, name: String, description: String?, difficulty: String?, actions: [UpdatePlanAction]) async {
        do {
            try await updatePlanWithoutRefresh(planId: planId, name: name, description: description, difficulty: difficulty, actions: actions)
            await refreshPersonalPlansOnly()
            showSuccessMessage("计划已更新")
        } catch {
            handleError(error, context: "更新计划")
        }
    }

    func updatePlanWithoutRefresh(planId: Int, name: String, description: String?, difficulty: String?, actions: [UpdatePlanAction]) async throws {
        try await repository.updateUserPlan(
            id: planId,
            planData: UpdatePlanRequest(
                name: name,
                description: description,
                difficulty: difficulty,
                duration: nil,
                actions: actions
            )
        )
    }

    func refreshPersonalPlansOnly() async {
        await loadPersonalPlans()
    }

    func clearData() {
        listLoadGeneration += 1
        listLoadTask?.cancel()
        listLoadTask = nil
        hasLoadedInitialData = false
        templatePlans = []
        personalPlans = []
        selectedPlan = nil
        isLoadingTemplates = false
        isLoadingPersonal = false
        isLoadingPlanDetail = false
        clearError()
    }

    var hasTemplates: Bool {
        !templatePlans.isEmpty
    }

    var hasPersonalPlans: Bool {
        !personalPlans.isEmpty
    }

    var hasAnyPlans: Bool {
        hasTemplates || hasPersonalPlans
    }

    private func loadLists() async {
        if let listLoadTask {
            await listLoadTask.value
            return
        }

        let generation = listLoadGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performListLoad(generation: generation)
        }
        listLoadTask = task
        await task.value
    }

    private func performListLoad(generation: Int) async {
        isLoadingTemplates = true
        isLoadingPersonal = true
        clearError()
        defer {
            if generation == listLoadGeneration {
                isLoadingTemplates = false
                isLoadingPersonal = false
                listLoadTask = nil
            }
        }

        async let templates = repository.templatePlans()
        async let personal = repository.userPlans()

        do {
            let loadedTemplates = try await templates
            guard generation == listLoadGeneration else { return }
            templatePlans = loadedTemplates
        } catch is CancellationError {
            return
        } catch {
            guard generation == listLoadGeneration else { return }
            handleError(error, context: "加载模板计划")
        }

        do {
            let loadedPersonalPlans = try await personal
            guard generation == listLoadGeneration else { return }
            personalPlans = loadedPersonalPlans
        } catch is CancellationError {
            return
        } catch {
            guard generation == listLoadGeneration else { return }
            handleError(error, context: "加载个人计划")
        }
    }

    private func clearError() {
        errorMessage = nil
        showError = false
    }

    private func handleError(_ error: Error, context: String) {
        errorMessage = "\(context)失败: \(AppError.map(error).userMessage)"
        showError = true
    }

    private func showSuccessMessage(_ message: String) {
        print("成功: \(message)")
    }
}

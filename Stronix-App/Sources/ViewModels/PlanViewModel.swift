import Foundation
import SwiftUI
import Combine

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
    @Published private(set) var lastCopiedUserPlanID: Int?

    private let repository: any PlanRepository
    private let copyTemplatePlanUseCase: CopyTemplatePlanUseCase
    private var hasLoadedInitialData = false
    private var listLoadTask: Task<Void, Never>?
    private var listLoadGeneration = 0

    init(repository: any PlanRepository = LocalPlanService.shared) {
        self.repository = repository
        copyTemplatePlanUseCase = CopyTemplatePlanUseCase(repository: repository)
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
            let response = try await copyTemplatePlanUseCase.execute(templatePlanID: templatePlan.id)
            lastCopiedUserPlanID = response.plan_id
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

    func applyUpdatedPlan(_ plan: TrainingPlan) async {
        if let index = personalPlans.firstIndex(where: { $0.id == plan.id }) {
            personalPlans[index] = plan
        }
        if selectedPlan?.id == plan.id {
            selectedPlan = plan
        }
        await refreshPersonalPlansOnly()
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
        lastCopiedUserPlanID = nil
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

@MainActor
final class TrainingViewModel: ObservableObject {
    @Published private(set) var editingActions: [MutableTrainingAction]
    @Published private(set) var completedSets: Set<String>
    @Published private(set) var setNotes: [String: String]
    @Published private(set) var setRestTimers: [String: Int]
    @Published private(set) var planName: String
    @Published private(set) var elapsedTimeText: String
    @Published private(set) var completedVolume: Double
    @Published private(set) var totalVolume: Double
    @Published private(set) var showRestTimer: Bool
    @Published private(set) var currentRestTime: Int
    @Published private(set) var isRestTimerPaused: Bool
    @Published private(set) var isCompleting = false
    @Published private(set) var completionError: String?

    private let session: any TrainingSessionManaging
    private let completionUseCase: any CompleteTrainingExecuting
    private var pendingCompletionSnapshot: TrainingCompletionSnapshot?
    private var sessionChange: AnyCancellable?

    init(
        session: any TrainingSessionManaging = TrainingSessionManager.shared,
        completionUseCase: any CompleteTrainingExecuting = CompleteTrainingUseCase(
            historyPersistence: TrainingHistoryService.shared,
            planUpdater: UpdatePlanUseCase(repository: LocalPlanService.shared)
        )
    ) {
        self.session = session
        self.completionUseCase = completionUseCase
        editingActions = session.editingActions
        completedSets = session.completedSets
        setNotes = session.setNotes
        setRestTimers = session.setRestTimers
        planName = session.planName
        elapsedTimeText = session.formattedTrainingTime()
        completedVolume = session.completedVolume()
        totalVolume = session.totalVolume()
        showRestTimer = session.showRestTimer
        currentRestTime = session.currentRestTime
        isRestTimerPaused = session.isRestTimerPaused

        sessionChange = session.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
    }

    var volumeText: String {
        "\(Int(completedVolume))/\(Int(totalVolume)) kg"
    }

    func startIfNeeded(plan: TrainingPlan) {
        if !session.isTrainingActive {
            session.startTraining(with: plan)
        }
        refresh()
    }

    func updateActions(_ actions: [MutableTrainingAction]) {
        session.updateActions(actions)
        refresh()
    }

    func updateCompletedSets(_ completedSets: Set<String>) {
        session.completedSets = completedSets
        refresh()
    }

    func updateSetNotes(_ setNotes: [String: String]) {
        session.setNotes = setNotes
        refresh()
    }

    func deleteAction(_ action: MutableTrainingAction) {
        session.deleteAction(action)
        refresh()
    }

    func toggleSetCompletion(setID: String, restTime: Int) {
        session.toggleSetCompletion(setID: setID, restTime: restTime)
        refresh()
    }

    func showRestTimer(for setID: String, restTime: Int) {
        session.handleRestTimerTapped(setId: setID, restTime: restTime)
        refresh()
    }

    func toggleRestTimer() {
        session.toggleRestTimer()
        refresh()
    }

    func resetRestTimer() {
        session.resetRestTimer()
        refresh()
    }

    func skipRestTimer() {
        session.skipRestTimer()
        refresh()
    }

    func closeRestTimer() {
        session.closeRestTimer()
        refresh()
    }

    func addRestTime(_ seconds: Int) {
        session.addRestTime(seconds)
        refresh()
    }

    func subtractRestTime(_ seconds: Int) {
        session.subtractRestTime(seconds)
        refresh()
    }

    func cancelTraining() {
        pendingCompletionSnapshot = nil
        session.stopTraining()
    }

    func hasPlanChanges() -> Bool {
        session.hasChangesFromOriginalPlan()
    }

    func saveHistoryOnly() async -> Bool {
        await complete(choice: .historyOnly)
    }

    func saveHistoryAndUpdatePlan() async -> Bool {
        await complete(choice: .saveHistoryAndUpdatePlan)
    }

    func retryCompletion() async -> Bool {
        guard let pendingCompletionSnapshot else { return false }
        return await complete(snapshot: pendingCompletionSnapshot, choice: .saveHistoryAndUpdatePlan)
    }

    private func complete(choice: TrainingCompletionChoice) async -> Bool {
        guard let snapshot = pendingCompletionSnapshot ?? session.captureCompletionSnapshot() else {
            completionError = "无法保存训练记录"
            return false
        }
        pendingCompletionSnapshot = snapshot
        return await complete(snapshot: snapshot, choice: choice)
    }

    private func complete(snapshot: TrainingCompletionSnapshot, choice: TrainingCompletionChoice) async -> Bool {
        guard !isCompleting else { return false }

        isCompleting = true
        completionError = nil
        defer { isCompleting = false }

        switch await completionUseCase.execute(snapshot: snapshot, choice: choice) {
        case .completed:
            pendingCompletionSnapshot = nil
            session.completeTraining()
            return true
        case .historySaveFailed(let error):
            completionError = "保存训练记录失败: \(AppError.map(error).userMessage)"
        case .historySavedPlanUpdateFailed(let error):
            completionError = "训练记录已保存，更新训练计划失败: \(AppError.map(error).userMessage)"
        case .planUpdateUnavailable:
            completionError = "无法更新训练计划"
        }

        return false
    }

    private func refresh() {
        editingActions = session.editingActions
        completedSets = session.completedSets
        setNotes = session.setNotes
        setRestTimers = session.setRestTimers
        planName = session.planName
        elapsedTimeText = session.formattedTrainingTime()
        completedVolume = session.completedVolume()
        totalVolume = session.totalVolume()
        showRestTimer = session.showRestTimer
        currentRestTime = session.currentRestTime
        isRestTimerPaused = session.isRestTimerPaused
    }
}

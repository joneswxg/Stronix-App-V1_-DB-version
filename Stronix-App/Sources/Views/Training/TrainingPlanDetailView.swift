import SwiftUI

struct TrainingPlanDetailView: View {
    @State private var plan: TrainingPlan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.designTokens) private var tokens
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject private var trainingManager = TrainingSessionManager.shared
    private let planViewModel: PlanViewModel?
    @State private var showEditPlan = false
    @State private var showTemplateCopyConfirmation = false
    @State private var isUsingTemplate = false
    @State private var copiedPlan: TrainingPlan?
    @State private var showCopiedPlan = false
    @State private var showTrainingConflictAlert = false
    @State private var isLoadingPlan = false
    @State private var hasLoadedUserPlan = false
    private let planService = LocalPlanService.shared

    init(plan: TrainingPlan, planViewModel: PlanViewModel? = nil) {
        _plan = State(initialValue: plan)
        self.planViewModel = planViewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    Text(plan.name).font(DesignTokens.Typography.pageTitle).foregroundStyle(tokens.contentPrimary)
                    Text(trainingDetailFormat("training.detail.volume", Double(plan.calculatedVolume))).font(DesignTokens.Typography.action).foregroundStyle(tokens.primary)
                    Text(trainingDetailFormat("training.detail.created", plan.createdDate)).font(DesignTokens.Typography.supporting).foregroundStyle(tokens.contentSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Spacing.large)
                .background(tokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous))

                if let description = plan.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                        Text("training.detail.description").font(DesignTokens.Typography.action).foregroundStyle(tokens.contentPrimary)
                        Text(description).font(DesignTokens.Typography.body).foregroundStyle(tokens.contentSecondary)
                    }
                    .padding(DesignTokens.Spacing.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous))
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    Text("training.detail.actions").font(DesignTokens.Typography.action).foregroundStyle(tokens.contentPrimary)
                    if let actions = plan.actions, !actions.isEmpty {
                        ForEach(actions) { DetailActionCard(action: $0) }
                    } else {
                        Text("training.detail.emptyActions").font(DesignTokens.Typography.body).foregroundStyle(tokens.contentSecondary).frame(maxWidth: .infinity).padding(DesignTokens.Spacing.xLarge)
                    }
                }

                if plan.isTemplate {
                    SemanticActionButton(
                        title: "planList.action.use",
                        loadingTitle: "planList.action.using",
                        style: .primary,
                        isEnabled: planViewModel != nil,
                        isLoading: isUsingTemplate
                    ) {
                        showTemplateCopyConfirmation = true
                    }
                } else {
                    SemanticActionButton(title: "training.action.start", loadingTitle: "training.state.loading", style: .primary, isEnabled: canStartTraining, isLoading: isLoadingPlan, action: handleStartTraining)
                        .accessibilityValue(startAccessibilityValue)
                        .accessibilityHint(startAccessibilityHint)
                }
            }
            .padding(DesignTokens.Spacing.large)
        }
        .background(tokens.canvas)
        .navigationTitle("training.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("training.action.back", action: dismiss.callAsFunction) }
            if !plan.isTemplate {
                ToolbarItem(placement: .navigationBarTrailing) { Button("training.action.edit") { showEditPlan = true } }
            }
        }
        .fullScreenCover(isPresented: $showEditPlan) {
            EditPlanView(plan: plan, onSaveSuccess: { updatedPlan in
                showEditPlan = false
                if let updatedPlan {
                    plan = updatedPlan
                    NotificationCenter.default.post(name: NSNotification.Name("PlanUpdatedFromDetail"), object: nil, userInfo: ["updatedPlan": updatedPlan])
                }
            })
        }
        .alert("planList.templateCopy.title", isPresented: $showTemplateCopyConfirmation) {
            Button("planList.action.cancel", role: .cancel) {}
            Button("planList.action.copy") {
                Task { await useTemplatePlan() }
            }
        } message: {
            Text("planList.templateCopy.message")
        }
        .navigationDestination(isPresented: $showCopiedPlan) {
            if let copiedPlan {
                TrainingPlanDetailView(plan: copiedPlan, planViewModel: planViewModel)
            }
        }
        .alert("training.alert.conflict.title", isPresented: $showTrainingConflictAlert) {
            Button("training.action.cancel", role: .cancel) {}
            Button("training.action.stopCurrent") { trainingManager.stopTraining(); trainingManager.startTraining(with: plan); dismiss() }
        } message: { Text(trainingDetailFormat("training.alert.conflict.message", trainingManager.planName)) }
        .onAppear(perform: reloadPlanData)
    }

    private var canStartTraining: Bool { !plan.isTemplate && hasLoadedUserPlan && !isLoadingPlan && plan.actions?.isEmpty == false }
    private var startAccessibilityValue: Text { isLoadingPlan ? Text("training.state.loading") : (canStartTraining ? Text("") : Text("training.state.unavailable")) }
    private var startAccessibilityHint: Text { canStartTraining ? Text("training.accessibility.startHint") : Text("training.accessibility.startUnavailableHint") }

    private func useTemplatePlan() async {
        guard plan.isTemplate, let planViewModel else { return }

        isUsingTemplate = true
        await planViewModel.copyTemplatePlan(plan)
        isUsingTemplate = false

        guard let copiedPlanID = planViewModel.lastCopiedUserPlanID else { return }
        copiedPlan = TrainingPlan(
            id: copiedPlanID,
            name: plan.name,
            creator: plan.creator,
            createdDate: plan.createdDate,
            lastTraining: plan.lastTraining,
            volume: plan.volume,
            description: plan.description,
            isTemplate: false,
            templateId: plan.id,
            difficulty: plan.difficulty,
            duration: plan.duration,
            actions: plan.actions
        )
        showCopiedPlan = true
    }

    private func handleStartTraining() {
        guard canStartTraining else { return }
        if trainingManager.isTrainingActive { showTrainingConflictAlert = true }
        else { trainingManager.startTraining(with: plan); dismiss() }
    }

    private func reloadPlanData() {
        isLoadingPlan = true
        if !plan.isTemplate { hasLoadedUserPlan = false }
        Task {
            do {
                let updatedPlan = try await (plan.isTemplate ? planService.getTemplatePlanDetail(planId: plan.id) : planService.getUserPlanDetail(planId: plan.id))
                await MainActor.run {
                    plan = updatedPlan
                    hasLoadedUserPlan = !updatedPlan.isTemplate
                    isLoadingPlan = false
                    NotificationCenter.default.post(name: NSNotification.Name("PlanUpdatedFromDetail"), object: nil, userInfo: ["updatedPlan": updatedPlan])
                }
            } catch { await MainActor.run { isLoadingPlan = false } }
        }
    }
}

private struct DetailActionCard: View {
    @Environment(\.designTokens) private var tokens
    let action: TrainingAction

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                Group {
                    if let image = loadDetailActionImage(resourcePath: action.imageUrl) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Rectangle()
                            .fill(tokens.primary.opacity(0.12))
                            .overlay {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .foregroundStyle(tokens.primary)
                            }
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))

                Text(action.name)
                    .font(DesignTokens.Typography.action)
                    .foregroundStyle(tokens.contentPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let notes = action.notes, !notes.isEmpty { Text(notes).font(DesignTokens.Typography.supporting).foregroundStyle(tokens.contentSecondary) }
            Text(trainingDetailFormat("training.detail.setCount", action.totalSets))
                .font(DesignTokens.Typography.supporting)
                .foregroundStyle(tokens.contentSecondary)
            ForEach(Array(action.sets.enumerated()), id: \.offset) { index, set in
                Text(setSummary(index: index, set: set))
                    .font(DesignTokens.Typography.feedback)
                    .foregroundStyle(tokens.contentSecondary)
            }
            Text(trainingDetailFormat("training.detail.rest", action.restTime))
                .font(DesignTokens.Typography.feedback)
                .foregroundStyle(tokens.contentSecondary)
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous).stroke(tokens.border, lineWidth: DesignTokens.Metric.borderWidth) }
    }
    private func setSummary(index: Int, set: TrainingSet) -> String {
        if action.recordBilateral {
            return trainingDetailFormat("training.detail.bilateralSet", index + 1, set.leftWeight, set.rightWeight, set.reps)
        }
        return trainingDetailFormat("training.detail.set", index + 1, set.weight, set.reps)
    }
}

private func loadDetailActionImage(resourcePath: String) -> UIImage? {
    guard let url = ActionImageResourceLocator().bundledGIFURL(for: resourcePath),
          let data = try? Data(contentsOf: url) else { return nil }
    return ActionImageDecoder.image(from: data)
}

private func trainingDetailFormat(_ key: String, _ value: CVarArg) -> String { String(format: NSLocalizedString(key, comment: ""), value) }
private func trainingDetailFormat(_ key: String, _ first: CVarArg, _ second: CVarArg, _ third: CVarArg) -> String { String(format: NSLocalizedString(key, comment: ""), first, second, third) }
private func trainingDetailFormat(_ key: String, _ first: CVarArg, _ second: CVarArg, _ third: CVarArg, _ fourth: CVarArg) -> String { String(format: NSLocalizedString(key, comment: ""), first, second, third, fourth) }

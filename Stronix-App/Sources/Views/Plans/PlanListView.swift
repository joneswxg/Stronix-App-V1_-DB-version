import SwiftUI

struct PlanListView: View {
    @Environment(\.designTokens) private var tokens
    @EnvironmentObject private var userSession: UserSession
    @ObservedObject var viewModel: PlanViewModel
    @ObservedObject var createPlanViewModel: CreatePlanViewModel
    @State private var showLogin = false
    @StateObject private var authViewModel = AuthViewModel()
    @State private var selectedTab = 1
    @State private var navigateToCreatePlan = false

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(tokens.canvas)
        .fullScreenCover(isPresented: $navigateToCreatePlan) {
            CreatePlanView(
                viewModel: createPlanViewModel,
                onSaveSucceeded: { await viewModel.refreshPersonalPlansOnly() }
            )
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
                .onDisappear {
                    if userSession.isAuthenticated {
                        Task { await viewModel.refresh() }
                    }
                }
        }
        .alert("planList.error.title", isPresented: $viewModel.showError) {
            Button("planList.action.confirm") { viewModel.showError = false }
            Button("planList.action.retry") { Task { await viewModel.refresh() } }
            if !userSession.isAuthenticated {
                Button("planList.action.login") { showLogin = true }
            }
        } message: {
            Text(viewModel.errorMessage ?? AppStrings.text("planList.error.unknown"))
        }
        .alert("auth.feedback.logoutFailed", isPresented: authErrorBinding) {
            Button("auth.action.confirm", role: .cancel) { authViewModel.errorMessage = nil }
        } message: {
            Text(authViewModel.errorMessage ?? AppStrings.text("auth.error.generic"))
        }
        .refreshable {
            if userSession.isAuthenticated {
                await viewModel.refresh()
            }
        }
        .task {
            guard userSession.isAuthenticated else { return }
            await viewModel.loadInitialData()
        }
        .onChange(of: userSession.isAuthenticated) { _, isLoggedIn in
            if isLoggedIn {
                Task { await viewModel.refresh() }
            } else {
                viewModel.clearData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PlanUpdatedFromDetail"))) { notification in
            guard let updatedPlan = notification.userInfo?["updatedPlan"] as? TrainingPlan else { return }
            if let index = viewModel.personalPlans.firstIndex(where: { $0.id == updatedPlan.id }) {
                var updatedPlans = viewModel.personalPlans
                updatedPlans[index] = updatedPlan
                viewModel.personalPlans = updatedPlans
            }
            if viewModel.selectedPlan?.id == updatedPlan.id {
                viewModel.selectedPlan = updatedPlan
            }
        }
    }

    private var authErrorBinding: Binding<Bool> {
        Binding(
            get: { authViewModel.errorMessage != nil },
            set: { if !$0 { authViewModel.errorMessage = nil } }
        )
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image("StronixLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 35)
                .accessibilityHidden(true)
            Text("STRONIX")
                .font(DesignTokens.Typography.action)
                .foregroundStyle(tokens.primary)
                .accessibilityHidden(true)
            Spacer()
            Button {
                if userSession.isAuthenticated {
                    Task { await authViewModel.logout(using: userSession) }
                } else {
                    showLogin = true
                }
            } label: {
                Image(systemName: userSession.isAuthenticated ? "person.circle.fill" : "person.circle")
                    .font(.title2)
                    .foregroundStyle(userSession.isAuthenticated ? tokens.primary : tokens.contentSecondary)
                    .frame(minWidth: DesignTokens.Metric.minimumTapSize, minHeight: DesignTokens.Metric.minimumTapSize)
            }
            .accessibilityLabel(userSession.isAuthenticated ? Text("planList.accessibility.logout") : Text("planList.accessibility.login"))
            .accessibilityHint(userSession.isAuthenticated ? Text("planList.accessibility.logoutHint") : Text("planList.accessibility.loginHint"))
            .disabled(authViewModel.isLoggingOut)
        }
        .padding(.horizontal, DesignTokens.Spacing.large)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(tokens.surface)
        .shadow(color: tokens.shadow, radius: 2, y: 1)
    }

    @ViewBuilder
    private var content: some View {
        if !userSession.isAuthenticated {
            ContentStateView(
                kind: .empty,
                symbol: "person.circle",
                title: "planList.signedOut.title",
                message: "planList.signedOut.message",
                actionTitle: "planList.action.loginNow",
                action: { showLogin = true }
            )
        } else if viewModel.showError && !viewModel.hasAnyPlans {
            ContentStateView(
                kind: .error,
                symbol: "exclamationmark.triangle",
                title: "planList.error.title",
                message: "planList.error.message",
                actionTitle: "planList.action.retry",
                action: { Task { await viewModel.refresh() } }
            )
        } else if viewModel.isLoadingTemplates && viewModel.isLoadingPersonal && !viewModel.hasAnyPlans {
            ContentStateView(
                kind: .loading,
                symbol: "",
                title: "planList.loading.title",
                message: "planList.loading.message"
            )
        } else if !viewModel.hasAnyPlans && !viewModel.isLoadingTemplates && !viewModel.isLoadingPersonal {
            ContentStateView(
                kind: .empty,
                symbol: "calendar.badge.plus",
                title: "planList.empty.title",
                message: "planList.empty.message",
                actionTitle: "planList.action.create",
                action: { navigateToCreatePlan = true }
            )
        } else {
            VStack(spacing: 0) {
                tabBar
                TabView(selection: $selectedTab) {
                    TemplatesView(viewModel: viewModel)
                        .tag(0)
                    PersonalPlansView(viewModel: viewModel)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            tabButton(title: "planList.tab.templates", selection: 0, isLoading: viewModel.isLoadingTemplates)
            tabButton(title: "planList.tab.personal", selection: 1, isLoading: viewModel.isLoadingPersonal)
            if selectedTab == 1 {
                Button { navigateToCreatePlan = true } label: {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.action)
                        .foregroundStyle(tokens.onPrimary)
                        .frame(minWidth: DesignTokens.Metric.minimumTapSize, minHeight: DesignTokens.Metric.minimumTapSize)
                        .background(tokens.primary)
                        .clipShape(Circle())
                }
                .accessibilityLabel(Text("planList.accessibility.create"))
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .background(tokens.surface)
        .shadow(color: tokens.shadow, radius: 2, y: 1)
    }

    private func tabButton(title: LocalizedStringKey, selection: Int, isLoading: Bool) -> some View {
        Button { selectedTab = selection } label: {
            HStack(spacing: DesignTokens.Spacing.small) {
                Text(title)
                    .font(DesignTokens.Typography.label)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(selectedTab == selection ? tokens.primary : tokens.contentSecondary)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metric.minimumTapSize)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(selectedTab == selection ? tokens.primary : .clear)
                    .frame(height: 3)
            }
        }
        .accessibilityValue(selectedTab == selection ? Text("planList.accessibility.selected") : Text("planList.accessibility.unselected"))
    }
}

struct TemplatesView: View {
    @Environment(\.designTokens) private var tokens
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var viewModel: PlanViewModel

    var body: some View {
        PlanGrid(
            plans: viewModel.templatePlans,
            isLoading: viewModel.isLoadingTemplates,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
            emptyState: ContentStateView(
                kind: .empty,
                symbol: "doc.text",
                title: "planList.templates.empty.title",
                message: "planList.templates.empty.message"
            )
        ) { plan in
            TemplatePlanCard(plan: plan, viewModel: viewModel)
        }
        .background(tokens.canvas)
    }
}

struct PersonalPlansView: View {
    @Environment(\.designTokens) private var tokens
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var viewModel: PlanViewModel

    var body: some View {
        PlanGrid(
            plans: viewModel.personalPlans,
            isLoading: viewModel.isLoadingPersonal,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
            emptyState: ContentStateView(
                kind: .empty,
                symbol: "person.crop.circle",
                title: "planList.personal.empty.title",
                message: "planList.personal.empty.message"
            )
        ) { plan in
            PersonalPlanCard(plan: plan, viewModel: viewModel)
        }
        .background(tokens.canvas)
    }
}

private struct PlanGrid<Card: View, EmptyState: View>: View {
    let plans: [TrainingPlan]
    let isLoading: Bool
    let isAccessibilitySize: Bool
    let emptyState: EmptyState
    @ViewBuilder let card: (TrainingPlan) -> Card

    private var columns: [GridItem] {
        isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        if isLoading && plans.isEmpty {
            ContentStateView(
                kind: .loading,
                symbol: "",
                title: "planList.loading.title",
                message: "planList.loading.message"
            )
        } else if plans.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.large) {
                    ForEach(plans) { plan in
                        card(plan)
                    }
                }
                .padding(DesignTokens.Spacing.large)
            }
        }
    }
}

struct PlanCardPresentation {
    static let height: CGFloat = 176
    static let maximumVisibleActionSummaries = 3

    let actions: [TrainingAction]

    init(actions: [TrainingAction]?) {
        self.actions = actions ?? []
    }

    func visibleActions(maximum: Int = Self.maximumVisibleActionSummaries) -> [TrainingAction] {
        Array(actions.prefix(maximum))
    }

    func remainingActionCount(afterShowing maximum: Int = Self.maximumVisibleActionSummaries) -> Int {
        max(0, actions.count - maximum)
    }

    var showsEmptyState: Bool {
        actions.isEmpty
    }
}

struct TemplatePlanCard: View {
    let plan: TrainingPlan
    @ObservedObject var viewModel: PlanViewModel

    var body: some View {
        PlanCardContainer {
            NavigationLink(destination: TrainingPlanDetailView(plan: plan, planViewModel: viewModel)) {
                PlanCardContent(plan: plan)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(plan.name), \(AppStrings.text("planList.accessibility.templatePlan"))"))
            .accessibilityHint(Text("planList.accessibility.openPlanHint"))
        }
    }
}

struct PersonalPlanCard: View {
    @Environment(\.designTokens) private var tokens
    let plan: TrainingPlan
    @ObservedObject var viewModel: PlanViewModel
    @State private var showEditPlan = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showCopyDialog = false
    @State private var copyPlanName = ""
    @State private var isCopying = false

    var body: some View {
        PlanCardContainer {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
                NavigationLink(destination: TrainingPlanDetailView(plan: plan)) {
                    PlanCardContent(plan: plan)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(Text("\(plan.name), \(AppStrings.text("planList.accessibility.personalPlan"))"))
                .accessibilityHint(Text("planList.accessibility.openPlanHint"))

                Menu {
                    Button {
                        Task {
                            await viewModel.loadPlanDetail(planId: plan.id)
                            if viewModel.selectedPlan != nil {
                                showEditPlan = true
                            }
                        }
                    } label: {
                        Label("planList.action.edit", systemImage: "pencil")
                    }
                    Button {
                        copyPlanName = "\(plan.name)-v1"
                        showCopyDialog = true
                    } label: {
                        Label("planList.action.copy", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("planList.action.delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(tokens.contentSecondary)
                        .frame(minWidth: DesignTokens.Metric.minimumTapSize, minHeight: DesignTokens.Metric.minimumTapSize)
                }
                .accessibilityLabel(Text("\(AppStrings.text("planList.accessibility.planMenu")): \(plan.name)"))
            }
        }
        .overlay {
            if isDeleting {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                    .fill(tokens.surface.opacity(0.75))
                ProgressView()
                    .tint(tokens.primary)
                    .accessibilityLabel(Text("planList.accessibility.loading"))
            }
        }
        .fullScreenCover(isPresented: $showEditPlan) {
            if let selectedPlan = viewModel.selectedPlan {
                EditPlanView(plan: selectedPlan, onSaveSuccess: { updatedPlan in
                    showEditPlan = false
                    guard let updatedPlan else { return }
                    Task { await viewModel.applyUpdatedPlan(updatedPlan) }
                })
            }
        }
        .alert("planList.delete.title", isPresented: $showDeleteAlert) {
            Button("planList.action.cancel", role: .cancel) {}
            Button("planList.action.delete", role: .destructive) {
                Task {
                    isDeleting = true
                    await viewModel.deletePlan(plan)
                    isDeleting = false
                }
            }
        } message: {
            Text(String(format: AppStrings.text("planList.delete.message"), plan.name))
        }
        .alert("planList.copy.title", isPresented: $showCopyDialog) {
            TextField("planList.copy.namePlaceholder", text: $copyPlanName)
            Button("planList.action.cancel", role: .cancel) { copyPlanName = "" }
            Button("planList.action.confirm") {
                guard !copyPlanName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task {
                    isCopying = true
                    await viewModel.copyPersonalPlan(plan, newName: copyPlanName)
                    isCopying = false
                    copyPlanName = ""
                }
            }
            .disabled(isCopying)
        } message: {
            Text("planList.copy.message")
        }
    }
}

private struct PlanCardContainer<Content: View>: View {
    @Environment(\.designTokens) private var tokens
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            content
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, minHeight: PlanCardPresentation.height, maxHeight: PlanCardPresentation.height, alignment: .topLeading)
        .background(tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                .stroke(tokens.border, lineWidth: DesignTokens.Metric.borderWidth)
        }
    }
}

private struct PlanCardContent: View {
    @Environment(\.designTokens) private var tokens
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let plan: TrainingPlan

    private var maximumVisibleActionSummaries: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : PlanCardPresentation.maximumVisibleActionSummaries
    }

    var body: some View {
        let presentation = PlanCardPresentation(actions: plan.actions)
        let visibleActions = presentation.visibleActions(maximum: maximumVisibleActionSummaries)
        let remainingActionCount = presentation.remainingActionCount(afterShowing: maximumVisibleActionSummaries)

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(plan.name)
                .font(DesignTokens.Typography.action)
                .foregroundStyle(tokens.contentPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if presentation.showsEmptyState {
                Text("planList.actionSummary.empty")
                    .font(DesignTokens.Typography.feedback)
                    .foregroundStyle(tokens.contentSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                ForEach(visibleActions, id: \.id) { action in
                    Text("\(action.name) × \(action.totalSets)")
                        .font(DesignTokens.Typography.feedback)
                        .foregroundStyle(tokens.contentSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if remainingActionCount > 0 {
                    Text(String(format: AppStrings.text("planList.actionSummary.more"), remainingActionCount))
                        .font(DesignTokens.Typography.feedback)
                        .foregroundStyle(tokens.contentSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }
}

#Preview {
    PlanListView(
        viewModel: PlanViewModel(),
        createPlanViewModel: CreatePlanViewModel(useCase: CreateUserPlanUseCase(repository: LocalPlanService.shared))
    )
    .withAppTheme()
}

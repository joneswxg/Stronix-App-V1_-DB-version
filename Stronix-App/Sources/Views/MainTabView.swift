import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.theme) private var theme: AppTheme
    @State private var selectedTab = 0
    @ObservedObject private var trainingManager = TrainingSessionManager.shared
    @StateObject private var planViewModel = PlanViewModel()
    @StateObject private var createPlanViewModel = CreatePlanViewModel(
        useCase: CreateUserPlanUseCase(repository: LocalPlanService.shared)
    )
    @StateObject private var keyboardManager = CustomKeyboardManager()
    @StateObject private var bodyMeasurementViewModel = BodyMeasurementViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
                BodyMeasurementTabView(viewModel: bodyMeasurementViewModel)
                    .tabItem {
                        Image(systemName: "figure.mixed.cardio")
                        Text("体测")
                    }
                    .tag(0)
                ActionListView()
                    .tabItem {
                        Image(systemName: "figure.strengthtraining.traditional")
                        Text("动作")
                    }
                    .tag(1)
                
                // 训练Tab - 根据训练状态显示不同页面
                NavigationStack {
                    Group {
                        if trainingManager.isTrainingActive, let currentPlan = trainingManager.currentPlan {
                            TrainingView(plan: currentPlan)
                                .id("training-active")
                        } else {
                            PlanListView(
                                viewModel: planViewModel,
                                createPlanViewModel: createPlanViewModel
                            )
                                .id("plan-list")
                        }
                    }
                }
                .environment(\.designTokens, DesignTokens(theme: theme, colorScheme: .light))
                .tabItem {
                    Image(systemName: "dumbbell.fill")
                    Text("训练")
                }
                .tag(2)
                
                HistoryView()
                    .tabItem {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("历史")
                    }
                    .tag(3)
                ProfileMainView()
                    .tabItem {
                        Image(systemName: "person.crop.circle")
                        Text("其他")
                    }
                    .tag(4)
        }
        .accentColor(theme.primary)
        .overlay(
            // 训练进行中的浮动指示器
            TrainingFloatingIndicator(
                trainingManager: trainingManager,
                onTap: {
                    selectedTab = 2
                    trainingManager.presentRestControls()
                },
                keyboardManager: keyboardManager
            )
        )
        .task {
            userSession.registerResetter(planViewModel)
            userSession.registerResetter(trainingManager)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            print("🔄 MainTabView selectedTab 变化: \(oldValue) -> \(newValue)")
        }
        .onChange(of: userSession.scopeID) { _, _ in
            selectedTab = 0
        }
        .onAppear {
            print("🔄 MainTabView onAppear - selectedTab: \(selectedTab)")
            print("🔄 MainTabView onAppear - trainingManager.isTrainingActive: \(trainingManager.isTrainingActive)")
            print("🔄 MainTabView onAppear - 视图被重建了！")
        }
        .onDisappear {
            print("🔄 MainTabView onDisappear - 视图被销毁了！")
        }
    }
}



#Preview {
    MainTabView()
        .environmentObject(
            UserSession(
                operations: AuthenticationUseCases(
                    repository: SQLiteAuthRepository(),
                    sessionStore: InMemoryLocalSessionStore()
                )
            )
        )
}

import SwiftUI

struct MainTabView: View {
    @AppStorage("MainTabView_selectedTab") private var selectedTab = 0 // 持久化选中的Tab
    @ObservedObject private var trainingManager = TrainingSessionManager.shared
    @AppStorage("MainTabView_lastUserSelectedTab") private var lastUserSelectedTab = 0 // 持久化用户最后选择的标签页
    
    var body: some View {
        TabView(selection: $selectedTab) {
                BodyMeasurementTabView()
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
                            TrainingView(plan: currentPlan, viewModel: PlanViewModel())
                                .id("training-active")
                        } else {
                            PlanListView()
                                .id("plan-list")
                        }
                    }
                }
                .tabItem {
                    Image(systemName: "bolt.fill")
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
        .overlay(
            // 训练进行中的浮动指示器
            TrainingFloatingIndicator {
                // 点击浮动框时，切换到训练Tab
                selectedTab = 2
            }
        )
        .onChange(of: selectedTab) { oldValue, newValue in
            print("🔄 MainTabView selectedTab 变化: \(oldValue) -> \(newValue)")
            if newValue == 0 && oldValue != 0 && lastUserSelectedTab != 0 {
                print("⚠️ MainTabView 意外跳转到体测页面！之前在: \(oldValue)，用户最后选择: \(lastUserSelectedTab)")
                // 恢复到用户最后选择的标签页
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🔄 MainTabView 恢复到用户最后选择的标签页: \(lastUserSelectedTab)")
                    selectedTab = lastUserSelectedTab
                }
            } else if newValue != 0 {
                // 用户主动选择了非体测页面，记录下来
                lastUserSelectedTab = newValue
            }
        }
        .onAppear {
            print("🔄 MainTabView onAppear - selectedTab: \(selectedTab)")
            print("🔄 MainTabView onAppear - lastUserSelectedTab: \(lastUserSelectedTab)")
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
} 

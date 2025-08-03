import SwiftUI

struct PlanListView: View {
    @StateObject private var viewModel = PlanViewModel()
    @ObservedObject private var authService = LocalUserService.shared
    @State private var showLogin = false
    @State private var selectedTab = 1  // 0: 计划模版, 1: 个人计划 - 默认显示个人计划
    @State private var isEditPlanPresented = false // 添加标记，跟踪EditPlan是否打开
    @State private var navigateToCreatePlan = false // 添加导航状态
    
    // 使用@AppStorage来持久化加载状态
    @AppStorage("PlanListView_hasInitiallyLoaded") private var hasInitiallyLoaded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo区域 - 与ActionListView保持一致
            HStack {
                Image("StronixLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 35)
                Spacer()
                Text("STRONIX")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                
                // 登录状态指示器
                if authService.isLoggedIn {
                    Button(action: {
                        Task {
                            await authService.logout()
                        }
                    }) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                } else {
                    Button(action: {
                        showLogin = true
                    }) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
            
            if !authService.isLoggedIn {
                // 未登录状态视图
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "person.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("请先登录")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                    
                    Text("登录后可以查看和管理您的训练计划")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        showLogin = true
                    }) {
                        Text("立即登录")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 44)
                            .background(Color.blue)
                            .cornerRadius(22)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.95))
            } else if !viewModel.hasAnyPlans && !viewModel.isLoadingTemplates && !viewModel.isLoadingPersonal {
                // 空状态视图
                VStack(spacing: 20) {
                    Spacer()
                    Text("您还没有创建任何训练计划")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        navigateToCreatePlan = true
                    }) {
                        Text("创建计划")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 44)
                            .background(Color.blue)
                            .cornerRadius(22)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.95))
            } else {
                VStack(spacing: 0) {
                    // 快速开始按钮
                    NavigationLink(destination: QuickStartTrainingView()) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                            
                            Text("快速开始")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(white: 0.98))
                    
                    // 标签页切换器
                    HStack(spacing: 0) {
                        // 计划模版标签
                        Button(action: {
                            selectedTab = 0
                        }) {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("计划模版")
                                        .font(.system(size: 16, weight: selectedTab == 0 ? .medium : .regular))
                                        .foregroundColor(selectedTab == 0 ? .blue : .gray)
                                    
                                    if viewModel.isLoadingTemplates {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    }
                                }
                                
                                Rectangle()
                                    .fill(selectedTab == 0 ? Color.blue : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 个人计划标签
                        Button(action: {
                            selectedTab = 1
                        }) {
                            VStack(spacing: 4) {
                                HStack(spacing: 8) {
                                    HStack(spacing: 4) {
                                        Text("个人计划")
                                            .font(.system(size: 16, weight: selectedTab == 1 ? .medium : .regular))
                                            .foregroundColor(selectedTab == 1 ? .blue : .gray)
                                        
                                        if viewModel.isLoadingPersonal {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                        }
                                    }
                                    
                                    if selectedTab == 1 {
                                        Button(action: {
                                            navigateToCreatePlan = true
                                        }) {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 18))
                                        }
                                    }
                                }
                                
                                Rectangle()
                                    .fill(selectedTab == 1 ? Color.blue : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
                    
                    // 内容区域
                    TabView(selection: $selectedTab) {
                        // 计划模版页面
                        TemplatesView(viewModel: viewModel)
                            .tag(0)
                        
                        // 个人计划页面
                        PersonalPlansView(viewModel: viewModel)
                            .tag(1)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
                }
            }
        }
        .navigationDestination(isPresented: $navigateToCreatePlan) {
            CreatePlanView()
                .onDisappear {
                    // 创建计划后刷新数据
                    if authService.isLoggedIn {
                        // 延迟刷新，让视图层级稳定下来
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            print("🔄 CreatePlanView onDisappear - 延迟刷新数据")
                            viewModel.refresh()
                            hasInitiallyLoaded = true
                        }
                    }
                }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
                .onDisappear {
                    // 登录后刷新数据
                    if authService.isLoggedIn {
                        viewModel.refresh()
                        hasInitiallyLoaded = true
                    }
                }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {
                viewModel.showError = false
            }
            Button("重试") {
                viewModel.refresh()
            }
            if !authService.isLoggedIn {
                Button("登录") {
                    showLogin = true
                }
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .refreshable {
            if authService.isLoggedIn {
                viewModel.refresh()
            }
        }
        .onAppear {
            print("🔍 PlanListView onAppear - isLoggedIn: \(authService.isLoggedIn), hasInitiallyLoaded: \(hasInitiallyLoaded), isEditPlanPresented: \(isEditPlanPresented)")
            
            // 如果EditPlan正在显示，不执行任何操作
            if isEditPlanPresented {
                print("🔍 PlanListView onAppear - EditPlan正在显示，跳过刷新")
                return
            }
            
            // 只在真正需要时进行token检查和数据加载
            if !hasInitiallyLoaded {
                Task {
                    // 检查token有效性
                    let _ = await authService.refreshTokenIfNeeded()
                    
                    // 首次加载时检查登录状态并加载数据
                    if authService.isLoggedIn {
                        print("🔄 PlanListView 首次加载数据")
                        viewModel.refresh()
                        hasInitiallyLoaded = true
                    } else {
                        // 未登录时也标记为已加载，避免重复检查
                        hasInitiallyLoaded = true
                    }
                }
            }
        }
        .onChange(of: authService.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                // 登录成功后刷新数据
                viewModel.refresh()
                hasInitiallyLoaded = true
            } else {
                // 登出后清空数据并重置加载标记
                viewModel.clearData()
                hasInitiallyLoaded = false
            }
        }
    }
}

// 计划模版视图
struct TemplatesView: View {
    @ObservedObject var viewModel: PlanViewModel
    
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        ScrollView {
            if viewModel.templatePlans.isEmpty && !viewModel.isLoadingTemplates {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("暂无模板计划")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text("系统模板计划正在准备中")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.templatePlans) { plan in
                        PlanTemplateCard(plan: plan, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(white: 0.97))
    }
}

// 个人计划视图
struct PersonalPlansView: View {
    @ObservedObject var viewModel: PlanViewModel
    
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        ScrollView {
            if viewModel.personalPlans.isEmpty && !viewModel.isLoadingPersonal {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("暂无个人计划")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text("点击右上角 + 号创建您的第一个训练计划")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.personalPlans) { plan in
                        PersonalPlanCard(plan: plan, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(white: 0.97))
    }
}

// 计划模版卡片
struct PlanTemplateCard: View {
    let plan: TrainingPlan
    @ObservedObject var viewModel: PlanViewModel
    @State private var isUsing = false
    @State private var showCopyConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.black)
                .lineLimit(1)
            
            VStack(alignment: .leading, spacing: 2) {
                // 显示动作信息 - 固定高度区域，只显示两行
                VStack(alignment: .leading, spacing: 1) {
                    if let actions = plan.actions, !actions.isEmpty {
                        ForEach(actions.prefix(2), id: \.id) { action in
                            Text("\(action.name) x \(action.totalSets)")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        
                        if actions.count > 2 {
                            Text("...")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("暂无动作")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .frame(height: 35, alignment: .top) // 减小固定高度
                
                HStack {
                    Text("容量: \(plan.calculatedVolume)kg")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.8))
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                NavigationLink(destination: TrainingPlanDetailView(plan: plan)) {
                    Text("查看")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    showCopyConfirmation = true
                }) {
                    HStack(spacing: 4) {
                        if isUsing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("使用")
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .disabled(isUsing)
            }
        }
        .padding(10)
        .frame(height: 120)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .alert("复制模板计划", isPresented: $showCopyConfirmation) {
            Button("取消", role: .cancel) { }
            Button("是") {
                Task {
                    isUsing = true
                    await viewModel.copyTemplatePlan(plan)
                    isUsing = false
                }
            }
        } message: {
            Text("是否将模板复制到个人计划？")
        }
    }
}

// 个人计划卡片
struct PersonalPlanCard: View {
    let plan: TrainingPlan
    @ObservedObject var viewModel: PlanViewModel
    @State private var showEditPlan = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                Spacer()
                
                // 工具菜单
                Menu {
                    Button(action: {
                        showEditPlan = true
                    }) {
                        Label("编辑", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        showDeleteAlert = true
                    }) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 20, height: 20)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                // 显示动作信息 - 固定高度区域，只显示两行
                VStack(alignment: .leading, spacing: 1) {
                    if let actions = plan.actions, !actions.isEmpty {
                        ForEach(actions.prefix(2), id: \.id) { action in
                            Text("\(action.name) x \(action.totalSets)")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        
                        if actions.count > 2 {
                            Text("...")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("暂无动作")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                .frame(height: 35, alignment: .top) // 减小固定高度
                
                HStack {
                    Text("容量: \(plan.calculatedVolume)kg")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.8))
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                NavigationLink(destination: TrainingPlanDetailView(plan: plan)) {
                    Text("查看")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    Task {
                        await viewModel.loadPlanDetail(planId: plan.id)
                        
                        if viewModel.selectedPlan != nil {
                            showEditPlan = true
                        }
                    }
                }) {
                    Text("编辑")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
            }
        }
        .padding(10)
        .frame(height: 120)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .fullScreenCover(isPresented: $showEditPlan) {
            if let selectedPlan = viewModel.selectedPlan {
                EditPlanView(plan: selectedPlan, onSaveSuccess: { updatedPlan in
                    print("🔄 EditPlanView onSaveSuccess 回调被触发，接收到更新后的计划")
                    print("🔄 更新后的计划名称: \(updatedPlan?.name ?? "无")")
                    
                    // 首先，关闭 fullScreenCover
                    self.showEditPlan = false
                    
                    // 如果有更新后的计划对象，直接更新列表中的对应项
                    if let updatedPlan = updatedPlan {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            print("🔄 EditPlanView onSaveSuccess - 直接更新列表中的计划项")
                            
                            // 在personalPlans数组中找到对应的计划并更新
                            if let index = viewModel.personalPlans.firstIndex(where: { $0.id == updatedPlan.id }) {
                                // 使用更可靠的方式触发SwiftUI更新：创建新数组
                                var updatedPlans = viewModel.personalPlans
                                updatedPlans[index] = updatedPlan
                                viewModel.personalPlans = updatedPlans
                                print("✅ 已更新列表中的计划项: \(updatedPlan.name)")
                                
                                // 打印更新后的动作信息用于调试
                                let actionsInfo = updatedPlan.actions?.prefix(2).map { "\($0.name) x \($0.totalSets)" }.joined(separator: ", ") ?? "无动作"
                                print("🔍 更新后动作信息: \(actionsInfo), 容量: \(updatedPlan.calculatedVolume)kg")
                            }
                            
                            // 同时更新 selectedPlan 以便详情页显示正确
                            viewModel.selectedPlan = updatedPlan
                            print("✅ 已更新 selectedPlan 数据")
                        }
                    } else {
                        // 如果没有返回更新后的计划对象，则重新加载该计划的详情
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            print("🔄 EditPlanView onSaveSuccess - 重新加载计划详情")
                            Task {
                                await viewModel.loadPlanDetail(planId: selectedPlan.id)
                                if let reloadedPlan = viewModel.selectedPlan {
                                    // 更新列表中的对应项 - 使用新数组方式
                                    if let index = viewModel.personalPlans.firstIndex(where: { $0.id == reloadedPlan.id }) {
                                        var updatedPlans = viewModel.personalPlans
                                        updatedPlans[index] = reloadedPlan
                                        viewModel.personalPlans = updatedPlans
                                        print("✅ 已更新列表中的计划项: \(reloadedPlan.name)")
                                    }
                                }
                            }
                        }
                    }
                })
                .onDisappear {
                    print("🔍 EditPlanView onDisappear - 不触发刷新")
                    // 兜底：如果因为某种原因 onSaveSuccess 未触发，这里确保状态一致
                    if self.showEditPlan {
                        self.showEditPlan = false
                    }
                }
            }
        }

        .alert("删除计划", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                Task {
                    isDeleting = true
                    await viewModel.deletePlan(plan)
                    isDeleting = false
                }
            }
        } message: {
            Text("确定要删除训练计划 \"\(plan.name)\" 吗？此操作无法撤销。")
        }
        .overlay(
            // 删除中的加载指示器
            Group {
                if isDeleting {
                    Color.black.opacity(0.3)
                        .cornerRadius(12)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        )
    }
}

#Preview {
    PlanListView()
} 

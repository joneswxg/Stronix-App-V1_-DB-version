import SwiftUI

struct PlanListView: View {
    @State private var showCreatePlan = false
    @State private var hasPlans = true  // 修改为true以显示内容
    @State private var selectedTab = 0  // 0: 计划模版, 1: 个人计划
    
    var body: some View {
        NavigationView {
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
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
                
                if !hasPlans {
                    // 空状态视图
                    VStack(spacing: 20) {
                        Spacer()
                        Text("您还没有创建任何训练计划")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            showCreatePlan = true
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
                                    Text("计划模版")
                                        .font(.system(size: 16, weight: selectedTab == 0 ? .medium : .regular))
                                        .foregroundColor(selectedTab == 0 ? .blue : .gray)
                                    
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
                                        Text("个人计划")
                                            .font(.system(size: 16, weight: selectedTab == 1 ? .medium : .regular))
                                            .foregroundColor(selectedTab == 1 ? .blue : .gray)
                                        
                                        if selectedTab == 1 {
                                            Button(action: {
                                                showCreatePlan = true
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
                            TemplatesView()
                                .tag(0)
                            
                            // 个人计划页面
                            PersonalPlansView()
                                .tag(1)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.3), value: selectedTab)
                    }
                }
            }
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
            }
        }
    }
}

// 计划模版视图
struct TemplatesView: View {
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<8, id: \.self) { index in
                    PlanTemplateCard(
                        title: "增肌计划 \(index + 1)",
                        actions: [
                            "3/4 sit up x3",
                            "alternate heel touchers x2", 
                            "arm slingers hanging x4"
                        ]
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(white: 0.97))
    }
}

// 个人计划视图
struct PersonalPlansView: View {
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<5, id: \.self) { index in
                    PersonalPlanCard(
                        title: "我的训练计划 \(index + 1)",
                        actions: [
                            "3/4 sit up x2",
                            "alternate heel touchers x3",
                            "arm slingers hanging x2"
                        ]
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(white: 0.97))
    }
}

// 计划模版卡片
struct PlanTemplateCard: View {
    let title: String
    let actions: [String]
    @State private var showDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .lineLimit(1)
            
            VStack(alignment: .leading, spacing: 3) {
                ForEach(actions.prefix(2), id: \.self) { action in
                    Text(action)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                if actions.count > 2 {
                    Text("...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    showDetail = true
                }) {
                    Text("查看")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: {
                    // TODO: 复制模版到个人计划
                }) {
                    Text("使用")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .padding(12)
        .frame(height: 140)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .onTapGesture {
            showDetail = true
        }
        .sheet(isPresented: $showDetail) {
            TrainingPlanDetailView(plan: TrainingPlan(
                id: 0,
                name: title,
                creator: "系统",
                createdDate: "2025-05-29",
                lastTraining: "未训练",
                volume: 720
            ))
        }
    }
}

// 个人计划卡片
struct PersonalPlanCard: View {
    let title: String
    let actions: [String]
    @State private var showEditPlan = false
    @State private var showPlanDetail = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 24, height: 24)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                ForEach(actions.prefix(2), id: \.self) { action in
                    Text(action)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                if actions.count > 2 {
                    Text("...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    showPlanDetail = true
                }) {
                    Text("查看")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: {
                    showEditPlan = true
                }) {
                    Text("编辑")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .padding(12)
        .frame(height: 140)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .onTapGesture {
            showPlanDetail = true
        }
        .sheet(isPresented: $showEditPlan) {
            EditPlanView(planTitle: title)
        }
        .sheet(isPresented: $showPlanDetail) {
            TrainingPlanDetailView(plan: TrainingPlan(
                id: 0,
                name: title,
                creator: "用户",
                createdDate: "2025-05-29",
                lastTraining: "未训练",
                volume: 480
            ))
        }
        .alert("删除计划", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                // TODO: 实现删除功能
                print("删除计划: \(title)")
            }
        } message: {
            Text("确定要删除训练计划 \"\(title)\" 吗？此操作无法撤销。")
        }
    }
}

#Preview {
    PlanListView()
} 
import SwiftUI

struct TrainingPlanDetailView: View {
    @State private var plan: TrainingPlan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    @State private var showEditPlan = false
    @ObservedObject private var trainingManager = TrainingSessionManager.shared
    @State private var showTrainingConflictAlert = false
    @State private var isLoadingPlan = false
    @State private var hasLoadedUserPlan = false
    private let planService = LocalPlanService.shared
    
    init(plan: TrainingPlan) {
        self._plan = State(initialValue: plan)
    }
    
    var body: some View {
        VStack(spacing: 0) {
                // 标题区域
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(plan.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.onSurface)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f", Double(plan.calculatedVolume))) kg")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(theme.primary)
                    }
                    
                    // 计划信息
                    HStack(spacing: 16) {
                        Text("创建: \(plan.createdDate)")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondary)
                        
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .background(theme.surface)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 计划描述
                        if let description = plan.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("计划描述")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(theme.onSurface)
                                
                                Text(description)
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(theme.surface)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        }
                        
                        // 训练动作
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(spacing: 12) {
                                if let actions = plan.actions, !actions.isEmpty {
                                    ForEach(actions) { action in
                                        DetailActionCard(action: action)
                                    }
                                } else {
                                    Text("暂无训练动作")
                                        .font(.system(size: 16))
                                        .foregroundColor(theme.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 40)
                                        .background(theme.surface)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // 底部按钮区域
                        VStack(spacing: 12) {
                            // 开始训练按钮（仅个人计划显示）
                            if !plan.isTemplate {
                                Button(action: {
                                    handleStartTraining()
                                }) {
                                    Text("开始训练")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(canStartTraining ? theme.primary : theme.disabled)
                                        .cornerRadius(25)
                                }
                                .disabled(!canStartTraining)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                }
                .background(theme.background)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                    .foregroundColor(theme.primary)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("训练计划详情")
                        .font(.headline)
                }
                
                // 编辑计划按钮（仅个人计划显示）
                if !plan.isTemplate {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("编辑") {
                            showEditPlan = true
                        }
                        .foregroundColor(theme.primary)
                    }
                }
            }
        .fullScreenCover(isPresented: $showEditPlan) {
            // 传递回调，保存成功后重新加载数据但保持在详情页
            EditPlanView(plan: plan, onSaveSuccess: { updatedPlan in
                print("🔄 TrainingPlanDetailView EditPlanView onSaveSuccess 回调被触发")
                
                // 关闭编辑页面
                showEditPlan = false
                
                // 重新加载计划数据
                reloadPlanData()
            })
        }
        .alert("训练冲突", isPresented: $showTrainingConflictAlert) {
            Button("取消", role: .cancel) { }
            Button("停止当前训练") {
                guard canStartTraining else { return }
                trainingManager.stopTraining()
                trainingManager.startTraining(with: plan)
                dismiss()
            }
        } message: {
            Text("每次只能执行一个训练计划。当前正在进行「\(trainingManager.planName)」训练，是否停止当前训练并开始新的训练？")
        }
        .onAppear {
            reloadPlanData()
        }
    }

    // MARK: - 私有方法
    
    private var canStartTraining: Bool {
        !plan.isTemplate && hasLoadedUserPlan && !isLoadingPlan && plan.actions?.isEmpty == false
    }

    private func handleStartTraining() {
        guard canStartTraining else { return }
        if trainingManager.isTrainingActive {
            // 如果已有训练在进行，显示冲突提示
            showTrainingConflictAlert = true
        } else {
            // 没有训练在进行，直接开始新训练
            trainingManager.startTraining(with: plan)
            dismiss()
        }
    }
    
    private func reloadPlanData() {
        isLoadingPlan = true
        if !plan.isTemplate {
            hasLoadedUserPlan = false
        }

        Task {
            do {
                let updatedPlan: TrainingPlan
                if plan.isTemplate {
                    updatedPlan = try await planService.getTemplatePlanDetail(planId: plan.id)
                } else {
                    updatedPlan = try await planService.getUserPlanDetail(planId: plan.id)
                }
                await MainActor.run {
                    self.plan = updatedPlan
                    hasLoadedUserPlan = !updatedPlan.isTemplate
                    isLoadingPlan = false
                    print("✅ 计划数据重新加载成功: \(updatedPlan.name), 动作数量: \(updatedPlan.actions?.count ?? 0)")
                    
                    // 发送通知给PlanListView，让它也更新对应的计划数据
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PlanUpdatedFromDetail"),
                        object: nil,
                        userInfo: ["updatedPlan": updatedPlan]
                    )
                }
            } catch {
                await MainActor.run {
                    isLoadingPlan = false
                }
                print("❌ 重新加载计划数据失败: \(error)")
            }
        }
    }
}

// 详情页动作卡片
struct DetailActionCard: View {
    let action: TrainingAction
    @Environment(\.theme) private var theme: AppTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // 动作缩略图 - 使用本地图片加载
                Group {
                    if let uiImage = loadLocalActionImage(fileName: extractImageFileName(from: action.imageUrl)) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Rectangle()
                            .fill(theme.secondary.opacity(0.3))
                            .overlay(
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .foregroundColor(theme.secondary)
                            )
                    }
                }
                .frame(width: 60, height: 60)
                .background(theme.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.onSurface)
                    
                    if let notes = action.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 16))
                            .foregroundColor(theme.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(String(format: "%.1f", Double(action.totalVolume))) kg")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primary)
                    
                    Text("\(action.totalSets) 组")
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondary)
                }
            }
            
            // 组数详情
            if !action.sets.isEmpty {
                VStack(spacing: 4) {
                    HStack {
                        Text("组数")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.secondary)
                        Spacer()
                    }
                    
                    ForEach(Array(action.sets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("\(index + 1)")
                                .font(.system(size: 14))
                                .foregroundColor(theme.secondary)
                                .frame(width: 20, alignment: .leading)
                            
                            if action.recordBilateral {
                                // 双侧训练显示左右重量
                                Text("左\(String(format: "%.1f", set.leftWeight))kg")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.onSurface)
                                    .frame(width: 65, alignment: .leading)
                                
                                Text("右\(String(format: "%.1f", set.rightWeight))kg")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.onSurface)
                                    .frame(width: 65, alignment: .leading)
                            } else {
                                // 普通训练显示单一重量
                                Text("\(String(format: "%.1f", set.weight))kg")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.onSurface)
                                    .frame(width: 55, alignment: .leading)
                                
                                Text("×")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.secondary)
                            }
                            
                            Text("\(set.reps)次")
                                .font(.system(size: 14))
                                .foregroundColor(theme.onSurface)
                                .frame(width: 40, alignment: .leading)
                            
                            Spacer()
                            
                            // 容量计算也要考虑双侧训练
                            if action.recordBilateral {
                                let totalWeight = set.leftWeight + set.rightWeight
                                Text("\(String(format: "%.1f", totalWeight * Double(set.reps)))kg")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.primary)
                            } else {
                                Text("\(String(format: "%.1f", set.weight * Double(set.reps)))kg")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.primary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.secondary.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
                .padding(.top, 8)
            }
            
            // 休息时间
            HStack {
                Text("休息时间: \(action.restTime)秒")
                    .font(.system(size: 16))
                    .foregroundColor(theme.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 辅助函数
private func extractImageFileName(from fullPath: String) -> String {
    // 从完整路径中提取文件名
    // 例如: "backend/static/images/actions/exercise_1.gif" -> "exercise_1.gif"
    return URL(fileURLWithPath: fullPath).lastPathComponent
}

/// 从本地bundle加载动作图片
private func loadLocalActionImage(fileName: String) -> UIImage? {
    // 清理路径，移除 .gif 扩展名
    let cleanPath = fileName.replacingOccurrences(of: ".gif", with: "")
    
    // 首先尝试直接使用完整路径加载
    if let url = Bundle.main.url(forResource: cleanPath, withExtension: "gif"),
       let data = try? Data(contentsOf: url),
       let image = UIImage(data: data) {
        return image
    }
    
    // 备用方案：提取文件名并从所有可能的目录加载
    let fileName = URL(string: cleanPath)?.lastPathComponent ?? cleanPath
    
    // 所有可能的目标肌肉目录
    let muscleDirectories = [
        "abs", "pectorals", "biceps", "triceps", "delts", "lats", "upper back",
        "quads", "hamstrings", "glutes", "calves", "forearms", "traps",
        "cardiovascular system", "spine", "adductors", "abductors",
        "serratus anterior", "levator scapulae"
    ]
    
    // 尝试从各个肌肉目录加载
    for muscleDir in muscleDirectories {
        let path = "Images/\(muscleDir)/\(fileName)"
        if let url = Bundle.main.url(forResource: path, withExtension: "gif"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
    }
    
    // 最后尝试旧的路径格式（兼容性）
    let legacyPaths = [
        "Media/Actions/\(fileName)",
        "Images/\(fileName)",
        fileName
    ]
    
    for path in legacyPaths {
        if let url = Bundle.main.url(forResource: path, withExtension: "gif"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
    }
    
    return nil
}

#Preview {
    // 预览代码暂时注释，等待类型定义完成
    Text("TrainingPlanDetailView Preview")
}
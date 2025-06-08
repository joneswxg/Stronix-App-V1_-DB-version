import SwiftUI

struct TrainingPlanDetailView: View {
    let plan: TrainingPlan
    @Environment(\.dismiss) private var dismiss
    @State private var showEditPlan = false
    @ObservedObject private var trainingManager = TrainingSessionManager.shared
    @State private var showTrainingConflictAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标题区域
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(plan.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Text("\(plan.calculatedVolume) kg")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    // 计划信息
                    HStack(spacing: 16) {
                        if let difficulty = plan.difficulty {
                            Text("难度: \(difficulty)")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Text("创建: \(plan.createdDate)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .background(Color.white)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 计划描述
                        if let description = plan.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("计划描述")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Text(description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        }
                        
                        // 训练动作
                        VStack(alignment: .leading, spacing: 16) {
                            Text("训练动作")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 12) {
                                if let actions = plan.actions, !actions.isEmpty {
                                    ForEach(actions) { action in
                                        DetailActionCard(action: action)
                                    }
                                } else {
                                    Text("暂无训练动作")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 40)
                                        .background(Color.white)
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
                                        .background(plan.actions?.isEmpty == false ? Color.blue : Color.gray)
                                        .cornerRadius(25)
                                }
                                .disabled(plan.actions?.isEmpty != false)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                }
                .background(Color(white: 0.95))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                // 编辑计划按钮（仅个人计划显示）
                if !plan.isTemplate {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("编辑") {
                            showEditPlan = true
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditPlan) {
            // 不再传递viewModel，避免状态冲突
            EditPlanView(plan: plan)
        }
        .alert("训练冲突", isPresented: $showTrainingConflictAlert) {
            Button("取消", role: .cancel) { }
            Button("停止当前训练") {
                trainingManager.stopTraining()
                trainingManager.startTraining(with: plan)
                dismiss()
            }
        } message: {
            Text("每次只能执行一个训练计划。当前正在进行「\(trainingManager.planName)」训练，是否停止当前训练并开始新的训练？")
        }
    }
    
    // MARK: - 私有方法
    
    private func handleStartTraining() {
        if trainingManager.isTrainingActive {
            // 如果已有训练在进行，显示冲突提示
            showTrainingConflictAlert = true
        } else {
            // 没有训练在进行，直接开始新训练
            trainingManager.startTraining(with: plan)
            dismiss()
        }
    }
}

// 详情页动作卡片
struct DetailActionCard: View {
    let action: TrainingAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // 动作缩略图 - 从服务器加载静态图片
                AsyncImage(url: URL(string: "http://127.0.0.1:6000/api/action/images/\(extractImageFileName(from: action.imageUrl))")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 60, height: 60)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    if let notes = action.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(action.totalVolume) kg")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Text("\(action.totalSets) 组")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            // 组数详情
            if !action.sets.isEmpty {
                VStack(spacing: 4) {
                    HStack {
                        Text("组数详情")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    
                    ForEach(Array(action.sets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("第\(index + 1)组")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .frame(width: 50, alignment: .leading)
                            
                            if action.recordBilateral {
                                // 双侧训练显示左右重量
                                Text("左\(Int(set.leftWeight))kg")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                    .frame(width: 60, alignment: .leading)
                                
                                Text("右\(Int(set.rightWeight))kg")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                    .frame(width: 60, alignment: .leading)
                            } else {
                                // 普通训练显示单一重量
                                Text("\(Int(set.weight))kg")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                    .frame(width: 50, alignment: .leading)
                                
                                Text("×")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            Text("\(set.reps)次")
                                .font(.system(size: 12))
                                .foregroundColor(.black)
                                .frame(width: 50, alignment: .leading)
                            
                            Spacer()
                            
                            // 容量计算也要考虑双侧训练
                            if action.recordBilateral {
                                let totalWeight = set.leftWeight + set.rightWeight
                                Text("\(Int(totalWeight * Double(set.reps)))kg")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            } else {
                                Text("\(Int(set.weight * Double(set.reps)))kg")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
                .padding(.top, 8)
            }
            
            // 休息时间
            HStack {
                Text("休息时间: \(action.restTime)秒")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
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

#Preview {
    let samplePlan = TrainingPlan(
        id: 1,
        name: "测试计划",
        creator: "我",
        createdDate: "2024-01-01",
        lastTraining: "未开始",
        volume: 0,
        description: "这是一个测试计划",
        difficulty: "中级"
    )
    return TrainingPlanDetailView(plan: samplePlan)
} 
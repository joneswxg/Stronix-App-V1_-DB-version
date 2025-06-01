import SwiftUI

struct TrainingPlanDetailView: View {
    let plan: TrainingPlan
    @Environment(\.dismiss) private var dismiss
    @State private var showStartTraining = false
    @State private var showEditPlan = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标题区域
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(plan.name)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Text("\(plan.volume) kg")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .background(Color.white)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 计划描述
                        VStack(alignment: .leading, spacing: 12) {
                            Text("计划描述")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                            
                            Text("显示创建时候时候写的描述信息")
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
                        
                        // 训练动作
                        VStack(alignment: .leading, spacing: 16) {
                            Text("训练动作")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 12) {
                                DetailActionCard(
                                    icon: "💪",
                                    name: "3/4 sit-up",
                                    sets: "3",
                                    volume: "240 kg"
                                )
                                
                                DetailActionCard(
                                    icon: "🏃",
                                    name: "alternate heel touchers",
                                    sets: "2",
                                    volume: "240 kg"
                                )
                                
                                DetailActionCard(
                                    icon: "💪",
                                    name: "arm slingers hanging straight legs",
                                    sets: "4",
                                    volume: "240 kg"
                                )
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // 底部按钮区域
                        VStack(spacing: 12) {
                            // 开始训练按钮
                            Button(action: {
                                showStartTraining = true
                            }) {
                                Text("开始训练")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.blue)
                                    .cornerRadius(25)
                            }
                            
                            // 编辑计划按钮
                            Button(action: {
                                showEditPlan = true
                            }) {
                                Text("编辑计划")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                                    .cornerRadius(22)
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
            }
        }
        .sheet(isPresented: $showStartTraining) {
            StartTrainingView(plan: plan)
        }
        .sheet(isPresented: $showEditPlan) {
            EditPlanView(planTitle: plan.name)
        }
    }
}

// 详情页动作卡片
struct DetailActionCard: View {
    let icon: String
    let name: String
    let sets: String
    let volume: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            Text("\(name) x \(sets)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
            
            Spacer()
            
            Text(volume)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// 开始训练视图（占位）
struct StartTrainingView: View {
    let plan: TrainingPlan
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("开始训练: \(plan.name)")
                    .font(.title)
                Text("训练功能开发中...")
                    .foregroundColor(.gray)
            }
            .navigationTitle("训练中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TrainingPlanDetailView(plan: TrainingPlan(
        id: 1,
        name: "胸肌训练",
        creator: "jones",
        createdDate: "2025-05-28",
        lastTraining: "未训练",
        volume: 720
    ))
} 
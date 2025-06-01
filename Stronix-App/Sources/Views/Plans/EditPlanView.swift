import SwiftUI

struct EditPlanView: View {
    @Environment(\.dismiss) private var dismiss
    let planTitle: String
    
    @State private var planName: String
    @State private var planDescription = "每周三次训练计划"
    @State private var isTemplate = false
    @State private var totalVolume = "120 kg"
    @State private var restTime = "60"
    @State private var showActionSelect = false
    
    // 模拟训练动作数据
    @State private var planActions: [PlanActionItem] = [
        PlanActionItem(
            id: 1,
            name: "3/4 sit-up",
            imageName: "action1",
            sets: [
                ActionSet(weight: 10.0, reps: 12)
            ]
        )
    ]
    
    init(planTitle: String) {
        self.planTitle = planTitle
        self._planName = State(initialValue: planTitle)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 顶部信息栏
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("训练计划总容量：\(totalVolume)")
                                .font(.system(size: 14, weight: .medium))
                            Text("实时计算，随输入更新")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    // 计划名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text("计划名称")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                        
                        TextField("输入计划名称", text: $planName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 16)
                    }
                    
                    // 计划描述
                    VStack(alignment: .leading, spacing: 8) {
                        Text("计划描述")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                        
                        TextField("输入计划描述", text: $planDescription, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                            .padding(.horizontal, 16)
                    }
                    
                    // 设为模板选项
                    HStack {
                        Toggle("设为模板（其他用户可以复制使用）", isOn: $isTemplate)
                            .font(.system(size: 14))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    // 训练动作标题
                    HStack {
                        Text("训练动作")
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    // 训练动作列表
                    ForEach(planActions) { action in
                        ActionEditCard(
                            action: action,
                            restTime: $restTime,
                            onDelete: {
                                deleteAction(action)
                            },
                            onUpdateSets: { updatedSets in
                                updateActionSets(action, sets: updatedSets)
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                    
                    // 添加动作按钮
                    Button(action: {
                        showActionSelect = true
                    }) {
                        Text("添加动作")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("编辑训练计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存更改") {
                        // TODO: 保存计划更改
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $showActionSelect) {
            PlanActionSelectView()
        }
    }
    
    private func deleteAction(_ action: PlanActionItem) {
        planActions.removeAll { $0.id == action.id }
    }
    
    private func updateActionSets(_ action: PlanActionItem, sets: [ActionSet]) {
        if let index = planActions.firstIndex(where: { $0.id == action.id }) {
            planActions[index].sets = sets
        }
    }
}

// 训练动作编辑卡片
struct ActionEditCard: View {
    let action: PlanActionItem
    @Binding var restTime: String
    let onDelete: () -> Void
    let onUpdateSets: ([ActionSet]) -> Void
    
    @State private var sets: [ActionSet]
    @State private var showDeleteAlert = false
    
    init(action: PlanActionItem, restTime: Binding<String>, onDelete: @escaping () -> Void, onUpdateSets: @escaping ([ActionSet]) -> Void) {
        self.action = action
        self._restTime = restTime
        self.onDelete = onDelete
        self.onUpdateSets = onUpdateSets
        self._sets = State(initialValue: action.sets)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 动作信息
            HStack {
                // 动作图片
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(.gray)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.name)
                        .font(.system(size: 16, weight: .medium))
                    Text("输入备注")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 容量显示
                Text("容量：120 kg")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan)
                    .cornerRadius(12)
                
                // 删除按钮
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Text("删除动作")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(12)
                }
            }
            
            // 休息时间
            HStack {
                Text("休息时间（秒）")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            
            TextField("60", text: $restTime)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
            
            // 组数设置标题
            HStack {
                Text("组数设置")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            
            // 组数表头
            HStack {
                Text("组数")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 40, alignment: .leading)
                
                Text("重量（kg）")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("次数")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 60, alignment: .leading)
                
                Text("操作")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 60, alignment: .center)
            }
            .foregroundColor(.gray)
            
            // 组数列表
            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                HStack {
                    Text("\(index + 1)")
                        .font(.system(size: 14))
                        .frame(width: 40, alignment: .leading)
                    
                    HStack {
                        TextField("10.0", value: Binding(
                            get: { sets[index].weight },
                            set: { sets[index].weight = $0 }
                        ), format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        
                        Text("kg")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    
                    TextField("12", value: Binding(
                        get: { sets[index].reps },
                        set: { sets[index].reps = $0 }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 60)
                    
                    Button(action: {
                        sets.remove(at: index)
                        onUpdateSets(sets)
                    }) {
                        Text("删除")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .frame(width: 60)
                }
            }
            
            // 新增一组按钮
            Button(action: {
                sets.append(ActionSet(weight: 10.0, reps: 12))
                onUpdateSets(sets)
            }) {
                Text("新增一组")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("确定要删除这个训练动作吗？")
        }
    }
}

// 数据模型
struct PlanActionItem: Identifiable {
    let id: Int
    let name: String
    let imageName: String
    var sets: [ActionSet]
}

struct ActionSet: Identifiable {
    let id = UUID()
    var weight: Double
    var reps: Int
}

#Preview {
    EditPlanView(planTitle: "我的训练计划")
} 
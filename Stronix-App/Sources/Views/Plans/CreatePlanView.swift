import SwiftUI

// MARK: - 数据模型
struct PlanAction: Identifiable {
    let id: Int
    let name: String
    let imageUrl: String
    let nameEn: String // 新增英文名
    let bodyPartId: Int // 新增部位ID
    let equipmentId: Int // 新增器材ID
    let targetMuscleIds: [Int] // 新增目标肌肉组
    var sets: [PlanSet]
    var restTime: Int = 60 // 默认休息时间60秒
    var notes: String = ""
    var isExpanded: Bool = false
    var isLeftRightMode: Bool = false // 新增：是否启用左右模式
}

struct PlanSet: Identifiable {
    let id = UUID()
    var weight: Double = 0.0
    var leftWeight: Double = 0.0  // 新增：左侧重量
    var rightWeight: Double = 0.0 // 新增：右侧重量
    var reps: Int = 0
    var notes: String = ""
    var isCompleted: Bool = false
    var hasNotes: Bool = false // 新增：是否有备注
}

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var planName = ""
    @State private var planNote = ""
    @State private var showPlanNote = false
    @State private var showActionSelect = false
    @State private var selectedActions: [PlanAction] = []
    @State private var showPlanMenu = false
    @State private var weightUnit: WeightUnit = .kg
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    
    private let planService = PlanService.shared
    
    enum WeightUnit: String, CaseIterable {
        case kg = "kg"
        case lbs = "lbs"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // 计划名称和菜单
                planNameSection
                
                // 计划描述（条件显示）
                if showPlanNote {
                    planNoteSection
                }
                
                // 添加动作按钮
                if selectedActions.isEmpty {
                    addActionButton
                }
                
                // 动作列表
                if !selectedActions.isEmpty {
                    actionListSection
                }
                
                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("创建计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await savePlan()
                        }
                    }) {
                        HStack(spacing: 4) {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("保存")
                            }
                        }
                    }
                    .disabled(planName.isEmpty || selectedActions.isEmpty || isSaving)
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定") {
                    showError = false
                }
            } message: {
                Text(errorMessage)
            }
            .alert("成功", isPresented: $showSuccess) {
                Button("确定") {
                    showSuccess = false
                    // 不在这里调用 dismiss()，因为已经在 savePlan() 中延迟调用了
                }
            } message: {
                Text(successMessage)
            }
        }
        .sheet(isPresented: $showActionSelect) {
            PlanActionSelectView { actions in
                addSelectedActions(actions)
            }
        }
    }
    
    // MARK: - 计划名称区域
    private var planNameSection: some View {
        HStack(spacing: 12) {
            TextField("输入计划名称", text: $planName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isSaving)
            
            Menu {
                if !showPlanNote {
                    Button(action: {
                        showPlanNote = true
                    }) {
                        Label("添加描述", systemImage: "note.text")
                    }
                } else {
                    Button(action: {
                        showPlanNote = false
                        planNote = ""
                    }) {
                        Label("删除描述", systemImage: "trash")
                    }
                }
                
                Button(action: {
                    // 编辑计划名称 - 可以聚焦到输入框
                }) {
                    Label("编辑计划名称", systemImage: "pencil")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .frame(width: 30, height: 30)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 计划描述区域
    private var planNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("添加计划描述", text: $planNote, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
                .disabled(isSaving)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 添加动作按钮
    private var addActionButton: some View {
        Button(action: {
            showActionSelect = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("添加动作")
            }
            .foregroundColor(.blue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(white: 0.97))
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .disabled(isSaving)
    }
    
    // MARK: - 动作列表区域
    private var actionListSection: some View {
        VStack(spacing: 12) {
            ForEach(selectedActions.indices, id: \.self) { index in
                PlanActionCard(
                    action: $selectedActions[index],
                    weightUnit: weightUnit,
                    onDelete: {
                        selectedActions.remove(at: index)
                    },
                    onToggleUnit: {
                        toggleWeightUnit()
                    },
                    isDisabled: isSaving
                )
            }
            
            // 添加更多动作按钮
            Button(action: {
                showActionSelect = true
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("添加动作")
                }
                .foregroundColor(.blue)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(white: 0.97))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .disabled(isSaving)
        }
    }
    
    // MARK: - 方法
    private func addSelectedActions(_ actions: [ActionListView.Action]) {
        let newActions = actions.map { action in
            PlanAction(
                id: action.id,
                name: action.name,
                imageUrl: action.image_url,
                nameEn: action.name_en ?? "",
                bodyPartId: action.body_part_id,
                equipmentId: action.equipment_id,
                targetMuscleIds: action.target_muscle_ids,
                sets: [PlanSet()] // 默认添加一组
            )
        }
        selectedActions.append(contentsOf: newActions)
    }
    
    private func toggleWeightUnit() {
        weightUnit = weightUnit == .kg ? .lbs : .kg
        // 这里可以添加单位转换逻辑
    }
    
    private func savePlan() async {
        isSaving = true
        errorMessage = ""
        
        do {
            // 构建请求数据
            let planData = CreatePlanRequest(
                name: planName,
                description: planNote.isEmpty ? nil : planNote,
                difficulty: nil, // 可以后续添加难度选择
                duration: nil,   // 可以后续添加时长估算
                actions: selectedActions.map { action in
                    CreatePlanAction(
                        action_id: action.id,
                        rest: action.restTime,
                        note: action.notes,
                        record_bilateral: action.isLeftRightMode,
                        sets: action.sets.map { set in
                            CreatePlanSet(
                                weight: action.isLeftRightMode ? nil : set.weight,
                                reps: set.reps,
                                left_weight: action.isLeftRightMode ? set.leftWeight : nil,
                                right_weight: action.isLeftRightMode ? set.rightWeight : nil
                            )
                        }
                    )
                }
            )
            
            // 调用API保存计划
            let response = try await planService.createPlan(planData)
            
            print("创建计划成功，计划ID: \(response.plan_id)")
            
            // 保存成功，延迟关闭视图以避免状态冲突
            await MainActor.run {
                successMessage = "计划保存成功！"
                showSuccess = true
                
                // 延迟关闭视图，让成功提示显示一下
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🔄 CreatePlanView - 保存成功，准备关闭视图")
                    dismiss()
                }
            }
            
        } catch {
            await MainActor.run {
                if let apiError = error as? APIError {
                    errorMessage = apiError.localizedDescription
                } else {
                    errorMessage = "保存失败: \(error.localizedDescription)"
                }
                showError = true
            }
        }
        
        isSaving = false
    }
}

// MARK: - 动作卡片组件
struct PlanActionCard: View {
    @Binding var action: PlanAction
    let weightUnit: CreatePlanView.WeightUnit
    let onDelete: () -> Void
    let onToggleUnit: () -> Void
    let isDisabled: Bool
    
    @State private var showActionMenu = false
    @State private var showSetMenu = false
    @State private var selectedSetIndex: Int?
    @State private var showRestTimer = false // 新增：休息计时器设置弹窗
    @State private var minutes: Int = 1 // 新增：分钟设置
    @State private var seconds: Int = 0 // 新增：秒数设置
    @State private var showActionDetail = false // 新增：显示动作详情
    
    // 计算总容量
    private var totalVolume: Int {
        action.sets.reduce(0) { total, set in
            if action.isLeftRightMode {
                return total + Int((set.leftWeight + set.rightWeight) * Double(set.reps))
            } else {
                return total + Int(set.weight * Double(set.reps))
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 动作头部
            actionHeader
            
            // 组数详情（展开时显示）
            if action.isExpanded {
                setsSection
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showRestTimer) {
            restTimerSettingSheet
        }
        .background(
            NavigationLink(
                destination: ActionDetailView(action: ActionListView.Action(
                    id: action.id,
                    name: action.name,
                    name_en: action.nameEn,
                    image_url: action.imageUrl,
                    body_part_id: action.bodyPartId,
                    equipment_id: action.equipmentId,
                    target_muscle_ids: action.targetMuscleIds
                )),
                isActive: $showActionDetail
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
    
    // 休息计时器设置表单
    private var restTimerSettingSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("设置休息时间")) {
                    Stepper("分钟: \(minutes)", value: $minutes, in: 0...10)
                    Stepper("秒数: \(seconds)", value: $seconds, in: 0...59)
                }
            }
            .navigationTitle("休息计时器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showRestTimer = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        action.restTime = minutes * 60 + seconds
                        showRestTimer = false
                    }
                }
            }
        }
    }
    
    // MARK: - 动作头部
    private var actionHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 动作图片
                AsyncImage(url: URL(string: "http://127.0.0.1:6000/api/action/images/\(action.imageUrl.components(separatedBy: "/").last ?? "")")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                // 动作信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(action.name)
                            .font(.system(size: 16, weight: .medium))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // 容量显示
                        Text("\(totalVolume)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("\(action.sets.count)组")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // 左右模式开关
                        Toggle(isOn: $action.isLeftRightMode) {
                            Text("记录左右")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .scaleEffect(0.8)
                        .disabled(isDisabled)
                        .onChange(of: action.isLeftRightMode) { newValue in
                            // 切换模式时清空重量数据
                            for index in action.sets.indices {
                                if newValue {
                                    // 切换到左右模式，清空普通重量
                                    action.sets[index].weight = 0.0
                                } else {
                                    // 切换到普通模式，清空左右重量
                                    action.sets[index].leftWeight = 0.0
                                    action.sets[index].rightWeight = 0.0
                                }
                            }
                        }
                    }
                }
                
                // 设置菜单
                Menu {
                    Button(action: {
                        showActionDetail = true
                    }) {
                        Label("动作详情", systemImage: "info.circle")
                    }
                    
                    Button(action: {
                        minutes = action.restTime / 60
                        seconds = action.restTime % 60
                        showRestTimer = true
                    }) {
                        Label("设置休息计时器", systemImage: "timer")
                    }
                    
                    Button(action: onToggleUnit) {
                        Label("切换单位 (\(weightUnit.displayName))", systemImage: "arrow.2.squarepath")
                    }
                    
                    Button(action: onDelete) {
                        Label("删除动作", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
                .disabled(isDisabled)
            }
            
            // 如果展开,显示表头
            if action.isExpanded {
                Divider()
                    .padding(.vertical, 4)
                
                tableHeader
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDisabled {
                withAnimation(.easeInOut(duration: 0.3)) {
                    action.isExpanded.toggle()
                }
            }
        }
    }
    
    // 表头组件
    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text("组")
                .frame(width: 30, alignment: .center)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            if action.isLeftRightMode {
                Text("左\(weightUnit.displayName)")
                    .frame(width: 40, alignment: .leading)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Text("右\(weightUnit.displayName)")
                    .frame(width: 40, alignment: .leading)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                Text(weightUnit.displayName)
                    .frame(width: 40, alignment: .leading)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Text("次数")
                .frame(width: 40, alignment: .leading)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
    }
    
    // MARK: - 组数区域
    private var setsSection: some View {
        VStack(spacing: 8) {
            // 组数列表
            ForEach(action.sets.indices, id: \.self) { index in
                setRow(index: index)
            }
            
            // 底部按钮区域
            HStack(spacing: 16) {
                Button(action: {
                    action.sets.append(PlanSet())
                }) {
                    Text("新增一组")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                .disabled(isDisabled)
                
                Spacer()
                
                Button(action: {
                    // TODO: 显示动作历史
                }) {
                    Text("动作历史")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                .disabled(isDisabled)
                                
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - 单组行
    private func setRow(index: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 组数标号
                Text("\(index + 1)")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, alignment: .center)
                
                if action.isLeftRightMode {
                    // 左侧重量
                    TextField("0", value: $action.sets[index].leftWeight, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 40)
                        .multilineTextAlignment(.center)
                        .disabled(isDisabled)
                    
                    // 右侧重量
                    TextField("0", value: $action.sets[index].rightWeight, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 40)
                        .multilineTextAlignment(.center)
                        .disabled(isDisabled)
                } else {
                    // 普通重量
                    TextField("0", value: $action.sets[index].weight, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 40)
                        .multilineTextAlignment(.center)
                        .disabled(isDisabled)
                }
                
                // 次数输入
                TextField("0", value: $action.sets[index].reps, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 40)
                    .multilineTextAlignment(.center)
                    .disabled(isDisabled)
                
                Spacer()
                
                // 组菜单
                Menu {
                    if action.sets[index].hasNotes {
                        Button(action: {
                            action.sets[index].hasNotes = false
                            action.sets[index].notes = ""
                        }) {
                            Label("删除备注", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                    } else {
                        Button(action: {
                            action.sets[index].hasNotes = true
                        }) {
                            Label("输入备注", systemImage: "note.text")
                        }
                    }
                    
                    Button(action: {
                        action.sets.remove(at: index)
                    }) {
                        Label("删除", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .frame(width: 30, height: 30)
                }
                .disabled(isDisabled)
            }
            
            // 备注输入框
            if action.sets[index].hasNotes {
                HStack {
                    Spacer()
                        .frame(width: 42) // 对齐组数标号
                    
                    TextField("输入备注", text: $action.sets[index].notes)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 14))
                        .disabled(isDisabled)
                    
                    Spacer()
                        .frame(width: 42) // 对齐菜单按钮
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
    }
}

#Preview {
    CreatePlanView()
} 

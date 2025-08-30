import SwiftUI
import UIKit
import Combine

// MARK: - 数据模型
struct PlanAction: Identifiable {
    let id: Int
    let actionId: Int // 真正的动作ID，用于保存到数据库
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
    @Environment(\.theme) private var theme: AppTheme
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
    @State private var selectedTargetMuscleId = 0 // 添加目标肌肉ID状态
    
    // MARK: - 键盘管理器
    @StateObject private var keyboardManager = CustomKeyboardManager()
    
    private let localPlanService = LocalPlanService.shared
    
    // 隐藏系统键盘的方法
    private func hideSystemKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    enum WeightUnit: String, CaseIterable {
        case kg = "kg"
        case lbs = "lbs"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // 计划名称和菜单
                        planNameSection
                        
                        // 计划描述（条件显示）
                        if showPlanNote {
                            planNoteSection
                        }
                     
                        // 动作列表
                        if !selectedActions.isEmpty {
                            actionListSection
                        }
                        
                        // 添加动作按钮（始终显示）
                        addActionButton
                        
                        // 底部间距
                        Spacer(minLength: 50)
                        
                        // 为键盘预留空间
                        if keyboardManager.isShowing {
                            Spacer()
                                .frame(height: 280)
                        }
                    }
                    .padding(.top, 20)
                }
                .background(theme.background)
                .contentShape(Rectangle())
                .onTapGesture {
                    // 点击空白区域隐藏键盘
                    if keyboardManager.isShowing {
                        keyboardManager.cancelKeyboard()
                        hideSystemKeyboard()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    // 系统键盘即将显示时，隐藏自定义键盘
                    if keyboardManager.isShowing {
                        keyboardManager.cancelKeyboard()
                    }
                }
                
                // 自定义键盘
                if keyboardManager.isShowing {
                    CustomNumberKeyboard(
                        value: $keyboardManager.currentValue,
                        isShowing: $keyboardManager.isShowing,
                        step: keyboardManager.step,
                        maxValue: keyboardManager.maxValue,
                        isInteger: keyboardManager.isInteger,
                        keyboardManager: keyboardManager
                    )
                    .onChange(of: keyboardManager.isShowing) { _, isShowing in
                        if !isShowing {
                            hideSystemKeyboard()
                        }
                    }
                }
            }
            .navigationTitle("创建计划")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(content: {
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
            })
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
            PlanActionSelectView(
                onActionSelected: { actionInfo in
                    addSelectedActionInfo(actionInfo)
                },
                existingActionIds: Set(selectedActions.map { $0.actionId })
            )
        }
    }
    
    // MARK: - 计划名称区域
    private var planNameSection: some View {
        HStack(spacing: 12) {
            TextField("输入计划名称", text: $planName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isSaving)
                .onTapGesture {
                    // 当点击计划名称输入框时，隐藏自定义键盘
                    if keyboardManager.isShowing {
                        keyboardManager.cancelKeyboard()
                    }
                }
            
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
                    .foregroundColor(theme.secondary)
                    .frame(width: 30, height: 30)
                    .background(theme.secondary.opacity(0.1))
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
                .onTapGesture {
                    // 当点击计划描述输入框时，隐藏自定义键盘
                    if keyboardManager.isShowing {
                        keyboardManager.cancelKeyboard()
                    }
                }
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
            .foregroundColor(theme.primary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(theme.surface)
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .disabled(isSaving)
    }
    
    // MARK: - 动作列表区域
    private var actionListSection: some View {
        VStack(spacing: 12) {
            ForEach(selectedActions, id: \.id) { action in
                PlanActionCardWrapper(
                    action: action,
                    selectedActions: $selectedActions,
                    weightUnit: weightUnit,
                    onDelete: {
                        deleteAction(action)
                    },
                    onToggleUnit: {
                        toggleWeightUnit()
                    },
                    isDisabled: isSaving,
                    keyboardManager: keyboardManager,
                    selectedTargetMuscleId: $selectedTargetMuscleId
                )
            }
        }
    }
    
    // MARK: - 方法
    private func addSelectedActionInfo(_ actionInfo: ActionInfo) {
        // 将ActionInfo转换为Action
        let action = Action(
            id: actionInfo.id,
            external_id: String(actionInfo.id),
            name: actionInfo.name,
            name_en: nil,
            gifUrl: actionInfo.imageUrl,
            description: nil,
            description_en: nil,
            difficulty: nil,
            bodypart_id: 0,
            equipment_id: nil,
            is_bilateral: false,
            target_muscle_ids: []
        )
        addSelectedAction(action)
    }
    
    private func addSelectedAction(_ action: Action) {
        let newAction = PlanAction(
            id: Int.random(in: 100000...999999), // 使用随机ID避免冲突
            actionId: action.id, // 真正的动作ID
            name: action.name,
            imageUrl: action.gifUrl ?? "",
            nameEn: action.name_en ?? "",
            bodyPartId: action.bodypart_id,
            equipmentId: action.equipment_id ?? 0,
            targetMuscleIds: action.target_muscle_ids,
            sets: [PlanSet()] // 默认添加一组
        )
        selectedActions.append(newAction)
    }
    
    private func deleteAction(_ action: PlanAction) {
        // 立即删除，不使用动画，避免竞态条件
        selectedActions.removeAll { $0.id == action.id }
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
                actions: selectedActions.enumerated().map { (index, action) in
                    CreatePlanAction(
                        action_id: action.actionId, // 使用真正的动作ID
                        order: index + 1,
                        rest: action.restTime,
                        note: action.notes,
                        record_bilateral: action.isLeftRightMode,
                        sets: action.sets.enumerated().map { (setIndex, set) in
                            CreatePlanSet(
                                set_number: setIndex + 1,
                                weight: action.isLeftRightMode ? nil : set.weight,
                                reps: set.reps,
                                left_weight: action.isLeftRightMode ? set.leftWeight : nil,
                                right_weight: action.isLeftRightMode ? set.rightWeight : nil
                            )
                        }
                    )
                }
            )
            
            // 调用本地服务保存计划
            let planDict: [String: Any] = [
                "name": planData.name,
                "description": planData.description ?? "",
                "difficulty": planData.difficulty ?? "",
                "duration": planData.duration ?? 0,
                "actions": planData.actions.map { action in
                    [
                        "action_id": action.action_id, // 这里已经是正确的actionId
                        "rest": action.rest,
                        "note": action.note ?? "",
                        "record_bilateral": action.record_bilateral,
                        "sets": action.sets.map { set in
                            [
                                "set_number": set.set_number,
                                "weight": set.weight ?? 0.0,
                                "reps": set.reps,
                                "left_weight": set.left_weight ?? 0.0,
                                "right_weight": set.right_weight ?? 0.0
                            ]
                        }
                    ]
                }
            ]
            
            // 获取当前用户ID
            guard let currentUser = LocalUserService.shared.currentUser else {
                throw LocalPlanError.unauthorized("用户未登录")
            }
            
            let response = try await localPlanService.createPlan(planDict, user_id: currentUser.id)
            
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
                if let localError = error as? LocalPlanError {
                    errorMessage = localError.message
                } else {
                    errorMessage = "保存失败: \(error.localizedDescription)"
                }
                showError = true
            }
        }
        
        isSaving = false
    }
}

// MARK: - 动作卡片包装器
struct PlanActionCardWrapper: View {
    let action: PlanAction
    @Binding var selectedActions: [PlanAction]
    let weightUnit: CreatePlanView.WeightUnit
    let onDelete: () -> Void
    let onToggleUnit: () -> Void
    let isDisabled: Bool
    let keyboardManager: CustomKeyboardManager
    @Binding var selectedTargetMuscleId: Int
    
    private var actionBinding: Binding<PlanAction> {
        Binding(
            get: {
                selectedActions.first { $0.id == action.id } ?? action
            },
            set: { newValue in
                if let index = selectedActions.firstIndex(where: { $0.id == action.id }) {
                    selectedActions[index] = newValue
                }
            }
        )
    }
    
    var body: some View {
        PlanActionCard(
            action: actionBinding,
            weightUnit: weightUnit,
            onDelete: onDelete,
            onToggleUnit: onToggleUnit,
            isDisabled: isDisabled,
            keyboardManager: keyboardManager,
            selectedTargetMuscleId: $selectedTargetMuscleId
        )
    }
}

// MARK: - 动作卡片组件
struct PlanActionCard: View {
    @Environment(\.theme) private var theme: AppTheme
    @Binding var action: PlanAction
    let weightUnit: CreatePlanView.WeightUnit
    let onDelete: () -> Void
    let onToggleUnit: () -> Void
    let isDisabled: Bool
    let keyboardManager: CustomKeyboardManager
    @Binding var selectedTargetMuscleId: Int
    
    @State private var showActionMenu = false
    @State private var showSetMenu = false
    @State private var selectedSetIndex: Int?
    @State private var showRestTimer = false // 新增：休息计时器设置弹窗
    @State private var minutes: Int = 1 // 新增：分钟设置
    @State private var seconds: Int = 0 // 新增：秒数设置
    @State private var showActionDetail = false // 新增：显示动作详情
    @State private var showDeleteAlert = false // 新增：删除确认弹窗
    @State private var showDeleteSetAlert = false // 新增：删除组确认弹窗
    @State private var setToDelete: PlanSet? = nil // 新增：要删除的组
    
    // 计算总容量
    private var totalVolume: Int {
        action.sets.reduce(0) { total, set in
            if action.isLeftRightMode {
                let leftWeight = set.leftWeight.isNaN || set.leftWeight.isInfinite ? 0.0 : set.leftWeight
                let rightWeight = set.rightWeight.isNaN || set.rightWeight.isInfinite ? 0.0 : set.rightWeight
                let volume = (leftWeight + rightWeight) * Double(set.reps)
                return total + Int(volume.isNaN || volume.isInfinite ? 0.0 : volume)
            } else {
                let weight = set.weight.isNaN || set.weight.isInfinite ? 0.0 : set.weight
                let volume = weight * Double(set.reps)
                return total + Int(volume.isNaN || volume.isInfinite ? 0.0 : volume)
            }
        }
    }
    
    // 隐藏系统键盘的方法
    private func hideSystemKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
        .navigationDestination(isPresented: $showActionDetail) {
            ActionDetailView(
                action: Action(
                    id: action.actionId, // 使用真正的动作ID
                    external_id: String(action.actionId),
                    name: action.name,
                    name_en: action.nameEn,
                    gifUrl: action.imageUrl,
                    description: nil,
                    description_en: nil,
                    difficulty: nil,
                    bodypart_id: action.bodyPartId,
                    equipment_id: action.equipmentId,
                    is_bilateral: false,
                    target_muscle_ids: action.targetMuscleIds
                ),
                selectedTargetMuscleId: $selectedTargetMuscleId
            )
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("确定要删除这个训练动作吗？")
        }
        .alert("确认删除", isPresented: $showDeleteSetAlert) {
            Button("取消", role: .cancel) { 
                setToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let setToDelete = setToDelete {
                    action.sets.removeAll { $0.id == setToDelete.id }
                }
                setToDelete = nil
            }
        } message: {
            Text("确定要删除这组吗？")
        }
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
            .toolbar(content: {
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
            })
        }
    }
    
    // MARK: - 动作头部
    private var actionHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 动作图片 - 使用本地图片加载
                Group {
                    if let uiImage = loadLocalActionImage(fileName: action.imageUrl) {
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
                            .foregroundColor(theme.secondary)
                    }
                    
                    HStack {
                        Text("\(action.sets.count)组")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondary)
                        
                        Spacer()
                        
                        // 左右模式开关
                        Toggle(isOn: $action.isLeftRightMode) {
                            Text("记录左右")
                                .font(.system(size: 12))
                                .foregroundColor(theme.secondary)
                        }
                        .tint(theme.primary)
                        .scaleEffect(0.8)
                        .disabled(isDisabled)
                        .onChange(of: action.isLeftRightMode) { _, newValue in
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
                    
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Label("删除动作", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(theme.primary)
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
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Text("组")
                    .frame(width: 30, height: 36, alignment: .center)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.secondary)
                    .background(theme.surface)
                    .cornerRadius(6)

                if action.isLeftRightMode {
                    Text("左\(weightUnit.displayName)")
                        .frame(width: 60, height: 36, alignment: .center)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .background(theme.surface)
                        .cornerRadius(6)
                    
                    Text("右\(weightUnit.displayName)")
                        .frame(width: 60, height: 36, alignment: .center)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .background(theme.surface)
                        .cornerRadius(6)
                } else {
                    Text(weightUnit.displayName)
                        .frame(width: 60, height: 36, alignment: .center)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .background(theme.surface)
                        .cornerRadius(6)
                }
                
                Text("次数")
                    .frame(width: 60, height: 36, alignment: .center)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.secondary)
                    .background(theme.surface)
                    .cornerRadius(6)
                
                Spacer()
            }
            .padding(.leading, 5)
            .padding(.trailing, 16)
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
    }
    
    // MARK: - 组数区域
    private var setsSection: some View {
        VStack(spacing: 16) {
            // 组数列表
            ForEach(action.sets.indices, id: \.self) { index in
                setRow(set: action.sets[index], setNumber: index + 1, setIndex: index)
            }
            
            // 底部按钮区域
            HStack(spacing: 16) {
                Button(action: {
                    action.sets.append(PlanSet())
                }) {
                    Text("新增一组")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primary)
                }
                .disabled(isDisabled)
                
                Spacer()
                
                Button(action: {
                    // TODO: 显示动作历史
                }) {
                    Text("动作历史")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primary)
                }
                .disabled(isDisabled)
                                
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - 单组行
    private func setRow(set: PlanSet, setNumber: Int, setIndex: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // 组数标号
                Text("\(setNumber)")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, height: 36, alignment: .center)
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(6)

                if action.isLeftRightMode {
                    // 左侧重量
                    Button(action: {
                        hideSystemKeyboard()
                        let inputId = "left_weight_\(action.id)_\(set.id)"
                        keyboardManager.showKeyboard(
                            inputId: inputId,
                            initialValue: set.leftWeight,
                            isInteger: false,
                            step: 1.0,
                            maxValue: 999.0
                        ) { newValue in
                            if setIndex < action.sets.count {
                                let safeValue = newValue.isNaN || newValue.isInfinite ? 0.0 : newValue
                                action.sets[setIndex].leftWeight = safeValue
                            }
                        }
                    }) {
                        let isActive = keyboardManager.activeInputId == "left_weight_\(action.id)_\(set.id)"
                        let isSelected = isActive && keyboardManager.isValueSelected
                        
                        Text({
                            let weight = set.leftWeight.isNaN || set.leftWeight.isInfinite ? 0.0 : set.leftWeight
                            return weight == 0 ? "0" : String(format: "%.1f", weight)
                        }())
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? .white : .black)
                            .frame(width: 60, height: 36)
                            .background(isSelected ? theme.primary : Color(UIColor.systemGroupedBackground))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isActive && !isSelected ? theme.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    .disabled(isDisabled)
                    
                    // 右侧重量
                    Button(action: {
                        hideSystemKeyboard()
                        let inputId = "right_weight_\(action.id)_\(set.id)"
                        keyboardManager.showKeyboard(
                            inputId: inputId,
                            initialValue: set.rightWeight,
                            isInteger: false,
                            step: 1.0,
                            maxValue: 999.0
                        ) { newValue in
                            if setIndex < action.sets.count {
                                let safeValue = newValue.isNaN || newValue.isInfinite ? 0.0 : newValue
                                action.sets[setIndex].rightWeight = safeValue
                            }
                        }
                    }) {
                        let isActive = keyboardManager.activeInputId == "right_weight_\(action.id)_\(set.id)"
                        let isSelected = isActive && keyboardManager.isValueSelected
                        
                        Text({
                            let weight = set.rightWeight.isNaN || set.rightWeight.isInfinite ? 0.0 : set.rightWeight
                            return weight == 0 ? "0" : String(format: "%.1f", weight)
                        }())
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? .white : .black)
                            .frame(width: 60, height: 36)
                            .background(isSelected ? theme.primary : Color(UIColor.systemGroupedBackground))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isActive && !isSelected ? theme.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    .disabled(isDisabled)
                } else {
                    // 普通重量
                    Button(action: {
                        hideSystemKeyboard()
                        let inputId = "weight_\(action.id)_\(set.id)"
                        keyboardManager.showKeyboard(
                            inputId: inputId,
                            initialValue: set.weight,
                            isInteger: false,
                            step: 1.0,
                            maxValue: 999.0
                        ) { newValue in
                        if setIndex < action.sets.count {
                            let safeValue = newValue.isNaN || newValue.isInfinite ? 0.0 : newValue
                            action.sets[setIndex].weight = safeValue
                        }
                    }
                    }) {
                        let isActive = keyboardManager.activeInputId == "weight_\(action.id)_\(set.id)"
                        let isSelected = isActive && keyboardManager.isValueSelected
                        
                        Text({
                            let weight = set.weight.isNaN || set.weight.isInfinite ? 0.0 : set.weight
                            return weight == 0 ? "0" : String(format: "%.1f", weight)
                        }())
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? .white : .black)
                            .frame(width: 60, height: 36)
                            .background(isSelected ? theme.primary : Color(UIColor.systemGroupedBackground))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isActive && !isSelected ? theme.primary : Color.clear, lineWidth: 2)
                        )
                    }
                    .disabled(isDisabled)
                }
                
                // 次数输入
                Button(action: {
                    hideSystemKeyboard()
                    let inputId = "reps_\(action.id)_\(set.id)"
                    keyboardManager.showKeyboard(
                        inputId: inputId,
                        initialValue: Double(set.reps),
                        isInteger: true,
                        step: 1.0,
                        maxValue: 999.0
                    ) { newValue in
                        if setIndex < action.sets.count {
                            let safeValue = newValue.isNaN || newValue.isInfinite ? 0.0 : newValue
                            action.sets[setIndex].reps = Int(safeValue)
                        }
                    }
                }) {
                    let isActive = keyboardManager.activeInputId == "reps_\(action.id)_\(set.id)"
                    let isSelected = isActive && keyboardManager.isValueSelected
                    
                    Text("\(set.reps)")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .white : .black)
                        .frame(width: 60, height: 36)
                        .background(isSelected ? theme.primary : Color(UIColor.systemGroupedBackground))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isActive && !isSelected ? theme.primary : Color.clear, lineWidth: 2)
                        )
                }
                .disabled(isDisabled)
                
                Spacer()
                
                // 组菜单
                Menu {
                    if set.hasNotes {
                        Button(action: {
                            if setIndex < action.sets.count {
                                action.sets[setIndex].hasNotes = false
                                action.sets[setIndex].notes = ""
                            }
                        }) {
                            Label("删除备注", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                    } else {
                        Button(action: {
                            if setIndex < action.sets.count {
                                action.sets[setIndex].hasNotes = true
                            }
                        }) {
                            Label("输入备注", systemImage: "note.text")
                        }
                    }
                    
                    Button(action: {
                        setToDelete = set
                        showDeleteSetAlert = true
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
            .padding(.leading, 20)
            .padding(.trailing, 16)
            
            // 备注输入框
            if set.hasNotes {
                HStack {
                    Spacer()
                        .frame(width: 42) // 对齐组数标号
                    
                    if setIndex < action.sets.count {
                        TextField("输入备注", text: $action.sets[setIndex].notes)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14))
                            .disabled(isDisabled)
                            .onTapGesture {
                                // 当点击备注输入框时，隐藏自定义键盘
                                if keyboardManager.isShowing {
                                    keyboardManager.cancelKeyboard()
                                }
                            }
                    }
                    
                    Spacer()
                        .frame(width: 42) // 对齐菜单按钮
                }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
    }
    
    /// 从本地bundle加载动作图片
    private func loadLocalActionImage(fileName: String) -> UIImage? {
        // 处理完整路径格式，例如：Images/abs/exercise_1.gif
        let cleanPath = fileName.replacingOccurrences(of: ".gif", with: "")
        
        // 尝试直接使用完整路径
        if let url = Bundle.main.url(forResource: cleanPath, withExtension: "gif"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
        
        // 备用方案：提取文件名
        let justFileName = URL(fileURLWithPath: fileName).lastPathComponent.replacingOccurrences(of: ".gif", with: "")
        
        // 尝试从不同的bundle路径加载图片
        let possiblePaths = [
            "Images/abs/\(justFileName)",
            "Images/pectorals/\(justFileName)",
            "Images/biceps/\(justFileName)",
            "Images/triceps/\(justFileName)",
            "Images/delts/\(justFileName)",
            "Images/lats/\(justFileName)",
            "Images/quads/\(justFileName)",
            "Images/hamstrings/\(justFileName)",
            "Images/glutes/\(justFileName)",
            "Images/calves/\(justFileName)",
            "Images/forearms/\(justFileName)",
            "Images/traps/\(justFileName)",
            "Images/cardiovascular system/\(justFileName)",
            "Images/spine/\(justFileName)",
            "Images/upper back/\(justFileName)",
            "Images/serratus anterior/\(justFileName)",
            "Images/levator scapulae/\(justFileName)",
            "Images/adductors/\(justFileName)",
            "Images/abductors/\(justFileName)",
            justFileName
        ]
        
        for path in possiblePaths {
            if let url = Bundle.main.url(forResource: path, withExtension: "gif"),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        
        return nil
    }
}

#Preview {
    CreatePlanView()
}

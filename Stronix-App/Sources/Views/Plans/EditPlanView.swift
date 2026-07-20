import SwiftUI
import UIKit

struct EditPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    let plan: TrainingPlan
    let onSaveSuccess: ((TrainingPlan?) -> Void)?
    
    @State private var planName: String
    @State private var planDescription: String
    @State private var difficulty: String
    @State private var isTemplate = false
    @State private var showActionSelect = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var preventDismiss = false
    @State private var savedPlan: TrainingPlan?
    
    // 编辑中的动作数据
    @State private var editingActions: [EditingAction] = []
    
    // 自定义键盘状态
    @StateObject private var keyboardManager = CustomKeyboardManager()
    
    // 隐藏系统键盘的方法
    private func hideSystemKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    init(plan: TrainingPlan, onSaveSuccess: ((TrainingPlan?) -> Void)? = nil) {
        self.plan = plan
        self.onSaveSuccess = onSaveSuccess
        self._planName = State(initialValue: plan.name)
        self._planDescription = State(initialValue: plan.description ?? "")
        self._difficulty = State(initialValue: plan.difficulty ?? "初级")
        
        // 初始化编辑中的动作数据
        let actions = plan.actions?.map { action in
            EditingAction(
                id: action.id,
                actionId: action.id,
                name: action.name,
                imageUrl: action.imageUrl,
                restTime: action.restTime,
                note: action.notes ?? "",
                recordBilateral: action.recordBilateral,
                isExpanded: false,
                sets: action.sets.enumerated().map { index, set in
                    EditingSet(
                        id: set.id,
                        order: index + 1,
                        weight: set.weight,
                        reps: set.reps,
                        leftWeight: set.leftWeight,
                        rightWeight: set.rightWeight
                    )
                }
            )
        } ?? []
        
        self._editingActions = State(initialValue: actions)
    }
    
    var totalVolume: Double {
        editingActions.reduce(0) { total, action in
            total + action.sets.reduce(0) { setTotal, set in
                if action.recordBilateral {
                    let leftWeight = set.leftWeight.isNaN || set.leftWeight.isInfinite ? 0.0 : set.leftWeight
                    let rightWeight = set.rightWeight.isNaN || set.rightWeight.isInfinite ? 0.0 : set.rightWeight
                    let volume = (leftWeight + rightWeight) * Double(set.reps)
                    return setTotal + (volume.isNaN || volume.isInfinite ? 0.0 : volume)
                } else {
                    let weight = set.weight.isNaN || set.weight.isInfinite ? 0.0 : set.weight
                    let volume = weight * Double(set.reps)
                    return setTotal + (volume.isNaN || volume.isInfinite ? 0.0 : volume)
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // 顶部信息栏 - 简化显示
                        HStack {
                            Text("容量: \(Int(totalVolume)) kg")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        // 计划名称
                        VStack(alignment: .leading, spacing: 8) {
                            Text("计划名称")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 16)
                            
                            TextField("输入计划名称", text: $planName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal, 16)
                                .disabled(isSaving)
                                .onTapGesture {
                                    // 当点击计划名称输入框时，隐藏自定义键盘
                                    if keyboardManager.isShowing {
                                        keyboardManager.cancelKeyboard()
                                    }
                                }
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
                                .disabled(isSaving)
                                .onTapGesture {
                                    // 当点击计划描述输入框时，隐藏自定义键盘
                                    if keyboardManager.isShowing {
                                        keyboardManager.cancelKeyboard()
                                    }
                                }
                        }
                        
                        // 训练动作标题
                        HStack {
                            Text("训练动作")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        // 训练动作列表
                        if !editingActions.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(editingActions, id: \.id) { action in
                                    EditingActionCardWrapper(
                                        action: action,
                                        editingActions: $editingActions,
                                        onDelete: {
                                            deleteAction(action)
                                        },
                                        onUpdate: { updatedAction in
                                            updateAction(updatedAction)
                                        },
                                        isDisabled: isSaving,
                                        keyboardManager: keyboardManager
                                    )
                                    .padding(.horizontal, 16)
                                }
                                
                                // 添加动作按钮
                                Button(action: {
                                    showActionSelect = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle")
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
                        } else {
                            // 空状态
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
            .navigationTitle("编辑训练计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        if !preventDismiss {
                            dismiss()
                        }
                    }
                    .foregroundColor(theme.secondary)
                    .disabled(isSaving || preventDismiss)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await savePlan()
                        }
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("保存")
                            }
                        }
                    }
                    .foregroundColor(theme.primary)
                    .fontWeight(.medium)
                    .disabled(isSaving || planName.isEmpty)
                }
            })
            .sheet(isPresented: $showActionSelect) {
                PlanActionSelectView(
                    onActionSelected: { selectedAction in
                        addAction(selectedAction)
                    },
                    existingActionIds: Set(editingActions.map { $0.actionId })
                )
            }
            .overlay(
                // 简化的Toast提示
                VStack {
                    Spacer()
                    if showToast {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.success)
                            Text(toastMessage)
                                .foregroundColor(theme.onSurface)
                        }
                        .padding()
                        .background(theme.surface.opacity(0.9))
                        .cornerRadius(12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 50)
                .animation(.easeInOut(duration: 0.3), value: showToast)
            )

        }
    }
    
    private func deleteAction(_ action: EditingAction) {
        // 立即删除，不使用动画，避免竞态条件
        editingActions.removeAll { $0.id == action.id }
    }
    
    private func updateAction(_ updatedAction: EditingAction) {
        if let index = editingActions.firstIndex(where: { $0.id == updatedAction.id }) {
            editingActions[index] = updatedAction
        }
    }
    
    private func addAction(_ action: ActionInfo) {
        let newAction = EditingAction(
            id: Int.random(in: 100000...999999),
            actionId: action.id,
            name: action.name,
            imageUrl: action.imageUrl,
            restTime: 60,
            note: "",
            recordBilateral: false,
            isExpanded: false,
            sets: [EditingSet(id: Int.random(in: 100000...999999), order: 1, weight: 10.0, reps: 12, leftWeight: 0.0, rightWeight: 0.0)]
        )
        editingActions.append(newAction)
    }
    
    private func savePlan() async {
        // 防止重复调用
        guard !isSaving else {
            print("⚠️ EditPlanView.savePlan() 正在保存中，跳过重复调用")
            return
        }
        
        print("🔄 EditPlanView.savePlan() 开始")
        print("🔄 EditPlanView.savePlan() 当前登录状态: \(LocalUserService.shared.isLoggedIn)")
        print("🔄 EditPlanView.savePlan() 当前用户: \(LocalUserService.shared.currentUser?.username ?? "无")")
        print("🔄 EditPlanView.savePlan() 当前用户ID: \(LocalUserService.shared.currentUser?.id ?? 0)")
        
        isSaving = true
        preventDismiss = true // 防止在保存过程中意外关闭
        
        let updateActions = editingActions.enumerated().map { index, action in
            UpdatePlanAction(
                action_id: action.actionId,
                order: index + 1,
                rest: action.restTime,
                note: action.note.isEmpty ? nil : action.note,
                record_bilateral: action.recordBilateral,
                sets: action.sets.enumerated().map { setIndex, set in
                    UpdatePlanSet(
                        order: setIndex + 1,
                        weight: action.recordBilateral ? nil : set.weight,
                        reps: set.reps,
                        left_weight: action.recordBilateral ? set.leftWeight : 0.0,
                        right_weight: action.recordBilateral ? set.rightWeight : 0.0
                    )
                }
            )
        }

        do {
            print("🔄 EditPlanView.savePlan() 调用API")
            // 使用PlanService，现在不会自动登出了
            let request = UpdatePlanRequest(
                name: planName,
                description: planDescription.isEmpty ? nil : planDescription,
                difficulty: plan.difficulty,
                duration: nil,
                actions: updateActions
            )
            
            print("🔄 EditPlanView.savePlan() 请求数据:")
            print("  - 计划ID: \(plan.id)")
            print("  - 计划名称: \(planName)")
            print("  - 计划描述: \(planDescription)")
            print("  - 计划难度: \(plan.difficulty ?? "无")")
            print("  - 动作数量: \(updateActions.count)")
            
            for (index, action) in updateActions.enumerated() {
                print("  - 动作\(index + 1): action_id=\(action.action_id), order=\(action.order), 组数=\(action.sets.count)")
                print("    休息时间: \(action.rest)秒, 双侧训练: \(action.record_bilateral)")
                for (setIndex, set) in action.sets.enumerated() {
                    if action.record_bilateral {
                        print("    组\(setIndex + 1): 左\(set.left_weight ?? 0)kg, 右\(set.right_weight ?? 0)kg, \(set.reps)次")
                    } else {
                        print("    组\(setIndex + 1): \(set.weight ?? 0)kg, \(set.reps)次")
                    }
                }
            }
            
            // 获取当前用户ID
            let currentUserId = LocalUserService.shared.currentUser?.id ?? 0
            try await LocalPlanService.shared.updatePlan(planId: plan.id, planData: request, user_id: currentUserId)
            
            print("🔄 EditPlanView.savePlan() API调用成功")
            isSaving = false
            
            // 保存成功后创建更新的计划对象
            await MainActor.run {
                print("🔄 EditPlanView.savePlan() 创建更新的计划对象")
                
                // 创建更新后的TrainingAction数组
                let updatedActions = editingActions.map { editingAction in
                    TrainingAction(
                        id: editingAction.actionId,
                        name: editingAction.name,
                        sets: editingAction.sets.map { editingSet in
                            TrainingSet(
                                id: editingSet.id,
                                weight: editingAction.recordBilateral ? 0 : editingSet.weight,
                                reps: editingSet.reps,
                                leftWeight: editingAction.recordBilateral ? editingSet.leftWeight : 0.0,
                                rightWeight: editingAction.recordBilateral ? editingSet.rightWeight : 0.0
                            )
                        },
                        restTime: editingAction.restTime,
                        notes: editingAction.note.isEmpty ? nil : editingAction.note,
                        recordBilateral: editingAction.recordBilateral,
                        imageUrl: editingAction.imageUrl
                    )
                }
                
                // 创建更新后的计划对象
                savedPlan = TrainingPlan(
                    id: plan.id,
                    name: planName,
                    creator: plan.creator,
                    createdDate: plan.createdDate,
                    lastTraining: plan.lastTraining,
                    volume: Int(totalVolume),
                    description: planDescription.isEmpty ? nil : planDescription,
                    isTemplate: plan.isTemplate,
                    templateId: plan.templateId,
                    difficulty: plan.difficulty,
                    duration: plan.duration,
                    actions: updatedActions
                )
                
                // 显示简单的成功提示
                toastMessage = "保存成功！"
                showToast = true
                preventDismiss = false
                
                // 1秒后自动触发 onSaveSuccess 回调
                // onSaveSuccess 将负责关闭当前视图并刷新数据
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showToast = false
                    // 调用回调，让父视图处理关闭和后续逻辑
                    onSaveSuccess?(savedPlan)
                    // 注意：此处不再直接 dismiss() 或 showPlanDetail = true，
                    // 这些逻辑将由调用方（PlanListView）在 onSaveSuccess 中处理
                }
            }
            
        } catch {
            print("🔄 EditPlanView.savePlan() 保存失败: \(error.localizedDescription)")
            print("🔄 EditPlanView.savePlan() 错误类型: \(type(of: error))")
            if let localError = error as? LocalPlanError {
                print("🔄 EditPlanView.savePlan() Local错误: \(localError)")
                if case .unauthorized = localError {
                    print("🔄 EditPlanView.savePlan() 认证失败")
                    await MainActor.run {
                        toastMessage = "登录已过期，请重新登录后再保存"
                        showToast = true
                        preventDismiss = false
                    }
                } else {
                    await MainActor.run {
                        toastMessage = "保存失败: \(localError.message)"
                        showToast = true
                        preventDismiss = false
                    }
                }
            } else {
                await MainActor.run {
                    toastMessage = "保存失败: \(error.localizedDescription)"
                    showToast = true
                    preventDismiss = false
                }
            }
            isSaving = false
        }
    }
}

// MARK: - 编辑中的数据模型

struct EditingAction: Identifiable {
    let id: Int
    let actionId: Int
    let name: String
    let imageUrl: String
    var restTime: Int
    var note: String
    var recordBilateral: Bool
    var isExpanded: Bool
    var sets: [EditingSet]
}

struct EditingSet: Identifiable {
    let id: Int
    let order: Int
    var weight: Double
    var reps: Int
    var leftWeight: Double
    var rightWeight: Double
}

// MARK: - 编辑动作卡片包装器

struct EditingActionCardWrapper: View {
    let action: EditingAction
    @Binding var editingActions: [EditingAction]
    let onDelete: () -> Void
    let onUpdate: (EditingAction) -> Void
    let isDisabled: Bool
    let keyboardManager: CustomKeyboardManager
    
    private var actionBinding: Binding<EditingAction> {
        Binding(
            get: {
                editingActions.first { $0.id == action.id } ?? action
            },
            set: { newValue in
                if let index = editingActions.firstIndex(where: { $0.id == action.id }) {
                    editingActions[index] = newValue
                }
            }
        )
    }
    
    var body: some View {
        EditingActionCard(
            action: actionBinding,
            onDelete: onDelete,
            onUpdate: onUpdate,
            isDisabled: isDisabled,
            keyboardManager: keyboardManager
        )
    }
}

// MARK: - 编辑动作卡片

struct EditingActionCard: View {
    @Environment(\.theme) private var theme: AppTheme
    @Binding var action: EditingAction
    let onDelete: () -> Void
    let onUpdate: (EditingAction) -> Void
    let isDisabled: Bool
    let keyboardManager: CustomKeyboardManager
    
    @State private var showDeleteAlert = false
    @State private var showRestTimer = false
    @State private var minutes: Int = 1
    @State private var seconds: Int = 0
    @State private var showActionDetail = false
    
    var actionVolume: Double {
        action.sets.reduce(0) { total, set in
            if action.recordBilateral {
                let leftWeight = set.leftWeight.isNaN || set.leftWeight.isInfinite ? 0.0 : set.leftWeight
                let rightWeight = set.rightWeight.isNaN || set.rightWeight.isInfinite ? 0.0 : set.rightWeight
                let volume = (leftWeight + rightWeight) * Double(set.reps)
                return total + (volume.isNaN || volume.isInfinite ? 0.0 : volume)
            } else {
                let weight = set.weight.isNaN || set.weight.isInfinite ? 0.0 : set.weight
                let volume = weight * Double(set.reps)
                return total + (volume.isNaN || volume.isInfinite ? 0.0 : volume)
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
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: theme.onBackground.opacity(0.05), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showRestTimer) {
            restTimerSettingSheet
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("确定要删除这个训练动作吗？")
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showRestTimer = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        action.restTime = minutes * 60 + seconds
                        onUpdate(action)
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
                // 动作图片 - 从本地bundle加载
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
                .frame(width: 50, height: 50)
                .background(theme.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // 动作信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(action.name)
                            .font(.system(size: 16, weight: .medium))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // 容量显示
                        Text("\(Int(actionVolume))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.secondary)
                    }
                    
                    HStack {
                        Text("\(action.sets.count)组")
                    .font(.system(size: 16))
                            .foregroundColor(theme.secondary)
                        
                        Spacer()
                        
                        // 左右模式开关
                        Toggle(isOn: $action.recordBilateral) {
                            Text("记录左右")
                                .font(.system(size: 12))
                                .foregroundColor(theme.secondary)
                        }
                        .tint(theme.primary)
                        .scaleEffect(0.8)
                        .disabled(isDisabled)
                        .onChange(of: action.recordBilateral) { oldValue, newValue in
                            // 切换模式时清空重量数据 - 创建新的sets数组
                            var updatedSets = action.sets
                            for i in updatedSets.indices {
                                if newValue {
                                    // 切换到左右模式，清空普通重量
                                    updatedSets[i].weight = 0.0
                                } else {
                                    // 切换到普通模式，清空左右重量
                                    updatedSets[i].leftWeight = 0.0
                                    updatedSets[i].rightWeight = 0.0
                                }
                            }
                            action.sets = updatedSets
                            onUpdate(action)
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
                    
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Label("删除动作", systemImage: "trash")
                    }
                    .foregroundColor(theme.error)
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

                if action.recordBilateral {
                    Text("左kg")
                        .frame(width: 60, height: 36, alignment: .center)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .background(theme.surface)
                        .cornerRadius(6)
                    
                    Text("右kg")
                        .frame(width: 60, height: 36, alignment: .center)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .background(theme.surface)
                        .cornerRadius(6)
                } else {
                    Text("kg")
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
            ForEach(action.sets, id: \.id) { set in
                if let index = action.sets.firstIndex(where: { $0.id == set.id }) {
                    setRow(index: index)
                }
            }
            
            // 底部按钮区域
            HStack(spacing: 16) {
                Button(action: {
                    action.sets.append(EditingSet(
                        id: Int.random(in: 100000...999999),
                        order: action.sets.count + 1,
                        weight: 10.0,
                        reps: 12,
                        leftWeight: 0.0,
                        rightWeight: 0.0
                    ))
                    onUpdate(action)
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
    
    // 隐藏系统键盘的方法
    private func hideSystemKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - 单组行
    private func setRow(index: Int) -> some View {
        // 边界检查，确保索引有效
        guard index < action.sets.count else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                // 组数标号
                Text("\(index + 1)")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, height: 36, alignment: .center)
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(6)
                
                if action.recordBilateral {
                    // 左侧重量
                    Button(action: {
                        hideSystemKeyboard()
                        let inputId = "left_weight_\(action.id)_\(index)"
                        keyboardManager.showKeyboard(
                            inputId: inputId,
                            initialValue: action.sets[index].leftWeight,
                            isInteger: false,
                            step: 1.0,
                            maxValue: 999.0
                        ) { newValue in
                            let safeValue = newValue.isNaN || newValue.isInfinite ? 0.0 : newValue
                            action.sets[index].leftWeight = safeValue
                            onUpdate(action)
                        }
                    }) {
                        let isActive = keyboardManager.activeInputId == "left_weight_\(action.id)_\(index)"
                        let isSelected = isActive && keyboardManager.isValueSelected
                        
                        Text({
                            let weight = action.sets[index].leftWeight.isNaN || action.sets[index].leftWeight.isInfinite ? 0.0 : action.sets[index].leftWeight
                            return weight == 0 ? "0" : String(format: "%.1f", weight)
                        }())
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? .white : .black)
                            .frame(width: 60, height: 36)
                            .background(isSelected ? theme.primary : Color(UIColor.systemGray6))
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
                        let inputId = "right_weight_\(action.id)_\(index)"
                        keyboardManager.showKeyboard(
                            inputId: inputId,
                            initialValue: action.sets[index].rightWeight,
                            isInteger: false,
                            step: 1.0,
                            maxValue: 999.0
                        ) { newValue in
                            let safeValue = newValue.isNaN || newValue.isInfinite ? 0.0 : newValue
                            action.sets[index].rightWeight = safeValue
                            onUpdate(action)
                        }
                    }) {
                        let isActive = keyboardManager.activeInputId == "right_weight_\(action.id)_\(index)"
                        let isSelected = isActive && keyboardManager.isValueSelected
                        
                        Text({
                            let weight = action.sets[index].rightWeight.isNaN || action.sets[index].rightWeight.isInfinite ? 0.0 : action.sets[index].rightWeight
                            return weight == 0 ? "0" : String(format: "%.1f", weight)
                        }())
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? .white : .black)
                            .frame(width: 60, height: 36)
                            .background(isSelected ? theme.primary : Color(UIColor.systemGray6))
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
                        let inputId = "weight_\(action.id)_\(index)"
                        keyboardManager.showKeyboard(
                            inputId: inputId,
                            initialValue: action.sets[index].weight,
                            isInteger: false,
                            step: 1.0,
                            maxValue: 999.0
                        ) { newValue in
                            let safeValue = newValue.isNaN || newValue.isInfinite ? 0.0 : newValue
                            action.sets[index].weight = safeValue
                            onUpdate(action)
                        }
                    }) {
                        let isActive = keyboardManager.activeInputId == "weight_\(action.id)_\(index)"
                        let isSelected = isActive && keyboardManager.isValueSelected
                        
                        Text({
                            let weight = action.sets[index].weight.isNaN || action.sets[index].weight.isInfinite ? 0.0 : action.sets[index].weight
                            return weight == 0 ? "0" : String(format: "%.1f", weight)
                        }())
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? .white : .black)
                            .frame(width: 60, height: 36)
                            .background(isSelected ? theme.primary : Color(UIColor.systemGray6))
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
                    let inputId = "reps_\(action.id)_\(index)"
                    keyboardManager.showKeyboard(
                        inputId: inputId,
                        initialValue: Double(action.sets[index].reps),
                        isInteger: true,
                        step: 1.0,
                        maxValue: 999.0
                    ) { newValue in
                        let safeValue = newValue.isNaN || newValue.isInfinite ? 0.0 : newValue
                        action.sets[index].reps = Int(safeValue)
                        onUpdate(action)
                    }
                }) {
                    let isActive = keyboardManager.activeInputId == "reps_\(action.id)_\(index)"
                    let isSelected = isActive && keyboardManager.isValueSelected
                    
                    Text("\(action.sets[index].reps)")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .white : .black)
                        .frame(width: 60, height: 36)
                        .background(isSelected ? theme.primary : Color(UIColor.systemGray6))
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
                    Button(action: {
                        // 使用当前组的ID来安全删除
                        if index < action.sets.count {
                            let setId = action.sets[index].id
                            action.sets.removeAll { $0.id == setId }
                            onUpdate(action)
                        }
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
            .padding(.leading, 40)
            .padding(.trailing, 16)
        }
        )
    }
}

#Preview {
    // 预览代码暂时注释，等待类型定义完成
    Text("EditPlanView Preview")
}

// MARK: - 辅助函数
private func extractImageFileName(from fullPath: String) -> String {
    // 从完整路径中提取文件名
    // 例如: "backend/static/images/actions/exercise_1.gif" -> "exercise_1.gif"
    return URL(fileURLWithPath: fullPath).lastPathComponent
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
    
    print("⚠️ 无法加载图片: \(fileName)")
    return nil
}

 

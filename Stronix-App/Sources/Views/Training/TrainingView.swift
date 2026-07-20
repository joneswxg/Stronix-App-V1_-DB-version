import SwiftUI
import UIKit

// MARK: - 可变的训练数据模型已移动到 MutableTrainingModels.swift

struct TrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    let plan: TrainingPlan
    @ObservedObject var viewModel: PlanViewModel
    @ObservedObject private var trainingManager = TrainingSessionManager.shared
    @ObservedObject private var trainingHistoryService = TrainingHistoryService.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    @State private var showActionSelect = false
    @State private var showCancelAlert = false
    @State private var showCompleteAlert = false
    @State private var showPlanUpdateAlert = false
    @State private var isCompleting = false
    @State private var completionError: String?
    @State private var showCompletionError = false
    @State private var showActionHistory = false
    @State private var selectedActionForHistory: (id: Int, name: String)?
    
    // 计时器状态现在由TrainingSessionManager管理
    
    // 计划是否有变动
    @State private var planHasChanges = false
    
    // 自定义键盘状态
    @StateObject private var keyboardManager = CustomKeyboardManager()
    
    init(plan: TrainingPlan, viewModel: PlanViewModel) {
        self.plan = plan
        self.viewModel = viewModel
    }
    
    // 隐藏系统键盘的方法
    private func hideSystemKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                VStack(spacing: 8) {
                    topInfoBar
                    planNameSection

                    if !trainingManager.editingActions.isEmpty {
                        actionListContent
                    } else {
                        emptyActionListContent
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: keyboardManager.isShowing ? -110 : 0) // 键盘出现时上移
                .animation(.easeInOut(duration: 0.3), value: keyboardManager.isShowing)
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onChange(of: keyboardManager.isShowing) { _, isShowing in
                        if !isShowing {
                            hideSystemKeyboard()
                        }
                    }
                }
            }
        }
        .navigationTitle("训练中")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            trainingViewToolbar
        }
        .sheet(isPresented: $showActionSelect) {
            PlanActionSelectView { selectedAction in
                addAction(selectedAction)
            }
        }
        .sheet(isPresented: $showActionHistory) {
            if let selectedAction = selectedActionForHistory {
                ActionHistoryView(
                    actionId: selectedAction.id,
                    actionName: selectedAction.name
                )
            }
        }
        .overlay(restTimerOverlay)
        .alert("确认取消锻炼", isPresented: $showCancelAlert) {
            Button("恢复", role: .cancel) { }
            Button("取消锻炼", role: .destructive) {
                trainingManager.stopTraining()
                dismiss()
            }
        } message: {
            Text("确信需要取消这次锻炼？所有进度都将丢失。")
        }
        .alert("完成训练", isPresented: $showCompleteAlert) {
            Button("取消", role: .cancel) { }
            Button("确定") {
                // 只检查计划是否有变动，不保存训练历史
                checkPlanChangesAndProceed()
            }
        } message: {
            Text("确认完成本次训练？")
        }
        .alert("更新训练计划", isPresented: $showPlanUpdateAlert) {
            Button("不更新", role: .cancel) {
                Task {
                    await saveTrainingHistoryOnly()
                }
            }
            Button("更新") {
                Task {
                    await updatePlanFromTraining()
                }
            }
        } message: {
            Text("检测到训练计划有变动，是否更新训练计划？")
        }
        .alert("完成训练失败", isPresented: $showCompletionError) {
            Button("确定") {
                completionError = nil
            }
        } message: {
            Text(completionError ?? "未知错误")
        }
        .onAppear {
            // 确保训练状态已经开始
            if !trainingManager.isTrainingActive {
                trainingManager.startTraining(with: plan)
            }
        }
    }
    
    // MARK: - 训练相关方法
    
    private func handleComplete() {
        print("🔍 handleComplete() 被调用")
        showCompleteAlert = true
        print("🔍 showCompleteAlert 设置为 true")
    }
    
    private func updatePlanFromTraining() async {
        isCompleting = true
        
        do {
            // 1. 保存训练历史
            if let trainingHistoryData = trainingManager.prepareTrainingHistoryData() {
                let response = try await TrainingHistoryService.shared.saveTrainingHistory(trainingHistoryData)
                print("✅ 训练历史保存成功，ID: \(response.history_id)")
            }
            
            // 2. 更新训练计划
            if let planUpdateData = trainingManager.preparePlanUpdateData() {
                try await TrainingHistoryService.shared.updatePlanFromTraining(
                    planId: plan.id,
                    request: planUpdateData
                )
                print("✅ 训练计划更新成功")
            }
            
            isCompleting = false
            finishTrainingAndDismiss()
            
        } catch {
            isCompleting = false
            completionError = "更新训练计划失败: \(error.localizedDescription)"
            showCompletionError = true
            print("❌ 更新训练计划失败: \(error)")
        }
    }
    
    private func finishTrainingAndDismiss() {
        trainingManager.completeTraining()
        dismiss()
    }
    
    // MARK: - 动作管理方法
    
    private func deleteAction(_ action: MutableTrainingAction) {
        // 使用更安全的删除方式，通过ID匹配而不是索引
        trainingManager.editingActions.removeAll { $0.id == action.id }
        
        // 清理相关的状态数据
        let actionIdString = String(action.id)
        
        // 清理 completedSets (Set)
        trainingManager.completedSets = trainingManager.completedSets.filter { setId in
            !setId.hasPrefix("\(actionIdString)_")
        }
        
        // 清理 setNotes (Dictionary)
        trainingManager.setNotes = trainingManager.setNotes.filter { key, _ in
            !key.hasPrefix("\(actionIdString)_")
        }
        
        // 清理 setRestTimers (Dictionary)
        trainingManager.setRestTimers = trainingManager.setRestTimers.filter { key, _ in
            !key.hasPrefix("\(actionIdString)_")
        }
        
        // 清理 setTimers (Dictionary)
        for setId in trainingManager.setRestTimers.keys {
            if setId.hasPrefix("\(actionIdString)_") {
                trainingManager.invalidateSetTimer(setId: setId)
            }
        }
        
        planHasChanges = true
    }
    
    private func updateAction(_ updatedAction: MutableTrainingAction) {
        if let index = trainingManager.editingActions.firstIndex(where: { $0.id == updatedAction.id }) {
            trainingManager.editingActions[index] = updatedAction
        }
        planHasChanges = true
    }
    
    private func addAction(_ action: ActionInfo) {
        let newAction = MutableTrainingAction(
            id: action.id,
            name: action.name,
            imageUrl: action.imageUrl,
            sets: [MutableTrainingSet(id: Int.random(in: 100000...999999), weight: 10.0, reps: 12)],
            restTime: 60,
            recordBilateral: false
        )
        trainingManager.editingActions.append(newAction)
        planHasChanges = true
    }
    
    // MARK: - 组休息计时器方法
    
    private func handleSetCompleted(setId: String, restTime: Int) {
        trainingManager.handleSetCompleted(setId: setId, restTime: restTime)
    }

    private func handleRestTimerTapped(setId: String, restTime: Int) {
        trainingManager.handleRestTimerTapped(setId: setId, restTime: restTime)
    }
    
    // Timer-related methods moved to TrainingSessionManager
    
    private func checkPlanChangesAndProceed() {
        // 只检查计划是否有变动，不保存训练历史
        planHasChanges = trainingManager.hasChangesFromOriginalPlan()
        print("🔍 planHasChanges = \(planHasChanges)")
        
        if planHasChanges {
            print("🔍 显示计划更新对话框")
            showPlanUpdateAlert = true
        } else {
            print("🔍 直接完成训练")
            Task {
                await saveTrainingHistoryOnly()
            }
        }
    }
    
    private func saveTrainingHistoryOnly() async {
        isCompleting = true
        
        do {
            // 只保存训练历史，不更新计划
            if let trainingHistoryData = trainingManager.prepareTrainingHistoryData() {
                let response = try await TrainingHistoryService.shared.saveTrainingHistory(trainingHistoryData)
                print("✅ 训练历史保存成功，ID: \(response.history_id)")
            }
            
            isCompleting = false
            finishTrainingAndDismiss()
            
        } catch {
            isCompleting = false
            completionError = "保存训练记录失败: \(error.localizedDescription)"
            showCompletionError = true
            print("❌ 保存训练历史失败: \(error)")
        }
    }
    
    // MARK: - 视图拆分
    private var topInfoBar: some View {
        HStack {
            Text("\(Int(trainingManager.completedVolume()))/\(Int(trainingManager.totalVolume())) kg")
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            Text(trainingManager.formattedTrainingTime())
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.primary)
        }
        .padding(12)
        .background(theme.surface)
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    private var planNameSection: some View {
        HStack {
            Text(trainingManager.planName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.onSurface)
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }





    private var actionListContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(trainingManager.editingActions.enumerated()), id: \.element.id) { index, action in
                    let canDeleteAction = trainingManager.editingActions.count > 1

                    TrainingActionCardWrapper(
                        action: action,
                        editingActions: $trainingManager.editingActions,
                        completedSets: $trainingManager.completedSets,
                        setNotes: $trainingManager.setNotes,
                        showNoteInput: .constant(Set<String>()),
                        setRestTimers: $trainingManager.setRestTimers,
                        onDelete: {
                            if canDeleteAction {
                                deleteAction(action)
                            }
                        },
                        onUpdate: { updatedAction in
                            updateAction(updatedAction)
                        },
                        onSetCompleted: { setId, restTime in
                            handleSetCompleted(setId: setId, restTime: restTime)
                        },
                        onRestTimerTapped: { setId, restTime in
                            handleRestTimerTapped(setId: setId, restTime: restTime)
                        },
                        onShowActionHistory: { actionId, actionName in
                            selectedActionForHistory = (id: actionId, name: actionName)
                            showActionHistory = true
                        },
                        canDelete: canDeleteAction,
                        keyboardManager: keyboardManager
                    )
                    .padding(.horizontal, 16)
                }

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
                    .background(theme.background)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 10)
            }
        }
    }

    private var emptyActionListContent: some View {
        VStack {
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
                .background(theme.background)
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private var trainingViewToolbar: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消锻炼") {
                    showCancelAlert = true
                }
                .foregroundColor(theme.error)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    handleComplete()
                }) {
                    HStack {
                        if isCompleting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("完成")
                        }
                    }
                }
                .foregroundColor(theme.primary)
                .fontWeight(.medium)
                .disabled(isCompleting)
            }
        }
    }

    private var restTimerOverlay: some View {
        Group {
            if trainingManager.showRestTimer {
                RestTimerOverlay(
                    restTime: $trainingManager.currentRestTime,
                    isRunning: !trainingManager.isRestTimerPaused,
                    onPause: {
                        trainingManager.toggleRestTimer()
                    },
                    onReset: {
                        trainingManager.resetRestTimer()
                    },
                    onSkip: {
                        trainingManager.skipRestTimer()
                    },
                    onClose: {
                        trainingManager.closeRestTimer()
                    },
                    onAddTime: {
                        trainingManager.addRestTime(10)
                    },
                    onSubtractTime: {
                        trainingManager.subtractRestTime(10)
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(), value: trainingManager.showRestTimer)
            }
        }
    }
}

// MARK: - 训练动作卡片包装器

struct TrainingActionCardWrapper: View {
    let action: MutableTrainingAction
    @Binding var editingActions: [MutableTrainingAction]
    @Binding var completedSets: Set<String>
    @Binding var setNotes: [String: String]
    @Binding var showNoteInput: Set<String>
    @Binding var setRestTimers: [String: Int]
    let onDelete: () -> Void
    let onUpdate: (MutableTrainingAction) -> Void
    let onSetCompleted: (String, Int) -> Void
    let onRestTimerTapped: (String, Int) -> Void
    let onShowActionHistory: (Int, String) -> Void
    let canDelete: Bool
    let keyboardManager: CustomKeyboardManager
    
    private var actionBinding: Binding<MutableTrainingAction> {
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
        TrainingActionCard(
            action: actionBinding,
            completedSets: $completedSets,
            setNotes: $setNotes,
            showNoteInput: $showNoteInput,
            setRestTimers: $setRestTimers,
            onDelete: onDelete,
            onUpdate: onUpdate,
            onSetCompleted: onSetCompleted,
            onRestTimerTapped: onRestTimerTapped,
            onShowActionHistory: onShowActionHistory,
            canDelete: canDelete,
            keyboardManager: keyboardManager
        )
    }
}

// MARK: - 训练动作卡片

struct TrainingActionCard: View {
    @Environment(\.theme) private var theme
    @Binding var action: MutableTrainingAction
    @Binding var completedSets: Set<String>
    @Binding var setNotes: [String: String]
    @Binding var showNoteInput: Set<String>
    @Binding var setRestTimers: [String: Int]
    let onDelete: () -> Void
    let onUpdate: (MutableTrainingAction) -> Void
    let onSetCompleted: (String, Int) -> Void
    let onRestTimerTapped: (String, Int) -> Void
    let onShowActionHistory: (Int, String) -> Void
    let canDelete: Bool
    let keyboardManager: CustomKeyboardManager
    
    @State private var showDeleteAlert = false
    @State private var showRestTimer = false
    @State private var minutes: Int = 1
    @State private var seconds: Int = 0
    @State private var isExpanded: Bool = true
    
    var actionVolume: Double {
        action.sets.reduce(0) { total, set in
            let setId = "\(action.id)_\(set.id)"
            if completedSets.contains(setId) {
                if action.recordBilateral {
                    return total + ((set.leftWeight + set.rightWeight) * Double(set.reps))
                } else {
                    return total + (set.weight * Double(set.reps))
                }
            }
            return total
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 动作头部
            actionHeader
            
            // 组数详情
            if isExpanded {
                setsSection
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
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
            .toolbar(content: {
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
            })
            }
            .padding(.leading, 4)
            .padding(.trailing, 4)
    }
    
    // MARK: - 动作头部
    private var actionHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                 // 动作图片 - 使用本地图片加载
                Group {
                    if let image = loadLocalActionImage(fileName: extractImageFilename(from: action.imageUrl)) {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .foregroundColor(theme.secondary)
                            )
                    }
                }
                .frame(width: 50, height: 50)
                .background(Color.gray.opacity(0.1))
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
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondary)
                        
                        Spacer()
                        
                        // 左右模式开关
                        HStack(spacing: 4) {
                            Text("记录左右")
                                .font(.system(size: 14))
                                .foregroundColor(theme.secondary)
                            Toggle("", isOn: $action.recordBilateral)
                                .scaleEffect(0.8)
                                .tint(theme.primary)
                        }
                        .onChange(of: action.recordBilateral) { oldValue, newValue in
                            // 切换模式时清空重量数据 - 使用更安全的方式
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
                        minutes = action.restTime / 60
                        seconds = action.restTime % 60
                        showRestTimer = true
                    }) {
                        Label("设置休息计时器", systemImage: "timer")
                    }
                    
                    if canDelete {
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            Label("删除动作", systemImage: "trash")
                        }
                        .foregroundColor(theme.error)
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(theme.primary)
                        .font(.system(size: 20))
                }
            }
            
            // 表头
            if isExpanded {
                Divider()
                    .padding(.vertical, 4)
                
                tableHeader
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
    
    // 表头组件
    private var tableHeader: some View {
        HStack(spacing: action.recordBilateral ? 3 : 6) {
            Text("组")
                .frame(width: 30, height: 36, alignment: .center)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.secondary)

            if action.recordBilateral {
                Text("左kg")
                    .frame(width: 50, height: 36, alignment: .center)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.secondary)
                
                Text("右kg")
                    .frame(width: 50, height: 36, alignment: .center)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.secondary)
            } else {
                Text("kg")
                    .frame(width: 50, height: 36, alignment: .center)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.secondary)
            }

            Text("次数")
                .frame(width: 50, height: 36, alignment: .center)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.secondary)

            Text("完成")
                .frame(width: 50, height: 36, alignment: .center)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.secondary)

            Text("休息")
                .frame(width: 60, height: 36, alignment: .center)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.secondary)

            Spacer()
        }
        .padding(.leading, 0)
        .padding(.trailing, 16)
    }
    
    // MARK: - 组数区域
    private var setsSection: some View {
        VStack(spacing: 8) {
            // 组数列表 - 修复索引越界问题
            ForEach(Array(action.sets.enumerated()), id: \.element.id) { index, set in
                VStack(spacing: 8) {
                    setRow(index: index)
                    
                    // 备注输入框 - 使用安全的set对象
                    let setId = "\(action.id)_\(set.id)"
                    if showNoteInput.contains(setId) {
                        TextField("输入备注...", text: Binding(
                            get: { setNotes[setId] ?? "" },
                            set: { setNotes[setId] = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
            }
            
            // 底部按钮区域
            HStack(spacing: 16) {
                Button(action: {
                    action.sets.append(MutableTrainingSet(
                        id: Int.random(in: 100000...999999),
                        weight: 10.0,
                        reps: 12
                    ))
                    onUpdate(action)
                }) {
                    Text("新增一组")
                        .font(.system(size: 16))
                        .foregroundColor(theme.primary)
                }
                
                Spacer()
                
                Button(action: {
                    onShowActionHistory(action.id, action.name)
                }) {
                    Text("动作历史")
                        .font(.system(size: 16))
                        .foregroundColor(theme.primary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - 单组行
    @ViewBuilder
    private func setRow(index: Int) -> some View {
        // 边界检查，确保索引有效
        if index < action.sets.count {
            let currentSet = action.sets[index] // 安全地获取当前组的引用
            let setId = "\(action.id)_\(currentSet.id)"
            let isCompleted = completedSets.contains(setId)
            let restTimeRemaining = setRestTimers[setId]
            
            HStack(spacing: action.recordBilateral ? 3 : 6) {
                // 组数标号
                Text("\(index + 1)")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, height: 36, alignment: .center)
                    .foregroundColor(isCompleted ? theme.onPrimary : theme.onSurface)
                    .background(isCompleted ? theme.primary : Color.clear)
                    .cornerRadius(6)
                
                if action.recordBilateral {
                    // 左侧重量
                    Button(action: {
                        hideSystemKeyboard()
                        let inputId = "left_weight_\(action.id)_\(index)"
                        keyboardManager.showKeyboard(
                            inputId: inputId,
                            initialValue: currentSet.leftWeight,
                            isInteger: false,
                            step: 1.0,
                            maxValue: 999.0
                        ) { newValue in
                            if index < action.sets.count {
                                action.sets[index].leftWeight = newValue
                                onUpdate(action)
                            }
                        }
                    }) {
                        let isActive = keyboardManager.activeInputId == "left_weight_\(action.id)_\(index)"
                        let isSelected = isActive && keyboardManager.isValueSelected
                        
                        Text(currentSet.leftWeight == 0 ? "0" : String(format: "%.1f", currentSet.leftWeight))
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? theme.onPrimary : (isCompleted ? theme.onPrimary : theme.onSurface))
                            .frame(width: 50, height: 36)
                            .background(isSelected ? theme.primary : (isCompleted ? theme.primary : theme.background))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isActive && !isSelected ? theme.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    
                    // 右侧重量
                    Button(action: {
                        hideSystemKeyboard()
                        let inputId = "right_weight_\(action.id)_\(index)"
                        keyboardManager.showKeyboard(
                            inputId: inputId,
                            initialValue: currentSet.rightWeight,
                            isInteger: false,
                            step: 1.0,
                            maxValue: 999.0
                        ) { newValue in
                            if index < action.sets.count {
                                action.sets[index].rightWeight = newValue
                                onUpdate(action)
                            }
                        }
                    }) {
                        let isActive = keyboardManager.activeInputId == "right_weight_\(action.id)_\(index)"
                        let isSelected = isActive && keyboardManager.isValueSelected
                        
                        Text(currentSet.rightWeight == 0 ? "0" : String(format: "%.1f", currentSet.rightWeight))
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? theme.onPrimary : (isCompleted ? theme.onPrimary : theme.onSurface))
                             .frame(width: 50, height: 36)
                             .background(isSelected ? theme.primary : (isCompleted ? theme.primary : theme.background))
                             .cornerRadius(6)
                             .overlay(
                                 RoundedRectangle(cornerRadius: 6)
                                     .stroke(isActive && !isSelected ? theme.primary : Color.clear, lineWidth: 2)
                             )
                    }
                } else {
                    // 普通重量
                    Button(action: {
                        hideSystemKeyboard()
                        let inputId = "weight_\(action.id)_\(index)"
                        keyboardManager.showKeyboard(
                            inputId: inputId,
                            initialValue: currentSet.weight,
                            isInteger: false,
                            step: 1.0,
                            maxValue: 999.0
                        ) { newValue in
                            if index < action.sets.count {
                                action.sets[index].weight = newValue
                                onUpdate(action)
                            }
                        }
                    }) {
                        let isActive = keyboardManager.activeInputId == "weight_\(action.id)_\(index)"
                        let isSelected = isActive && keyboardManager.isValueSelected
                        
                        Text(currentSet.weight == 0 ? "0" : String(format: "%.1f", currentSet.weight))
                            .font(.system(size: 16))        
                            .foregroundColor(isSelected ? theme.onPrimary : (isCompleted ? theme.onPrimary : theme.onSurface))
                            .frame(width: 50, height: 36)
                            .background(isSelected ? theme.primary : (isCompleted ? theme.primary : theme.background))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isActive && !isSelected ? theme.primary : Color.clear, lineWidth: 2)
                            )
                    }
                }
                
                // 次数输入
                Button(action: {
                    hideSystemKeyboard()
                    let inputId = "reps_\(action.id)_\(index)"
                    keyboardManager.showKeyboard(
                        inputId: inputId,
                        initialValue: Double(currentSet.reps),
                        isInteger: true,
                        step: 1.0,
                        maxValue: 999.0
                    ) { newValue in
                        if index < action.sets.count {
                            action.sets[index].reps = Int(newValue)
                            onUpdate(action)
                        }
                    }
                }) {
                    let isActive = keyboardManager.activeInputId == "reps_\(action.id)_\(index)"
                    let isSelected = isActive && keyboardManager.isValueSelected
                    
                    Text("\(currentSet.reps)")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? theme.onPrimary : (isCompleted ? theme.onPrimary : theme.onSurface))
                        .frame(width: 50, height: 36)
                        .background(isSelected ? theme.primary : (isCompleted ? theme.primary : theme.background))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isActive && !isSelected ? theme.primary : Color.clear, lineWidth: 2)
                        )
                }
                
                // 打勾框
                Button(action: {
                    if isCompleted {
                        completedSets.remove(setId)
                    } else {
                        completedSets.insert(setId)
                        // 开始倒计时，但不弹出浮动窗口
                        onSetCompleted(setId, action.restTime)
                    }
                }) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? theme.primary : theme.secondary)
                        .font(.system(size: 20))
                }
                .frame(width: 50, alignment: .center)
                
                // 休息时间显示/倒计时框
                Button(action: {
                    // 点击倒计时框才弹出编辑窗口
                    onRestTimerTapped(setId, action.restTime)
                }) {
                    if let remainingTime = restTimeRemaining, remainingTime > 0 {
                        // 显示倒计时
                        Text(formatRestTime(remainingTime))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.onPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.primary)
                            .cornerRadius(8)
                    } else {
                        // 显示默认休息时间
                        Text("\(action.restTime)s")
                            .font(.system(size: 16))
                            .foregroundColor(theme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.primary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .frame(width: 60, alignment: .center)
                
                Spacer()
                
                // 组菜单
                Menu {
                    Button(action: {
                        if showNoteInput.contains(setId) {
                            showNoteInput.remove(setId)
                        } else {
                            showNoteInput.insert(setId)
                        }
                    }) {
                        Label(showNoteInput.contains(setId) ? "取消备注" : "备注", systemImage: "note.text")
                    }
                    
                    if action.sets.count > 1 {
                        Button(action: {
                            // 使用更安全的删除方式，通过ID匹配而不是索引
                            if index < action.sets.count {
                                let setToRemove = action.sets[index]
                                action.sets.removeAll { $0.id == setToRemove.id }
                                completedSets.remove(setId)
                                setNotes.removeValue(forKey: setId)
                                showNoteInput.remove(setId)
                                onUpdate(action)
                            }
                        }) {
                            Label("删除", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
        }
    }
    
    // 格式化休息时间
    private func formatRestTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        } else {
            return "\(remainingSeconds)s"
        }
    }
    
    // 隐藏系统键盘的方法
    private func hideSystemKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // 提取图片文件名的辅助函数
    private func extractImageFilename(from imageUrl: String) -> String {
        // 从完整路径中提取文件名
        // 例如：从 "backend/static/images/actions/exercise_1.gif" 提取 "exercise_1.gif"
        return URL(string: imageUrl)?.lastPathComponent ?? "exercise_1.gif"
    }
    
    /// 从本地bundle加载动作图片
    private func loadLocalActionImage(fileName: String) -> Image? {
        // 清理路径，移除 .gif 扩展名
        let cleanPath = fileName.replacingOccurrences(of: ".gif", with: "")
        
        // 首先尝试直接使用完整路径加载
        if let url = Bundle.main.url(forResource: cleanPath, withExtension: "gif"),
           let data = try? Data(contentsOf: url),
           let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
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
               let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
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
               let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            }
        }
        
        return nil
    }
}

// MARK: - 休息计时器浮动窗口

struct RestTimerOverlay: View {
    @Environment(\.theme) private var theme
    @Binding var restTime: Int
    let isRunning: Bool
    let onPause: () -> Void
    let onReset: () -> Void
    let onSkip: () -> Void
    let onClose: () -> Void
    let onAddTime: () -> Void
    let onSubtractTime: () -> Void
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea(.container, edges: .bottom)
                .onTapGesture {
                    onClose()
                }
            
            // 计时器窗口
            VStack(spacing: 20) {
                // 关闭按钮
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(theme.secondary)
                    }
                }
                
                // 大圆形计时器显示
                ZStack {
                    Circle()
                        .stroke(theme.secondary.opacity(0.3), lineWidth: 8)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(restTime) / 300.0) // 假设最大5分钟
                        .stroke(theme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text(formatRestTime(restTime))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(theme.onSurface)
                        
                        Text(isRunning ? "运行中" : "已暂停")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondary)
                    }
                }
                
                // 控制按钮
                HStack(spacing: 20) {
                    // 减少时间
                    Button(action: onSubtractTime) {
                        VStack {
                            Image(systemName: "minus")
                                .font(.system(size: 20))
                            Text("-10s")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(theme.primary)
                        .frame(width: 60, height: 60)
                        .background(theme.surface)
                        .cornerRadius(30)
                        .shadow(radius: 2)
                    }
                    
                    // 暂停/继续
                    Button(action: onPause) {
                        VStack {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                            Text(isRunning ? "暂停" : "继续")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(theme.primary)
                        .frame(width: 60, height: 60)
                        .background(theme.surface)
                        .cornerRadius(30)
                        .shadow(radius: 2)
                    }
                    
                    // 增加时间
                    Button(action: onAddTime) {
                        VStack {
                            Image(systemName: "plus")
                                .font(.system(size: 20))
                            Text("+10s")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(theme.primary)
                        .frame(width: 60, height: 60)
                        .background(theme.surface)
                        .cornerRadius(30)
                        .shadow(radius: 2)
                    }
                }
                
                // 底部按钮
                HStack(spacing: 20) {
                    Button(action: onReset) {
                        Text("重置")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.primary)
                            .frame(width: 100, height: 44)
                            .background(theme.surface)
                            .cornerRadius(22)
                            .shadow(radius: 2)
                    }
                    
                    Button(action: onSkip) {
                        Text("完成")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.onPrimary)
                            .frame(width: 100, height: 44)
                            .background(theme.primary)
                            .cornerRadius(22)
                            .shadow(radius: 2)
                    }
                }
            }
            .padding(30)
            .background(theme.surface)
            .cornerRadius(20)
            .shadow(radius: 10)
            .frame(maxWidth: 320)
            .padding(.horizontal, 20)
        }
    }
    
    private func formatRestTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    // 预览代码暂时注释，等待类型定义完成
    Text("TrainingView Preview")
}

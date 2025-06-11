import SwiftUI

// MARK: - 可变的训练数据模型已移动到 MutableTrainingModels.swift

struct TrainingView: View {
    @Environment(\.dismiss) private var dismiss
    let plan: TrainingPlan
    @ObservedObject var viewModel: PlanViewModel
    @ObservedObject private var trainingManager = TrainingSessionManager.shared
    @ObservedObject private var trainingHistoryService = TrainingHistoryService.shared
    
    @State private var showActionSelect = false
    @State private var showCancelAlert = false
    @State private var showCompleteAlert = false
    @State private var showPlanUpdateAlert = false
    @State private var isCompleting = false
    @State private var completionError: String?
    @State private var showCompletionError = false
    
    // 休息计时器状态
    @State private var showRestTimer = false
    @State private var currentRestTime: Int = 0
    @State private var restTimer: Timer?
    @State private var isRestTimerPaused = false
    @State private var currentSetId: String = ""
    
    // 组的倒计时状态
    @State private var setRestTimers: [String: Int] = [:] // 每组的剩余休息时间
    @State private var setTimers: [String: Timer] = [:] // 每组的计时器
    
    // 计划是否有变动
    @State private var planHasChanges = false
    
    init(plan: TrainingPlan, viewModel: PlanViewModel) {
        self.plan = plan
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 16) {
            topInfoBar
            planNameSection
            totalTimerSection
            actionListHeader

            if !trainingManager.editingActions.isEmpty {
                actionListContent
            } else {
                emptyActionListContent
            }
        }
        .padding(.top, 16)
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
        .onDisappear {
            stopAllSetTimers()
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
        setRestTimers = setRestTimers.filter { key, _ in
            !key.hasPrefix("\(actionIdString)_")
        }
        
        // 清理 setTimers (Dictionary)
        for (key, timer) in setTimers {
            if key.hasPrefix("\(actionIdString)_") {
                timer.invalidate()
                setTimers.removeValue(forKey: key)
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
            id: Int.random(in: 100000...999999),
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
        // 开始该组的倒计时
        startSetRestTimer(setId: setId, restTime: restTime)
    }
    
    private func handleRestTimerTapped(setId: String, restTime: Int) {
        // 点击倒计时框时，弹出编辑窗口
        currentSetId = setId
        currentRestTime = setRestTimers[setId] ?? restTime
        showRestTimer = true
        startRestTimer()
    }
    
    private func startSetRestTimer(setId: String, restTime: Int) {
        // 停止该组之前的计时器
        setTimers[setId]?.invalidate()
        
        // 设置初始时间
        setRestTimers[setId] = restTime
        
        // 开始新的计时器
        setTimers[setId] = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let currentTime = setRestTimers[setId], currentTime > 0 {
                setRestTimers[setId] = currentTime - 1
            } else {
                // 时间到了，停止计时器
                setTimers[setId]?.invalidate()
                setTimers.removeValue(forKey: setId)
                setRestTimers.removeValue(forKey: setId)
            }
        }
    }
    
    private func stopSetTimer(setId: String) {
        setTimers[setId]?.invalidate()
        setTimers.removeValue(forKey: setId)
        setRestTimers.removeValue(forKey: setId)
    }
    
    private func stopAllSetTimers() {
        for timer in setTimers.values {
            timer.invalidate()
        }
        setTimers.removeAll()
        setRestTimers.removeAll()
    }
    
    // MARK: - 浮动休息计时器方法
    
    private func startRestTimer() {
        isRestTimerPaused = false
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if currentRestTime > 0 {
                currentRestTime -= 1
                // 同步更新组计时器
                setRestTimers[currentSetId] = currentRestTime
            } else {
                skipRestTimer()
            }
        }
    }
    
    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
    }
    
    private func toggleRestTimer() {
        if isRestTimerPaused {
            startRestTimer()
        } else {
            stopRestTimer()
            isRestTimerPaused = true
        }
    }
    
    private func resetRestTimer() {
        stopRestTimer()
        // 重置为该动作的默认休息时间
        if let actionId = currentSetId.split(separator: "_").first,
           let action = trainingManager.editingActions.first(where: { String($0.id) == actionId }) {
            currentRestTime = action.restTime
            setRestTimers[currentSetId] = action.restTime
        }
        startRestTimer()
    }
    
    private func skipRestTimer() {
        stopRestTimer()
        stopSetTimer(setId: currentSetId)
        showRestTimer = false
        isRestTimerPaused = false
    }
    
    private func closeRestTimer() {
        stopRestTimer()
        // 恢复组计时器
        if let remainingTime = setRestTimers[currentSetId] {
            startSetRestTimer(setId: currentSetId, restTime: remainingTime)
        }
        showRestTimer = false
        isRestTimerPaused = false
    }
    
    private func addRestTime(_ seconds: Int) {
        currentRestTime += seconds
        setRestTimers[currentSetId] = currentRestTime
    }
    
    private func subtractRestTime(_ seconds: Int) {
        currentRestTime = max(0, currentRestTime - seconds)
        setRestTimers[currentSetId] = currentRestTime
    }
    
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
            VStack(alignment: .leading, spacing: 4) {
                Text("训练容量：\(Int(trainingManager.completedVolume()))/\(Int(trainingManager.totalVolume())) kg")
                    .font(.system(size: 14, weight: .medium))
                Text("实时更新，随训练进度变化")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.cyan.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private var planNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("训练计划")
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)

            Text(trainingManager.planName)
                .font(.system(size: 18, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 16)
        }
    }

    private var totalTimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("训练时长")
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)

            Text(trainingManager.formattedTrainingTime())
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
        }
    }

    private var actionListHeader: some View {
        HStack {
            Text("训练动作")
                .font(.system(size: 16, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var actionListContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(trainingManager.editingActions.enumerated()), id: \.element.id) { index, action in
                    let canDeleteAction = trainingManager.editingActions.count > 1

                    TrainingActionCardWrapper(
                        action: action,
                        editingActions: $trainingManager.editingActions,
                        completedSets: $trainingManager.completedSets,
                        setNotes: $trainingManager.setNotes,
                        showNoteInput: .constant(Set<String>()),
                        setRestTimers: $setRestTimers,
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
                        canDelete: canDeleteAction
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
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.97))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 20)
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
                .foregroundColor(.blue)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(white: 0.97))
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
                .foregroundColor(.red)
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
                .foregroundColor(.blue)
                .fontWeight(.medium)
                .disabled(isCompleting)
            }
        }
    }

    private var restTimerOverlay: some View {
        Group {
            if showRestTimer {
                RestTimerOverlay(
                    restTime: $currentRestTime,
                    isRunning: !isRestTimerPaused,
                    onPause: {
                        toggleRestTimer()
                    },
                    onReset: {
                        resetRestTimer()
                    },
                    onSkip: {
                        skipRestTimer()
                    },
                    onClose: {
                        closeRestTimer()
                    },
                    onAddTime: {
                        addRestTime(10)
                    },
                    onSubtractTime: {
                        subtractRestTime(10)
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(), value: showRestTimer)
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
    let canDelete: Bool
    
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
            canDelete: canDelete
        )
    }
}

// MARK: - 训练动作卡片

struct TrainingActionCard: View {
    @Binding var action: MutableTrainingAction
    @Binding var completedSets: Set<String>
    @Binding var setNotes: [String: String]
    @Binding var showNoteInput: Set<String>
    @Binding var setRestTimers: [String: Int]
    let onDelete: () -> Void
    let onUpdate: (MutableTrainingAction) -> Void
    let onSetCompleted: (String, Int) -> Void
    let onRestTimerTapped: (String, Int) -> Void
    let canDelete: Bool
    
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
    }
    
    // MARK: - 动作头部
    private var actionHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 动作图片
                AsyncImage(url: URL(string: "http://127.0.0.1:6000/api/action/images/\(extractImageFilename(from: action.imageUrl))")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
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
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("\(action.sets.count)组")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // 左右模式开关
                        Toggle(isOn: $action.recordBilateral) {
                            Text("记录左右")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .scaleEffect(0.8)
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
                        .foregroundColor(.red)
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.blue)
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
        HStack(spacing: 12) {
            Text("组")
                .frame(width: 30, alignment: .center)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            if action.recordBilateral {
                Text("左kg")
                    .frame(width: 40, alignment: .leading)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Text("右kg")
                    .frame(width: 40, alignment: .leading)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                Text("kg")
                    .frame(width: 40, alignment: .leading)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Text("次数")
                .frame(width: 40, alignment: .leading)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            Text("完成")
                .frame(width: 40, alignment: .center)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            Text("休息")
                .frame(width: 40, alignment: .center)
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
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: 显示动作历史
                }) {
                    Text("动作历史")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
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
            let setId = "\(action.id)_\(action.sets[index].id)"
            let isCompleted = completedSets.contains(setId)
            let restTimeRemaining = setRestTimers[setId]
            
            HStack(spacing: 12) {
                // 组数标号
                Text("\(index + 1)")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, alignment: .center)
                    .foregroundColor(isCompleted ? .blue : .primary)
                
                if action.recordBilateral {
                    // 左侧重量
                    TextField("0", value: Binding(
                        get: { 
                            guard index < action.sets.count else { return 0.0 }
                            return action.sets[index].leftWeight 
                        },
                        set: { newValue in
                            guard index < action.sets.count else { return }
                            action.sets[index].leftWeight = newValue
                            onUpdate(action)
                        }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .frame(width: 40)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isCompleted ? .blue : .primary)
                    
                    // 右侧重量
                    TextField("0", value: Binding(
                        get: { 
                            guard index < action.sets.count else { return 0.0 }
                            return action.sets[index].rightWeight 
                        },
                        set: { newValue in
                            guard index < action.sets.count else { return }
                            action.sets[index].rightWeight = newValue
                            onUpdate(action)
                        }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .frame(width: 40)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isCompleted ? .blue : .primary)
                } else {
                    // 普通重量
                    TextField("0", value: Binding(
                        get: { 
                            guard index < action.sets.count else { return 0.0 }
                            return action.sets[index].weight 
                        },
                        set: { newValue in
                            guard index < action.sets.count else { return }
                            action.sets[index].weight = newValue
                            onUpdate(action)
                        }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .frame(width: 40)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isCompleted ? .blue : .primary)
                }
                
                // 次数输入
                TextField("0", value: Binding(
                    get: { 
                        guard index < action.sets.count else { return 0 }
                        return action.sets[index].reps 
                    },
                    set: { newValue in
                        guard index < action.sets.count else { return }
                        action.sets[index].reps = newValue
                        onUpdate(action)
                    }
                ), format: .number)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .frame(width: 40)
                .multilineTextAlignment(.center)
                .foregroundColor(isCompleted ? .blue : .primary)
                
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
                        .foregroundColor(isCompleted ? .green : .gray)
                        .font(.system(size: 20))
                }
                .frame(width: 40, alignment: .center)
                
                // 休息时间显示/倒计时框
                Button(action: {
                    // 点击倒计时框才弹出编辑窗口
                    onRestTimerTapped(setId, action.restTime)
                }) {
                    if let remainingTime = restTimeRemaining, remainingTime > 0 {
                        // 显示倒计时
                        Text(formatRestTime(remainingTime))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(8)
                    } else {
                        // 显示默认休息时间
                        Text("\(action.restTime)s")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .frame(width: 50, alignment: .center)
                
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
    
    // 提取图片文件名的辅助函数
    private func extractImageFilename(from imageUrl: String) -> String {
        // 从完整路径中提取文件名
        // 例如：从 "backend/static/images/actions/exercise_1.gif" 提取 "exercise_1.gif"
        return URL(string: imageUrl)?.lastPathComponent ?? "exercise_1.gif"
    }
}

// MARK: - 休息计时器浮动窗口

struct RestTimerOverlay: View {
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
                            .foregroundColor(.gray)
                    }
                }
                
                // 大圆形计时器显示
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(restTime) / 300.0) // 假设最大5分钟
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text(formatRestTime(restTime))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(isRunning ? "运行中" : "已暂停")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
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
                        .foregroundColor(.blue)
                        .frame(width: 60, height: 60)
                        .background(Color.white)
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
                        .foregroundColor(.blue)
                        .frame(width: 60, height: 60)
                        .background(Color.white)
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
                        .foregroundColor(.blue)
                        .frame(width: 60, height: 60)
                        .background(Color.white)
                        .cornerRadius(30)
                        .shadow(radius: 2)
                    }
                }
                
                // 底部按钮
                HStack(spacing: 20) {
                    Button(action: onReset) {
                        Text("重置")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 100, height: 44)
                            .background(Color.white)
                            .cornerRadius(22)
                            .shadow(radius: 2)
                    }
                    
                    Button(action: onSkip) {
                        Text("完成")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 100, height: 44)
                            .background(Color.blue)
                            .cornerRadius(22)
                            .shadow(radius: 2)
                    }
                }
            }
            .padding(30)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(.horizontal, 40)
        }
    }
    
    private func formatRestTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    let samplePlan = TrainingPlan(
        id: 1,
        name: "测试训练计划",
        creator: "我",
        createdDate: "2024-01-01",
        lastTraining: "未开始",
        volume: 0,
        actions: [
            TrainingAction(
                id: 1,
                name: "深蹲",
                sets: [
                    TrainingSet(id: 101, weight: 60, reps: 5),
                    TrainingSet(id: 102, weight: 70, reps: 5)
                ],
                restTime: 60,
                recordBilateral: false
            )
        ]
    )
    let viewModel = PlanViewModel()
    TrainingView(plan: samplePlan, viewModel: viewModel)
} 
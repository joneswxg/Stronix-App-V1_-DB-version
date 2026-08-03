import SwiftUI

struct EditHistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    let selectedDate: Date
    let historyData: TrainingDetailData
    let historyId: Int
    
    private let planName: String
    @State private var duration: String
    @State private var totalVolume: String
    @State private var editableDate: Date // 可编辑的日期
    @State private var isSaving = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var preventDismiss = false
    
    // 编辑中的动作数据
    @State private var editingExercises: [EditingExercise] = []
    
    // 本地日期格式化器
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter
    }()
    
    init(selectedDate: Date, historyData: TrainingDetailData, historyId: Int) {
        self.selectedDate = selectedDate
        self.historyData = historyData
        self.historyId = historyId
        self.planName = historyData.planName
        self._duration = State(initialValue: Self.extractDurationNumber(from: historyData.duration))
        self._totalVolume = State(initialValue: historyData.totalVolume)
        self._editableDate = State(initialValue: selectedDate) // 初始化可编辑日期
        
        // 初始化编辑中的动作数据
        let exercises = historyData.exercises.map { exercise in
            let editingSets = exercise.sets.map { set in
                EditingHistorySet(
                    id: UUID(),
                    number: set.number,
                    weight: set.weight,
                    reps: set.reps,
                    actualReps: set.actualReps,
                    isCompleted: set.isCompleted,
                    leftWeight: set.leftWeight,
                    rightWeight: set.rightWeight,
                    isBilateral: set.isBilateral,
                    rir: set.rir
                )
            }
            
            // 检查是否有任何一组是双侧训练
            let hasBilateral = editingSets.contains { $0.isBilateral }
            
            return EditingExercise(
                id: UUID(),
                action_id: exercise.action_id,
                name: exercise.name,
                isExpanded: false,
                sets: editingSets,
                recordBilateral: hasBilateral
            )
        }
        self._editingExercises = State(initialValue: exercises)
    }
    
    var calculatedVolume: Int {
        editingExercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { setTotal, set in
                // 只计算已完成的组
                if set.isCompleted {
                    if set.isBilateral {
                        setTotal + Int((set.leftWeight + set.rightWeight) * Double(set.actualReps))
                    } else {
                        setTotal + Int(set.weight * Double(set.actualReps))
                    }
                } else {
                    setTotal
                }
            }
        }
    }
    
    // 从格式化的时长字符串中提取纯数字
    static func extractDurationNumber(from durationString: String) -> String {
        // 处理各种格式："30分钟"、"1小时30分钟"、"0"、"<1分钟"
        if durationString == "0" {
            return "0"
        }
        
        // 使用正则表达式提取数字
        let pattern = "(\\d+)小时(\\d+)分钟|(\\d+)分钟"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: durationString.utf16.count)
            if let match = regex.firstMatch(in: durationString, range: range) {
                // 检查是否匹配"小时分钟"格式
                if match.range(at: 1).location != NSNotFound && match.range(at: 2).location != NSNotFound {
                    let hoursRange = match.range(at: 1)
                    let minutesRange = match.range(at: 2)
                    if let hoursString = Range(hoursRange, in: durationString),
                       let minutesString = Range(minutesRange, in: durationString),
                       let hours = Int(String(durationString[hoursString])),
                       let minutes = Int(String(durationString[minutesString])) {
                        return String(hours * 60 + minutes)
                    }
                }
                // 检查是否匹配"分钟"格式
                else if match.range(at: 3).location != NSNotFound {
                    let minutesRange = match.range(at: 3)
                    if let minutesString = Range(minutesRange, in: durationString) {
                        return String(durationString[minutesString])
                    }
                }
            }
        }
        
        // 如果无法解析，返回"0"
        return "0"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Logo区域
                HStack {
                    Image("StronixLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 35)
                    Spacer()
                    Text("STRONIX")
                         .font(.system(size: 20, weight: .bold, design: .rounded))
                         .foregroundColor(theme.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.background)
                .shadow(color: theme.shadow.opacity(0.1), radius: 1, y: 1)
                    
                    // 顶部信息栏
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("实际完成容量：\(calculatedVolume) kg")
                                .font(.system(size: 14, weight: .medium))
                            Text("仅计算已完成的组，实时更新")
                                 .font(.system(size: 12))
                                 .foregroundColor(theme.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(theme.primary.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    // 训练日期
                    VStack(alignment: .leading, spacing: 8) {
                        Text("训练日期")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                        
                        DatePicker(
                            "选择训练日期",
                            selection: $editableDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding()
                        .background(theme.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                        .disabled(isSaving)
                    }
                    
                    // 计划名称（只显示）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("训练计划")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                        
                        Text(planName)
                            .font(.system(size: 16))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.secondary.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                    }
                    
                    // 训练时长
                    VStack(alignment: .leading, spacing: 8) {
                        Text("训练时长")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                        
                        HStack {
                            TextField("输入训练时长", text: $duration)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .disabled(isSaving)
                            
                            Text("分钟")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.secondary)
                                .padding(.trailing, 8)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // 训练动作标题
                    HStack {
                        Text("训练动作")
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    // 训练动作列表
                    if !editingExercises.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(editingExercises, id: \.id) { exercise in
                                EditingExerciseCardWrapper(
                                    exercise: exercise,
                                    editingExercises: $editingExercises,
                                    onDelete: {
                                        deleteExercise(exercise)
                                    },
                                    onUpdate: { updatedExercise in
                                        updateExercise(updatedExercise)
                                    },
                                    isDisabled: isSaving
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // 底部间距
                Spacer(minLength: 50)
            }
            .padding(.top, 20)
        }
        .background(theme.background)
        .navigationTitle("编辑训练记录")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
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
                        await saveHistory()
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
                .disabled(isSaving)
            }
        }
        .overlay(
            // Toast提示
            VStack {
                Spacer()
                if showToast {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.success)
                        Text(toastMessage)
                            .foregroundColor(theme.onPrimary)
                    }
                    .padding()
                    .background(theme.onSurface.opacity(0.8))
                    .cornerRadius(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 50)
            .animation(.easeInOut(duration: 0.3), value: showToast)
        )
     }
    
    private func deleteExercise(_ exercise: EditingExercise) {
        editingExercises.removeAll { $0.id == exercise.id }
    }
    
    private func updateExercise(_ updatedExercise: EditingExercise) {
        if let index = editingExercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            editingExercises[index] = updatedExercise
        }
    }
    
    private func saveHistory() async {
        print("🔄 EditHistoryDetailView.saveHistory() 开始")
        print("📅 保存的训练日期: \(dateFormatter.string(from: editableDate))")
        print("📋 保存的计划名称: \(planName)")
        print("⏱️ 保存的训练时长: \(duration)")
        print("💪 保存的训练动作数量: \(editingExercises.count)")
        
        isSaving = true
        preventDismiss = true
        
        do {
            // 将编辑中的训练动作转换为TrainingHistoryDetail数组
            var details: [TrainingHistoryDetail] = []
            
            for exercise in editingExercises {
                for (index, set) in exercise.sets.enumerated() {
                    let detail = TrainingHistoryDetail(
                        action_id: exercise.action_id,
                        set_number: index + 1,
                        weight: set.isBilateral ? nil : Double(set.weight),
                        weight_unit: "kg",
                        reps: set.actualReps,
                        difficulty: nil,
                        rir: set.rir,
                        left_weight: set.isBilateral ? Double(set.leftWeight) : nil,
                        right_weight: set.isBilateral ? Double(set.rightWeight) : nil,
                        is_completed: set.isCompleted,
                        note: nil,
                        history_record_bilateral: set.isBilateral
                    )
                    details.append(detail)
                }
            }
            
            // 创建更新请求
            let updateRequest = UpdateTrainingHistoryRequest(
                training_date: ISO8601DateFormatter().string(from: editableDate),
                volume: Double(calculatedVolume),
                duration: Int(duration) ?? 0,
                note: nil, // 如果需要备注功能，可以添加相应的状态变量
                details: details
            )
            
            // 调用更新服务
            try await TrainingHistoryService.shared.updateTrainingHistory(
                historyId: historyId, // 使用传入的历史记录ID
                request: updateRequest
            )
            
            print("✅ 训练历史更新成功")
            
            await MainActor.run {
                isSaving = false
                preventDismiss = false
                
                // 显示成功提示
                toastMessage = "保存成功！"
                showToast = true
                
                // 1.5秒后自动关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showToast = false
                    dismiss()
                }
            }
        } catch {
            print("❌ 保存训练历史失败: \(error)")
            
            await MainActor.run {
                isSaving = false
                preventDismiss = false
                
                // 显示错误提示
                toastMessage = "保存失败，请重试"
                showToast = true
                
                // 3秒后自动隐藏错误提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    showToast = false
                }
            }
        }
    }
}

// MARK: - 编辑中的数据模型

struct EditingExercise: Identifiable {
    let id: UUID
    let action_id: Int
    let name: String
    var isExpanded: Bool
    var sets: [EditingHistorySet]
    var recordBilateral: Bool
    
    init(id: UUID = UUID(), action_id: Int, name: String, isExpanded: Bool = false, sets: [EditingHistorySet] = [], recordBilateral: Bool = false) {
        self.id = id
        self.action_id = action_id
        self.name = name
        self.isExpanded = isExpanded
        self.sets = sets
        self.recordBilateral = recordBilateral
    }
}

struct EditingHistorySet: Identifiable {
    let id: UUID
    let number: Int
    var weight: Double
    var reps: Int
    var actualReps: Int
    var isCompleted: Bool
    var leftWeight: Double
    var rightWeight: Double
    var isBilateral: Bool
    var rir: SetRIR?

    init(id: UUID = UUID(), number: Int, weight: Double, reps: Int, actualReps: Int, isCompleted: Bool, leftWeight: Double = 0, rightWeight: Double = 0, isBilateral: Bool = false, rir: SetRIR? = nil) {
        self.id = id
        self.number = number
        self.weight = weight
        self.reps = reps
        self.actualReps = actualReps
        self.isCompleted = isCompleted
        self.leftWeight = leftWeight
        self.rightWeight = rightWeight
        self.isBilateral = isBilateral
        self.rir = rir
    }
}

// MARK: - 编辑动作卡片包装器

struct EditingExerciseCardWrapper: View {
    let exercise: EditingExercise
    @Binding var editingExercises: [EditingExercise]
    let onDelete: () -> Void
    let onUpdate: (EditingExercise) -> Void
    let isDisabled: Bool
    
    private var exerciseBinding: Binding<EditingExercise> {
        Binding(
            get: {
                editingExercises.first { $0.id == exercise.id } ?? exercise
            },
            set: { newValue in
                if let index = editingExercises.firstIndex(where: { $0.id == exercise.id }) {
                    editingExercises[index] = newValue
                }
            }
        )
    }
    
    var body: some View {
        EditingExerciseCard(
            
            
            exercise: exerciseBinding,
            onDelete: onDelete,
            onUpdate: onUpdate,
            isDisabled: isDisabled
        )
    }
}

// MARK: - 编辑动作卡片

struct EditingExerciseCard: View {
    @Environment(\.theme) private var theme: AppTheme
    @Binding var exercise: EditingExercise
    let onDelete: () -> Void
    let onUpdate: (EditingExercise) -> Void
    let isDisabled: Bool
    
    @State private var showDeleteAlert = false
    
    var exerciseVolume: Int {
        exercise.sets.reduce(0) { total, set in
            // 只计算已完成的组
            if set.isCompleted {
                if set.isBilateral {
                    total + Int((set.leftWeight + set.rightWeight) * Double(set.actualReps))
                } else {
                    total + Int(set.weight * Double(set.actualReps))
                }
            } else {
                total
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 动作头部
            exerciseHeader
            
            // 组数详情（展开时显示）
            if exercise.isExpanded {
                setsSection
            }
        }
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: theme.shadow.opacity(0.05), radius: 5, x: 0, y: 2)
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("确定要删除这个训练动作吗？")
        }
    }
    
    // MARK: - 动作头部
    private var exerciseHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 动作图片
                Image(systemName: "figure.strengthtraining.traditional")
                     .font(.title2)
                     .foregroundColor(theme.primary)
                     .frame(width: 40, height: 40)
                     .background(theme.primary.opacity(0.1))
                    .cornerRadius(8)
                
                // 动作信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(exercise.name)
                            .font(.system(size: 16, weight: .medium))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // 容量显示
                        Text("\(exerciseVolume)容量")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondary)
                    }
                    
                    Text("\(exercise.sets.count)组")
                         .font(.system(size: 14))
                         .foregroundColor(theme.secondary)
                }
                
                // 删除按钮
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                         .foregroundColor(theme.error)
                        .font(.system(size: 16))
                }
                .disabled(isDisabled)
            }
            
            // 如果展开,显示表头
            if exercise.isExpanded {
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
                    exercise.isExpanded.toggle()
                }
            }
        }
    }
    
    // 表头组件
    private var tableHeader: some View {
        HStack(spacing: exercise.recordBilateral ? 3 : 12) {
            Text("组")
                .frame(width: 30, alignment: .center)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondary)
                .padding(.leading, 52) // 与动作名称对齐
             
            if exercise.recordBilateral {
                Text("左kg")
                    .frame(width: 42, alignment: .center)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondary)
                
                Text("右kg")
                    .frame(width: 42, alignment: .center)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondary)
            } else {
                Text("重量")
                    .frame(width: 50, alignment: .leading)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondary)
            }

            Text("次数")
                .frame(width: 50, alignment: .leading)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            Text("完成")
                .frame(width: 50, alignment: .center)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            Spacer()
        }
    }
    
    // MARK: - 组数区域
    private var setsSection: some View {
        VStack(spacing: 8) {
            // 组数列表
            ForEach(exercise.sets, id: \.id) { set in
                if let index = exercise.sets.firstIndex(where: { $0.id == set.id }) {
                    setRow(index: index)
                }
            }
            
            // 底部按钮区域
            HStack(spacing: 16) {
                Button(action: {
                    exercise.sets.append(EditingHistorySet(
                        id: UUID(),
                        number: exercise.sets.count + 1,
                        weight: 0,
                        reps: 0,
                        actualReps: 0,
                        isCompleted: false,
                        leftWeight: 0,
                        rightWeight: 0,
                        isBilateral: exercise.recordBilateral
                    ))
                    onUpdate(exercise)
                }) {
                    Text("新增一组")
                         .font(.system(size: 14))
                         .foregroundColor(theme.primary)
                }
                .disabled(isDisabled)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    // MARK: - 单组行
    private func setRow(index: Int) -> some View {
        guard index < exercise.sets.count else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            HStack(spacing: exercise.recordBilateral ? 3 : 12) {
                // 组数标号，与动作名称对齐
                Text("\(exercise.sets[index].number)")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, alignment: .center)
                    .padding(.leading, 52) // 与动作名称对齐
                
                if exercise.recordBilateral {
                    // 左侧重量输入
                    TextField("0", value: Binding(
                        get: { 
                            guard index < exercise.sets.count else { return 0 }
                            return exercise.sets[index].leftWeight 
                        },
                        set: { newValue in
                            guard index < exercise.sets.count else { return }
                            exercise.sets[index].leftWeight = newValue
                            onUpdate(exercise)
                        }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 42)
                    .multilineTextAlignment(.center)
                    .disabled(isDisabled)
                    
                    // 右侧重量输入
                    TextField("0", value: Binding(
                        get: { 
                            guard index < exercise.sets.count else { return 0 }
                            return exercise.sets[index].rightWeight 
                        },
                        set: { newValue in
                            guard index < exercise.sets.count else { return }
                            exercise.sets[index].rightWeight = newValue
                            onUpdate(exercise)
                        }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 42)
                    .multilineTextAlignment(.center)
                    .disabled(isDisabled)
                } else {
                    // 普通重量输入
                    TextField("0", value: Binding(
                        get: { 
                            guard index < exercise.sets.count else { return 0 }
                            return exercise.sets[index].weight 
                        },
                        set: { newValue in
                            guard index < exercise.sets.count else { return }
                            exercise.sets[index].weight = newValue
                            onUpdate(exercise)
                        }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .disabled(isDisabled)
                }
                
                // 次数输入（实际完成次数）
                TextField("0", value: Binding(
                    get: { 
                        guard index < exercise.sets.count else { return 0 }
                        return exercise.sets[index].actualReps 
                    },
                    set: { newValue in
                        guard index < exercise.sets.count else { return }
                        exercise.sets[index].actualReps = newValue
                        // 同时更新计划次数，保持一致
                        exercise.sets[index].reps = newValue
                        onUpdate(exercise)
                    }
                ), format: .number)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .disabled(isDisabled)
                
                // 完成状态切换
                Button(action: {
                    guard index < exercise.sets.count else { return }
                    exercise.sets[index].isCompleted.toggle()
                    onUpdate(exercise)
                }) {
                    let isCompleted = index < exercise.sets.count ? exercise.sets[index].isCompleted : false
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? theme.success : theme.secondary)
                        .font(.system(size: 20))
                }
                .frame(width: 50, alignment: .center)
                .disabled(isDisabled)
                
                Spacer()
                
                // 组菜单
                Menu {
                    Button(action: {
                        if index < exercise.sets.count {
                            let setId = exercise.sets[index].id
                            exercise.sets.removeAll { $0.id == setId }
                            onUpdate(exercise)
                        }
                    }) {
                        Label("删除", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(theme.secondary)
                        .frame(width: 30, height: 30)
                }
                .disabled(isDisabled)
            }
        )
    }
}



#Preview {
    let sampleData = TrainingDetailData(
        planName: "Strong 5x5 - Workout A",
        duration: "1分钟",
        totalVolume: "500 kg",
        exercises: [
            ExerciseDetail(
                action_id: 1,
                name: "杠铃卧推",
                sets: [
                    SetDetail(number: 1, weight: 60, reps: 12, actualReps: 12, isCompleted: true),
                    SetDetail(number: 2, weight: 60, reps: 10, actualReps: 10, isCompleted: false)
                ]
            )
        ]
    )
    
    EditHistoryDetailView(
        selectedDate: Date(),
        historyData: sampleData,
        historyId: 1
    )
}

import SwiftUI

struct EditHistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedDate: Date
    let historyData: TrainingDetailData
    
    @State private var planName: String
    @State private var duration: String
    @State private var totalVolume: String
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
    
    init(selectedDate: Date, historyData: TrainingDetailData) {
        self.selectedDate = selectedDate
        self.historyData = historyData
        self._planName = State(initialValue: historyData.planName)
        self._duration = State(initialValue: historyData.duration)
        self._totalVolume = State(initialValue: historyData.totalVolume)
        
        // 初始化编辑中的动作数据
        let exercises = historyData.exercises.map { exercise in
            EditingExercise(
                id: UUID(),
                name: exercise.name,
                isExpanded: false,
                sets: exercise.sets.map { set in
                    EditingHistorySet(
                        id: UUID(),
                        number: set.number,
                        weight: set.weight,
                        reps: set.reps,
                        actualReps: set.actualReps,
                        isCompleted: true
                    )
                }
            )
        }
        self._editingExercises = State(initialValue: exercises)
    }
    
    var calculatedVolume: Int {
        editingExercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { setTotal, set in
                setTotal + (set.weight * set.actualReps)
            }
        }
    }
    
    var body: some View {
        NavigationView {
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
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
                    
                    // 顶部信息栏
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("训练总容量：\(calculatedVolume) kg")
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
                    
                    // 训练日期
                    VStack(alignment: .leading, spacing: 8) {
                        Text("训练日期")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                        
                        Text("\(selectedDate, formatter: dateFormatter)")
                            .font(.system(size: 16))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 16)
                    }
                    
                    // 计划名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text("训练计划")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                        
                        TextField("输入计划名称", text: $planName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 16)
                            .disabled(isSaving)
                    }
                    
                    // 训练时长
                    VStack(alignment: .leading, spacing: 8) {
                        Text("训练时长")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                        
                        TextField("输入训练时长", text: $duration)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 16)
                            .disabled(isSaving)
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
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("编辑训练记录")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .overlay(
                // 自定义导航栏
                VStack {
                    HStack {
                        Button("取消") {
                            if !preventDismiss {
                                dismiss()
                            }
                        }
                        .foregroundColor(.gray)
                        .disabled(isSaving || preventDismiss)
                        
                        Spacer()
                        
                        Text("编辑训练记录")
                            .font(.headline)
                        
                        Spacer()
                        
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
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                        .disabled(isSaving || planName.isEmpty)
                    }
                    .padding()
                    .background(Color.white)
                    .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
                    
                    Spacer()
                }
            )
            .overlay(
                // Toast提示
                VStack {
                    Spacer()
                    if showToast {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(toastMessage)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 50)
                .animation(.easeInOut(duration: 0.3), value: showToast)
            )
        }
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
        
        isSaving = true
        preventDismiss = true
        
        // 模拟保存过程
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒延迟
        
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
    }
}

// MARK: - 编辑中的数据模型

struct EditingExercise: Identifiable {
    let id: UUID
    let name: String
    var isExpanded: Bool
    var sets: [EditingHistorySet]
}

struct EditingHistorySet: Identifiable {
    let id: UUID
    let number: Int
    var weight: Int
    var reps: Int
    var actualReps: Int
    var isCompleted: Bool
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
    @Binding var exercise: EditingExercise
    let onDelete: () -> Void
    let onUpdate: (EditingExercise) -> Void
    let isDisabled: Bool
    
    @State private var showDeleteAlert = false
    
    var exerciseVolume: Int {
        exercise.sets.reduce(0) { total, set in
            total + (set.weight * set.actualReps)
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
    
    // MARK: - 动作头部
    private var exerciseHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 动作图片
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
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
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(exercise.sets.count)组")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                // 删除按钮
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
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
        HStack(spacing: 12) {
            Text("组")
                .frame(width: 30, alignment: .center)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.leading, 52) // 与动作名称对齐
            
            Text("重量")
                .frame(width: 50, alignment: .leading)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            Text("次数")
                .frame(width: 50, alignment: .leading)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            Text("实际")
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
                        isCompleted: false
                    ))
                    onUpdate(exercise)
                }) {
                    Text("新增一组")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
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
            HStack(spacing: 12) {
                // 组数标号，与动作名称对齐
                Text("\(exercise.sets[index].number)")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30, alignment: .center)
                    .padding(.leading, 52) // 与动作名称对齐
                
                // 重量输入
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
                
                // 计划次数输入
                TextField("0", value: Binding(
                    get: { 
                        guard index < exercise.sets.count else { return 0 }
                        return exercise.sets[index].reps 
                    },
                    set: { newValue in
                        guard index < exercise.sets.count else { return }
                        exercise.sets[index].reps = newValue
                        onUpdate(exercise)
                    }
                ), format: .number)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .disabled(isDisabled)
                
                // 实际次数输入
                TextField("0", value: Binding(
                    get: { 
                        guard index < exercise.sets.count else { return 0 }
                        return exercise.sets[index].actualReps 
                    },
                    set: { newValue in
                        guard index < exercise.sets.count else { return }
                        exercise.sets[index].actualReps = newValue
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
                    Image(systemName: exercise.sets[index].isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(exercise.sets[index].isCompleted ? .green : .gray)
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
                        .foregroundColor(.gray)
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
                name: "杠铃卧推",
                sets: [
                    SetDetail(number: 1, weight: 60, reps: 12, actualReps: 12),
                    SetDetail(number: 2, weight: 60, reps: 10, actualReps: 10)
                ]
            )
        ]
    )
    
    return EditHistoryDetailView(
        selectedDate: Date(),
        historyData: sampleData
    )
}
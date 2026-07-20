import SwiftUI

struct TrainingHistoryDetailView: View {
    @Environment(\.theme) private var theme: AppTheme
    
    let historyId: Int
    @State private var showEditView = false
    @State private var selectedHistory: TrainingHistoryDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @ObservedObject private var trainingHistoryService = TrainingHistoryService.shared
    
    // 本地日期格式化器
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // 加载训练历史详情
    private func loadHistoryDetail() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                print("🔄 获取训练历史详情，ID: \(historyId)")
                let detail = try await trainingHistoryService.getTrainingHistoryDetail(historyId: historyId)
                
                await MainActor.run {
                    self.selectedHistory = detail
                    self.isLoading = false
                    print("✅ 训练历史详情加载完成")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("❌ 加载训练历史详情失败: \(error)")
                }
            }
        }
    }
    
    // 将API数据转换为UI数据
    private var detailData: TrainingDetailData? {
        guard let selectedHistory = selectedHistory else { 
            return nil 
        }
        
        print("🔄 开始转换训练详情数据: \(selectedHistory.history.plan_name)")
        
        // 按动作分组详情
        let groupedDetails = Dictionary(grouping: selectedHistory.details) { $0.action_id }
        
        var exercises: [ExerciseDetail] = []
        
        for (actionId, details) in groupedDetails {
            let actionName = details.first?.action_name ?? "未知动作"
            
            let sets = details.sorted { $0.set_number < $1.set_number }.map { detail in
                // 使用 history_record_bilateral 字段判断是否为双侧训练
                let isBilateral = detail.history_record_bilateral
                
                if isBilateral {
                    // 双侧训练：显示左右重量
                    return SetDetail(
                        number: detail.set_number,
                        weight: 0.0, // 双侧训练不使用统一重量
                        reps: detail.reps ?? 0,
                        actualReps: detail.reps ?? 0,
                        isCompleted: detail.is_completed,
                        leftWeight: detail.left_weight ?? 0.0,
                        rightWeight: detail.right_weight ?? 0.0,
                        isBilateral: true
                    )
                } else {
                    // 普通训练：显示统一重量
                    return SetDetail(
                        number: detail.set_number,
                        weight: detail.weight ?? 0.0,
                        reps: detail.reps ?? 0,
                        actualReps: detail.reps ?? 0,
                        isCompleted: detail.is_completed
                    )
                }
            }
            
            exercises.append(ExerciseDetail(action_id: actionId, name: actionName, sets: sets))
        }
        
        // 格式化时长
        let durationText = formatDuration(selectedHistory.history.duration)
        
        return TrainingDetailData(
            planName: selectedHistory.history.plan_name,
            duration: durationText,
            totalVolume: "\(String(format: "%.1f", selectedHistory.history.volume)) kg",
            exercises: exercises
        )
    }
    
    // 格式化时长
    private func formatDuration(_ duration: Int) -> String {
        // duration 现在统一为分钟单位
        let minutes = duration
        
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)小时\(remainingMinutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            // 对于不足1分钟的情况，显示为"0"
            return "0"
        }
    }
    
    private func formatTrainingTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return timeFormatter.string(from: date)
        }
        return dateString
    }
    
    private func getTrainingDate() -> Date {
        guard let selectedHistory = selectedHistory else { return Date() }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: selectedHistory.history.training_date) ?? Date()
    }

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            logoSection
            navigationSection
            
            if isLoading {
                Spacer()
                VStack {
                    ProgressView("加载训练详情...")
                    Text("正在加载训练详细数据")
                        .font(.caption)
                        .foregroundColor(theme.secondary)
                        .padding(.top, 8)
                }
                Spacer()
            } else if let errorMessage = errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(theme.warning)
                    
                    Text("加载失败")
                        .font(.headline)
                        .foregroundColor(theme.onSurface)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(theme.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("重试") {
                        loadHistoryDetail()
                    }
                    .padding()
                    .background(theme.primary)
                    .foregroundColor(theme.onPrimary)
                    .cornerRadius(8)
                }
                .padding()
                Spacer()
            } else if let detailData = detailData {
                contentScrollView(detailData)
            } else {
                Spacer()
                VStack {
                    Text("没有训练数据")
                        .foregroundColor(theme.secondary)
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("🎬 TrainingHistoryDetailView 出现，历史ID: \(historyId)")
            loadHistoryDetail()
        }
        .navigationDestination(isPresented: $showEditView) {
            if let detailData = detailData {
                EditHistoryDetailView(
                    selectedDate: getTrainingDate(),
                    historyData: detailData,
                    historyId: historyId
                )
            }
        }
    }
    
    // MARK: - 视图组件
    
    private var logoSection: some View {
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
        .background(theme.surface)
        .shadow(color: theme.shadow.opacity(0.1), radius: 1, y: 1)
    }
    
    private var navigationSection: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(theme.primary)
            }
            Spacer()
            Text("训练详情")
                .font(.headline)
                .foregroundColor(theme.onSurface)
            Spacer()
            Button(action: {
                showEditView = true
            }) {
                Text("编辑")
                    .font(.headline)
                    .foregroundColor(theme.primary)
            }
        }
        .padding()
        .background(theme.surface)
        .shadow(color: theme.shadow.opacity(0.1), radius: 1, y: 1)
    }
    
    private func contentScrollView(_ data: TrainingDetailData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dateTimeSection
                summarySection(data)
                exercisesList(data)
            }
            .padding()
        }
    }
    
    private var dateTimeSection: some View {
        HStack(spacing: 15) {
            Image(systemName: "clock")
                .foregroundColor(theme.secondary)
            
            if let selectedHistory = selectedHistory {
                let trainingDate = getTrainingDate()
                Text("\(trainingDate, formatter: dateFormatter)")
                    .font(.subheadline)
                    .foregroundColor(theme.secondary)
                
                Text("• \(formatTrainingTime(selectedHistory.history.training_date))")
                    .font(.subheadline)
                    .foregroundColor(theme.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private func summarySection(_ data: TrainingDetailData) -> some View {
        HStack {
            Spacer()
            VStack {
                Image(systemName: "clock")
                    .font(.title3)
                Text(data.duration)
                    .font(.subheadline)
            }
            Spacer()
            VStack {
                Image(systemName: "scalemass")
                    .font(.title3)
                Text(data.totalVolume)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding()
        .background(theme.shadow.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func exercisesList(_ data: TrainingDetailData) -> some View {
        ForEach(0..<data.exercises.count, id: \.self) { index in
            ExerciseCard(exercise: data.exercises[index])
        }
    }
}

struct ExerciseCard: View {
    @Environment(\.theme) private var theme: AppTheme
    let exercise: ExerciseDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            exerciseHeader
            exerciseSets
        }
        .padding()
        .background(theme.surface)
        .cornerRadius(10)
        .shadow(color: theme.shadow.opacity(0.1), radius: 2, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var exerciseHeader: some View {
        HStack {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title2)
                .foregroundColor(theme.primary)
                .frame(width: 40, height: 40)
                .background(theme.primary.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundColor(theme.onSurface)
            }
            
            Spacer()
        }
        .padding(.bottom, 5)
    }
    
    private var exerciseSets: some View {
        ForEach(0..<exercise.sets.count, id: \.self) { index in
            let set = exercise.sets[index]
            HStack {
                Text("第\(set.number)组")
                    .frame(width: 60, alignment: .leading)
                    .font(.subheadline)
                
                // 根据是否为双侧训练显示不同的重量信息
                if set.isBilateral {
                    Text("左\(String(format: "%.1f", set.leftWeight))kg 右\(String(format: "%.1f", set.rightWeight))kg × \(set.reps)")
                        .font(.subheadline)
                        .foregroundColor(theme.onSurface)
                } else {
                    Text(set.weight == 0 ? "+0.0 kg × \(set.reps)" : "\(String(format: "%.1f", set.weight)) kg × \(set.reps)")
                        .font(.subheadline)
                        .foregroundColor(theme.onSurface)
                }
                
                Spacer()
                
                if set.isCompleted {
                Image(systemName: "checkmark")
                    .font(.subheadline)
                    .foregroundColor(theme.success)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    private func calculateVolume() -> Int {
        return exercise.sets.reduce(0) { total, set in
            if set.isBilateral {
                // 双侧训练：左右重量之和乘以次数
                return total + Int((set.leftWeight + set.rightWeight) * Double(set.reps))
            } else {
                // 普通训练：重量乘以次数
                return total + Int(set.weight * Double(set.reps))
            }
        }
    }
}

#Preview {
    TrainingHistoryDetailView(historyId: 1)
}
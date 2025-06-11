import SwiftUI

struct TrainingHistoryDetailView: View {
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
        
        for (_, details) in groupedDetails {
            let actionName = details.first?.action_name ?? "未知动作"
            
            let sets = details.sorted { $0.set_number < $1.set_number }.map { detail in
                SetDetail(
                    number: detail.set_number,
                    weight: Int(detail.weight ?? 0),
                    reps: detail.reps ?? 0,
                    actualReps: detail.reps ?? 0
                )
            }
            
            exercises.append(ExerciseDetail(name: actionName, sets: sets))
        }
        
        // 格式化时长
        let durationText = formatDuration(selectedHistory.history.duration)
        
        return TrainingDetailData(
            planName: selectedHistory.history.plan_name,
            duration: durationText,
            totalVolume: "\(Int(selectedHistory.history.volume)) kg",
            exercises: exercises
        )
    }
    
    // 格式化时长
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            // 对于不足1分钟的情况，显示为"<1分钟"
            return "<1分钟"
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
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
                Spacer()
            } else if let errorMessage = errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("加载失败")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("重试") {
                        loadHistoryDetail()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                Spacer()
            } else if let selectedHistory = selectedHistory, let detailData = detailData {
                contentScrollView(detailData)
            } else {
                Spacer()
                VStack {
                    Text("没有训练数据")
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("🎬 TrainingHistoryDetailView 出现，历史ID: \(historyId)")
            loadHistoryDetail()
        }
        .sheet(isPresented: $showEditView) {
            if let detailData = detailData {
                EditHistoryDetailView(
                    selectedDate: getTrainingDate(),
                    historyData: detailData
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
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
    }
    
    private var navigationSection: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            Spacer()
            Text("训练详情")
                .font(.headline)
            Spacer()
            Button(action: {
                showEditView = true
            }) {
                Text("编辑")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.white)
        .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)
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
                .foregroundColor(.secondary)
            
            if let selectedHistory = selectedHistory {
                let trainingDate = getTrainingDate()
                Text("\(trainingDate, formatter: dateFormatter)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("• \(formatTrainingTime(selectedHistory.history.training_date))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func exercisesList(_ data: TrainingDetailData) -> some View {
        ForEach(data.exercises, id: \.name) { exercise in
            ExerciseCard(exercise: exercise)
        }
    }
}

struct ExerciseCard: View {
    let exercise: ExerciseDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            exerciseHeader
            exerciseSets
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var exerciseHeader: some View {
        HStack {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(exercise.name)
                    .font(.headline)
                Text("\(calculateVolume())kg 容量")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.bottom, 5)
    }
    
    private var exerciseSets: some View {
        ForEach(exercise.sets, id: \.number) { set in
            HStack {
                Text("第\(set.number)组")
                    .frame(width: 60, alignment: .leading)
                    .font(.subheadline)
                
                Text(set.weight == 0 ? "+0 kg × \(set.reps)" : "\(set.weight) kg × \(set.reps)")
                    .font(.subheadline)
                
                Spacer()
                
                Image(systemName: "checkmark")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            .padding(.vertical, 2)
        }
    }
    
    private func calculateVolume() -> Int {
        exercise.sets.reduce(0) { $0 + $1.weight * $1.actualReps }
    }
}

#Preview {
    TrainingHistoryDetailView(historyId: 1)
} 
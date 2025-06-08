import SwiftUI

// 训练详情数据结构
struct TrainingDetailData {
    let planName: String
    let duration: String
    let totalVolume: String
    let exercises: [ExerciseDetail]
}

struct ExerciseDetail {
    let name: String
    let sets: [SetDetail]
}

struct SetDetail {
    let number: Int
    let weight: Int
    let reps: Int
    let actualReps: Int
}

struct HistoryDetailView: View {
    let selectedDate: Date
    let selectedDateString: String?
    @State private var showEditView = false
    @State private var historyList: [TrainingHistoryItem] = []
    @State private var selectedHistory: TrainingHistoryDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingHistoryList = false
    
    @ObservedObject private var trainingHistoryService = TrainingHistoryService.shared
    
    // 便利初始化器 - 接受Date对象（保持向后兼容）
    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        self.selectedDateString = nil
    }
    
    // 新的初始化器 - 接受字符串（推荐使用）
    init(selectedDateString: String) {
        // 创建一个虚拟的Date对象用于显示
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.selectedDate = formatter.date(from: selectedDateString) ?? Date()
        self.selectedDateString = selectedDateString
    }
    
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

    // 根据日期查找训练历史
    private func loadHistoryForDate() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
                selectedHistory = nil
                showingHistoryList = false
            }
            
            print("🔍 开始加载日期的训练历史详情")
            
            do {
                // 确定目标日期字符串
                let targetDateString: String
                if let dateString = selectedDateString {
                    // 直接使用传入的字符串
                    targetDateString = dateString
                    print("🎯 使用传入的日期字符串: \(targetDateString)")
                } else {
                    // 回退到Date对象解析（保持向后兼容）
                    var calendar = Calendar.current
                    calendar.timeZone = TimeZone.current
                    let targetDateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                    
                    targetDateString = String(format: "%04d-%02d-%02d", 
                                            targetDateComponents.year!, 
                                            targetDateComponents.month!, 
                                            targetDateComponents.day!)
                    
                    print("🎯 从Date对象解析的日期字符串: \(targetDateString)")
                }
                
                // 直接使用日期过滤参数查询特定日期的训练历史
                let response = try await trainingHistoryService.getTrainingHistory(
                    page: 1, 
                    limit: 100, 
                    planId: nil, 
                    startDate: targetDateString,
                    endDate: nil
                )
                
                print("📋 获取到 \(response.histories.count) 条该日期的训练历史记录")
                
                await MainActor.run {
                    self.historyList = response.histories
                    
                    if response.histories.isEmpty {
                        self.errorMessage = "该日期没有训练记录"
                        self.isLoading = false
                        print("❌ 该日期没有训练记录")
                    } else if response.histories.count == 1 {
                        // 只有一条记录，直接加载详情
                        print("✅ 找到1条训练历史，直接加载详情")
                        loadHistoryDetail(response.histories.first!)
                    } else {
                        // 多条记录，显示选择列表
                        print("✅ 找到 \(response.histories.count) 条训练历史，显示选择列表")
                        self.showingHistoryList = true
                        self.isLoading = false
                    }
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
    
    // 加载特定训练历史的详情
    private func loadHistoryDetail(_ history: TrainingHistoryItem) {
        Task {
            isLoading = true
            do {
                print("🔄 获取训练历史详情，ID: \(history.id)")
                let detail = try await trainingHistoryService.getTrainingHistoryDetail(historyId: history.id)
                
                await MainActor.run {
                    self.selectedHistory = detail
                    self.isLoading = false
                    self.showingHistoryList = false
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
        } else {
            return "\(minutes)分钟"
        }
    }

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                logoSection
                navigationSection
                
                if isLoading {
                    Spacer()
                    VStack {
                        ProgressView("加载训练详情...")
                        Text("正在加载 \(selectedDate, formatter: dateFormatter) 的训练数据")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    Spacer()
                } else if let errorMessage = errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("该日期没有训练记录")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(selectedDate, formatter: dateFormatter)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("点击其他有训练记录的日期查看详情")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else if showingHistoryList {
                    historyListSection
                } else if let selectedHistory = selectedHistory, detailData != nil {
                    contentScrollView([selectedHistory])
                } else if !historyList.isEmpty {
                    // 有历史记录但还没有选择具体的记录
                    Spacer()
                    VStack {
                        ProgressView("准备显示训练详情...")
                        Text("正在处理训练数据...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    Spacer()
                } else {
                    Spacer()
                    VStack {
                        Text("没有训练数据")
                            .foregroundColor(.gray)
                        Text("选中日期: \(selectedDate, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                    }
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            print("🎬 HistoryDetailView 出现，选中日期: \(selectedDate)")
            // 重置状态
            selectedHistory = nil
            showingHistoryList = false
            loadHistoryForDate()
        }
        .sheet(isPresented: $showEditView) {
            if let detailData = detailData {
                EditHistoryDetailView(
                    selectedDate: selectedDate,
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
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
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
    
    private var historyListSection: some View {
        VStack(spacing: 0) {
            Text("该日期有多条训练记录")
                .font(.headline)
                .padding()
            
            Text("请选择要查看的训练记录：")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(historyList, id: \.id) { history in
                        Button(action: {
                            loadHistoryDetail(history)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(history.plan_name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(formatTrainingTime(history.training_date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Text("时长: \(history.duration)分钟")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text("重量: \(Int(history.volume))kg")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }
    
    private func formatTrainingTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return timeFormatter.string(from: date)
        }
        return dateString
    }
    
    private func contentScrollView(_ data: [TrainingHistoryDetailResponse]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dateTimeSection
                
                if let detailData = detailData {
                    summarySection(detailData)
                    exercisesList(detailData)
                }
            }
            .padding()
        }
    }
    
    private var dateTimeSection: some View {
        HStack(spacing: 15) {
            Image(systemName: "clock")
                .foregroundColor(.secondary)
            Text("\(selectedDate, formatter: dateFormatter)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let selectedHistory = selectedHistory {
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
    HistoryDetailView(selectedDate: Date())
} 
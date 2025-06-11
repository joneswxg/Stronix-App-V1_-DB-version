import SwiftUI
import Charts

struct StatisticsView: View {
    @State private var selectedTab: StatisticsTab = .overview
    @State private var selectedTimeRange: TimeRange = .thisWeek
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // 统计数据
    @State private var statisticsData: StatisticsData?
    
    @ObservedObject private var trainingHistoryService = TrainingHistoryService.shared
    
    enum StatisticsTab: String, CaseIterable, Identifiable {
        case overview = "概览统计"
        case analysis = "动作分析"
        
        var id: String { self.rawValue }
    }
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case thisWeek = "本周"
        case thisMonth = "本月"
        case thisYear = "本年"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标签切换器
            Picker("统计选项", selection: $selectedTab) {
                ForEach(StatisticsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 10)
            
            // 根据选择显示对应内容
            switch selectedTab {
            case .overview:
                OverviewStatisticsView(
                    selectedTimeRange: $selectedTimeRange,
                    statisticsData: $statisticsData,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage
                )
            case .analysis:
                ActionAnalysisView()
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            loadStatisticsData()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            loadStatisticsData()
        }
    }
    
    private func loadStatisticsData() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                // 根据时间范围转换为API参数
                let timeRangeParam: String
                switch selectedTimeRange {
                case .thisWeek:
                    timeRangeParam = "week"
                case .thisMonth:
                    timeRangeParam = "month"
                case .thisYear:
                    timeRangeParam = "year"
                }
                
                print("📊 开始加载统计数据，时间范围: \(timeRangeParam)")
                
                // 调用API获取统计数据
                let response = try await trainingHistoryService.getTrainingStatistics(timeRange: timeRangeParam)
                
                await MainActor.run {
                    // 转换API数据为UI数据
                    statisticsData = convertToStatisticsData(response)
                    isLoading = false
                    print("✅ 统计数据加载成功")
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    print("❌ 加载统计数据失败: \(error)")
                }
            }
        }
    }
    
    /// 将API响应转换为UI数据模型
    private func convertToStatisticsData(_ response: TrainingStatisticsResponse) -> StatisticsData {
        // 转换容量趋势数据
        let volumeTrend = response.volume_trend.compactMap { item -> TrendData? in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: item.date) else { return nil }
            return TrendData(date: date, value: item.volume)
        }
        
        // 转换计划使用数据
        let planUsage = response.plan_usage.map { item in
            PlanUsageData(plan_name: item.plan_name, count: item.count, percentage: item.percentage)
        }
        
        return StatisticsData(
            totalVolume: Int(response.core_metrics.total_volume),
            totalDuration: response.core_metrics.total_duration,
            trainingCount: response.core_metrics.training_count,
            streakDays: response.core_metrics.streak_days,
            volumeTrend: volumeTrend,
            planUsage: planUsage
        )
    }
}

// MARK: - 概览统计视图
struct OverviewStatisticsView: View {
    @Binding var selectedTimeRange: StatisticsView.TimeRange
    @Binding var statisticsData: StatisticsData?
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 时间范围选择器
                timeRangeSelector
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let data = statisticsData {
                    statisticsContent(data)
                } else {
                    emptyView
                }
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var timeRangeSelector: some View {
        HStack {
            Text("时间范围")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
            
            Spacer()
            
            Menu {
                ForEach(StatisticsView.TimeRange.allCases) { range in
                    Button(range.rawValue) {
                        selectedTimeRange = range
                    }
                }
            } label: {
                HStack {
                    Text(selectedTimeRange.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.top, 10)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView("加载统计数据...")
            Text("正在分析您的训练数据")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("暂无统计数据")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("完成更多训练后查看统计信息")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func statisticsContent(_ data: StatisticsData) -> some View {
        VStack(spacing: 20) {
            // 核心指标卡片
            coreMetricsSection(data)
            
            // 训练容量趋势图
            volumeTrendSection(data)
            
            // 最常用训练计划
            planUsageSection(data)
        }
    }
    
    private func coreMetricsSection(_ data: StatisticsData) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("核心指标")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatisticsMetricCard(
                    title: "总训练容量",
                    value: formatVolumeNumber(data.totalVolume),
                    icon: "scalemass",
                    color: .blue
                )
                
                StatisticsMetricCard(
                    title: "总训练时长",
                    value: formatDuration(data.totalDuration),
                    icon: "clock",
                    color: .green
                )
                
                StatisticsMetricCard(
                    title: "训练次数",
                    value: "\(data.trainingCount)次",
                    icon: "figure.strengthtraining.traditional",
                    color: .orange
                )
                
                StatisticsMetricCard(
                    title: "连续训练",
                    value: "\(data.streakDays)天",
                    icon: "flame",
                    color: .red
                )
            }
        }
    }
    
    private func volumeTrendSection(_ data: StatisticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("训练容量趋势")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            Chart(data.volumeTrend) { item in
                LineMark(
                    x: .value("日期", item.date),
                    y: .value("容量", item.value)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                PointMark(
                    x: .value("日期", item.date),
                    y: .value("容量", item.value)
                )
                .foregroundStyle(.blue)
                .symbolSize(60)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Double.self) {
                            Text("\(Int(intValue/1000))k")
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month().day())
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    private func planUsageSection(_ data: StatisticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最常用训练计划")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            VStack(spacing: 12) {
                ForEach(Array(data.planUsage.enumerated()), id: \.0) { index, plan in
                    PlanUsageRow(
                        rank: index + 1,
                        planName: plan.plan_name,
                        count: plan.count,
                        percentage: plan.percentage
                    )
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    // 格式化数字
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000.0)
        }
        return "\(number)"
    }
    
    // 格式化容量数字（包含单位）
    private func formatVolumeNumber(_ number: Int) -> String {
        return "\(number)kg"
    }
    
    // 格式化时长
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)小时\(remainingMinutes)分"
        } else {
            return "\(remainingMinutes)分钟"
        }
    }
}

// MARK: - 动作分析视图
struct ActionAnalysisView: View {
    @State private var selectedAction: BigThreeAction = .squat
    @State private var actionProgressData: ActionProgressResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @ObservedObject private var trainingHistoryService = TrainingHistoryService.shared
    
    enum BigThreeAction: String, CaseIterable, Identifiable {
        case squat = "深蹲"
        case benchPress = "平板卧推"
        case deadlift = "硬拉"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .squat: return "figure.strengthtraining.traditional"
            case .benchPress: return "figure.strengthtraining.functional"
            case .deadlift: return "figure.strengthtraining.traditional"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 动作选择器
                actionSelector
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    // 当前记录卡片
                    currentRecordCard
                    
                    // 进步曲线图
                    progressChart
                    
                    // 容量趋势图
                    volumeChart
                }
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            loadActionProgress()
        }
        .onChange(of: selectedAction) { _, _ in
            loadActionProgress()
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView("加载动作数据...")
            Text("正在分析\(selectedAction.rawValue)的进步情况")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                loadActionProgress()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func loadActionProgress() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                print("💪 开始加载动作进步数据: \(selectedAction.rawValue)")
                
                // 调用API获取动作进步数据
                let response = try await trainingHistoryService.getActionProgress(actionName: selectedAction.rawValue)
                
                await MainActor.run {
                    actionProgressData = response
                    isLoading = false
                    print("✅ 动作进步数据加载成功")
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    print("❌ 加载动作进步数据失败: \(error)")
                }
            }
        }
    }
    
    private var actionSelector: some View {
        VStack(spacing: 16) {
            HStack {
                Text("选择动作")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
            }
            
            HStack(spacing: 12) {
                ForEach(BigThreeAction.allCases) { action in
                    ActionButton(
                        action: action,
                        isSelected: selectedAction == action
                    ) {
                        selectedAction = action
                    }
                }
            }
        }
        .padding(.top, 10)
    }
    
    private var currentRecordCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: selectedAction.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(selectedAction.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
            }
            
            HStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最大重量")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(actionProgressData?.best_record.max_weight ?? 0))kg")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                    Text(formatDate(actionProgressData?.best_record.date ?? ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近训练")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(actionProgressData?.current_record.max_weight ?? 0))kg × \(actionProgressData?.current_record.max_reps ?? 0)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                    Text(formatDate(actionProgressData?.current_record.date ?? ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
        return dateString
    }
    
    private var progressChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重量进步曲线")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            // 使用真实的进步数据
            let progressData = convertProgressData(actionProgressData?.progress_data ?? [])
            
            Chart(progressData) { item in
                LineMark(
                    x: .value("日期", item.date),
                    y: .value("重量", item.value)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                PointMark(
                    x: .value("日期", item.date),
                    y: .value("重量", item.value)
                )
                .foregroundStyle(.red)
                .symbolSize(60)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Double.self) {
                            Text("\(Int(intValue))kg")
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month())
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    private var volumeChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("训练容量趋势")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            // 使用真实的容量数据
            let volumeData = convertVolumeData(actionProgressData?.progress_data ?? [])
            
            Chart(volumeData) { item in
                AreaMark(
                    x: .value("日期", item.date),
                    y: .value("容量", item.value)
                )
                .foregroundStyle(.purple.opacity(0.3))
                
                LineMark(
                    x: .value("日期", item.date),
                    y: .value("容量", item.value)
                )
                .foregroundStyle(.purple)
                .lineStyle(StrokeStyle(lineWidth: 3))
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Double.self) {
                            Text("\(Int(intValue/1000))k")
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month())
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    /// 转换进步数据为图表数据
    private func convertProgressData(_ progressData: [ProgressData]) -> [TrendData] {
        return progressData.compactMap { item -> TrendData? in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: item.date) else { return nil }
            return TrendData(date: date, value: item.max_weight)
        }
    }
    
    /// 转换容量数据为图表数据
    private func convertVolumeData(_ progressData: [ProgressData]) -> [TrendData] {
        return progressData.compactMap { item -> TrendData? in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: item.date) else { return nil }
            return TrendData(date: date, value: item.total_volume)
        }
    }
}

// MARK: - 数据模型
struct StatisticsData {
    let totalVolume: Int
    let totalDuration: Int // 分钟
    let trainingCount: Int
    let streakDays: Int
    let volumeTrend: [TrendData]
    let planUsage: [PlanUsageData]
}

struct TrendData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct PlanUsageData {
    let plan_name: String
    let count: Int
    let percentage: Int
}

// MARK: - UI组件
struct StatisticsMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

struct PlanUsageRow: View {
    let rank: Int
    let planName: String
    let count: Int
    let percentage: Int
    
    var body: some View {
        HStack {
            // 排名
            Text("\(rank)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            // 计划名称
            Text(planName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
            
            Spacer()
            
            // 次数和百分比
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)次")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                Text("\(percentage)%")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ActionButton: View {
    let action: ActionAnalysisView.BigThreeAction
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(action.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

#Preview {
    StatisticsView()
} 
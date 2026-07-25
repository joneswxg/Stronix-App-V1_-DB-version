import SwiftUI
import Charts

enum ChartType {
    case volume
    case duration
}

enum TimeRange: String, CaseIterable, Identifiable {
    case currentMonth = "本月"
    case currentYear = "本年"
    
    var id: String { self.rawValue }
    
    // 获取日期范围显示文本
    var dateRangeText: String {
        let now = Date()
        let formatter = DateFormatter()
        
        switch self {
        case .currentMonth:
            formatter.dateFormat = "yyyy.M"
            return "(\(formatter.string(from: now)))"
        case .currentYear:
            formatter.dateFormat = "yyyy"
            return "(\(formatter.string(from: now)))"
        }
    }
    
    // 获取完整显示文本（包含日期范围）
    var displayText: String {
        return "\(self.rawValue) \(dateRangeText)"
    }
    
    var statisticsGranularity: String {
        switch self {
        case .currentMonth:
            return "(按天统计)"
        case .currentYear:
            return "(按月统计)"
        }
    }
}

struct StatisticsView: View {
    @Environment(\.theme) private var theme: AppTheme
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedTimeRange: TimeRange = .currentMonth
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // 统计数据
    @State private var statisticsData: StatisticsData?
    
    // 导航状态
    @State private var showBodyPartAnalysis = false
    @State private var selectedChartData: TrendData?
    @State private var showChartDetail = false
    @State private var selectedChartType: ChartType = .volume
    @State private var selectedDate: Date?

    @ObservedObject private var trainingHistoryService = TrainingHistoryService.shared
    @StateObject private var viewModel = ActionListViewModel()
    
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
                
                // 部位统计部分 - 暂时隐藏，后续开发
                // bodyPartAnalysisSection
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
        }
        .background(theme.background)
        .onAppear {
            loadStatisticsData()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            loadStatisticsData()
        }
        .sheet(isPresented: $showChartDetail) {
            if let data = selectedChartData {
                ChartDetailView(data: data, timeRange: selectedTimeRange, chartType: selectedChartType)
                    .presentationDetents([.height(120)])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(16)
            }
        }
    }
    
    private var timeRangeSelector: some View {
        HStack {
            Text("时间范围")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.onSurface)
            
            Spacer()
            
            Menu {
                ForEach(TimeRange.allCases) { range in
                    Button(range.displayText) {
                        selectedTimeRange = range
                    }
                }
            } label: {
                HStack {
                    Text(selectedTimeRange.displayText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.onSurface)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
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
                .foregroundColor(theme.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(theme.warning)
            
            Text("加载失败")
                .font(.headline)
                .foregroundColor(theme.onSurface)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 50))
                .foregroundColor(theme.secondary)
            
            Text("暂无统计数据")
                .font(.headline)
                .foregroundColor(theme.onSurface)
            
            Text("完成更多训练后查看统计信息")
                .font(.subheadline)
                .foregroundColor(theme.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func statisticsContent(_ data: StatisticsData) -> some View {
        VStack(spacing: 20) {
            coreMetricsSection(data)
            volumeTrendSection(data)
            durationTrendSection(data)
        }
    }
    
    private func coreMetricsSection(_ data: StatisticsData) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("概况")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.onSurface)
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
                    color: theme.primary
                )
                
                StatisticsMetricCard(
                    title: "总训练时长",
                    value: formatDuration(data.totalDuration),
                    icon: "clock",
                    color: theme.success
                )
                
                StatisticsMetricCard(
                    title: "训练次数",
                    value: "\(data.trainingCount)次",
                    icon: "figure.strengthtraining.traditional",
                    color: theme.warning
                )
                
                StatisticsMetricCard(
                    title: "训练天数",
                    value: "\(data.trainingDays)天",
                    icon: "calendar",
                    color: theme.error
                )
            }
        }
    }
    
    private func volumeTrendSection(_ data: StatisticsData) -> some View {
        let chartData = generateFixedAxisData(volumeData: data.volumeTrend)
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("训练容量趋势 \(selectedTimeRange.statisticsGranularity)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.onSurface)
            
            volumeChart(chartData: chartData)
        }
        .padding(16)
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: theme.shadow.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    // 部位统计部分 - 暂时隐藏，后续开发
    /*
    private var bodyPartAnalysisSection: some View {
        Button(action: {
            showBodyPartAnalysis = true
        }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 20))
                        .foregroundColor(theme.primary)
                    
                    Text("部位统计")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondary)
                }
                
                Text("查看各部位的训练容量和时长统计")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(theme.surface)
            .cornerRadius(12)
            .shadow(color: theme.shadow.opacity(0.1), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showBodyPartAnalysis) {
            BodyPartAnalysisView()
        }
    }
    */
    
    private func volumeChart(chartData: [TrendData]) -> some View {
        let filteredData = chartData.filter { $0.value > 0 }
        let maxValue = filteredData.map { $0.value }.max() ?? 0
        let yScaleDomain = 0...max(maxValue, 10)
        let xScaleDomain = getXAxisDomain(chartData: chartData)
        
        return Chart(filteredData) { item in
            BarMark(
                x: .value("日期", item.date),
                y: .value("容量", item.value)
            )
            .foregroundStyle(theme.primary)
            .opacity(selectedDate == item.date ? 0.7 : 1.0)
        }
        .chartAngleSelection(value: .constant(nil as Double?))
        .chartOverlay { chartProxy in
            volumeChartBackground(chartProxy: chartProxy, filteredData: filteredData, xDomain: xScaleDomain)
        }
        .frame(height: 200)
        .chartXScale(domain: xScaleDomain)
        .chartYScale(domain: yScaleDomain)
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
            AxisMarks { _ in
                AxisGridLine()
            }
        }
    }
    
    private func volumeChartBackground(chartProxy: ChartProxy, filteredData: [TrendData], xDomain: ClosedRange<Date>) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    guard !filteredData.isEmpty else { return }
                    
                    // 获取图表的实际绘制区域
                    guard let plotFrame = chartProxy.plotFrame else { return }
                    let plotAreaFrame = geometry[plotFrame]
                    
                    // 计算点击位置在绘制区域内的相对位置
                    let relativeX = (location.x - plotAreaFrame.minX) / plotAreaFrame.width
                    let clampedRelativeX = max(0, min(relativeX, 1))
                    
                    // 根据X轴domain计算对应的日期
                    let timeInterval = xDomain.upperBound.timeIntervalSince(xDomain.lowerBound)
                    let targetDate = Date(timeIntervalSince1970: xDomain.lowerBound.timeIntervalSince1970 + timeInterval * clampedRelativeX)
                    
                    // 找到最接近的数据点
                    let closestData = filteredData.min { data1, data2 in
                        abs(data1.date.timeIntervalSince(targetDate)) < abs(data2.date.timeIntervalSince(targetDate))
                    }
                    
                    if let selectedData = closestData {
                        self.selectedChartData = selectedData
                        self.selectedDate = selectedData.date
                        self.selectedChartType = .volume
                        self.showChartDetail = true
                    }
                }
        }
    }
    
    private func durationChart(chartData: [TrendData]) -> some View {
        let filteredData = chartData.filter { $0.value > 0 }
        let maxValue = filteredData.map { $0.value }.max() ?? 0
        let yScaleDomain = 0...max(maxValue, 10)
        let xScaleDomain = getXAxisDomain(chartData: chartData)
        
        return Chart(chartData) { item in
            BarMark(
                x: .value("日期", item.date),
                y: .value("时长", item.value)
            )
            .foregroundStyle(theme.success)
            .opacity(selectedDate == item.date ? 0.7 : 1.0)
        }
        .chartOverlay { chartProxy in
            durationChartBackground(chartProxy: chartProxy, filteredData: chartData, xDomain: xScaleDomain)
        }
        .frame(height: 200)
        .chartXScale(domain: xScaleDomain)
        .chartYScale(domain: yScaleDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Double.self) {
                        Text("\(Int(intValue))m")
                            .font(.caption)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
            }
        }
    }
    
    private func durationChartBackground(chartProxy: ChartProxy, filteredData: [TrendData], xDomain: ClosedRange<Date>) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    guard !filteredData.isEmpty else { return }
                    
                    guard let plotFrame = chartProxy.plotFrame else { return }
                    let plotAreaFrame = geometry[plotFrame]
                    let relativeX = (location.x - plotAreaFrame.minX) / plotAreaFrame.width
                    let clampedRelativeX = max(0, min(relativeX, 1))
                    
                    // 根据X轴domain计算对应的日期
                    let timeInterval = xDomain.upperBound.timeIntervalSince(xDomain.lowerBound)
                    let targetDate = Date(timeIntervalSince1970: xDomain.lowerBound.timeIntervalSince1970 + timeInterval * clampedRelativeX)
                    
                    // 找到最接近的数据点
                    let closestData = filteredData.min { abs($0.date.timeIntervalSince(targetDate)) < abs($1.date.timeIntervalSince(targetDate)) }
                    
                    if let selectedData = closestData {
                        selectedChartData = selectedData
                        selectedDate = selectedData.date
                        selectedChartType = .duration
                        showChartDetail = true
                    }
                }
        }
    }
    
    private func durationTrendSection(_ data: StatisticsData) -> some View {
        let chartData = generateFixedAxisData(volumeData: data.durationTrend)
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("训练时长趋势 \(selectedTimeRange.statisticsGranularity)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.onSurface)
            
            durationChart(chartData: chartData)
        }
        .padding(16)
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: theme.shadow.opacity(0.1), radius: 3, x: 0, y: 2)
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
    
    // 根据时间范围获取合适的日期格式
    private func getDateFormat() -> Date.FormatStyle {
        switch selectedTimeRange {
        case .currentMonth:
            return .dateTime.month().day() // "Jun 1"
        case .currentYear:
            return .dateTime.month(.abbreviated) // "Jun"
        }
    }
    
    // 生成固定轴数据
    private func generateFixedAxisData(volumeData: [TrendData]) -> [TrendData] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .currentMonth:
            // 显示当月每天
            var fixedData: [TrendData] = []
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let monthRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
            
            for day in monthRange {
                if let dayInMonth = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                    // 查找该天的所有数据并累加
                    let dayDataList = volumeData.filter { item in
                        calendar.isDate(item.date, inSameDayAs: dayInMonth)
                    }
                    let dayVolume = dayDataList.reduce(0) { $0 + $1.value }
                    
                    fixedData.append(TrendData(date: dayInMonth, value: dayVolume))
                }
            }
            return fixedData
            
        case .currentYear:
            // 显示12个月
            var fixedData: [TrendData] = []
            for i in 0..<12 {
                let monthDate = calendar.date(byAdding: .month, value: -11 + i, to: now) ?? now
                let monthStart = calendar.dateInterval(of: .month, for: monthDate)?.start ?? monthDate
                
                // 查找该月的数据（累加该月所有天的数据）
                var monthVolume: Double = 0
                let monthRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<32
                for day in monthRange {
                    if let dayInMonth = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                        let dayDataList = volumeData.filter { item in
                            calendar.isDate(item.date, inSameDayAs: dayInMonth)
                        }
                        monthVolume += dayDataList.reduce(0) { $0 + $1.value }
                    }
                }
                
                fixedData.append(TrendData(date: monthStart, value: monthVolume))
            }
            return fixedData
        }
    }
    
    // 获取格式化的轴标签
    private func getFormattedAxisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        
        switch selectedTimeRange {
        case .currentMonth:
            // 显示每天的日期
            formatter.dateFormat = "d"
            return formatter.string(from: date)
            
        case .currentYear:
            formatter.dateFormat = "M月"
            return formatter.string(from: date)
        }
    }
    
    // 获取x轴范围
    private func getXAxisDomain(chartData: [TrendData]) -> ClosedRange<Date> {
        guard let firstDate = chartData.first?.date,
              let lastDate = chartData.last?.date else {
            let now = Date()
            return now...now
        }
        
        // 为了确保柱状图居中显示，在首尾添加一些边距
        let startPadding: TimeInterval
        let endPadding: TimeInterval
        
        switch selectedTimeRange {
        case .currentMonth:
            startPadding = -0.5 * 24 * 3600 // 0.5天
            endPadding = 0.5 * 24 * 3600    // 0.5天
        case .currentYear:
            startPadding = -15 * 24 * 3600  // 15天
            endPadding = 15 * 24 * 3600     // 15天
        }
        
        let startDate = firstDate.addingTimeInterval(startPadding)
        let endDate = lastDate.addingTimeInterval(endPadding)
        
        return startDate...endDate
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
                case .currentMonth:
                    timeRangeParam = "current_month"
                case .currentYear:
                    timeRangeParam = "current_year"
                }
                
                print("📊 开始加载统计数据，时间范围: \(timeRangeParam)")
                
                // 调用API获取统计数据
                let response = try await trainingHistoryService.getTrainingStatistics(timeRange: timeRangeParam)
                var statisticsData = convertToStatisticsData(response)
                
                // 对于"本年"时间范围，需要额外获取准确的训练天数
                if timeRangeParam == "current_year" {
                    do {
                        let calendar = Calendar.current
                        let now = Date()
                        let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        let startDateString = dateFormatter.string(from: startOfYear)
                        let endDateString = dateFormatter.string(from: now)
                        
                        print("🗓️ 获取本年训练天数: \(startDateString) 到 \(endDateString)")
                        
                        let trainingDatesResponse = try await trainingHistoryService.getTrainingDates(
                            startDate: startDateString,
                            endDate: endDateString
                        )
                        
                        // 更新训练天数为准确值
                        statisticsData = StatisticsData(
                            totalVolume: statisticsData.totalVolume,
                            totalDuration: statisticsData.totalDuration,
                            trainingCount: statisticsData.trainingCount,
                            trainingDays: trainingDatesResponse.total_days,
                            volumeTrend: statisticsData.volumeTrend,
                            durationTrend: statisticsData.durationTrend
                        )
                        
                        print("✅ 本年训练天数更新为: \(trainingDatesResponse.total_days)")
                        
                    } catch {
                        print("⚠️ 获取本年训练天数失败，使用默认值: \(error)")
                    }
                }
                
                await MainActor.run {
                    // 转换API数据为UI数据
                    self.statisticsData = statisticsData
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
            
            guard let date = formatter.date(from: item.date) else { 
                return nil 
            }
            
            return TrendData(date: date, value: item.volume)
        }
        
        // 转换时长趋势数据
        let durationTrend = response.duration_trend.compactMap { item -> TrendData? in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            guard let date = formatter.date(from: item.date) else { 
                return nil 
            }
            
            return TrendData(date: date, value: Double(item.duration))
        }
        
        // 计算实际训练天数：根据时间范围使用不同的计算方法
        let actualTrainingDays: Int
        
        switch response.time_range {
        case "current_month":
            // 对于本月，统计volume_trend中的不重复日期数量
            let uniqueTrainingDates = Set(response.volume_trend.map { $0.date })
            actualTrainingDays = uniqueTrainingDates.count
            
        case "current_year":
            // 对于本年，需要通过getTrainingDates方法获取准确的训练天数
            // 这里先使用训练次数作为临时值，实际值将在loadStatisticsData中异步获取
            actualTrainingDays = response.core_metrics.training_count
            
        default:
            // 其他时间范围，使用volume_trend中的不重复日期数量
            let uniqueTrainingDates = Set(response.volume_trend.map { $0.date })
            actualTrainingDays = uniqueTrainingDates.count
        }
        
        print("📊 训练统计数据转换:")
        print("   - 时间范围: \(response.time_range)")
        print("   - 训练次数: \(response.core_metrics.training_count)")
        print("   - 训练天数: \(actualTrainingDays)")
        print("   - Volume趋势数据点数: \(response.volume_trend.count)")
        
        return StatisticsData(
            totalVolume: Int(response.core_metrics.total_volume),
            totalDuration: response.core_metrics.total_duration,
            trainingCount: response.core_metrics.training_count,
            trainingDays: actualTrainingDays,
            volumeTrend: volumeTrend,
            durationTrend: durationTrend
        )
    }
}

// MARK: - 数据模型
struct StatisticsData {
    let totalVolume: Int
    let totalDuration: Int // 分钟
    let trainingCount: Int
    let trainingDays: Int // 训练天数
    let volumeTrend: [TrendData]
    let durationTrend: [TrendData]
}

struct TrendData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - 统计指标卡片
struct StatisticsMetricCard: View {
    @Environment(\.theme) private var theme: AppTheme
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
                .foregroundColor(theme.onSurface)
            
            Text(title)
                .font(.caption)
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: theme.shadow.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}



struct ChartDetailView: View {
    @Environment(\.theme) private var theme: AppTheme
    @Environment(\.dismiss) private var dismiss
    
    let data: TrendData
    let timeRange: TimeRange
    let chartType: ChartType
    
    var body: some View {
        VStack(spacing: 8) {
            // 数值显示
            if chartType == .volume {
                Text("\(Int(data.value))kg")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.onSurface)
            } else {
                Text(formatDurationForDetail(data.value))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.onSurface)
            }
            
            // 日期范围
            Text(formatDateForDetail(data.date))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(theme.background)
    }
    
    private func formatDateForDetail(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        switch timeRange {
        case .currentMonth:
            formatter.dateFormat = "M月d日 EEEE"
            return formatter.string(from: date)
        case .currentYear:
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: date)
        }
    }
    
    private func getStatisticsPeriodText() -> String {
        switch timeRange {
        case .currentMonth:
            return "按天统计"
        case .currentYear:
            return "按月统计"
        }
    }
    
    private func formatDurationForDetail(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        
        if hours > 0 {
            return "\(hours)小时\(mins)分钟"
        } else {
            return "\(mins)分钟"
        }
    }
}

#Preview {
    StatisticsView()
}

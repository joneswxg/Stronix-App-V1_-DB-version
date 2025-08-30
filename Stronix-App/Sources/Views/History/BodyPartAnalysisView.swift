import SwiftUI
import Charts

/// 部位统计视图类型
enum BodyPartViewType: String, CaseIterable, Identifiable {
    case weekly = "周视图"
    case monthly = "月视图"
    
    var id: String { self.rawValue }
}

/// 数据模型
struct BodyPartAnalysisData: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
    let duration: Double // 分钟
}

/// 独立的部位统计视图
struct BodyPartAnalysisView: View {
    @Environment(\.theme) private var theme: AppTheme
    @State private var selectedViewType: BodyPartViewType = .weekly
    @State private var selectedBodyPartId: Int = 6 // 默认选择上臂
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // 数据状态
    @State private var weeklyData: [BodyPartAnalysisData] = []
    @State private var monthlyData: [BodyPartAnalysisData] = []
    
    @ObservedObject private var trainingHistoryService = TrainingHistoryService.shared
    @StateObject private var viewModel = ActionListViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 标题
                headerSection
                
                // 视图类型选择器
                viewTypeSelector
                
                // 部位选择器
                bodyPartSelector
                
                // 年份选择器（仅月视图显示）
                if selectedViewType == .monthly {
                    yearSelector
                }
                
                // 图表内容
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    chartContent
                }
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
        }
        .background(theme.background)
        .onAppear {
            loadData()
        }
        .onChange(of: selectedViewType) { _, _ in
            loadData()
        }
        .onChange(of: selectedBodyPartId) { _, _ in
            loadData()
        }
        .onChange(of: selectedYear) { _, _ in
            if selectedViewType == .monthly {
                loadData()
            }
        }
    }
    
    // MARK: - 视图组件
    
    private var headerSection: some View {
        HStack {
            Text("部位统计")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.onSurface)
            Spacer()
        }
        .padding(.top, 10)
    }
    
    private var viewTypeSelector: some View {
        HStack {
            ForEach(BodyPartViewType.allCases) { viewType in
                Button(action: {
                    selectedViewType = viewType
                }) {
                    Text(viewType.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selectedViewType == viewType ? .white : theme.onSurface)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedViewType == viewType ? theme.primary : theme.surface)
                        )
                }
            }
            Spacer()
        }
    }
    
    private var bodyPartSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择部位")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.onSurface)
            
            Menu {
                ForEach(viewModel.bodyParts, id: \.id) { bodyPart in
                    Button(bodyPart.display_name) {
                        selectedBodyPartId = bodyPart.id
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                    Text(viewModel.bodyParts.first(where: { $0.id == selectedBodyPartId })?.display_name ?? "上臂")
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .foregroundColor(theme.onSurface)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    private var yearSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择年份")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.onSurface)
            
            Menu {
                ForEach(getAvailableYears(), id: \.self) { year in
                    Button("\(year)年") {
                        selectedYear = year
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                    Text("\(selectedYear)年")
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .foregroundColor(theme.onSurface)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView("加载部位统计数据...")
            Text("正在分析您的训练数据")
                .font(.caption)
                .foregroundColor(theme.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(theme.secondary)
            
            Text("加载失败")
                .font(.headline)
                .foregroundColor(theme.onSurface)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    private var chartContent: some View {
        VStack(spacing: 20) {
            // 训练容量图表
            volumeChartSection
            
            // 训练时长图表
            durationChartSection
        }
    }
    
    private var volumeChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("训练容量")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.onSurface)
                Spacer()
                Text(selectedViewType == .weekly ? "过去10周" : "\(selectedYear)年1-12月")
                    .font(.caption)
                    .foregroundColor(theme.secondary)
            }
            
            if getCurrentData().isEmpty {
                Text("暂无数据")
                    .foregroundColor(theme.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(getCurrentData()) { item in
                    BarMark(
                        x: .value("日期", item.date),
                        y: .value("容量", item.volume)
                    )
                    .foregroundStyle(theme.primary)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: getXAxisFormat())
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: theme.shadow.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    private var durationChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("训练时长")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.onSurface)
                Spacer()
                Text(selectedViewType == .weekly ? "过去10周" : "\(selectedYear)年1-12月")
                    .font(.caption)
                    .foregroundColor(theme.secondary)
            }
            
            if getCurrentData().isEmpty {
                Text("暂无数据")
                    .foregroundColor(theme.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(getCurrentData()) { item in
                    BarMark(
                        x: .value("日期", item.date),
                        y: .value("时长", item.duration)
                    )
                    .foregroundStyle(theme.accent)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: getXAxisFormat())
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: theme.shadow.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    // MARK: - 辅助方法
    
    private func getCurrentData() -> [BodyPartAnalysisData] {
        return selectedViewType == .weekly ? weeklyData : monthlyData
    }
    
    private func getXAxisFormat() -> Date.FormatStyle {
        if selectedViewType == .weekly {
            // 周视图：显示每周第一天的日期，竖直显示
            return .dateTime.year().month(.twoDigits).day(.twoDigits)
        } else {
            // 月视图：显示月份
            return .dateTime.month(.abbreviated)
        }
    }
    
    private func getAvailableYears() -> [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear-2)...(currentYear)).reversed()
    }
    
    private func loadData() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                guard let selectedBodyPart = viewModel.bodyParts.first(where: { $0.id == selectedBodyPartId }) else {
                    await MainActor.run {
                        errorMessage = "未找到对应的身体部位"
                        isLoading = false
                    }
                    return
                }
                
                let bodyPartName = selectedBodyPart.display_name
                
                if selectedViewType == .weekly {
                    // 加载周数据（过去10周）
                    async let volumeResponse = trainingHistoryService.getWeeklyVolumeByBodyPart(bodyPart: bodyPartName)
                    async let durationResponse = trainingHistoryService.getWeeklyDurationByBodyPart(bodyPart: bodyPartName)
                    
                    let (volumeResult, durationResult) = try await (volumeResponse, durationResponse)
                    
                    await MainActor.run {
                        weeklyData = combineWeeklyData(volumeData: volumeResult, durationData: durationResult)
                        isLoading = false
                    }
                } else {
                    // 加载月数据（指定年份的1-12月）
                    let monthlyVolumeData = try await getMonthlyVolumeByBodyPart(bodyPart: bodyPartName, year: selectedYear)
                    let monthlyDurationData = try await getMonthlyDurationByBodyPart(bodyPart: bodyPartName, year: selectedYear)
                    
                    await MainActor.run {
                        monthlyData = combineMonthlyData(volumeData: monthlyVolumeData, durationData: monthlyDurationData, year: selectedYear)
                        isLoading = false
                    }
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "加载数据失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func combineWeeklyData(volumeData: [VolumeTrendData], durationData: [DurationTrendData]) -> [BodyPartAnalysisData] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var combinedData: [BodyPartAnalysisData] = []
        
        // 创建日期到容量的映射
        let volumeMap = Dictionary(uniqueKeysWithValues: volumeData.map { ($0.date, $0.volume) })
        
        // 创建日期到时长的映射
        let durationMap = Dictionary(uniqueKeysWithValues: durationData.map { ($0.date, Double($0.duration)) })
        
        // 获取所有唯一日期
        let allDates = Set(volumeData.map { $0.date } + durationData.map { $0.date })
        
        for dateString in allDates.sorted() {
            guard let date = dateFormatter.date(from: dateString) else { continue }
            
            let volume = volumeMap[dateString] ?? 0.0
            let duration = durationMap[dateString] ?? 0.0
            
            combinedData.append(BodyPartAnalysisData(
                date: date,
                volume: volume,
                duration: duration
            ))
        }
        
        return combinedData.sorted { $0.date < $1.date }
    }
    
    private func combineMonthlyData(volumeData: [VolumeTrendData], durationData: [DurationTrendData], year: Int) -> [BodyPartAnalysisData] {
        var combinedData: [BodyPartAnalysisData] = []
        
        // 为1-12月创建数据
        for month in 1...12 {
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            
            guard let date = calendar.date(from: components) else { continue }
            
            // 查找对应月份的数据
            let monthString = String(format: "%04d-%02d", year, month)
            
            let volume = volumeData.first { $0.date.hasPrefix(monthString) }?.volume ?? 0.0
            let duration = Double(durationData.first { $0.date.hasPrefix(monthString) }?.duration ?? 0)
            
            combinedData.append(BodyPartAnalysisData(
                date: date,
                volume: volume,
                duration: duration
            ))
        }
        
        return combinedData
    }
    
    private func getMonthlyVolumeByBodyPart(bodyPart: String, year: Int) async throws -> [VolumeTrendData] {
        return try await trainingHistoryService.getMonthlyVolumeByBodyPart(bodyPart: bodyPart, year: year)
    }
    
    private func getMonthlyDurationByBodyPart(bodyPart: String, year: Int) async throws -> [DurationTrendData] {
        return try await trainingHistoryService.getMonthlyDurationByBodyPart(bodyPart: bodyPart, year: year)
    }
}

#Preview {
    BodyPartAnalysisView()
}
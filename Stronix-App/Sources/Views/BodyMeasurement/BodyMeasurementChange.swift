import SwiftUI
import Charts

// MARK: - 图表数据模型
struct MeasurementData {
    let date: Date
    let weight: Double
    let muscleMass: Double
    let bodyFatPercentage: Double
}

struct BodyMeasurementChange: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var userSession: UserSession
    @StateObject private var viewModel = BodyMeasurementViewModel()
    @State private var selectedStartDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var selectedEndDate = Date()
    @State private var showingDatePicker = false
    @State private var selectedDataIndex: Int? = nil
    
    // 从真实数据转换为图表数据，按日期排序并过滤
    private var chartData: [MeasurementData] {
        return viewModel.measurements
            .filter { record in
                // 过滤在选定日期范围内的数据
                record.measurementTimestamp >= selectedStartDate && record.measurementTimestamp <= selectedEndDate
            }
            .sorted { $0.measurementTimestamp < $1.measurementTimestamp } // 按日期从早到晚排序
            .map { record in
                MeasurementData(
                    date: record.measurementTimestamp,
                    weight: record.weightKg,
                    muscleMass: record.skeletalMuscleMassKg,
                    bodyFatPercentage: record.bodyFatPercentage
                )
            }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 日期选择区域
                dateSelectionSection
                
                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if chartData.isEmpty {
                    emptyStateView
                } else {
                    // 基础代谢率图表
                    chartCard(
                        title: "基础代谢率",
                        unit: "kcal",
                        currentValue: calculateCurrentBMR(),
                        data: chartData.map { calculateBMRWithKatchMcArdle(weight: $0.weight, bodyFatPercentage: $0.bodyFatPercentage) }
                    )
                    
                    // 体重图表
                    chartCard(
                        title: "体重",
                        unit: "kg",
                        currentValue: chartData.last?.weight ?? 0,
                        data: chartData.map { $0.weight }
                    )
                    
                    // 骨骼肌量图表
                    chartCard(
                        title: "骨骼肌量",
                        unit: "kg",
                        currentValue: chartData.last?.muscleMass ?? 0,
                        data: chartData.map { $0.muscleMass }
                    )
                    
                    // 体脂肪图表
                    chartCard(
                        title: "体脂肪",
                        unit: "kg",
                        currentValue: calculateCurrentBodyFatKg(),
                        data: chartData.map { $0.weight * $0.bodyFatPercentage / 100 }
                    )
                    
                    // BMI图表
                    chartCard(
                        title: "BMI",
                        unit: "kg/m²",
                        currentValue: calculateCurrentBMI(),
                        data: chartData.map { calculateBMI(weight: $0.weight, height: getLatestHeight()) }
                    )
                    
                    // 体脂百分比图表
                    chartCard(
                        title: "体脂百分比",
                        unit: "%",
                        currentValue: chartData.last?.bodyFatPercentage ?? 0,
                        data: chartData.map { $0.bodyFatPercentage }
                    )
                    
                    // 内脏脂肪等级图表
                    chartCard(
                        title: "内脏脂肪等级",
                        unit: "Level",
                        currentValue: Double(getLatestVisceralFatLevel()),
                        data: getVisceralFatLevelData()
                    )
                }
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
        }
        .background(theme.background)
        .task {
            userSession.registerResetter(viewModel)
        }
        .onAppear {
            Task {
                await viewModel.loadMeasurements()
            }
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .sheet(isPresented: $showingDatePicker) {
            DateRangePickerView(
                startDate: $selectedStartDate,
                endDate: $selectedEndDate,
                onDismiss: {
                    showingDatePicker = false
                    // 重置选中的数据点索引
                    selectedDataIndex = nil
                }
            )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(theme.secondary)
            
            Text("暂无体测数据")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(theme.secondary)
            
            Text("请先添加体测记录")
                .font(.system(size: 14))
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }
    
    private var dateSelectionSection: some View {
        HStack(spacing: 16) {
            Button(action: {
                showingDatePicker = true
            }) {
                HStack {
                    Text(formatDateRange())
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
            
            Spacer()
            
            Button(action: {
                // 显示项设置功能
            }) {
                Image(systemName: "gearshape")
                    .foregroundColor(theme.secondary)
            }
        }
        .padding(.top, 10)
    }
    
    private func chartCard(title: String, unit: String, currentValue: Double, data: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title + " (\(unit))")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
            
            // 显示选中点的信息或当前值
            dataDisplaySection(unit: unit, currentValue: currentValue, data: data)
            
            // 图表
            chartSection(data: data)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func dataDisplaySection(unit: String, currentValue: Double, data: [Double]) -> some View {
        HStack {
            if let selectedIndex = selectedDataIndex, selectedIndex < chartData.count {
                Text(formatSelectedDate(chartData[selectedIndex].date))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(data[selectedIndex], specifier: "%.1f")\(unit)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
            } else {
                Text(formatCurrentDate())
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(currentValue, specifier: "%.1f")\(unit)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
            }
        }
    }
    
    private func chartSection(data: [Double]) -> some View {
        let chartDataWithValues = Array(zip(chartData, data))
        
        return Chart(chartDataWithValues, id: \.0.date) { measurementData, value in
            LineMark(
                x: .value("Date", measurementData.date),
                y: .value("Value", value)
            )
            .foregroundStyle(theme.primary)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            PointMark(
                x: .value("Date", measurementData.date),
                y: .value("Value", value)
            )
            .foregroundStyle(theme.primary)
            .symbolSize(40)
            
            // 显示选中点的垂直虚线
            if let selectedIndex = selectedDataIndex, selectedIndex < chartData.count,
               chartData[selectedIndex].date == measurementData.date {
                RuleMark(x: .value("Selected", measurementData.date))
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .frame(height: 120)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatChartDate(date))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .chartYScale(domain: getChartYDomain(data: data))
        .onTapGesture { location in
            handleChartTap(location: location)
        }
    }
    
    private func handleChartTap(location: CGPoint) {
        // 计算点击位置对应的数据点
        let chartWidth = UIScreen.main.bounds.width - 72 // 减去padding
        guard chartData.count > 1 else { 
            selectedDataIndex = 0
            return 
        }
        
        // 基于日期范围计算点击位置
        let startDate = chartData.first?.date ?? Date()
        let endDate = chartData.last?.date ?? Date()
        let totalTimeInterval = endDate.timeIntervalSince(startDate)
        
        if totalTimeInterval > 0 {
            let relativePosition = location.x / chartWidth
            let targetTimeInterval = startDate.timeIntervalSince1970 + (totalTimeInterval * relativePosition)
            let targetDate = Date(timeIntervalSince1970: targetTimeInterval)
            
            // 找到最接近的数据点
            guard !chartData.isEmpty else { return }
            var closestIndex = 0
            guard let firstData = chartData.first else { return }
            var minTimeDifference = abs(firstData.date.timeIntervalSince(targetDate))
            
            for (index, data) in chartData.enumerated() {
                let timeDifference = abs(data.date.timeIntervalSince(targetDate))
                if timeDifference < minTimeDifference {
                    minTimeDifference = timeDifference
                    closestIndex = index
                }
            }
            
            selectedDataIndex = closestIndex
        } else {
            selectedDataIndex = 0
        }
    }
    
    private func getChartYDomain(data: [Double]) -> ClosedRange<Double> {
        guard let minValue = data.min(), let maxValue = data.max() else {
            return 0...100
        }
        
        let padding = max(0.5, (maxValue - minValue) * 0.1)
        let lowerBound = max(0, minValue - padding)
        let upperBound = maxValue + padding
        
        return lowerBound...upperBound
    }
    
    private func formatDateRange() -> String {
        let calendar = Calendar.current
        let isToday = calendar.isDate(selectedEndDate, inSameDayAs: Date())
        
        if isToday {
            return "\(BodyMeasurementDateFormatting.changeRangeDate(selectedStartDate)) ~ 最近"
        } else {
            return "\(BodyMeasurementDateFormatting.changeRangeDate(selectedStartDate)) ~ \(BodyMeasurementDateFormatting.changeRangeDate(selectedEndDate))"
        }
    }
    
    private func formatCurrentDate() -> String {
        BodyMeasurementDateFormatting.changeDateTime(selectedEndDate)
    }

    private func formatSelectedDate(_ date: Date) -> String {
        BodyMeasurementDateFormatting.changeDateTime(date)
    }

    private func formatChartDate(_ date: Date) -> String {
        BodyMeasurementDateFormatting.changeChartLabel(date)
    }
    
    // MARK: - 计算函数
    private func getLatestHeight() -> Double {
        return getLatestMeasurement()?.heightCm ?? 175.0
    }
    
    private func getLatestVisceralFatLevel() -> Int {
        return getLatestMeasurement()?.visceralFatLevel ?? 3
    }
    
    private func getVisceralFatLevelData() -> [Double] {
        // 创建一个映射，将过滤和排序后的数据与原始数据匹配
        let filteredAndSortedMeasurements = viewModel.measurements
            .filter { record in
                record.measurementTimestamp >= selectedStartDate && record.measurementTimestamp <= selectedEndDate
            }
            .sorted { $0.measurementTimestamp < $1.measurementTimestamp }
        return filteredAndSortedMeasurements.map { Double($0.visceralFatLevel) }
    }
    
    private func calculateCurrentBMR() -> Double {
        guard let latest = getLatestMeasurement() else { return 0 }
        return latest.calculateBMR(age: 25, gender: "male") // TODO: 从用户信息获取年龄和性别
    }
    
    private func calculateCurrentBMI() -> Double {
        guard let latest = getLatestMeasurement() else { return 0 }
        return latest.bmi
    }
    
    private func calculateCurrentBodyFatKg() -> Double {
        guard let latest = getLatestMeasurement() else { return 0 }
        return latest.bodyFatKg
    }
    
    private func getLatestMeasurement() -> BodyMeasurement? {
        return viewModel.measurements
            .filter { record in
                record.measurementTimestamp >= selectedStartDate && record.measurementTimestamp <= selectedEndDate
            }
            .sorted { $0.measurementTimestamp < $1.measurementTimestamp }
            .last
    }
    
    private func calculateBMR(weight: Double, height: Double) -> Double {
        // 使用Mifflin-St Jeor公式计算BMR (已弃用，保留兼容性)
        return 10 * weight + 6.25 * height - 5 * 25 + 5 // 假设25岁男性
    }
    
    private func calculateBMRWithKatchMcArdle(weight: Double, bodyFatPercentage: Double) -> Double {
        // 使用Katch-McArdle公式计算BMR
        // 计算瘦体重 (Lean Body Mass, LBM)
        let leanBodyMass = weight * (1 - bodyFatPercentage / 100)
        
        // 使用Katch-McArdle公式计算BMR
        // BMR = 370 + (21.6 * LBM)
        return 370 + (21.6 * leanBodyMass)
    }
    
    private func calculateBMI(weight: Double, height: Double) -> Double {
        let heightInMeters = height / 100
        return weight / (heightInMeters * heightInMeters)
    }
}

// MARK: - 日期范围选择器
struct DateRangePickerView: View {
    @Environment(\.theme) private var theme
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onDismiss: () -> Void
    
    @State private var tempStartDate: Date
    @State private var tempEndDate: Date
    @State private var selectedQuickOption: String? = nil
    
    init(startDate: Binding<Date>, endDate: Binding<Date>, onDismiss: @escaping () -> Void) {
        self._startDate = startDate
        self._endDate = endDate
        self.onDismiss = onDismiss
        self._tempStartDate = State(initialValue: startDate.wrappedValue)
        self._tempEndDate = State(initialValue: endDate.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 快速选择按钮
                quickSelectionButtons
                
                Divider()
                
                // 自定义日期选择
                VStack(alignment: .leading, spacing: 16) {
                    Text("自定义日期范围")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 16) {
                        // 开始日期
                        VStack(alignment: .leading, spacing: 8) {
                            Text("开始日期")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.secondary)
                            DatePicker("", selection: $tempStartDate, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .foregroundColor(theme.primary)
                                // 移除这行：.onChange(of: tempStartDate) { selectedQuickOption = nil }
                        }
                        .padding(.horizontal, 20)
                        
                        // 结束日期
                        VStack(alignment: .leading, spacing: 8) {
                            Text("结束日期")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.secondary)
                            DatePicker("", selection: $tempEndDate, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .foregroundColor(theme.primary)
                                // 移除这行：.onChange(of: tempEndDate) { selectedQuickOption = nil }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("选择日期范围")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    onDismiss()
                },
                trailing: Button("确定") {
                    // 确保开始日期不晚于结束日期
                    if tempStartDate <= tempEndDate {
                        startDate = tempStartDate
                        endDate = tempEndDate
                    }
                    onDismiss()
                }
                .fontWeight(.semibold)
            )
        }
    }
    
    private var quickSelectionButtons: some View {
        VStack(spacing: 12) {
            Text("快速选择")
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickDateButton(
                    title: "最近7天",
                    isSelected: selectedQuickOption == "最近7天"
                ) {
                    tempEndDate = Date()
                    tempStartDate = Calendar.current.date(byAdding: .day, value: -7, to: tempEndDate) ?? tempEndDate
                    selectedQuickOption = "最近7天"
                }
                
                QuickDateButton(
                    title: "最近30天",
                    isSelected: selectedQuickOption == "最近30天"
                ) {
                    tempEndDate = Date()
                    tempStartDate = Calendar.current.date(byAdding: .day, value: -30, to: tempEndDate) ?? tempEndDate
                    selectedQuickOption = "最近30天"
                }
                
                QuickDateButton(
                    title: "最近3个月",
                    isSelected: selectedQuickOption == "最近3个月"
                ) {
                    tempEndDate = Date()
                    tempStartDate = Calendar.current.date(byAdding: .month, value: -3, to: tempEndDate) ?? tempEndDate
                    selectedQuickOption = "最近3个月"
                }
                
                QuickDateButton(
                    title: "最近6个月",
                    isSelected: selectedQuickOption == "最近6个月"
                ) {
                    tempEndDate = Date()
                    tempStartDate = Calendar.current.date(byAdding: .month, value: -6, to: tempEndDate) ?? tempEndDate
                    selectedQuickOption = "最近6个月"
                }
                
                QuickDateButton(
                    title: "最近1年",
                    isSelected: selectedQuickOption == "最近1年"
                ) {
                    tempEndDate = Date()
                    tempStartDate = Calendar.current.date(byAdding: .year, value: -1, to: tempEndDate) ?? tempEndDate
                    selectedQuickOption = "最近1年"
                }
                
                QuickDateButton(
                    title: "全部",
                    isSelected: selectedQuickOption == "全部"
                ) {
                    tempEndDate = Date()
                    tempStartDate = Calendar.current.date(byAdding: .year, value: -10, to: tempEndDate) ?? tempEndDate
                    selectedQuickOption = "全部"
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 快速日期选择按钮
struct QuickDateButton: View {
    @Environment(\.theme) private var theme
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : theme.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? theme.primary : theme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    BodyMeasurementChange()
}
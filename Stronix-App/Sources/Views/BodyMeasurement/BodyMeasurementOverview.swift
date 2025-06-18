import SwiftUI
import Charts

struct BodyMeasurementOverview: View {
    @StateObject private var viewModel = BodyMeasurementViewModel()
    @State private var showingRecordsList = false
    
    var body: some View {
        ZStack {
            mainContent
            bottomButtons
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddMeasurementSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingRecordsList) {
            BodyMeasurementListView(viewModel: viewModel)
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                
                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if viewModel.measurements.isEmpty {
                    emptyStateView
                } else {
                    metricCardsSection
                    chartSection
                }
                
                Spacer(minLength: 100)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无体测数据")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
            
            Text("点击下方按钮添加您的第一条体测记录")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }
    
    private var headerSection: some View {
        HStack {
            Text("体测概要")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
            Spacer()
            Button(action: {
                // 显示项设置功能，暂时不实现
            }) {
                Image(systemName: "gearshape")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var metricCardsSection: some View {
        let displayData = viewModel.displayDataPoint
        
        return HStack(spacing: 15) {
            MetricCard(
                title: "体重",
                value: displayData?.weight_kg ?? 0,
                unit: "kg",
                isSelected: viewModel.selectedMetric == .weight
            ) {
                viewModel.selectMetric(.weight)
            }
            
            MetricCard(
                title: "骨骼肌量",
                value: displayData?.skeletal_muscle_mass_kg ?? 0,
                unit: "kg",
                isSelected: viewModel.selectedMetric == .muscleMass
            ) {
                viewModel.selectMetric(.muscleMass)
            }
            
            MetricCard(
                title: "体脂百分比",
                value: displayData?.body_fat_percentage ?? 0,
                unit: "%",
                isSelected: viewModel.selectedMetric == .bodyFat
            ) {
                viewModel.selectMetric(.bodyFat)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var chartSection: some View {
        VStack(spacing: 10) {
            selectedDataPointView
            chartView
        }
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var selectedDataPointView: some View {
        if let selectedData = viewModel.selectedDataPoint {
            HStack {
                Text(formatDateForDisplay(selectedData.measurementDate))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
                Text(viewModel.formatValue(viewModel.getValueForMetric(selectedData), for: viewModel.selectedMetric))
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var chartView: some View {
        // 按时间排序数据（从最早到最新）
        let sortedChartData = viewModel.chartData.sorted { $0.measurementDate < $1.measurementDate }
        
        let chart = Chart(Array(sortedChartData.enumerated()), id: \.offset) { index, data in
            LineMark(
                x: .value("日期", index),
                y: .value("数值", viewModel.getValueForMetric(data))
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            PointMark(
                x: .value("日期", index),
                y: .value("数值", viewModel.getValueForMetric(data))
            )
            .foregroundStyle(.blue)
            .symbolSize(50)
            
            // 显示选中点的垂直虚线
            if let selectedData = viewModel.selectedDataPoint,
               let selectedIndex = sortedChartData.firstIndex(where: { $0.id == selectedData.id }) {
                RuleMark(x: .value("Selected", selectedIndex))
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        
        return chart
            .frame(height: 200)
            .padding(.horizontal, 20)
            .chartYScale(domain: viewModel.getYAxisDomain())
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(5, sortedChartData.count))) { value in
                    AxisValueLabel {
                        if let index = value.as(Int.self), index < sortedChartData.count {
                            Text(formatDateForChart(sortedChartData[index].measurementDate))
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .onTapGesture { location in
                handleChartTap(location: location, chartData: sortedChartData)
            }
            .onAppear {
                // 页面加载时默认选择最新的数据点
                if let latestData = sortedChartData.last {
                    viewModel.selectDataPoint(latestData)
                }
            }
    }
    
    private func handleChartTap(location: CGPoint, chartData: [BodyMeasurementRecord]) {
        guard !chartData.isEmpty else { return }
        
        // 计算点击位置对应的数据点
        let chartWidth = UIScreen.main.bounds.width - 80 // 减去padding
        let dataRange = max(1, chartData.count - 1)
        let pointWidth = chartWidth / Double(dataRange)
        let tappedIndex = Int(round(location.x / pointWidth))
        
        if tappedIndex >= 0 && tappedIndex < chartData.count {
            viewModel.selectDataPoint(chartData[tappedIndex])
        }
    }
    
    // 图表专用的日期格式化函数（月日）
    private func formatDateForChart(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    // 显示用的日期格式化函数（年月日）
    private func formatDateForDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
    
    private var bottomButtons: some View {
        VStack {
            Spacer()
            HStack(spacing: 15) {
                // 查看记录按钮
                if !viewModel.measurements.isEmpty {
                    Button(action: {
                        showingRecordsList = true
                    }) {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("查看记录")
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 25)
                        .frame(height: 70)
                        .background(Color.white)
                        .cornerRadius(25)
                        .shadow(color: .gray.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                }
                
                addButton
                shareButton
            }
            .padding(.bottom, 30)
        }
    }
    
    private var shareButton: some View {
        Button(action: {
            // 分享功能，暂时不实现
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("分享")
            }
            .foregroundColor(.blue)
            .padding(.vertical, 12)
            .padding(.horizontal, 30)
            .frame(height: 70)
            .background(Color.white)
            .cornerRadius(25)
            .shadow(color: .gray.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
    
    private var addButton: some View {
        Button(action: {
            viewModel.showAddSheet()
        }) {
            HStack {
                Image(systemName: "plus")
                Text("添加结果")
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 30)
            .frame(height: 70)
            .background(Color.blue)
            .cornerRadius(25)
            .shadow(color: .gray.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
    

}

// 指标卡片组件
struct MetricCard: View {
    let title: String
    let value: Double
    let unit: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text("\(value, specifier: "%.1f")")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                Text(unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 2)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    BodyMeasurementOverview()
} 

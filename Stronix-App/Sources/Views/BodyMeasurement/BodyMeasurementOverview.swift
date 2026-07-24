import SwiftUI
import Charts

struct BodyMeasurementOverview: View {
    @Environment(\.theme) private var theme
    @ObservedObject var viewModel: BodyMeasurementViewModel
    @EnvironmentObject private var userSession: UserSession
    @State private var showLogin = false
    
    var body: some View {
        NavigationView {
            ZStack {
                mainContent
                bottomButtons
            }
            .background(theme.background)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddMeasurementSheet(viewModel: viewModel)
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                
                if !userSession.isAuthenticated {
                    // 未登录状态视图
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "person.circle")
                            .font(.system(size: 64))
                            .foregroundColor(theme.secondary.opacity(0.5))
                        
                        Text("请先登录")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(theme.onSurface)
                        
                        Text("登录后可以查看和管理您的体测数据")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showLogin = true
                        }) {
                            Text("立即登录")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.onPrimary)
                                .frame(width: 120, height: 44)
                                .background(theme.primary)
                                .cornerRadius(22)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isLoading {
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
                .foregroundColor(theme.secondary)
            
            Text("暂无体测数据")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(theme.secondary)
            
            Text("点击下方按钮添加您的第一条体测记录")
                .font(.system(size: 14))
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }
    
    private var headerSection: some View {
        HStack {
            Text("体测概要")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.onSurface)
            Spacer()
            
            // 登录状态指示器
            if userSession.isAuthenticated {
                Button(action: {
                    Task {
                        try? await userSession.logout()
                    }
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.primary)
                }
            } else {
                Button(action: {
                    showLogin = true
                }) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 20))
                        .foregroundColor(theme.secondary)
                }
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
                value: displayData?.weightKg ?? 0,
                unit: "kg",
                isSelected: viewModel.selectedMetric == .weight
            ) {
                viewModel.selectMetric(.weight)
            }
            
            MetricCard(
                title: "骨骼肌量",
                value: displayData?.skeletalMuscleMassKg ?? 0,
                unit: "kg",
                isSelected: viewModel.selectedMetric == .muscleMass
            ) {
                viewModel.selectMetric(.muscleMass)
            }
            
            MetricCard(
                title: "体脂百分比",
                value: displayData?.bodyFatPercentage ?? 0,
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
        .background(theme.surface)
        .cornerRadius(12)
        .shadow(color: theme.shadow.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var selectedDataPointView: some View {
        if let selectedData = viewModel.selectedDataPoint {
            HStack {
                Text(BodyMeasurementDateFormatting.detailDate(selectedData.measurementTimestamp))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondary)
                Spacer()
                Text(viewModel.formatValue(viewModel.getValueForMetric(selectedData), for: viewModel.selectedMetric))
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var chartView: some View {
        // 按时间排序数据（从最早到最新）
        let sortedChartData = viewModel.chartData.sorted { $0.measurementTimestamp < $1.measurementTimestamp }
        
        let chart = Chart(Array(sortedChartData.enumerated()), id: \.offset) { index, data in
            LineMark(
                x: .value("日期", index),
                y: .value("数值", viewModel.getValueForMetric(data))
            )
            .foregroundStyle(theme.primary)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            PointMark(
                x: .value("日期", index),
                y: .value("数值", viewModel.getValueForMetric(data))
            )
            .foregroundStyle(theme.primary)
            .symbolSize(50)
            
            // 显示选中点的垂直虚线
            if let selectedData = viewModel.selectedDataPoint,
               let selectedIndex = sortedChartData.firstIndex(where: { $0.id == selectedData.id }) {
                RuleMark(x: .value("Selected", selectedIndex))
                    .foregroundStyle(theme.secondary)
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
                            Text(BodyMeasurementDateFormatting.chartLabel(sortedChartData[index].measurementTimestamp))
                                .font(.system(size: 10))
                                .foregroundColor(theme.secondary)
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
    
    private func handleChartTap(location: CGPoint, chartData: [BodyMeasurement]) {
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
    
    
    private var bottomButtons: some View {
        VStack {
            Spacer()
            if userSession.isAuthenticated {
                HStack(spacing: 15) {
                    // 查看记录按钮 - 改为NavigationLink
                    if !viewModel.measurements.isEmpty {
                        NavigationLink(destination: BodyMeasurementListView(viewModel: viewModel)) {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("查看记录")
                            }
                            .foregroundColor(theme.primary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 25)
                            .frame(height: 70)
                            .background(theme.surface)
                            .cornerRadius(25)
                            .shadow(color: theme.shadow.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                    }
                    
                    addButton
                    shareButton
                }
                .padding(.bottom, 30)
            }
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
            .foregroundColor(theme.primary)
            .padding(.vertical, 12)
            .padding(.horizontal, 30)
            .frame(height: 70)
            .background(theme.surface)
            .cornerRadius(25)
            .shadow(color: theme.shadow.opacity(0.3), radius: 3, x: 0, y: 2)
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
            .background(theme.primary)
            .cornerRadius(25)
            .shadow(color: theme.shadow.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
    

}

// 指标卡片组件
struct MetricCard: View {
    @Environment(\.theme) private var theme
    let title: String
    let value: Double
    let unit: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.secondary)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text("\(value, specifier: "%.1f")")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.onSurface)
                Text(unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondary)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(isSelected ? theme.primary.opacity(0.1) : theme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? theme.primary : Color.clear, lineWidth: 2)
        )
        .shadow(color: theme.shadow.opacity(0.1), radius: 3, x: 0, y: 2)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    BodyMeasurementOverview(viewModel: BodyMeasurementViewModel())
        .environmentObject(
            UserSession(
                operations: AuthenticationUseCases(
                    repository: SQLiteAuthRepository(),
                    sessionStore: InMemoryLocalSessionStore()
                )
            )
        )
}

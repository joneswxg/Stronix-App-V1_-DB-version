import SwiftUI
import Charts

// 测量数据模型
struct MeasurementData: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let muscleMass: Double
    let bodyFatPercentage: Double
}

// 指标类型枚举
enum MetricType: String, CaseIterable {
    case weight = "体重"
    case muscleMass = "骨骼肌量"
    case bodyFat = "体脂百分比"
    
    var unit: String {
        switch self {
        case .weight: return "kg"
        case .muscleMass: return "kg"
        case .bodyFat: return "%"
        }
    }
}

struct BodyMeasurementOverview: View {
    @State private var selectedMetric: MetricType = .weight
    @State private var showingAddSheet = false
    @State private var selectedDataPoint: MeasurementData?
    
    // 示例数据
    @State private var measurementData: [MeasurementData] = [
        MeasurementData(date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!, weight: 76.2, muscleMass: 37.5, bodyFatPercentage: 15.2),
        MeasurementData(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, weight: 75.8, muscleMass: 37.2, bodyFatPercentage: 14.9),
        MeasurementData(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, weight: 75.7, muscleMass: 36.8, bodyFatPercentage: 14.8),
        MeasurementData(date: Date(), weight: 75.7, muscleMass: 36.8, bodyFatPercentage: 14.8)
    ]
    
    var body: some View {
        ZStack {
            mainContent
            bottomButtons
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $showingAddSheet) {
            AddMeasurementSheet { newData in
                measurementData.append(newData)
                measurementData.sort { $0.date < $1.date }
            }
        }
        .onAppear {
            selectedDataPoint = latestData
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                metricCardsSection
                chartSection
                Spacer(minLength: 100)
            }
        }
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
        let displayData = selectedDataPoint ?? latestData
        
        return HStack(spacing: 15) {
            MetricCard(
                title: "体重",
                value: displayData?.weight ?? 0,
                unit: "kg",
                isSelected: selectedMetric == .weight
            ) {
                selectedMetric = .weight
            }
            
            MetricCard(
                title: "骨骼肌量",
                value: displayData?.muscleMass ?? 0,
                unit: "kg",
                isSelected: selectedMetric == .muscleMass
            ) {
                selectedMetric = .muscleMass
            }
            
            MetricCard(
                title: "体脂百分比",
                value: displayData?.bodyFatPercentage ?? 0,
                unit: "%",
                isSelected: selectedMetric == .bodyFat
            ) {
                selectedMetric = .bodyFat
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
        if let selectedData = selectedDataPoint {
            HStack {
                Text(formatDate(selectedData.date))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(getValueForMetric(selectedData), specifier: "%.1f")\(selectedMetric.unit)")
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var chartView: some View {
        let chart = Chart(measurementData) { data in
            LineMark(
                x: .value("日期", data.date),
                y: .value("数值", getValueForMetric(data))
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            PointMark(
                x: .value("日期", data.date),
                y: .value("数值", getValueForMetric(data))
            )
            .foregroundStyle(.blue)
            .symbolSize(50)
            
            // 显示选中点的垂直虚线
            if let selectedData = selectedDataPoint {
                RuleMark(x: .value("Selected", selectedData.date))
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        
        return chart
            .frame(height: 200)
            .padding(.horizontal, 20)
            .chartYScale(domain: getYAxisDomain())
            .onTapGesture { location in
                handleChartTap(location: location)
            }
    }
    
    private func handleChartTap(location: CGPoint) {
        // 计算点击位置对应的数据点
        let chartWidth = UIScreen.main.bounds.width - 80 // 减去padding
        let dataRange = measurementData.count - 1
        let pointWidth = chartWidth / Double(dataRange)
        let tappedIndex = Int(round(location.x / pointWidth))
        
        if tappedIndex >= 0 && tappedIndex < measurementData.count {
            selectedDataPoint = measurementData[tappedIndex]
        }
    }
    
    private var bottomButtons: some View {
        VStack {
            Spacer()
            HStack(spacing: 20) {
                shareButton
                addButton
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
            .background(Color.white)
            .cornerRadius(25)
            .shadow(color: .gray.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
    
    private var addButton: some View {
        Button(action: {
            showingAddSheet = true
        }) {
            HStack {
                Image(systemName: "plus")
                Text("添加结果")
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 30)
            .background(Color.blue)
            .cornerRadius(25)
            .shadow(color: .gray.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
    
    private var latestData: MeasurementData? {
        measurementData.max { $0.date < $1.date }
    }
    
    private func getValueForMetric(_ data: MeasurementData) -> Double {
        switch selectedMetric {
        case .weight: return data.weight
        case .muscleMass: return data.muscleMass
        case .bodyFat: return data.bodyFatPercentage
        }
    }
    
    private func getYAxisDomain() -> ClosedRange<Double> {
        let values = measurementData.map { getValueForMetric($0) }
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...100
        }
        
        // 为Y轴添加适当的边距，并确保刻度间隔为1
        let padding = max(1.0, (maxValue - minValue) * 0.1)
        let lowerBound = max(0, minValue - padding)
        let upperBound = maxValue + padding
        
        return lowerBound...upperBound
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd HH:mm"
        return formatter.string(from: date)
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

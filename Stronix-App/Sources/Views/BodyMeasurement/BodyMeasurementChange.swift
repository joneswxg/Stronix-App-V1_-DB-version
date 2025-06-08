import SwiftUI
import Charts

struct BodyMeasurementChange: View {
    @State private var selectedStartDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var selectedEndDate = Date()
    @State private var showingDatePicker = false
    @State private var selectedDataIndex: Int? = nil
    
    // 示例数据
    private let sampleData: [MeasurementData] = [
        MeasurementData(date: Calendar.current.date(byAdding: .day, value: -60, to: Date())!, weight: 75.7, muscleMass: 36.8, bodyFatPercentage: 14.8),
        MeasurementData(date: Calendar.current.date(byAdding: .day, value: -45, to: Date())!, weight: 74.9, muscleMass: 37.1, bodyFatPercentage: 13.1),
        MeasurementData(date: Calendar.current.date(byAdding: .day, value: -30, to: Date())!, weight: 74.9, muscleMass: 37.1, bodyFatPercentage: 13.1),
        MeasurementData(date: Calendar.current.date(byAdding: .day, value: -15, to: Date())!, weight: 74.9, muscleMass: 37.1, bodyFatPercentage: 13.1),
        MeasurementData(date: Date(), weight: 74.9, muscleMass: 37.1, bodyFatPercentage: 13.1)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 日期选择区域
                dateSelectionSection
                
                // 基础代谢率图表
                chartCard(
                    title: "基础代谢率",
                    unit: "kcal",
                    currentValue: 1776,
                    data: sampleData.map { _ in Double.random(in: 1760...1780) }
                )
                
                // 体重图表
                chartCard(
                    title: "体重",
                    unit: "kg",
                    currentValue: 74.9,
                    data: sampleData.map { $0.weight }
                )
                
                // 骨骼肌量图表
                chartCard(
                    title: "骨骼肌量",
                    unit: "kg",
                    currentValue: 37.1,
                    data: sampleData.map { $0.muscleMass }
                )
                
                // 体脂肪图表
                chartCard(
                    title: "体脂肪",
                    unit: "kg",
                    currentValue: 9.8,
                    data: sampleData.map { _ in Double.random(in: 9.5...11.5) }
                )
                
                // BMI图表
                chartCard(
                    title: "BMI",
                    unit: "kg/m²",
                    currentValue: 23.6,
                    data: sampleData.map { _ in Double.random(in: 23.4...24.0) }
                )
                
                // 体脂百分比图表
                chartCard(
                    title: "体脂百分比",
                    unit: "%",
                    currentValue: 13.1,
                    data: sampleData.map { $0.bodyFatPercentage }
                )
                
                // 内脏脂肪等级图表
                chartCard(
                    title: "内脏脂肪等级",
                    unit: "Level",
                    currentValue: 3,
                    data: sampleData.map { _ in Double.random(in: 3...4) }
                )
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var dateSelectionSection: some View {
        HStack(spacing: 16) {
            Button(action: {
                showingDatePicker = true
            }) {
                HStack {
                    Text(formatDateRange())
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
            
            Spacer()
            
            Button(action: {
                // 显示项设置功能
            }) {
                Image(systemName: "gearshape")
                    .foregroundColor(.gray)
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
            if let selectedIndex = selectedDataIndex, selectedIndex < sampleData.count {
                Text(formatSelectedDate(sampleData[selectedIndex].date))
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
        let chartData = Array(zip(sampleData.indices, data))
        
        return Chart(chartData, id: \.0) { index, value in
            LineMark(
                x: .value("Index", index),
                y: .value("Value", value)
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            PointMark(
                x: .value("Index", index),
                y: .value("Value", value)
            )
            .foregroundStyle(.blue)
            .symbolSize(40)
            
            // 显示选中点的垂直虚线
            if let selectedIndex = selectedDataIndex, selectedIndex == index {
                RuleMark(x: .value("Selected", index))
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
        }
        .frame(height: 120)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self), index < sampleData.count {
                        Text(formatChartDate(sampleData[index].date))
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
        let pointWidth = chartWidth / Double(sampleData.count - 1)
        let tappedIndex = Int(round(location.x / pointWidth))
        
        if tappedIndex >= 0 && tappedIndex < sampleData.count {
            selectedDataIndex = tappedIndex
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yy.MM.dd"
        return "\(formatter.string(from: selectedStartDate)) ~ 最近"
    }
    
    private func formatCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy.MM.dd HH:mm"
        return formatter.string(from: selectedEndDate)
    }
    
    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy.MM.dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatChartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return formatter.string(from: date)
    }
}

#Preview {
    BodyMeasurementChange()
} 
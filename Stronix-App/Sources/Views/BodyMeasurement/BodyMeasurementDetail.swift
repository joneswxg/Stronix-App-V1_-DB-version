import SwiftUI

struct BodyMeasurementDetail: View {
    @State private var selectedDate = Date()
    @State private var currentData: DetailedMeasurementData = DetailedMeasurementData.sampleData
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 日期导航
                HStack {
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(formatDate(selectedDate))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                        Text(formatTime(selectedDate))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: {
                        // 删除功能
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white)
                
                // 肌肉脂肪分析
                AnalysisSection(title: "肌肉脂肪分析") {
                    VStack(spacing: 16) {
                        MetricRow(
                            title: "体重",
                            value: currentData.weight,
                            unit: "kg",
                            change: currentData.weightChange,
                            progressValue: 0.6,
                            labels: ["低标准", "标准", "超标准"]
                        )
                        
                        MetricRow(
                            title: "骨骼肌量",
                            value: currentData.muscleMass,
                            unit: "kg",
                            change: currentData.muscleMassChange,
                            progressValue: 0.7,
                            labels: ["低标准", "标准", "超标准"]
                        )
                        
                        MetricRow(
                            title: "体脂肪",
                            value: currentData.bodyFat,
                            unit: "kg",
                            change: currentData.bodyFatChange,
                            progressValue: 0.3,
                            labels: ["低标准", "标准", "超标准"]
                        )
                    }
                }
                
                // 肥胖分析
                AnalysisSection(title: "肥胖分析") {
                    VStack(spacing: 16) {
                        MetricRow(
                            title: "BMI",
                            value: currentData.bmi,
                            unit: "kg/m²",
                            change: currentData.bmiChange,
                            progressValue: 0.5,
                            labels: ["低标准", "标准", "超标准"]
                        )
                        
                        MetricRow(
                            title: "体脂百分比",
                            value: currentData.bodyFatPercentage,
                            unit: "%",
                            change: currentData.bodyFatPercentageChange,
                            progressValue: 0.4,
                            labels: ["低标准", "标准", "超标准"]
                        )
                    }
                }
                
                // 腹部肥胖分析
                AnalysisSection(title: "腹部肥胖分析") {
                    VStack(spacing: 16) {
                        MetricRow(
                            title: "内脏脂肪等级",
                            value: Double(currentData.visceralFatLevel),
                            unit: "Lv",
                            change: currentData.visceralFatChange,
                            progressValue: 0.2,
                            labels: ["低", "高"],
                            isSimpleScale: true
                        )
                    }
                }
                
                // 综合分析
                AnalysisSection(title: "综合分析") {
                    VStack(spacing: 16) {
                        MetricRow(
                            title: "基础代谢率",
                            value: Double(currentData.basalMetabolicRate),
                            unit: "kcal",
                            change: currentData.bmrChange,
                            progressValue: 0.0,
                            labels: [],
                            showProgress: false
                        )
                    }
                }
                
                Spacer(minLength: 50)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy.MM.dd (EEEE)"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// 分析区域组件
struct AnalysisSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 10)
    }
}

// 指标行组件
struct MetricRow: View {
    let title: String
    let value: Double
    let unit: String
    let change: Double
    let progressValue: Double
    let labels: [String]
    var isSimpleScale: Bool = false
    var showProgress: Bool = true
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
            }
            
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(value, specifier: "%.1f")")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                Text(unit)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Spacer()
                if change != 0 {
                    Text(change > 0 ? "+\(change, specifier: "%.1f")" : "\(change, specifier: "%.1f")")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            if showProgress {
                VStack(spacing: 8) {
                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * progressValue, height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                    
                    // 标签
                    if !labels.isEmpty {
                        HStack {
                            ForEach(labels.indices, id: \.self) { index in
                                Text(labels[index])
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                if index < labels.count - 1 {
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// 详细测量数据模型
struct DetailedMeasurementData {
    let weight: Double
    let weightChange: Double
    let muscleMass: Double
    let muscleMassChange: Double
    let bodyFat: Double
    let bodyFatChange: Double
    let bmi: Double
    let bmiChange: Double
    let bodyFatPercentage: Double
    let bodyFatPercentageChange: Double
    let visceralFatLevel: Int
    let visceralFatChange: Double
    let basalMetabolicRate: Int
    let bmrChange: Double
    
    static let sampleData = DetailedMeasurementData(
        weight: 74.9,
        weightChange: 0.0,
        muscleMass: 37.1,
        muscleMassChange: 0.0,
        bodyFat: 9.8,
        bodyFatChange: 0.0,
        bmi: 23.6,
        bmiChange: 0.0,
        bodyFatPercentage: 13.1,
        bodyFatPercentageChange: 0.0,
        visceralFatLevel: 3,
        visceralFatChange: 0,
        basalMetabolicRate: 1776,
        bmrChange: 0
    )
}

#Preview {
    BodyMeasurementDetail()
} 
import SwiftUI

struct BodyMeasurementDetail: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var userSession: UserSession
    @ObservedObject var viewModel: BodyMeasurementViewModel
    @State private var selectedDate = Date()
    @State private var selectedMeasurementID: Int?
    @State private var currentData: DetailedMeasurementData = DetailedMeasurementData.sampleData
    @State private var currentIndex = 0
    @State private var showingDeleteAlert = false
    @State private var showingBMRInfo = false
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if viewModel.measurements.isEmpty {
                ContentUnavailableView("暂无体测数据", systemImage: "chart.line.uptrend.xyaxis", description: Text("请先添加体测记录"))
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                VStack(spacing: 0) {
                // 日期导航
                HStack {
                    Button(action: {
                        navigateToPrevious()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(currentIndex > 0 ? theme.secondary : theme.secondary.opacity(0.3))
                    }
                    .disabled(currentIndex <= 0)
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(BodyMeasurementDateFormatting.detailDate(selectedDate))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.onSurface)
                        Text(BodyMeasurementDateFormatting.listDate(selectedDate))
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        navigateToNext()
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(currentIndex < viewModel.measurements.count - 1 ? theme.secondary : theme.secondary.opacity(0.3))
                    }
                    .disabled(currentIndex >= viewModel.measurements.count - 1)
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(theme.error)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(theme.surface)
                
                // 肌肉脂肪分析
                AnalysisSection(title: "肌肉脂肪分析") {
                    VStack(spacing: 16) {
                        MetricRow(
                            title: "体重",
                            value: currentData.weight,
                            unit: "kg",
                            change: currentData.weightChange.change,
                            progressValue: 0.6,
                            labels: ["低标准", "标准", "超标准"]
                        )
                        
                        MetricRow(
                            title: "骨骼肌量",
                            value: currentData.muscleMass,
                            unit: "kg",
                            change: currentData.muscleMassChange.change,
                            progressValue: 0.7,
                            labels: ["低标准", "标准", "超标准"]
                        )
                        
                        MetricRow(
                            title: "体脂肪",
                            value: currentData.bodyFat,
                            unit: "kg",
                            change: currentData.bodyFatChange.change,
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
                            change: currentData.bmiChange.change,
                            progressValue: 0.5,
                            labels: ["低标准", "标准", "超标准"]
                        )
                        
                        MetricRow(
                            title: "体脂百分比",
                            value: currentData.bodyFatPercentage,
                            unit: "%",
                            change: currentData.bodyFatPercentageChange.change,
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
                            change: currentData.visceralFatChange.change,
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
                            change: currentData.bmrChange.change,
                            progressValue: 0.0,
                            labels: [],
                            showProgress: false,
                            showInfoButton: true,
                            onInfoTapped: {
                                showingBMRInfo = true
                            }
                        )
                    }
                }
                
                Spacer(minLength: 50)
                }
            }
        }
        .background(theme.background)
        .onAppear {
            updateCurrentData()
        }
        .onChange(of: viewModel.measurements) {
            synchronizeSelection()
            updateCurrentData()
        }
        .onChange(of: currentIndex) {
            updateCurrentData()
        }
        .alert("删除确认", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteCurrentMeasurement()
            }
        } message: {
            Text("确定要删除这条体测记录吗？此操作无法撤销。")
        }
        .alert("基础代谢率计算公式", isPresented: $showingBMRInfo) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("使用 Katch-McArdle 公式计算：\n\n1. 首先计算瘦体重（LBM）\n   LBM = 体重 × (1 - 体脂百分比 ÷ 100)\n\n2. 然后计算基础代谢率\n   BMR = 370 + (21.6 × LBM)")
        }
    }
    
    // MARK: - 数据管理函数
    private func synchronizeSelection() {
        guard !viewModel.measurements.isEmpty else {
            currentIndex = 0
            selectedMeasurementID = nil
            return
        }

        if let selectedMeasurementID,
           let index = viewModel.measurements.firstIndex(where: { $0.id == selectedMeasurementID }) {
            currentIndex = index
        } else {
            currentIndex = min(currentIndex, viewModel.measurements.count - 1)
            selectedMeasurementID = viewModel.measurements[currentIndex].id
        }
    }

    private func updateCurrentData() {
        guard !viewModel.measurements.isEmpty else {
            return
        }

        synchronizeSelection()
        let current = viewModel.measurements[currentIndex]
        let previous = currentIndex > 0 ? viewModel.measurements[currentIndex - 1] : nil
        
        currentData = DetailedMeasurementData(
            current: current,
            previous: previous,
            userAge: 0,
            userGender: userSession.currentUser?.gender ?? ""
        )
        
        selectedDate = current.measurementTimestamp
    }
    
    private func navigateToPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
            selectedMeasurementID = viewModel.measurements[currentIndex].id
        }
    }

    private func navigateToNext() {
        if currentIndex < viewModel.measurements.count - 1 {
            currentIndex += 1
            selectedMeasurementID = viewModel.measurements[currentIndex].id
        }
    }
    
    private func deleteCurrentMeasurement() {
        guard !viewModel.measurements.isEmpty, currentIndex < viewModel.measurements.count else {
            return
        }
        
        let measurementToDelete = viewModel.measurements[currentIndex]
        
        Task {
            let success = await viewModel.deleteMeasurement(measurementToDelete.id)
            if success {
                // 调整当前索引
                if currentIndex >= viewModel.measurements.count {
                    currentIndex = max(0, viewModel.measurements.count - 1)
                }
                updateCurrentData()
            }
        }
    }
}

// 分析区域组件
struct AnalysisSection<Content: View>: View {
    @Environment(\.theme) private var theme
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
                .foregroundColor(theme.onSurface)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(theme.surface)
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 10)
    }
}

// 指标行组件
struct MetricRow: View {
    @Environment(\.theme) private var theme
    let title: String
    let value: Double
    let unit: String
    let change: Double
    let progressValue: Double
    let labels: [String]
    var isSimpleScale: Bool = false
    var showProgress: Bool = true
    var showInfoButton: Bool = false
    var onInfoTapped: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.onSurface)
                    
                    if showInfoButton {
                        Button(action: {
                            onInfoTapped?()
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(theme.primary)
                                .font(.system(size: 14))
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(theme.secondary)
                        .font(.system(size: 12))
                }
            }
            
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(value, specifier: "%.1f")")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.onSurface)
                Text(unit)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondary)
                Spacer()
                if change != 0 {
                    Text(change > 0 ? "+\(change, specifier: "%.1f")" : "\(change, specifier: "%.1f")")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondary)
                }
            }
            
            if showProgress {
                VStack(spacing: 8) {
                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(theme.secondary.opacity(0.2))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(theme.primary)
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
                                    .foregroundColor(theme.secondary)
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



#Preview {
    BodyMeasurementDetail(viewModel: BodyMeasurementViewModel())
        .environmentObject(
            UserSession(
                operations: AuthenticationUseCases(
                    repository: SQLiteAuthRepository(),
                    sessionStore: InMemoryLocalSessionStore()
                )
            )
        )
}
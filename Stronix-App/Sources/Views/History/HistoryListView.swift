import SwiftUI

struct HistoryListView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme: AppTheme
    let selectedDate: Date
    let selectedDateString: String?
    @State private var historyList: [TrainingHistoryItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false
    @State private var historyToDelete: TrainingHistoryItem?
    @State private var isDeleting = false
    
    @ObservedObject private var trainingHistoryService = TrainingHistoryService.shared
    
    // 便利初始化器 - 接受Date对象（保持向后兼容）
    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        self.selectedDateString = nil
    }
    
    // 新的初始化器 - 接受字符串（推荐使用）
    init(selectedDateString: String) {
        // 创建一个虚拟的Date对象用于显示，使用当前时区避免时区偏差
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        self.selectedDate = formatter.date(from: selectedDateString) ?? Date()
        self.selectedDateString = selectedDateString
        
        // 添加调试日志
        print("🎬 HistoryListView 初始化，日期字符串: \(selectedDateString)")
    }
    
    // 本地日期格式化器
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // 根据日期查找训练历史
    private func loadHistoryForDate() {
        // 确保有有效的日期字符串
        guard let targetDateString = getTargetDateString() else {
            print("❌ 无法获取有效的日期字符串")
            return
        }
        
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            print("🔍 开始加载日期的训练历史列表")
            print("🎯 使用日期字符串: \(targetDateString)")
            
            do {
                // 直接使用日期过滤参数查询特定日期的训练历史
                // 注意：endDate也设置为同一天，确保只查询该日期的记录
                let response = try await trainingHistoryService.getTrainingHistory(
                    page: 1, 
                    limit: 100, 
                    planId: nil, 
                    startDate: targetDateString,
                    endDate: targetDateString
                )
                
                print("📋 获取到 \(response.histories.count) 条该日期的训练历史记录")
                
                await MainActor.run {
                    self.historyList = response.histories
                    
                    if response.histories.isEmpty {
                        self.errorMessage = "该日期没有训练记录"
                        print("❌ 该日期没有训练记录")
                    } else {
                        print("✅ 找到 \(response.histories.count) 条训练历史")
                    }
                    
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("❌ 加载训练历史列表失败: \(error)")
                }
            }
        }
    }
    
    // 获取目标日期字符串的辅助方法
    private func getTargetDateString() -> String? {
        if let dateString = selectedDateString {
            // 直接使用传入的字符串
            return dateString
        } else {
            // 回退到Date对象解析（保持向后兼容）
            var calendar = Calendar.current
            calendar.timeZone = TimeZone.current
            let targetDateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            
            guard let year = targetDateComponents.year,
                  let month = targetDateComponents.month,
                  let day = targetDateComponents.day else {
                return nil
            }
            
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
    }
    
    private func formatTrainingTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return timeFormatter.string(from: date)
        }
        return dateString
    }
    
    // 格式化训练时长（将秒数转换为分钟数）
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            // 对于不足1分钟的情况，显示为"<1分钟"
            return "<1分钟"
        }
    }
    
    // 删除训练历史
    private func deleteHistory(_ history: TrainingHistoryItem) {
        Task {
            await MainActor.run {
                isDeleting = true
            }
            
            do {
                try await trainingHistoryService.deleteTrainingHistory(historyId: history.id)
                
                await MainActor.run {
                    // 从列表中移除已删除的项目
                    historyList.removeAll { $0.id == history.id }
                    isDeleting = false
                    
                    // 如果列表为空，显示无记录消息
                    if historyList.isEmpty {
                        errorMessage = "该日期没有训练记录"
                    }
                    
                    print("✅ 训练历史删除成功，ID: \(history.id)")
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    // 显示详细的错误信息
                    print("❌ 删除训练历史失败: \(error.localizedDescription)")
                    print("❌ 错误类型: \(type(of: error))")
                    print("❌ 错误详情: \(error)")
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            logoSection
            navigationSection
                
                if isLoading {
                    Spacer()
                    VStack {
                        ProgressView("加载训练记录...")
                        Text("正在加载 \(selectedDate, formatter: dateFormatter) 的训练数据")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    Spacer()
                } else if errorMessage != nil {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(theme.secondary)
                        
                        Text("该日期没有训练记录")
                            .font(.headline)
                            .foregroundColor(theme.onSurface)
                        
                        Text("\(selectedDate, formatter: dateFormatter)")
                            .font(.subheadline)
                            .foregroundColor(theme.secondary)
                        
                        Text("点击其他有训练记录的日期查看详情")
                            .font(.caption)
                            .foregroundColor(theme.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    historyListSection
                }
            }
            .navigationBarHidden(true)
        .onAppear {
            print("🎬 HistoryListView 出现，选中日期: \(selectedDate)")
            print("🎬 HistoryListView 出现，日期字符串: \(selectedDateString ?? "nil")")
            loadHistoryForDate()
        }
        .onChange(of: selectedDateString) { oldValue, newValue in
            print("🔄 日期字符串改变: \(oldValue ?? "nil") -> \(newValue ?? "nil")")
            if newValue != nil {
                loadHistoryForDate()
            }
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let history = historyToDelete {
                    deleteHistory(history)
                }
            }
        } message: {
            if let history = historyToDelete {
                Text("确定要删除训练记录「\(history.plan_name)」吗？此操作无法撤销。")
            }
        }
    }
    
    // MARK: - 视图组件
    
    private var logoSection: some View {
        HStack {
            Image("StronixLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 35)
            Spacer()
            Text("STRONIX")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(theme.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.surface)
        .shadow(color: theme.shadow.opacity(0.1), radius: 1, y: 1)
    }
    
    private var navigationSection: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(theme.primary)
            }
            Spacer()
            Text("训练记录")
                .font(.headline)
            Spacer()
            // 占位符，保持布局平衡
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding()
        .background(theme.surface)
        .shadow(color: theme.shadow.opacity(0.1), radius: 1, y: 1)
    }
    
    private var historyListSection: some View {
        VStack(spacing: 0) {
            Text("\(selectedDate, formatter: dateFormatter)")
                .font(.headline)
                .padding()
            
            Text("该日期的训练记录：")
                .font(.subheadline)
                .foregroundColor(theme.secondary)
                .padding(.bottom)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(historyList, id: \.id) { history in
                        HStack(spacing: 0) {
                            // 训练记录内容 - 可点击进入详情
                            NavigationLink(destination: TrainingHistoryDetailView(historyId: history.id)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(history.plan_name)
                                            .font(.headline)
                                            .foregroundColor(theme.onSurface)
                                        
                                        Text(formatTrainingTime(history.training_date))
                                            .font(.caption)
                                            .foregroundColor(theme.secondary)
                                        
                                        HStack {
                                            Text("时长: \(formatDuration(history.duration))")
                                                .font(.caption)
                                                .foregroundColor(theme.secondary)
                                            
                                            Spacer()
                                            
                                            Text("重量: \(Int(history.volume))kg")
                                                .font(.caption)
                                                .foregroundColor(theme.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(theme.secondary)
                                }
                                .padding()
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 删除按钮
                            Button(action: {
                                historyToDelete = history
                                showingDeleteAlert = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                    .foregroundColor(theme.error)
                                    .frame(width: 44, height: 44)
                            }
                            .disabled(isDeleting)
                        }
                        .background(theme.surface.opacity(0.5))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    HistoryListView(selectedDate: Date())
}
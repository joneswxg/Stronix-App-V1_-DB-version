import SwiftUI
import SQLite

struct ActionHistoryView: SwiftUI.View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    let actionId: Int
    let actionName: String
    
    @State private var historyData: [ActionHistoryData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some SwiftUI.View {
        NavigationView {
            VStack(spacing: 0) {
                // 头部信息
                headerSection
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if historyData.isEmpty {
                    emptyView
                } else {
                    historyListView
                }
            }
            .background(theme.background)
            .navigationTitle("动作历史")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .overlay(
                // 自定义导航栏
                VStack {
                    HStack {
                        Button("关闭") {
                            dismiss()
                        }
                        .foregroundColor(theme.secondary)
                        
                        Spacer()
                        
                        Text("动作历史")
                            .font(.headline)
                            .foregroundColor(theme.onSurface)
                        
                        Spacer()
                        
                        // 占位，保持对称
                        Text("关闭")
                            .foregroundColor(.clear)
                    }
                    .padding()
                    .background(theme.surface)
                    .shadow(color: theme.shadow.opacity(0.1), radius: 1, y: 1)
                    
                    Spacer()
                }
            )
        }
        .onAppear {
            loadActionHistory()
        }
    }
    
    // MARK: - 头部信息
    private var headerSection: some SwiftUI.View {
        VStack(spacing: 12) {
            // Logo区域
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
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [theme.surface, theme.background]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: theme.shadow.opacity(0.15), radius: 3, y: 2)
            
            // 动作信息
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(actionName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.onSurface)
                    Text("过去5次训练记录")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.primary)
                }
                Spacer()
                
                // 装饰性图标
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(theme.primary.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        theme.primary.opacity(0.15),
                        theme.primary.opacity(0.08)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(theme.primary.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
        .padding(.top, 60) // 为自定义导航栏留出空间
    }
    
    // MARK: - 加载视图
    private var loadingView: some SwiftUI.View {
        VStack {
            Spacer()
            ProgressView("加载中...")
                .foregroundColor(theme.secondary)
            Spacer()
        }
    }
    
    // MARK: - 错误视图
    private func errorView(_ error: String) -> some SwiftUI.View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(theme.error)
            Text("加载失败")
                .font(.headline)
                .foregroundColor(theme.onSurface)
            Text(error)
                .font(.body)
                .foregroundColor(theme.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                loadActionHistory()
            }
            .foregroundColor(theme.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(theme.primary.opacity(0.1))
            .cornerRadius(8)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - 空数据视图
    private var emptyView: some SwiftUI.View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(theme.secondary)
            Text("暂无历史记录")
                .font(.headline)
                .foregroundColor(theme.onSurface)
            Text("该动作还没有训练记录")
                .font(.body)
                .foregroundColor(theme.secondary)
            Spacer()
        }
    }
    
    // MARK: - 历史记录列表
    private var historyListView: some SwiftUI.View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(historyData.enumerated()), id: \.offset) { index, data in
                    ActionHistoryCard(
                        data: data,
                        index: index + 1
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - 加载数据
    private func loadActionHistory() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let data = try await fetchActionHistory(actionId: actionId)
                await MainActor.run {
                    self.historyData = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - 数据获取
    private func fetchActionHistory(actionId: Int) async throws -> [ActionHistoryData] {
        guard let db = DatabaseManager.shared.getConnection() else {
            throw NSError(domain: "DatabaseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "数据库连接失败"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    var actionHistoryData: [ActionHistoryData] = []
                    
                    // 查询包含指定动作的训练历史，按日期倒序排列，限制5条
                    let historyQuery = """
                        SELECT DISTINCT th.id, th.plan_name, th.training_date
                        FROM training_history th
                        INNER JOIN training_history_details thd ON th.id = thd.history_id
                        WHERE thd.action_id = ?
                        ORDER BY th.training_date DESC
                        LIMIT 5
                    """
                    
                    let historyStatement = try db.prepare(historyQuery, actionId)
                    
                    for historyRow in historyStatement {
                        guard historyRow.count >= 3 else { continue }
                        
                        let historyId: Int
                        let planName: String
                        let trainingDate: String
                        
                        // 安全地提取数据
                        if let id = historyRow[0] as? Int64 {
                            historyId = Int(id)
                        } else if let id = historyRow[0] as? Int {
                            historyId = id
                        } else {
                            continue
                        }
                        
                        guard let name = historyRow[1] as? String,
                              let date = historyRow[2] as? String else {
                            continue
                        }
                        
                        planName = name
                        trainingDate = date
                        
                        // 查询该次训练中该动作的详细数据
                        let detailsQuery = """
                            SELECT set_number, weight, reps, is_completed
                            FROM training_history_details
                            WHERE history_id = ? AND action_id = ?
                            ORDER BY set_number ASC
                        """
                        
                        let detailsStatement = try db.prepare(detailsQuery, historyId, actionId)
                        
                        var sets: [ActionHistorySet] = []
                        var totalVolume = 0
                        
                        for detailRow in detailsStatement {
                            guard detailRow.count >= 4 else { continue }
                            
                            let setNumber: Int
                            let weight: Double
                            let reps: Int
                            let isCompleted: Bool
                            
                            // 安全地提取数据
                            if let num = detailRow[0] as? Int64 {
                                setNumber = Int(num)
                            } else if let num = detailRow[0] as? Int {
                                setNumber = num
                            } else {
                                continue
                            }
                            
                            if let w = detailRow[1] as? Double {
                                weight = w
                            } else if let w = detailRow[1] as? Int64 {
                                weight = Double(w)
                            } else if let w = detailRow[1] as? Int {
                                weight = Double(w)
                            } else {
                                continue
                            }
                            
                            if let r = detailRow[2] as? Int64 {
                                reps = Int(r)
                            } else if let r = detailRow[2] as? Int {
                                reps = r
                            } else {
                                continue
                            }
                            
                            if let completed = detailRow[3] as? Bool {
                                isCompleted = completed
                            } else if let completed = detailRow[3] as? Int64 {
                                isCompleted = completed != 0
                            } else if let completed = detailRow[3] as? Int {
                                isCompleted = completed != 0
                            } else {
                                continue
                            }
                            
                            let weightInt = Int(weight)
                            sets.append(ActionHistorySet(
                                setNumber: setNumber,
                                weight: weightInt,
                                reps: reps,
                                isCompleted: isCompleted
                            ))
                            
                            // 计算总容量（只计算完成的组）
                            if isCompleted {
                                totalVolume += weightInt * reps
                            }
                        }
                        
                        actionHistoryData.append(ActionHistoryData(
                            date: trainingDate,
                            planName: planName,
                            sets: sets,
                            totalVolume: totalVolume
                        ))
                    }
                    
                    continuation.resume(returning: actionHistoryData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - 数据模型
struct ActionHistoryData {
    let date: String
    let planName: String
    let sets: [ActionHistorySet]
    let totalVolume: Int
}

struct ActionHistorySet {
    let setNumber: Int
    let weight: Int
    let reps: Int
    let isCompleted: Bool
}

// MARK: - 历史记录卡片
struct ActionHistoryCard: SwiftUI.View {
    @Environment(\.theme) private var theme: AppTheme
    let data: ActionHistoryData
    let index: Int
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter
    }()
    
    private var formattedDate: String {
        if let date = dateFormatter.date(from: data.date) {
            return displayDateFormatter.string(from: date)
        }
        return data.date
    }
    
    var body: some SwiftUI.View {
        VStack(spacing: 0) {
            // 卡片头部
            cardHeader
            
            // 组数详情（始终显示）
            setsDetail
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    theme.surface,
                    theme.surface.opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: theme.shadow.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 卡片头部
    private var cardHeader: some SwiftUI.View {
        HStack(spacing: 12) {
            // 序号
            Text("\(index)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.onPrimary)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            theme.primary,
                            theme.primary.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(theme.primary.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: theme.primary.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // 训练信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(formattedDate)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.onSurface)
                    
                    Spacer()
                    
                    Text("\(data.totalVolume)kg")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(theme.secondary.opacity(0.1))
                        )
                        .overlay(
                            Capsule()
                                .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                HStack {
                    Text(data.planName)
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondary)
                    
                    Spacer()
                    
                    Text("\(data.sets.count)组")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(theme.secondary.opacity(0.1))
                        )
                        .overlay(
                            Capsule()
                                .stroke(theme.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
        }
        .padding(16)
    }
    
    // MARK: - 组数详情
    private var setsDetail: some SwiftUI.View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 16)
            
            // 表头
            HStack {
                Text("组")
                    .frame(width: 40, alignment: .center)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.primary)
                
                Text("重量")
                    .frame(width: 60, alignment: .center)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.primary)
                
                Text("次数")
                    .frame(width: 60, alignment: .center)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.primary)
                
                Text("状态")
                    .frame(width: 60, alignment: .center)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        theme.primary.opacity(0.08),
                        theme.primary.opacity(0.05)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            // 组数列表
            ForEach(Array(data.sets.enumerated()), id: \.offset) { index, set in
                setRow(set, isEven: index % 2 == 0)
            }
        }
    }
    
    // MARK: - 单组行
    private func setRow(_ set: ActionHistorySet, isEven: Bool) -> some SwiftUI.View {
        HStack {
            Text("\(set.setNumber)")
                .frame(width: 40, alignment: .center)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.onSurface)
            
            Text("\(set.weight)kg")
                .frame(width: 60, alignment: .center)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.primary)
            
            Text("\(set.reps)")
                .frame(width: 60, alignment: .center)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.primary)
            
            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .frame(width: 60, alignment: .center)
                .font(.system(size: 18))
                .foregroundColor(set.isCompleted ? theme.primary : theme.error)
                .shadow(color: (set.isCompleted ? theme.primary : theme.error).opacity(0.3), radius: 2, x: 0, y: 1)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            isEven ? 
            theme.surface : 
            theme.background.opacity(0.3)
        )
    }
}

#Preview {
    ActionHistoryView(actionId: 1, actionName: "卧推")
}


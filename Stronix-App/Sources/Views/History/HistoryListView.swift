import SwiftUI

struct HistoryListView: View {
    @Environment(\.theme) private var theme: AppTheme
    @Environment(\.dismiss) private var dismiss

    let selectedDate: Date
    let selectedDateString: String
    private let repository: TrainingHistoryRepository
    private let ownerIDProvider: () -> Int?
    private let deleteHistory: (Int) async throws -> Void
    @StateObject private var viewModel: HistoryListViewModel
    @State private var historyToDelete: TrainingHistoryItem?
    @State private var deleteErrorMessage: String?
    @State private var isDeleting = false

    init(
        selectedDateString: String,
        repository: TrainingHistoryRepository = SQLiteTrainingHistoryRepository(),
        ownerIDProvider: @escaping () -> Int? = { CurrentUserContext.shared.currentUserID },
        deleteHistory: @escaping (Int) async throws -> Void = { _ in }
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        self.selectedDate = formatter.date(from: selectedDateString) ?? Date()
        self.selectedDateString = selectedDateString
        self.repository = repository
        self.ownerIDProvider = ownerIDProvider
        self.deleteHistory = deleteHistory
        _viewModel = StateObject(wrappedValue: HistoryListViewModel(repository: repository))
    }

    init(
        selectedDate: Date,
        repository: TrainingHistoryRepository = SQLiteTrainingHistoryRepository(),
        ownerIDProvider: @escaping () -> Int? = { CurrentUserContext.shared.currentUserID },
        deleteHistory: @escaping (Int) async throws -> Void = { _ in }
    ) {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let dateString = String(format: "%04d-%02d-%02d", components.year ?? 1970, components.month ?? 1, components.day ?? 1)
        self.selectedDate = selectedDate
        self.selectedDateString = dateString
        self.repository = repository
        self.ownerIDProvider = ownerIDProvider
        self.deleteHistory = deleteHistory
        _viewModel = StateObject(wrappedValue: HistoryListViewModel(repository: repository))
    }

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

    var body: some View {
        VStack(spacing: 0) {
            logoSection
            navigationSection
            content
        }
        .navigationBarHidden(true)
        .task(id: selectedDateString) {
            await load()
        }
        .alert("确认删除", isPresented: Binding(
            get: { historyToDelete != nil },
            set: { if !$0 { historyToDelete = nil } }
        )) {
            Button("取消", role: .cancel) { historyToDelete = nil }
            Button("删除", role: .destructive) {
                if let historyToDelete {
                    Task { await delete(historyToDelete) }
                }
            }
            .disabled(isDeleting)
        } message: {
            Text("确定要删除训练记录「\(historyToDelete?.plan_name ?? "")」吗？此操作无法撤销。")
        }
        .alert("删除失败", isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            Spacer()
            VStack {
                ProgressView("加载训练记录...")
                Text("正在加载 \(selectedDate, formatter: dateFormatter) 的训练数据")
                    .font(.caption)
                    .foregroundColor(theme.secondary)
                    .padding(.top, 8)
            }
            Spacer()
        case .empty:
            emptyState
        case .failure(let message):
            failureState(message)
        case .success(let page):
            historyListSection(page.histories)
        }
    }

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
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(theme.primary)
            }
            Spacer()
            Text("训练记录").font(.headline)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding()
        .background(theme.surface)
        .shadow(color: theme.shadow.opacity(0.1), radius: 1, y: 1)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
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
            Spacer()
        }
        .padding()
    }

    private func failureState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(theme.warning)
            Text("加载失败").font(.headline).foregroundColor(theme.onSurface)
            Text(message).font(.subheadline).foregroundColor(theme.secondary).multilineTextAlignment(.center)
            Button("重试") { Task { await viewModel.retry() } }
                .padding()
                .background(theme.primary)
                .foregroundColor(theme.onPrimary)
                .cornerRadius(8)
            Spacer()
        }
        .padding()
    }

    private func historyListSection(_ histories: [TrainingHistoryItem]) -> some View {
        VStack(spacing: 0) {
            Text("\(selectedDate, formatter: dateFormatter)").font(.headline).padding()
            Text("该日期的训练记录：")
                .font(.subheadline)
                .foregroundColor(theme.secondary)
                .padding(.bottom)
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(histories, id: \.id) { history in
                        HStack(spacing: 0) {
                            NavigationLink(destination: TrainingHistoryDetailView(
                                historyId: history.id,
                                repository: repository,
                                ownerIDProvider: ownerIDProvider
                            )) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(history.plan_name).font(.headline).foregroundColor(theme.onSurface)
                                        Text(formatTrainingTime(history.training_date)).font(.caption).foregroundColor(theme.secondary)
                                        HStack {
                                            Text("时长: \(formatDuration(history.duration))").font(.caption).foregroundColor(theme.secondary)
                                            Spacer()
                                            Text("重量: \(Int(history.volume))kg").font(.caption).foregroundColor(theme.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(theme.secondary)
                                }
                                .padding()
                            }
                            .buttonStyle(.plain)
                            Button { historyToDelete = history } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(theme.error)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .background(theme.surface.opacity(0.5))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }

    private func delete(_ history: TrainingHistoryItem) async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await deleteHistory(history.id)
            historyToDelete = nil
            await load()
        } catch {
            historyToDelete = nil
            deleteErrorMessage = AppError.map(error).userMessage
        }
    }

    private func load() async {
        guard let ownerID = ownerIDProvider() else {
            await viewModel.load(query: TrainingHistoryListQuery(
                ownerID: 0,
                page: TrainingHistoryPageRequest(page: 1, pageSize: 100),
                filter: TrainingHistoryFilter()
            ))
            return
        }
        await viewModel.load(query: TrainingHistoryListQuery(
            ownerID: ownerID,
            page: TrainingHistoryPageRequest(page: 1, pageSize: 100),
            filter: TrainingHistoryFilter(
                dateRange: TrainingHistoryDateRange(startDate: selectedDateString, endDate: selectedDateString)
            )
        ))
    }

    private func formatTrainingTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString).map(timeFormatter.string) ?? dateString
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 { return "\(hours)小时\(remainder)分钟" }
        return minutes > 0 ? "\(minutes)分钟" : "<1分钟"
    }
}

#Preview {
    HistoryListView(selectedDate: Date())
}

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var userSession: UserSession
    @Environment(\.designTokens) private var tokens
    @Environment(\.theme) private var theme: AppTheme
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedHistoryTab: HistoryTab = .calendar
    private let historyRepository: TrainingHistoryRepository
    private let deleteHistory: (Int) async throws -> Void

    init(
        historyRepository: TrainingHistoryRepository = SQLiteTrainingHistoryRepository(),
        deleteHistory: @escaping (Int) async throws -> Void = { historyID in
            try await TrainingHistoryService.shared.deleteTrainingHistory(historyId: historyID)
        }
    ) {
        self.historyRepository = historyRepository
        self.deleteHistory = deleteHistory
    }

    enum HistoryTab: String, CaseIterable, Identifiable {
        case calendar = "日历"
        case statistics = "统计"

        var id: String { self.rawValue }
    }

    private var lightTokens: DesignTokens {
        DesignTokens(theme: theme, colorScheme: .light)
    }

    var body: some View {
        NavigationStack {
            if userSession.isAuthenticated {
                VStack(spacing: 0) {
                    // 自定义顶部Logo和标题
                    VStack(spacing: 8) {
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

                        HStack {
                            Spacer()
                            // 更多选项菜单 (包含"管理历史记录")
                            Menu {
                                NavigationLink {
                                    ManageHistoryRecordsView()
                                } label: {
                                    Label("管理历史记录", systemImage: "pencil.and.ellipsis.rectangle")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title2)
                                    .foregroundColor(lightTokens.contentPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(lightTokens.surface)
                    .shadow(color: lightTokens.shadow, radius: 1, y: 1)

                    // 日历/统计 切换器
                    Picker("历史选项", selection: $selectedHistoryTab) {
                        ForEach(HistoryTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 10)

                    // 根据选择显示对应内容
                    switch selectedHistoryTab {
                    case .calendar:
                        CalendarView(
                            repository: historyRepository,
                            deleteHistory: deleteHistory
                        )
                    case .statistics:
                        StatisticsView()
                    }
                    Spacer()
                }
                .background(lightTokens.canvas)
                .navigationBarHidden(true)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 56))
                        .foregroundColor(theme.secondary)
                    Text("请先登录")
                        .font(.headline)
                    Text("登录后可以查看您的训练历史")
                        .foregroundColor(theme.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(lightTokens.canvas)
            }
        }
        .environment(\.designTokens, lightTokens)
        .environment(\.colorScheme, .light)
    }
}

#Preview {
    HistoryView()
        .environmentObject(
            UserSession(
                operations: AuthenticationUseCases(
                    repository: SQLiteAuthRepository(),
                    sessionStore: InMemoryLocalSessionStore()
                )
            )
        )
}
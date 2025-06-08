import SwiftUI

struct HistoryView: View {
    @State private var selectedHistoryTab: HistoryTab = .calendar

    enum HistoryTab: String, CaseIterable, Identifiable {
        case calendar = "日历"
        case statistics = "统计"

        var id: String { self.rawValue }
    }

    var body: some View {
        NavigationView {
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
                            .foregroundColor(.blue)
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
                                .foregroundColor(.black)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .shadow(color: .gray.opacity(0.1), radius: 1, y: 1)

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
                    CalendarView()
                case .statistics:
                    StatisticsView()
                }
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    HistoryView()
} 
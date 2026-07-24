import SwiftUI

struct TrainingHistoryDetailView: View {
    @Environment(\.theme) private var theme: AppTheme
    @Environment(\.dismiss) private var dismiss

    let historyId: Int
    private let repository: TrainingHistoryRepository
    private let ownerIDProvider: () -> Int?
    @StateObject private var viewModel: TrainingHistoryDetailViewModel
    @State private var showEditView = false

    init(
        historyId: Int,
        repository: TrainingHistoryRepository = SQLiteTrainingHistoryRepository(),
        ownerIDProvider: @escaping () -> Int? = { CurrentUserContext.shared.currentUserID }
    ) {
        self.historyId = historyId
        self.repository = repository
        self.ownerIDProvider = ownerIDProvider
        _viewModel = StateObject(wrappedValue: TrainingHistoryDetailViewModel(repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            switch viewModel.phase {
            case .loading:
                Spacer()
                ProgressView("加载训练详情...")
                Spacer()
            case .empty:
                Spacer()
                Text("没有训练数据").foregroundColor(theme.secondary)
                Spacer()
            case .failure(let message):
                failure(message)
            case .success(let detail):
                details(detail)
            }
        }
        .navigationBarHidden(true)
        .task { await load() }
        .navigationDestination(isPresented: $showEditView) {
            if case .success(let detail) = viewModel.phase {
                EditHistoryDetailView(
                    selectedDate: trainingDate(from: detail.history.training_date),
                    historyData: editData(from: detail),
                    historyId: historyId
                )
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left").font(.title2).foregroundColor(theme.primary)
            }
            Spacer()
            Text("训练详情").font(.headline).foregroundColor(theme.onSurface)
            Spacer()
            Button("编辑") { showEditView = true }
                .font(.headline)
                .foregroundColor(theme.primary)
        }
        .padding()
        .background(theme.surface)
        .shadow(color: theme.shadow.opacity(0.1), radius: 1, y: 1)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle").font(.system(size: 50)).foregroundColor(theme.warning)
            Text("加载失败").font(.headline).foregroundColor(theme.onSurface)
            Text(message).font(.subheadline).foregroundColor(theme.secondary).multilineTextAlignment(.center)
            Button("重试") { Task { await viewModel.retry() } }
                .padding().background(theme.primary).foregroundColor(theme.onPrimary).cornerRadius(8)
            Spacer()
        }
        .padding()
    }

    private func details(_ detail: TrainingHistoryReadDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                let date = trainingDate(from: detail.history.training_date)
                HStack(spacing: 15) {
                    Image(systemName: "clock").foregroundColor(theme.secondary)
                    Text(date, formatter: dateFormatter).font(.subheadline).foregroundColor(theme.secondary)
                    Text("• \(trainingTime(detail.history.training_date))").font(.subheadline).foregroundColor(theme.secondary)
                }
                HStack {
                    Spacer()
                    summary(icon: "clock", value: formatDuration(detail.history.duration))
                    Spacer()
                    summary(icon: "scalemass", value: "\(String(format: "%.1f", detail.history.volume)) kg")
                    Spacer()
                }
                .padding().background(theme.shadow.opacity(0.1)).cornerRadius(10)
                ForEach(detail.actions, id: \.actionID) { action in
                    actionCard(action)
                }
            }
            .padding()
        }
    }

    private func summary(icon: String, value: String) -> some View {
        VStack { Image(systemName: icon).font(.title3); Text(value).font(.subheadline) }
    }

    private func actionCard(_ action: TrainingHistoryDetailAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional").font(.title2).foregroundColor(theme.primary)
                Text(action.name).font(.headline).foregroundColor(theme.onSurface)
                Spacer()
            }
            ForEach(action.sets, id: \.setNumber) { set in
                HStack {
                    Text("第\(set.setNumber)组").frame(width: 60, alignment: .leading)
                    if set.isBilateral {
                        Text("左\(String(format: "%.1f", set.leftWeight ?? 0))\(set.weightUnit) 右\(String(format: "%.1f", set.rightWeight ?? 0))\(set.weightUnit) × \(set.reps ?? 0)")
                    } else {
                        Text("\(String(format: "%.1f", set.weight ?? 0)) \(set.weightUnit) × \(set.reps ?? 0)")
                    }
                    Spacer()
                    if set.isCompleted { Image(systemName: "checkmark").foregroundColor(theme.success) }
                }
                .font(.subheadline).foregroundColor(theme.onSurface)
            }
        }
        .padding().background(theme.surface).cornerRadius(10)
        .shadow(color: theme.shadow.opacity(0.1), radius: 2, x: 0, y: 2)
    }

    private func editData(from detail: TrainingHistoryReadDetail) -> TrainingDetailData {
        TrainingDetailData(
            planName: detail.history.plan_name,
            duration: formatDuration(detail.history.duration),
            totalVolume: "\(String(format: "%.1f", detail.history.volume)) kg",
            exercises: detail.actions.map { action in
                ExerciseDetail(
                    action_id: action.actionID,
                    name: action.name,
                    sets: action.sets.map { set in
                        SetDetail(
                            number: set.setNumber,
                            weight: set.weight ?? 0,
                            reps: set.reps ?? 0,
                            actualReps: set.reps ?? 0,
                            isCompleted: set.isCompleted,
                            leftWeight: set.leftWeight ?? 0,
                            rightWeight: set.rightWeight ?? 0,
                            isBilateral: set.isBilateral
                        )
                    }
                )
            }
        )
    }

    private func load() async {
        await viewModel.load(historyID: historyId, ownerID: ownerIDProvider() ?? 0)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy年MM月dd日"; return formatter
    }()
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"; return formatter
    }()
    private func trainingDate(from string: String) -> Date { ISO8601DateFormatter().date(from: string) ?? Date() }
    private func trainingTime(_ string: String) -> String { timeFormatter.string(from: trainingDate(from: string)) }
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60; let remainder = minutes % 60
        return hours > 0 ? "\(hours)小时\(remainder)分钟" : "\(minutes)分钟"
    }
}

#Preview { TrainingHistoryDetailView(historyId: 1) }

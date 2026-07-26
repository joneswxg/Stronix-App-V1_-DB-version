import Foundation

@MainActor
final class HistoryCalendarViewModel: ObservableObject, UserScopedStateResetting {
    enum Phase: Equatable {
        case idle
        case loading
        case success
        case failure(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var trainingDatesInMonth: Set<String> = []

    private let loadTrainingDates: LoadTrainingDatesUseCase
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(repository: TrainingHistoryRepository) {
        loadTrainingDates = LoadTrainingDatesUseCase(repository: repository)
    }

    func load(date: Date, ownerID: Int?) async {
        guard let ownerID else {
            loadTask?.cancel()
            loadTask = nil
            trainingDatesInMonth = []
            phase = .failure(AppError.authenticationRequired.userMessage)
            return
        }

        loadTask?.cancel()
        phase = .loading

        let generation = loadGeneration
        let range = dateRange(for: date)
        let loadTrainingDates = loadTrainingDates
        let task = Task { [weak self] in
            do {
                let dates = try await loadTrainingDates.execute(ownerID: ownerID, range: range)
                guard !Task.isCancelled, generation == self?.loadGeneration else { return }
                self?.trainingDatesInMonth = Set(dates.dates)
                self?.phase = .success
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, generation == self?.loadGeneration else { return }
                self?.phase = .failure(AppError.map(error).userMessage)
            }
        }
        loadTask = task
        await task.value
    }

    func resetUserScopedState() {
        loadGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        trainingDatesInMonth = []
        phase = .idle
    }

    private func dateRange(for date: Date) -> TrainingHistoryDateRange {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let startDate = String(format: "%04d-%02d-01", year, month)
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        let endDate = String(format: "%04d-%02d-%02d", year, month, daysInMonth)
        return TrainingHistoryDateRange(startDate: startDate, endDate: endDate)
    }
}

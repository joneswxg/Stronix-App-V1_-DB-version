import Foundation

@MainActor
final class HistoryListViewModel: ObservableObject, UserScopedStateResetting {
    enum Phase: Equatable {
        case idle
        case loading
        case success(TrainingHistoryPage)
        case empty(TrainingHistoryPagination)
        case failure(String)
    }

    @Published private(set) var phase: Phase = .idle

    private let repository: TrainingHistoryRepository
    private var lastQuery: TrainingHistoryListQuery?
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(repository: TrainingHistoryRepository) {
        self.repository = repository
    }

    func load(query: TrainingHistoryListQuery) async {
        loadTask?.cancel()
        lastQuery = query
        phase = .loading

        let generation = loadGeneration
        let repository = repository
        let task = Task { [weak self] in
            do {
                let page = try await Task.detached {
                    try repository.trainingHistory(query)
                }.value
                guard !Task.isCancelled, generation == self?.loadGeneration else { return }
                self?.phase = page.histories.isEmpty ? .empty(page.pagination) : .success(page)
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

    func retry() async {
        guard let lastQuery else { return }
        await load(query: lastQuery)
    }

    func resetUserScopedState() {
        loadGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        lastQuery = nil
        phase = .idle
    }
}

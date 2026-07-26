import Foundation

@MainActor
final class TrainingHistoryDetailViewModel: ObservableObject, UserScopedStateResetting {
    enum Phase: Equatable {
        case idle
        case loading
        case success(TrainingHistoryReadDetail)
        case empty
        case failure(String)
    }

    @Published private(set) var phase: Phase = .idle

    private let repository: TrainingHistoryRepository
    private var lastRequest: (historyID: Int, ownerID: Int)?
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(repository: TrainingHistoryRepository) {
        self.repository = repository
    }

    func load(historyID: Int, ownerID: Int) async {
        loadTask?.cancel()
        lastRequest = (historyID, ownerID)
        phase = .loading

        let generation = loadGeneration
        let repository = repository
        let task = Task { [weak self] in
            do {
                let detail = try await Task.detached {
                    try repository.trainingHistoryDetail(id: historyID, ownerID: ownerID)
                }.value
                guard !Task.isCancelled, generation == self?.loadGeneration else { return }
                self?.phase = detail.actions.isEmpty ? .empty : .success(detail)
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
        guard let lastRequest else { return }
        await load(historyID: lastRequest.historyID, ownerID: lastRequest.ownerID)
    }

    func resetUserScopedState() {
        loadGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        lastRequest = nil
        phase = .idle
    }
}

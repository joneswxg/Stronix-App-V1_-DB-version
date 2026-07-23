import Foundation

@MainActor
final class HistoryListViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case success(TrainingHistoryPage)
        case empty(TrainingHistoryPagination)
        case failure(String)
    }

    @Published private(set) var phase: Phase = .loading

    private let repository: TrainingHistoryRepository
    private var lastQuery: TrainingHistoryListQuery?

    init(repository: TrainingHistoryRepository) {
        self.repository = repository
    }

    func load(query: TrainingHistoryListQuery) async {
        lastQuery = query
        phase = .loading

        do {
            let repository = repository
            let page = try await Task.detached {
                try repository.trainingHistory(query)
            }.value
            phase = page.histories.isEmpty ? .empty(page.pagination) : .success(page)
        } catch {
            phase = .failure(AppError.map(error).userMessage)
        }
    }

    func retry() async {
        guard let lastQuery else { return }
        await load(query: lastQuery)
    }
}

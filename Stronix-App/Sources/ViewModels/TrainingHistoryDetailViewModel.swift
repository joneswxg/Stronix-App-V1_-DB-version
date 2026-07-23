import Foundation

@MainActor
final class TrainingHistoryDetailViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case success(TrainingHistoryReadDetail)
        case empty
        case failure(String)
    }

    @Published private(set) var phase: Phase = .loading

    private let repository: TrainingHistoryRepository
    private var lastRequest: (historyID: Int, ownerID: Int)?

    init(repository: TrainingHistoryRepository) {
        self.repository = repository
    }

    func load(historyID: Int, ownerID: Int) async {
        lastRequest = (historyID, ownerID)
        phase = .loading

        do {
            let repository = repository
            let detail = try await Task.detached {
                try repository.trainingHistoryDetail(id: historyID, ownerID: ownerID)
            }.value
            phase = detail.actions.isEmpty ? .empty : .success(detail)
        } catch {
            phase = .failure(AppError.map(error).userMessage)
        }
    }

    func retry() async {
        guard let lastRequest else { return }
        await load(historyID: lastRequest.historyID, ownerID: lastRequest.ownerID)
    }
}

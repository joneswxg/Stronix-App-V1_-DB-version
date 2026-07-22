import Foundation

@MainActor
final class ActionHistoryViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case success([ActionHistoryData])
        case empty
        case failure(String)
    }

    @Published private(set) var phase: Phase = .loading

    private let repository: ActionHistoryRepository

    init(repository: ActionHistoryRepository) {
        self.repository = repository
    }

    func load(actionID: Int) async {
        phase = .loading

        do {
            let repository = repository
            let history = try await Task.detached {
                try repository.actionHistory(for: actionID)
            }.value
            phase = history.isEmpty ? .empty : .success(history)
        } catch {
            phase = .failure(error.localizedDescription)
        }
    }

    func retry(actionID: Int) async {
        await load(actionID: actionID)
    }
}

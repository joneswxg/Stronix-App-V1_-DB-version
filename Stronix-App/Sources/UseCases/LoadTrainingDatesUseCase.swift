import Foundation

struct LoadTrainingDatesUseCase {
    private let repository: TrainingHistoryRepository

    init(repository: TrainingHistoryRepository) {
        self.repository = repository
    }

    func execute(
        ownerID: Int,
        range: TrainingHistoryDateRange
    ) async throws -> TrainingHistoryDates {
        try await Task.detached { [repository] in
            try repository.trainingDates(ownerID: ownerID, in: range)
        }.value
    }
}

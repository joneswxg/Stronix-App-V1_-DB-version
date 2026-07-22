import XCTest
@testable import Stronix

@MainActor
final class ActionHistoryViewModelTests: XCTestCase {
    func testLoadPublishesSuccess() async {
        let history = [ActionHistoryData(date: "2026-07-22", planName: "Push", sets: [], totalVolume: 0)]
        let repository = MockActionHistoryRepository(results: [.success(history)])
        let viewModel = ActionHistoryViewModel(repository: repository)

        await viewModel.load(actionID: 42)

        XCTAssertEqual(viewModel.phase, .success(history))
    }

    func testLoadPublishesEmpty() async {
        let repository = MockActionHistoryRepository(results: [.success([])])
        let viewModel = ActionHistoryViewModel(repository: repository)

        await viewModel.load(actionID: 42)

        XCTAssertEqual(viewModel.phase, .empty)
    }

    func testLoadPublishesFailure() async {
        let repository = MockActionHistoryRepository(results: [.failure(TestError.loadFailed)])
        let viewModel = ActionHistoryViewModel(repository: repository)

        await viewModel.load(actionID: 42)

        XCTAssertEqual(viewModel.phase, .failure(TestError.loadFailed.localizedDescription))
    }

    func testRetryLoadsAgainAfterFailure() async {
        let history = [ActionHistoryData(date: "2026-07-22", planName: "Push", sets: [], totalVolume: 0)]
        let repository = MockActionHistoryRepository(results: [.failure(TestError.loadFailed), .success(history)])
        let viewModel = ActionHistoryViewModel(repository: repository)

        await viewModel.load(actionID: 42)
        await viewModel.retry(actionID: 42)

        XCTAssertEqual(viewModel.phase, .success(history))
        XCTAssertEqual(repository.requestedActionIDs, [42, 42])
    }

    func testLoadForwardsActionID() async {
        let repository = MockActionHistoryRepository(results: [.success([])])
        let viewModel = ActionHistoryViewModel(repository: repository)

        await viewModel.load(actionID: 99)

        XCTAssertEqual(repository.requestedActionIDs, [99])
    }
}

private final class MockActionHistoryRepository: ActionHistoryRepository, @unchecked Sendable {
    private var results: [Result<[ActionHistoryData], Error>]
    private(set) var requestedActionIDs: [Int] = []

    init(results: [Result<[ActionHistoryData], Error>]) {
        self.results = results
    }

    func actionHistory(for actionID: Int) throws -> [ActionHistoryData] {
        requestedActionIDs.append(actionID)
        return try results.removeFirst().get()
    }
}

private enum TestError: LocalizedError {
    case loadFailed

    var errorDescription: String? {
        "Unable to load action history"
    }
}

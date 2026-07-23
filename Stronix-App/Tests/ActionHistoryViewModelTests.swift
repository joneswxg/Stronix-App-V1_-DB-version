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

    func testLoadPublishesUserSafeFailure() async {
        let repository = MockActionHistoryRepository(results: [.failure(TestError.loadFailed)])
        let viewModel = ActionHistoryViewModel(repository: repository)

        await viewModel.load(actionID: 42)

        XCTAssertEqual(viewModel.phase, .failure("暂时无法完成请求，请稍后重试"))
    }

    func testLoadDoesNotExposeDatabaseFailureDetails() async {
        let repository = MockActionHistoryRepository(results: [
            .failure(DatabaseError.operationFailed(underlying: TestError.databaseFailure))
        ])
        let viewModel = ActionHistoryViewModel(repository: repository)

        await viewModel.load(actionID: 42)

        XCTAssertEqual(viewModel.phase, .failure("数据暂时无法读取，请稍后重试"))
    }

    func testLoadDoesNotExposeRepositoryFailureDetails() async {
        let repository = MockActionHistoryRepository(results: [.failure(TestError.databaseFailure)])
        let viewModel = ActionHistoryViewModel(repository: repository)

        await viewModel.load(actionID: 42)

        guard case .failure(let message) = viewModel.phase else {
            return XCTFail("Expected a failure state")
        }
        XCTAssertEqual(message, "暂时无法完成请求，请稍后重试")
        XCTAssertFalse(message.contains("SQLite"))
        XCTAssertFalse(message.contains("SELECT"))
        XCTAssertFalse(message.contains("/tmp/stronix.db"))
        XCTAssertFalse(message.contains("LocalActionService"))
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
    case databaseFailure

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "Unable to load action history"
        case .databaseFailure:
            return "SQLite error near SELECT at /tmp/stronix.db from LocalActionService"
        }
    }
}

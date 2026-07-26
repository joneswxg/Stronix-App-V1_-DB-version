import XCTest
@testable import Stronix

@MainActor
final class HistoryListViewModelTests: XCTestCase {
    func testLoadPublishesSuccess() async {
        let page = makePage(histories: [makeHistory(id: 1)])
        let repository = MockTrainingHistoryRepository(listResults: [.success(page)])
        let viewModel = HistoryListViewModel(repository: repository)

        await viewModel.load(query: query())

        XCTAssertEqual(viewModel.phase, .success(page))
        XCTAssertEqual(repository.queries, [query()])
    }

    func testLoadPublishesEmpty() async {
        let page = makePage(histories: [])
        let repository = MockTrainingHistoryRepository(listResults: [.success(page)])
        let viewModel = HistoryListViewModel(repository: repository)

        await viewModel.load(query: query())

        XCTAssertEqual(viewModel.phase, .empty(page.pagination))
    }

    func testLoadPublishesUserSafeFailure() async {
        let repository = MockTrainingHistoryRepository(listResults: [.failure(TestHistoryError.loadFailed)])
        let viewModel = HistoryListViewModel(repository: repository)

        await viewModel.load(query: query())

        XCTAssertEqual(viewModel.phase, .failure("暂时无法完成请求，请稍后重试"))
    }

    func testRetryRepeatsQueryAfterFailure() async {
        let page = makePage(histories: [makeHistory(id: 1)])
        let repository = MockTrainingHistoryRepository(listResults: [.failure(TestHistoryError.loadFailed), .success(page)])
        let viewModel = HistoryListViewModel(repository: repository)

        await viewModel.load(query: query())
        await viewModel.retry()

        XCTAssertEqual(viewModel.phase, .success(page))
        XCTAssertEqual(repository.queries, [query(), query()])
    }

    func testLoadPublishesLoadingWhileRepositoryIsInFlight() async {
        let page = makePage(histories: [makeHistory(id: 1)])
        let repository = BlockingTrainingHistoryRepository(listResult: .success(page), detailResult: .success(makeDetail()))
        let viewModel = HistoryListViewModel(repository: repository)

        let loadTask = Task { await viewModel.load(query: query()) }
        await fulfillment(of: [repository.listRequestStarted], timeout: 1)

        XCTAssertEqual(viewModel.phase, .loading)

        repository.completeListRequest()
        await loadTask.value

        XCTAssertEqual(viewModel.phase, .success(page))
    }

    func testResetClearsStateAndKeepsDelayedResultFromPublishing() async {
        let stalePage = makePage(histories: [makeHistory(id: 1)])
        let repository = SequencedBlockingTrainingHistoryRepository(
            listResults: [.success(stalePage)],
            detailResults: []
        )
        let viewModel = HistoryListViewModel(repository: repository)

        let loadTask = Task { await viewModel.load(query: query()) }
        await fulfillment(of: [repository.listRequestStarted[0]], timeout: 1)

        viewModel.resetUserScopedState()

        XCTAssertEqual(viewModel.phase, .idle)

        repository.completeListRequest(at: 0)
        await loadTask.value

        XCTAssertEqual(viewModel.phase, .idle)
    }

    func testNewScopeResultWinsWhenOutgoingLoadCompletesLast() async {
        let stalePage = makePage(histories: [makeHistory(id: 1)])
        let currentPage = makePage(histories: [makeHistory(id: 2)])
        let repository = SequencedBlockingTrainingHistoryRepository(
            listResults: [.success(stalePage), .success(currentPage)],
            detailResults: []
        )
        let viewModel = HistoryListViewModel(repository: repository)

        let staleLoad = Task { await viewModel.load(query: query(ownerID: 7)) }
        await fulfillment(of: [repository.listRequestStarted[0]], timeout: 1)
        viewModel.resetUserScopedState()

        let currentLoad = Task { await viewModel.load(query: query(ownerID: 8)) }
        await fulfillment(of: [repository.listRequestStarted[1]], timeout: 1)

        repository.completeListRequest(at: 0)
        await staleLoad.value

        XCTAssertEqual(viewModel.phase, .loading)

        repository.completeListRequest(at: 1)
        await currentLoad.value

        XCTAssertEqual(viewModel.phase, .success(currentPage))
    }

    private func query(ownerID: Int = 7) -> TrainingHistoryListQuery {
        TrainingHistoryListQuery(
            ownerID: ownerID,
            page: TrainingHistoryPageRequest(page: 2, pageSize: 10),
            filter: TrainingHistoryFilter(
                userPlanID: 3,
                dateRange: TrainingHistoryDateRange(startDate: "2026-07-21", endDate: "2026-07-22")
            )
        )
    }
}

@MainActor
final class TrainingHistoryDetailViewModelTests: XCTestCase {
    func testLoadPublishesSuccess() async {
        let detail = makeDetail()
        let repository = MockTrainingHistoryRepository(detailResults: [.success(detail)])
        let viewModel = TrainingHistoryDetailViewModel(repository: repository)

        await viewModel.load(historyID: 42, ownerID: 7)

        XCTAssertEqual(viewModel.phase, .success(detail))
        XCTAssertEqual(repository.detailRequests.map { $0.historyID }, [42])
        XCTAssertEqual(repository.detailRequests.map { $0.ownerID }, [7])
    }

    func testLoadPublishesEmptyForDetailWithoutActions() async {
        let detail = TrainingHistoryReadDetail(history: makeHistory(id: 42), actions: [])
        let repository = MockTrainingHistoryRepository(detailResults: [.success(detail)])
        let viewModel = TrainingHistoryDetailViewModel(repository: repository)

        await viewModel.load(historyID: 42, ownerID: 7)

        XCTAssertEqual(viewModel.phase, .empty)
    }

    func testLoadDoesNotExposeDatabaseDetails() async {
        let repository = MockTrainingHistoryRepository(detailResults: [
            .failure(DatabaseError.operationFailed(underlying: TestHistoryError.databaseFailure))
        ])
        let viewModel = TrainingHistoryDetailViewModel(repository: repository)

        await viewModel.load(historyID: 42, ownerID: 7)

        XCTAssertEqual(viewModel.phase, .failure("数据暂时无法读取，请稍后重试"))
    }

    func testRetryRepeatsDetailRequestAfterFailure() async {
        let detail = makeDetail()
        let repository = MockTrainingHistoryRepository(detailResults: [.failure(TestHistoryError.loadFailed), .success(detail)])
        let viewModel = TrainingHistoryDetailViewModel(repository: repository)

        await viewModel.load(historyID: 42, ownerID: 7)
        await viewModel.retry()

        XCTAssertEqual(viewModel.phase, .success(detail))
        XCTAssertEqual(repository.detailRequests.map { $0.historyID }, [42, 42])
        XCTAssertEqual(repository.detailRequests.map { $0.ownerID }, [7, 7])
    }
    func testLoadPublishesLoadingWhileRepositoryIsInFlight() async {
        let detail = makeDetail()
        let repository = BlockingTrainingHistoryRepository(listResult: .success(makePage(histories: [])), detailResult: .success(detail))
        let viewModel = TrainingHistoryDetailViewModel(repository: repository)

        let loadTask = Task { await viewModel.load(historyID: 42, ownerID: 7) }
        await fulfillment(of: [repository.detailRequestStarted], timeout: 1)

        XCTAssertEqual(viewModel.phase, .loading)

        repository.completeDetailRequest()
        await loadTask.value

        XCTAssertEqual(viewModel.phase, .success(detail))
    }

    func testResetClearsStateAndKeepsDelayedResultFromPublishing() async {
        let repository = SequencedBlockingTrainingHistoryRepository(
            listResults: [],
            detailResults: [.success(makeDetail())]
        )
        let viewModel = TrainingHistoryDetailViewModel(repository: repository)

        let loadTask = Task { await viewModel.load(historyID: 42, ownerID: 7) }
        await fulfillment(of: [repository.detailRequestStarted[0]], timeout: 1)

        viewModel.resetUserScopedState()

        XCTAssertEqual(viewModel.phase, .idle)

        repository.completeDetailRequest(at: 0)
        await loadTask.value

        XCTAssertEqual(viewModel.phase, .idle)
    }

    func testNewScopeResultWinsWhenOutgoingLoadCompletesLast() async {
        let staleDetail = makeDetail(historyID: 42)
        let currentDetail = makeDetail(historyID: 84)
        let repository = SequencedBlockingTrainingHistoryRepository(
            listResults: [],
            detailResults: [.success(staleDetail), .success(currentDetail)]
        )
        let viewModel = TrainingHistoryDetailViewModel(repository: repository)

        let staleLoad = Task { await viewModel.load(historyID: 42, ownerID: 7) }
        await fulfillment(of: [repository.detailRequestStarted[0]], timeout: 1)
        viewModel.resetUserScopedState()

        let currentLoad = Task { await viewModel.load(historyID: 84, ownerID: 8) }
        await fulfillment(of: [repository.detailRequestStarted[1]], timeout: 1)

        repository.completeDetailRequest(at: 0)
        await staleLoad.value

        XCTAssertEqual(viewModel.phase, .loading)

        repository.completeDetailRequest(at: 1)
        await currentLoad.value

        XCTAssertEqual(viewModel.phase, .success(currentDetail))
    }
}

@MainActor
final class HistoryCalendarViewModelTests: XCTestCase {
    func testResetClearsDatesAndKeepsDelayedResultFromPublishing() async {
        let staleDates = TrainingHistoryDates(
            dates: ["2026-07-22"],
            range: TrainingHistoryDateRange(startDate: "2026-07-01", endDate: "2026-07-31")
        )
        let repository = SequencedBlockingTrainingHistoryRepository(
            dateResults: [.success(staleDates)],
            listResults: [],
            detailResults: []
        )
        let viewModel = HistoryCalendarViewModel(repository: repository)

        let loadTask = Task { await viewModel.load(date: sampleMonth(), ownerID: 7) }
        await fulfillment(of: [repository.dateRequestStarted[0]], timeout: 1)

        viewModel.resetUserScopedState()

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertEqual(viewModel.trainingDatesInMonth, [])

        repository.completeDateRequest(at: 0)
        await loadTask.value

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertEqual(viewModel.trainingDatesInMonth, [])
    }

    func testNewScopeDatesWinWhenOutgoingLoadCompletesLast() async {
        let staleDates = TrainingHistoryDates(
            dates: ["2026-07-22"],
            range: TrainingHistoryDateRange(startDate: "2026-07-01", endDate: "2026-07-31")
        )
        let currentDates = TrainingHistoryDates(
            dates: ["2026-07-23"],
            range: TrainingHistoryDateRange(startDate: "2026-07-01", endDate: "2026-07-31")
        )
        let repository = SequencedBlockingTrainingHistoryRepository(
            dateResults: [.success(staleDates), .success(currentDates)],
            listResults: [],
            detailResults: []
        )
        let viewModel = HistoryCalendarViewModel(repository: repository)

        let staleLoad = Task { await viewModel.load(date: sampleMonth(), ownerID: 7) }
        await fulfillment(of: [repository.dateRequestStarted[0]], timeout: 1)
        viewModel.resetUserScopedState()

        let currentLoad = Task { await viewModel.load(date: sampleMonth(), ownerID: 8) }
        await fulfillment(of: [repository.dateRequestStarted[1]], timeout: 1)

        repository.completeDateRequest(at: 0)
        await staleLoad.value

        XCTAssertEqual(viewModel.phase, .loading)

        repository.completeDateRequest(at: 1)
        await currentLoad.value

        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertEqual(viewModel.trainingDatesInMonth, ["2026-07-23"])
    }

    private func sampleMonth() -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 1))!
    }
}

private final class SequencedBlockingTrainingHistoryRepository: TrainingHistoryRepository, @unchecked Sendable {
    private(set) var dateRequestStarted: [XCTestExpectation]
    private(set) var listRequestStarted: [XCTestExpectation]
    private(set) var detailRequestStarted: [XCTestExpectation]

    private let dateResults: [Result<TrainingHistoryDates, Error>]
    private let listResults: [Result<TrainingHistoryPage, Error>]
    private let detailResults: [Result<TrainingHistoryReadDetail, Error>]
    private var dateCompletions: [DispatchSemaphore] = []
    private var listCompletions: [DispatchSemaphore] = []
    private var detailCompletions: [DispatchSemaphore] = []
    private let lock = NSLock()

    init(
        dateResults: [Result<TrainingHistoryDates, Error>] = [],
        listResults: [Result<TrainingHistoryPage, Error>],
        detailResults: [Result<TrainingHistoryReadDetail, Error>]
    ) {
        self.dateResults = dateResults
        self.listResults = listResults
        self.detailResults = detailResults
        dateRequestStarted = dateResults.map { _ in XCTestExpectation(description: "date request started") }
        listRequestStarted = listResults.map { _ in XCTestExpectation(description: "list request started") }
        detailRequestStarted = detailResults.map { _ in XCTestExpectation(description: "detail request started") }
    }

    func trainingDates(ownerID: Int, in range: TrainingHistoryDateRange) throws -> TrainingHistoryDates {
        let request = lock.withLock { () -> (XCTestExpectation, DispatchSemaphore, Result<TrainingHistoryDates, Error>) in
            let index = dateCompletions.count
            let completion = DispatchSemaphore(value: 0)
            dateCompletions.append(completion)
            return (dateRequestStarted[index], completion, dateResults[index])
        }
        request.0.fulfill()
        request.1.wait()
        return try request.2.get()
    }

    func trainingHistory(_ query: TrainingHistoryListQuery) throws -> TrainingHistoryPage {
        let request = lock.withLock { () -> (XCTestExpectation, DispatchSemaphore, Result<TrainingHistoryPage, Error>) in
            let index = listCompletions.count
            let completion = DispatchSemaphore(value: 0)
            listCompletions.append(completion)
            return (listRequestStarted[index], completion, listResults[index])
        }
        request.0.fulfill()
        request.1.wait()
        return try request.2.get()
    }

    func trainingHistoryDetail(id: Int, ownerID: Int) throws -> TrainingHistoryReadDetail {
        let request = lock.withLock { () -> (XCTestExpectation, DispatchSemaphore, Result<TrainingHistoryReadDetail, Error>) in
            let index = detailCompletions.count
            let completion = DispatchSemaphore(value: 0)
            detailCompletions.append(completion)
            return (detailRequestStarted[index], completion, detailResults[index])
        }
        request.0.fulfill()
        request.1.wait()
        return try request.2.get()
    }

    func completeDateRequest(at index: Int) {
        _ = lock.withLock { dateCompletions[index].signal() }
    }

    func completeListRequest(at index: Int) {
        _ = lock.withLock { listCompletions[index].signal() }
    }

    func completeDetailRequest(at index: Int) {
        _ = lock.withLock { detailCompletions[index].signal() }
    }
}

private final class BlockingTrainingHistoryRepository: TrainingHistoryRepository, @unchecked Sendable {
    let listRequestStarted = XCTestExpectation(description: "list request started")
    let detailRequestStarted = XCTestExpectation(description: "detail request started")

    private let listResult: Result<TrainingHistoryPage, Error>
    private let detailResult: Result<TrainingHistoryReadDetail, Error>
    private let listCompletion = DispatchSemaphore(value: 0)
    private let detailCompletion = DispatchSemaphore(value: 0)

    init(
        listResult: Result<TrainingHistoryPage, Error>,
        detailResult: Result<TrainingHistoryReadDetail, Error>
    ) {
        self.listResult = listResult
        self.detailResult = detailResult
    }

    func trainingDates(ownerID: Int, in range: TrainingHistoryDateRange) throws -> TrainingHistoryDates {
        TrainingHistoryDates(dates: [], range: range)
    }

    func trainingHistory(_ query: TrainingHistoryListQuery) throws -> TrainingHistoryPage {
        listRequestStarted.fulfill()
        listCompletion.wait()
        return try listResult.get()
    }

    func trainingHistoryDetail(id: Int, ownerID: Int) throws -> TrainingHistoryReadDetail {
        detailRequestStarted.fulfill()
        detailCompletion.wait()
        return try detailResult.get()
    }

    func completeListRequest() {
        listCompletion.signal()
    }

    func completeDetailRequest() {
        detailCompletion.signal()
    }
}

private final class MockTrainingHistoryRepository: TrainingHistoryRepository, @unchecked Sendable {
    private var listResults: [Result<TrainingHistoryPage, Error>]
    private var detailResults: [Result<TrainingHistoryReadDetail, Error>]
    private(set) var queries: [TrainingHistoryListQuery] = []
    private(set) var detailRequests: [(historyID: Int, ownerID: Int)] = []

    init(
        listResults: [Result<TrainingHistoryPage, Error>] = [],
        detailResults: [Result<TrainingHistoryReadDetail, Error>] = []
    ) {
        self.listResults = listResults
        self.detailResults = detailResults
    }

    func trainingDates(ownerID: Int, in range: TrainingHistoryDateRange) throws -> TrainingHistoryDates {
        TrainingHistoryDates(dates: [], range: range)
    }

    func trainingHistory(_ query: TrainingHistoryListQuery) throws -> TrainingHistoryPage {
        queries.append(query)
        return try listResults.removeFirst().get()
    }

    func trainingHistoryDetail(id: Int, ownerID: Int) throws -> TrainingHistoryReadDetail {
        detailRequests.append((id, ownerID))
        return try detailResults.removeFirst().get()
    }
}

private enum TestHistoryError: LocalizedError {
    case loadFailed
    case databaseFailure

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "Unable to load training history"
        case .databaseFailure:
            return "SQLite error near SELECT at /tmp/stronix.db"
        }
    }
}

private func makeHistory(id: Int) -> TrainingHistoryItem {
    TrainingHistoryItem(
        id: id,
        plan_id: 3,
        plan_name: "Push",
        training_date: "2026-07-22T12:00:00Z",
        volume: 300,
        duration: 45,
        note: nil,
        created_at: "2026-07-22T12:00:00Z"
    )
}

private func makePage(histories: [TrainingHistoryItem]) -> TrainingHistoryPage {
    TrainingHistoryPage(
        histories: histories,
        pagination: TrainingHistoryPagination(page: 1, pageSize: 20, total: histories.count, pageCount: histories.isEmpty ? 0 : 1)
    )
}

private func makeDetail(historyID: Int = 42) -> TrainingHistoryReadDetail {
    TrainingHistoryReadDetail(
        history: makeHistory(id: historyID),
        actions: [
            TrainingHistoryDetailAction(
                actionID: 1,
                name: "Squat",
                sets: [
                    TrainingHistoryDetailSet(
                        setNumber: 1,
                        weight: 40,
                        weightUnit: "kg",
                        reps: 10,
                        difficulty: nil,
                        leftWeight: nil,
                        rightWeight: nil,
                        isCompleted: true,
                        isBilateral: false
                    )
                ]
            )
        ]
    )
}

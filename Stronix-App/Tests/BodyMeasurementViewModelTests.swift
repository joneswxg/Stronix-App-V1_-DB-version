import XCTest
@testable import Stronix

@MainActor
final class BodyMeasurementViewModelTests: XCTestCase {
    func testMutationsUpdateSharedMeasurementsAndSelectedDataPoint() async {
        let older = measurement(id: 1, timestamp: Date(timeIntervalSince1970: 1_000), weight: 70)
        let newer = measurement(id: 2, timestamp: Date(timeIntervalSince1970: 2_000), weight: 72)
        let updated = measurement(id: 1, timestamp: Date(timeIntervalSince1970: 3_000), weight: 71)
        let operations = BodyMeasurementOperationsStub(
            measurements: [older],
            createdMeasurement: newer,
            updatedMeasurement: updated
        )
        let viewModel = BodyMeasurementViewModel(operations: operations)

        await viewModel.loadMeasurements()
        XCTAssertEqual(viewModel.measurements, [older])

        let didAdd = await viewModel.addMeasurement(draft())
        XCTAssertTrue(didAdd)
        XCTAssertEqual(viewModel.measurements, [newer, older])
        XCTAssertEqual(viewModel.selectedDataPoint, newer)

        let didUpdate = await viewModel.updateMeasurement(id: older.id, with: draft())
        XCTAssertTrue(didUpdate)
        XCTAssertEqual(viewModel.measurements, [updated, newer])

        viewModel.selectDataPoint(updated)
        let didDelete = await viewModel.deleteMeasurement(updated.id)
        XCTAssertTrue(didDelete)
        XCTAssertEqual(viewModel.measurements, [newer])
        XCTAssertEqual(viewModel.selectedDataPoint, newer)
    }

    func testCreateFailurePreservesLoadedStateAndSuccessfulRetryClearsSafeError() async {
        let existing = measurement(id: 1, timestamp: Date(timeIntervalSince1970: 1_000), weight: 70)
        let created = measurement(id: 2, timestamp: Date(timeIntervalSince1970: 2_000), weight: 72)
        let operations = BodyMeasurementOperationsStub(
            measurements: [existing],
            createdMeasurement: created,
            createError: BodyMeasurementRepositoryError.unauthenticated
        )
        let viewModel = BodyMeasurementViewModel(operations: operations)

        await viewModel.loadMeasurements()
        let didCreate = await viewModel.addMeasurement(draft())

        XCTAssertFalse(didCreate)
        XCTAssertEqual(viewModel.measurements, [existing])
        XCTAssertEqual(viewModel.selectedDataPoint, existing)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.text("bodyMeasurement.error.unauthenticated"))

        operations.createError = nil
        let didRetry = await viewModel.addMeasurement(draft())

        XCTAssertTrue(didRetry)
        XCTAssertEqual(viewModel.measurements, [created, existing])
        XCTAssertEqual(viewModel.selectedDataPoint, created)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testUpdateFailurePreservesLoadedStateAndSuccessfulRetryClearsSafeError() async {
        let existing = measurement(id: 1, timestamp: Date(timeIntervalSince1970: 1_000), weight: 70)
        let updated = measurement(id: 1, timestamp: Date(timeIntervalSince1970: 2_000), weight: 71)
        let operations = BodyMeasurementOperationsStub(
            measurements: [existing],
            updatedMeasurement: updated,
            updateError: BodyMeasurementRepositoryError.notFoundOrUnauthorized
        )
        let viewModel = BodyMeasurementViewModel(operations: operations)

        await viewModel.loadMeasurements()
        let didUpdate = await viewModel.updateMeasurement(id: existing.id, with: draft())

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(viewModel.measurements, [existing])
        XCTAssertEqual(viewModel.selectedDataPoint, existing)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.text("bodyMeasurement.error.unavailable"))

        operations.updateError = nil
        let didRetry = await viewModel.updateMeasurement(id: existing.id, with: draft())

        XCTAssertTrue(didRetry)
        XCTAssertEqual(viewModel.measurements, [updated])
        XCTAssertEqual(viewModel.selectedDataPoint, updated)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDeleteFailurePreservesLoadedStateAndSuccessfulRetryClearsSafeError() async {
        let existing = measurement(id: 1, timestamp: Date(timeIntervalSince1970: 1_000), weight: 70)
        let operations = BodyMeasurementOperationsStub(
            measurements: [existing],
            deleteError: TestPersistenceError()
        )
        let viewModel = BodyMeasurementViewModel(operations: operations)

        await viewModel.loadMeasurements()
        let didDelete = await viewModel.deleteMeasurement(existing.id)

        XCTAssertFalse(didDelete)
        XCTAssertEqual(viewModel.measurements, [existing])
        XCTAssertEqual(viewModel.selectedDataPoint, existing)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.text("bodyMeasurement.error.generic"))

        operations.deleteError = nil
        let didRetry = await viewModel.deleteMeasurement(existing.id)

        XCTAssertTrue(didRetry)
        XCTAssertTrue(viewModel.measurements.isEmpty)
        XCTAssertNil(viewModel.selectedDataPoint)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadFailureClearsLoadingAndRecoveryClearsError() async {
        let expected = measurement(id: 1, timestamp: Date(), weight: 70)
        let operations = BodyMeasurementOperationsStub(
            measurements: [expected],
            listError: BodyMeasurementRepositoryError.unauthenticated
        )
        let viewModel = BodyMeasurementViewModel(operations: operations)

        await viewModel.loadMeasurements()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.measurements.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, AppStrings.text("bodyMeasurement.error.unauthenticated"))

        operations.listError = nil
        await viewModel.loadMeasurements()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.measurements, [expected])
    }

    func testResetUserScopedStateClearsAllUserSpecificUIState() async {
        let record = measurement(id: 1, timestamp: Date(), weight: 70)
        let viewModel = BodyMeasurementViewModel(
            operations: BodyMeasurementOperationsStub(measurements: [record])
        )

        await viewModel.loadMeasurements()
        viewModel.showAddSheet()
        viewModel.errorMessage = "failure"
        viewModel.resetUserScopedState()

        XCTAssertTrue(viewModel.measurements.isEmpty)
        XCTAssertNil(viewModel.selectedDataPoint)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showingAddSheet)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testDelayedUserADeleteCannotRemoveUserBRecordWithSameID() async {
        let userBMeasurement = measurement(id: 1, timestamp: Date(timeIntervalSince1970: 2_000), weight: 80)
        let operations = SuspendingDeleteBodyMeasurementOperations(measurements: [userBMeasurement])
        let viewModel = BodyMeasurementViewModel(operations: operations)

        let delete = Task { await viewModel.deleteMeasurement(userBMeasurement.id) }
        await fulfillment(of: [operations.deleteRequestStarted], timeout: 1)

        viewModel.resetUserScopedState()
        await viewModel.loadMeasurements()
        operations.completeDeleteRequest()
        let didDelete = await delete.value

        XCTAssertFalse(didDelete)
        XCTAssertEqual(viewModel.measurements, [userBMeasurement])
        XCTAssertEqual(viewModel.selectedDataPoint, userBMeasurement)
        XCTAssertEqual(viewModel.chartData, [userBMeasurement])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDelayedUserAUpdateCannotReplaceUserBRecordWithSameID() async {
        let userAUpdatedMeasurement = measurement(id: 1, timestamp: Date(timeIntervalSince1970: 1_000), weight: 70)
        let userBMeasurement = measurement(id: 1, timestamp: Date(timeIntervalSince1970: 2_000), weight: 80)
        let operations = SuspendingUpdateBodyMeasurementOperations(
            measurements: [userBMeasurement],
            updatedMeasurement: userAUpdatedMeasurement
        )
        let viewModel = BodyMeasurementViewModel(operations: operations)

        let update = Task { await viewModel.updateMeasurement(id: 1, with: draft()) }
        await fulfillment(of: [operations.updateRequestStarted], timeout: 1)

        viewModel.resetUserScopedState()
        await viewModel.loadMeasurements()
        operations.completeUpdateRequest()
        let didUpdate = await update.value

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(viewModel.measurements, [userBMeasurement])
        XCTAssertEqual(viewModel.selectedDataPoint, userBMeasurement)
        XCTAssertEqual(viewModel.chartData, [userBMeasurement])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDelayedUserACreateCannotPublishAfterUserBScopeLoads() async {
        let userAMeasurement = measurement(id: 1, timestamp: Date(timeIntervalSince1970: 1_000), weight: 70)
        let userBMeasurement = measurement(id: 2, timestamp: Date(timeIntervalSince1970: 2_000), weight: 80)
        let operations = SuspendingCreateBodyMeasurementOperations(
            measurements: [userBMeasurement],
            createdMeasurement: userAMeasurement
        )
        let viewModel = BodyMeasurementViewModel(operations: operations)

        let create = Task { await viewModel.addMeasurement(draft()) }
        await fulfillment(of: [operations.createRequestStarted], timeout: 1)

        viewModel.resetUserScopedState()
        await viewModel.loadMeasurements()
        operations.completeCreateRequest()
        let didCreate = await create.value

        XCTAssertFalse(didCreate)
        XCTAssertEqual(viewModel.measurements, [userBMeasurement])
        XCTAssertEqual(viewModel.selectedDataPoint, userBMeasurement)
        XCTAssertEqual(viewModel.chartData, [userBMeasurement])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testDelayedUserALoadCannotRepopulateMeasurementsAfterScopeReset() async {
        let userAMeasurement = measurement(id: 1, timestamp: Date(), weight: 70)
        let operations = SuspendingBodyMeasurementOperations(measurements: [userAMeasurement])
        let viewModel = BodyMeasurementViewModel(operations: operations)

        let load = Task { await viewModel.loadMeasurements() }
        await fulfillment(of: [operations.listRequestStarted], timeout: 1)

        viewModel.resetUserScopedState()
        operations.completeListRequest()
        await load.value

        XCTAssertTrue(viewModel.measurements.isEmpty)
        XCTAssertNil(viewModel.selectedDataPoint)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
}

private final class SuspendingDeleteBodyMeasurementOperations: BodyMeasurementOperating, @unchecked Sendable {
    let deleteRequestStarted = XCTestExpectation(description: "measurement delete request started")

    private let measurements: [BodyMeasurement]
    private let lock = NSLock()
    private var deleteContinuation: CheckedContinuation<Void, Error>?

    init(measurements: [BodyMeasurement]) {
        self.measurements = measurements
    }

    func listMeasurements() async throws -> [BodyMeasurement] {
        measurements
    }

    func measurement(id: Int) async throws -> BodyMeasurement {
        try XCTUnwrap(measurements.first { $0.id == id })
    }

    func createMeasurement(_ draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        throw BodyMeasurementRepositoryError.notFoundOrUnauthorized
    }

    func updateMeasurement(id: Int, with draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        throw BodyMeasurementRepositoryError.notFoundOrUnauthorized
    }

    func deleteMeasurement(id: Int) async throws {
        deleteRequestStarted.fulfill()
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock { deleteContinuation = continuation }
        }
    }

    func completeDeleteRequest() {
        let continuation = lock.withLock {
            defer { deleteContinuation = nil }
            return deleteContinuation
        }
        continuation?.resume(returning: ())
    }
}

private final class SuspendingUpdateBodyMeasurementOperations: BodyMeasurementOperating, @unchecked Sendable {
    let updateRequestStarted = XCTestExpectation(description: "measurement update request started")

    private let measurements: [BodyMeasurement]
    private let updatedMeasurement: BodyMeasurement
    private let lock = NSLock()
    private var updateContinuation: CheckedContinuation<BodyMeasurement, Error>?

    init(measurements: [BodyMeasurement], updatedMeasurement: BodyMeasurement) {
        self.measurements = measurements
        self.updatedMeasurement = updatedMeasurement
    }

    func listMeasurements() async throws -> [BodyMeasurement] {
        measurements
    }

    func measurement(id: Int) async throws -> BodyMeasurement {
        try XCTUnwrap(measurements.first { $0.id == id })
    }

    func createMeasurement(_ draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        throw BodyMeasurementRepositoryError.notFoundOrUnauthorized
    }

    func updateMeasurement(id: Int, with draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        updateRequestStarted.fulfill()
        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock { updateContinuation = continuation }
        }
    }

    func completeUpdateRequest() {
        let continuation = lock.withLock {
            defer { updateContinuation = nil }
            return updateContinuation
        }
        continuation?.resume(returning: updatedMeasurement)
    }

    func deleteMeasurement(id: Int) async throws {}
}

private final class SuspendingCreateBodyMeasurementOperations: BodyMeasurementOperating, @unchecked Sendable {
    let createRequestStarted = XCTestExpectation(description: "measurement create request started")

    private let measurements: [BodyMeasurement]
    private let createdMeasurement: BodyMeasurement
    private let lock = NSLock()
    private var createContinuation: CheckedContinuation<BodyMeasurement, Error>?

    init(measurements: [BodyMeasurement], createdMeasurement: BodyMeasurement) {
        self.measurements = measurements
        self.createdMeasurement = createdMeasurement
    }

    func listMeasurements() async throws -> [BodyMeasurement] {
        measurements
    }

    func measurement(id: Int) async throws -> BodyMeasurement {
        try XCTUnwrap(measurements.first { $0.id == id })
    }

    func createMeasurement(_ draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        createRequestStarted.fulfill()
        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock { createContinuation = continuation }
        }
    }

    func completeCreateRequest() {
        let continuation = lock.withLock {
            defer { createContinuation = nil }
            return createContinuation
        }
        continuation?.resume(returning: createdMeasurement)
    }

    func updateMeasurement(id: Int, with draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        throw BodyMeasurementRepositoryError.notFoundOrUnauthorized
    }

    func deleteMeasurement(id: Int) async throws {}
}

private final class SuspendingBodyMeasurementOperations: BodyMeasurementOperating, @unchecked Sendable {
    let listRequestStarted = XCTestExpectation(description: "measurement list request started")

    private let measurements: [BodyMeasurement]
    private let lock = NSLock()
    private var listContinuation: CheckedContinuation<[BodyMeasurement], Error>?

    init(measurements: [BodyMeasurement]) {
        self.measurements = measurements
    }

    func listMeasurements() async throws -> [BodyMeasurement] {
        listRequestStarted.fulfill()
        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock { listContinuation = continuation }
        }
    }

    func completeListRequest() {
        let continuation = lock.withLock {
            defer { listContinuation = nil }
            return listContinuation
        }
        continuation?.resume(returning: measurements)
    }

    func measurement(id: Int) async throws -> BodyMeasurement {
        try XCTUnwrap(measurements.first { $0.id == id })
    }

    func createMeasurement(_ draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        throw BodyMeasurementRepositoryError.notFoundOrUnauthorized
    }

    func updateMeasurement(id: Int, with draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        throw BodyMeasurementRepositoryError.notFoundOrUnauthorized
    }

    func deleteMeasurement(id: Int) async throws {}
}

private struct TestPersistenceError: Error {}

private final class BodyMeasurementOperationsStub: BodyMeasurementOperating, @unchecked Sendable {
    var measurements: [BodyMeasurement]
    var listError: Error?
    let createdMeasurement: BodyMeasurement?
    let updatedMeasurement: BodyMeasurement?
    var createError: Error?
    var updateError: Error?
    var deleteError: Error?

    init(
        measurements: [BodyMeasurement],
        listError: Error? = nil,
        createdMeasurement: BodyMeasurement? = nil,
        updatedMeasurement: BodyMeasurement? = nil,
        createError: Error? = nil,
        updateError: Error? = nil,
        deleteError: Error? = nil
    ) {
        self.measurements = measurements
        self.listError = listError
        self.createdMeasurement = createdMeasurement
        self.updatedMeasurement = updatedMeasurement
        self.createError = createError
        self.updateError = updateError
        self.deleteError = deleteError
    }

    func listMeasurements() async throws -> [BodyMeasurement] {
        if let listError {
            throw listError
        }
        return measurements
    }

    func measurement(id: Int) async throws -> BodyMeasurement {
        try XCTUnwrap(measurements.first { $0.id == id })
    }

    func createMeasurement(_ draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        if let createError {
            throw createError
        }
        return try XCTUnwrap(createdMeasurement)
    }

    func updateMeasurement(id: Int, with draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        if let updateError {
            throw updateError
        }
        return try XCTUnwrap(updatedMeasurement)
    }

    func deleteMeasurement(id: Int) async throws {
        if let deleteError {
            throw deleteError
        }
    }
}

private func measurement(id: Int, timestamp: Date, weight: Double) -> BodyMeasurement {
    BodyMeasurement(
        id: id,
        measurementTimestamp: timestamp,
        weightKg: weight,
        heightCm: 175,
        bodyFatPercentage: 20,
        skeletalMuscleMassKg: 35,
        visceralFatLevel: 5,
        createdAt: timestamp,
        updatedAt: timestamp
    )
}

private func draft() -> BodyMeasurementDraft {
    BodyMeasurementDraft(
        measurementTimestamp: Date(),
        weightKg: 70,
        heightCm: 175,
        bodyFatPercentage: 20,
        skeletalMuscleMassKg: 35,
        visceralFatLevel: 5
    )
}

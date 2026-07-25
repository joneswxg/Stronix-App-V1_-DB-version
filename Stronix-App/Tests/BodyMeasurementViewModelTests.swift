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
}

private final class BodyMeasurementOperationsStub: BodyMeasurementOperating, @unchecked Sendable {
    var measurements: [BodyMeasurement]
    var listError: Error?
    let createdMeasurement: BodyMeasurement?
    let updatedMeasurement: BodyMeasurement?

    init(
        measurements: [BodyMeasurement],
        listError: Error? = nil,
        createdMeasurement: BodyMeasurement? = nil,
        updatedMeasurement: BodyMeasurement? = nil
    ) {
        self.measurements = measurements
        self.listError = listError
        self.createdMeasurement = createdMeasurement
        self.updatedMeasurement = updatedMeasurement
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
        try XCTUnwrap(createdMeasurement)
    }

    func updateMeasurement(id: Int, with draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        try XCTUnwrap(updatedMeasurement)
    }

    func deleteMeasurement(id: Int) async throws {}
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

import Foundation

protocol BodyMeasurementOperating: Sendable {
    func listMeasurements() async throws -> [BodyMeasurement]
    func measurement(id: Int) async throws -> BodyMeasurement
    func createMeasurement(_ draft: BodyMeasurementDraft) async throws -> BodyMeasurement
    func updateMeasurement(id: Int, with draft: BodyMeasurementDraft) async throws -> BodyMeasurement
    func deleteMeasurement(id: Int) async throws
}

struct BodyMeasurementUseCases: BodyMeasurementOperating {
    private let repository: any BodyMeasurementRepository

    init(repository: any BodyMeasurementRepository = SQLiteBodyMeasurementRepository()) {
        self.repository = repository
    }

    func listMeasurements() async throws -> [BodyMeasurement] {
        try repository.list()
    }

    func measurement(id: Int) async throws -> BodyMeasurement {
        try repository.measurement(id: id)
    }

    func createMeasurement(_ draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        try repository.create(draft)
    }

    func updateMeasurement(id: Int, with draft: BodyMeasurementDraft) async throws -> BodyMeasurement {
        try repository.update(id: id, with: draft)
    }

    func deleteMeasurement(id: Int) async throws {
        try repository.delete(id: id)
    }
}

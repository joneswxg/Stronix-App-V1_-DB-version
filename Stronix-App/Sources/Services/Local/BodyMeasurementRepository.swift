import Foundation
import SQLite

enum BodyMeasurementRepositoryError: Error, Equatable {
    case unauthenticated
    case invalidMeasurementID
    case invalidMeasurementTimestamp
    case invalidWeight
    case invalidHeight
    case invalidBodyFatPercentage
    case invalidSkeletalMuscleMass
    case invalidVisceralFatLevel
    case notFoundOrUnauthorized
    case malformedStoredTimestamp
}

protocol BodyMeasurementRepository: Sendable {
    func list() throws -> [BodyMeasurement]
    func measurement(id: Int) throws -> BodyMeasurement
    func create(_ draft: BodyMeasurementDraft) throws -> BodyMeasurement
    func update(id: Int, with draft: BodyMeasurementDraft) throws -> BodyMeasurement
    func delete(id: Int) throws
}

final class SQLiteBodyMeasurementRepository: BodyMeasurementRepository, @unchecked Sendable {
    private let connectionProvider: () -> Connection?
    private let currentUserProvider: any CurrentUserProviding
    private let now: () -> Date

    init(
        connectionProvider: @escaping () -> Connection? = { DatabaseManager.shared.getConnection() },
        currentUserProvider: any CurrentUserProviding = CurrentUserContext.shared,
        now: @escaping () -> Date = Date.init
    ) {
        self.connectionProvider = connectionProvider
        self.currentUserProvider = currentUserProvider
        self.now = now
    }

    func list() throws -> [BodyMeasurement] {
        let ownerID = try authenticatedUserID()
        let connection = try connection()
        do {
            let rows = try connection.prepare(
                """
                SELECT id, measurement_timestamp, weight_kg, height_cm,
                       body_fat_percentage, skeletal_muscle_mass_kg,
                       visceral_fat_level, created_at, updated_at
                FROM body_measurements
                WHERE user_id = ?
                ORDER BY measurement_timestamp DESC, created_at DESC, id DESC
                """,
                ownerID
            )
            return try rows.map(measurement(from:)).sorted(by: Self.measurementOrdering)
        } catch let error as BodyMeasurementRepositoryError {
            throw error
        } catch {
            throw DatabaseError.operationFailed(underlying: error)
        }
    }

    func measurement(id: Int) throws -> BodyMeasurement {
        guard id > 0 else { throw BodyMeasurementRepositoryError.invalidMeasurementID }
        let ownerID = try authenticatedUserID()
        let connection = try connection()
        do {
            let rows = try connection.prepare(
                """
                SELECT id, measurement_timestamp, weight_kg, height_cm,
                       body_fat_percentage, skeletal_muscle_mass_kg,
                       visceral_fat_level, created_at, updated_at
                FROM body_measurements
                WHERE id = ? AND user_id = ?
                """,
                id,
                ownerID
            )
            guard let row = rows.makeIterator().next() else {
                throw BodyMeasurementRepositoryError.notFoundOrUnauthorized
            }
            return try measurement(from: row)
        } catch let error as BodyMeasurementRepositoryError {
            throw error
        } catch {
            throw DatabaseError.operationFailed(underlying: error)
        }
    }

    func create(_ draft: BodyMeasurementDraft) throws -> BodyMeasurement {
        try validate(draft)
        let ownerID = try authenticatedUserID()
        let connection = try connection()
        let timestamp = try normalizedMeasurementTimestamp(for: draft)
        let timestampNow = BodyMeasurementDateFormatting.storageString(from: now())
        do {
            try connection.run(
                """
                INSERT INTO body_measurements (
                    user_id, measurement_timestamp, weight_kg, height_cm,
                    body_fat_percentage, skeletal_muscle_mass_kg,
                    visceral_fat_level, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                ownerID,
                timestamp,
                draft.weightKg,
                draft.heightCm,
                draft.bodyFatPercentage,
                draft.skeletalMuscleMassKg,
                draft.visceralFatLevel,
                timestampNow,
                timestampNow
            )
            return try measurement(id: Int(connection.lastInsertRowid))
        } catch let error as BodyMeasurementRepositoryError {
            throw error
        } catch {
            throw DatabaseError.operationFailed(underlying: error)
        }
    }

    func update(id: Int, with draft: BodyMeasurementDraft) throws -> BodyMeasurement {
        guard id > 0 else { throw BodyMeasurementRepositoryError.invalidMeasurementID }
        try validate(draft)
        let ownerID = try authenticatedUserID()
        let connection = try connection()
        let timestamp = try normalizedMeasurementTimestamp(for: draft)
        let updatedAt = BodyMeasurementDateFormatting.storageString(from: now())
        do {
            try connection.run(
                """
                UPDATE body_measurements
                SET measurement_timestamp = ?, weight_kg = ?, height_cm = ?,
                    body_fat_percentage = ?, skeletal_muscle_mass_kg = ?,
                    visceral_fat_level = ?, updated_at = ?
                WHERE id = ? AND user_id = ?
                """,
                timestamp,
                draft.weightKg,
                draft.heightCm,
                draft.bodyFatPercentage,
                draft.skeletalMuscleMassKg,
                draft.visceralFatLevel,
                updatedAt,
                id,
                ownerID
            )
            guard connection.changes > 0 else { throw BodyMeasurementRepositoryError.notFoundOrUnauthorized }
            return try measurement(id: id)
        } catch let error as BodyMeasurementRepositoryError {
            throw error
        } catch {
            throw DatabaseError.operationFailed(underlying: error)
        }
    }

    func delete(id: Int) throws {
        guard id > 0 else { throw BodyMeasurementRepositoryError.invalidMeasurementID }
        let ownerID = try authenticatedUserID()
        let connection = try connection()
        do {
            try connection.run(
                "DELETE FROM body_measurements WHERE id = ? AND user_id = ?",
                id,
                ownerID
            )
            guard connection.changes > 0 else { throw BodyMeasurementRepositoryError.notFoundOrUnauthorized }
        } catch let error as BodyMeasurementRepositoryError {
            throw error
        } catch {
            throw DatabaseError.operationFailed(underlying: error)
        }
    }

    private func authenticatedUserID() throws -> Int {
        guard let userID = currentUserProvider.currentUserID, userID > 0 else {
            throw BodyMeasurementRepositoryError.unauthenticated
        }
        return userID
    }

    private func connection() throws -> Connection {
        guard let connection = connectionProvider() else {
            throw DatabaseError.notReady
        }
        return connection
    }

    private func validate(_ draft: BodyMeasurementDraft) throws {
        guard draft.weightKg.isFinite, (20...200).contains(draft.weightKg) else {
            throw BodyMeasurementRepositoryError.invalidWeight
        }
        guard draft.heightCm.isFinite, (100...250).contains(draft.heightCm) else {
            throw BodyMeasurementRepositoryError.invalidHeight
        }
        guard draft.bodyFatPercentage.isFinite, (0...50).contains(draft.bodyFatPercentage) else {
            throw BodyMeasurementRepositoryError.invalidBodyFatPercentage
        }
        guard draft.skeletalMuscleMassKg.isFinite, (10...100).contains(draft.skeletalMuscleMassKg) else {
            throw BodyMeasurementRepositoryError.invalidSkeletalMuscleMass
        }
        guard (1...20).contains(draft.visceralFatLevel) else {
            throw BodyMeasurementRepositoryError.invalidVisceralFatLevel
        }
    }

    private func normalizedMeasurementTimestamp(for draft: BodyMeasurementDraft) throws -> String {
        guard draft.measurementTimestamp.timeIntervalSinceReferenceDate.isFinite else {
            throw BodyMeasurementRepositoryError.invalidMeasurementTimestamp
        }
        return BodyMeasurementDateFormatting.storageString(
            from: BodyMeasurementDateFormatting.localCalendarDay(from: draft.measurementTimestamp)
        )
    }

    private static func measurementOrdering(_ left: BodyMeasurement, _ right: BodyMeasurement) -> Bool {
        if left.measurementTimestamp != right.measurementTimestamp {
            return left.measurementTimestamp > right.measurementTimestamp
        }
        if left.createdAt != right.createdAt {
            return left.createdAt > right.createdAt
        }
        return left.id > right.id
    }

    private func measurement(from row: Statement.Element) throws -> BodyMeasurement {
        guard
            let id = int(row[0]),
            let timestamp = string(row[1]).flatMap(BodyMeasurementDateFormatting.storageDate),
            let weight = double(row[2]),
            let height = double(row[3]),
            let bodyFat = double(row[4]),
            let muscleMass = double(row[5]),
            let visceralFat = int(row[6]),
            let createdAt = string(row[7]).flatMap(BodyMeasurementDateFormatting.storageDate),
            let updatedAt = string(row[8]).flatMap(BodyMeasurementDateFormatting.storageDate)
        else {
            throw BodyMeasurementRepositoryError.malformedStoredTimestamp
        }
        return BodyMeasurement(
            id: id,
            measurementTimestamp: timestamp,
            weightKg: weight,
            heightCm: height,
            bodyFatPercentage: bodyFat,
            skeletalMuscleMassKg: muscleMass,
            visceralFatLevel: visceralFat,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func int(_ value: Binding?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(value) }
        return nil
    }

    private func double(_ value: Binding?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? Int64 { return Double(value) }
        return nil
    }

    private func string(_ value: Binding?) -> String? {
        value as? String
    }
}

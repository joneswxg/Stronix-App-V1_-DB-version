import Foundation
import SQLite

struct ActionHistoryData: Equatable {
    let date: String
    let planName: String
    let sets: [ActionHistorySet]
    let totalVolume: Int
}

struct ActionHistorySet: Equatable {
    let setNumber: Int
    let weight: Int
    let reps: Int
    let isCompleted: Bool
}

protocol ActionHistoryRepository: Sendable {
    func actionHistory(for actionID: Int) throws -> [ActionHistoryData]
}

final class SQLiteActionHistoryRepository: ActionHistoryRepository, @unchecked Sendable {
    private let connectionProvider: () -> Connection?

    init(connection: Connection) {
        connectionProvider = { connection }
    }

    init(connectionProvider: @escaping () -> Connection? = { DatabaseManager.shared.getConnection() }) {
        self.connectionProvider = connectionProvider
    }

    func actionHistory(for actionID: Int) throws -> [ActionHistoryData] {
        guard let connection = connectionProvider() else {
            throw DatabaseError.notReady
        }

        do {
            let historyRows = try connection.prepare(
                """
                SELECT DISTINCT th.id, th.plan_name, th.training_date
                FROM training_history th
                INNER JOIN training_history_details thd ON th.id = thd.history_id
                WHERE thd.action_id = ?
                ORDER BY th.training_date DESC
                LIMIT 5
                """,
                actionID
            )

            return try historyRows.compactMap { row in
                guard
                    let historyID = int(row[0]),
                    let planName = row[1] as? String,
                    let trainingDate = row[2] as? String
                else {
                    return nil
                }

                let details = try connection.prepare(
                    """
                    SELECT set_number, weight, reps, is_completed
                    FROM training_history_details
                    WHERE history_id = ? AND action_id = ?
                    ORDER BY set_number ASC
                    """,
                    historyID,
                    actionID
                )

                var totalVolume = 0
                let sets = details.compactMap { detail -> ActionHistorySet? in
                    guard
                        let setNumber = int(detail[0]),
                        let weight = double(detail[1]),
                        let reps = int(detail[2]),
                        let isCompleted = bool(detail[3])
                    else {
                        return nil
                    }

                    let displayWeight = Int(weight)
                    if isCompleted {
                        totalVolume += displayWeight * reps
                    }

                    return ActionHistorySet(
                        setNumber: setNumber,
                        weight: displayWeight,
                        reps: reps,
                        isCompleted: isCompleted
                    )
                }

                return ActionHistoryData(
                    date: trainingDate,
                    planName: planName,
                    sets: sets,
                    totalVolume: totalVolume
                )
            }
        } catch {
            throw DatabaseError.operationFailed(underlying: error)
        }
    }

    private func int(_ value: Binding?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(value) }
        return nil
    }

    private func double(_ value: Binding?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int64 { return Double(value) }
        if let value = value as? Int { return Double(value) }
        return nil
    }

    private func bool(_ value: Binding?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = int(value) { return value != 0 }
        return nil
    }
}

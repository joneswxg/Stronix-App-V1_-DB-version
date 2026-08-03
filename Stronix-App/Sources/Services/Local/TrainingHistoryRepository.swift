import Foundation
import SQLite

struct TrainingHistoryDateRange: Equatable, Sendable {
    let startDate: String
    let endDate: String
}

struct TrainingHistoryPageRequest: Equatable, Sendable {
    let page: Int
    let pageSize: Int
}

struct TrainingHistoryFilter: Equatable, Sendable {
    let userPlanID: Int?
    let dateRange: TrainingHistoryDateRange?

    init(userPlanID: Int? = nil, dateRange: TrainingHistoryDateRange? = nil) {
        self.userPlanID = userPlanID
        self.dateRange = dateRange
    }
}

struct TrainingHistoryListQuery: Equatable, Sendable {
    let ownerID: Int
    let page: TrainingHistoryPageRequest
    let filter: TrainingHistoryFilter
}

struct TrainingHistoryPagination: Equatable, Sendable {
    let page: Int
    let pageSize: Int
    let total: Int
    let pageCount: Int
}

struct TrainingHistoryPage: Equatable, Sendable {
    let histories: [TrainingHistoryItem]
    let pagination: TrainingHistoryPagination
}

struct TrainingHistoryDates: Equatable, Sendable {
    let dates: [String]
    let range: TrainingHistoryDateRange
}

struct TrainingHistoryDetailSet: Equatable, Sendable {
    let setNumber: Int
    let weight: Double?
    let weightUnit: String
    let reps: Int?
    let difficulty: String?
    let rir: SetRIR?
    let leftWeight: Double?
    let rightWeight: Double?
    let isCompleted: Bool
    let isBilateral: Bool
    init(
        setNumber: Int,
        weight: Double?,
        weightUnit: String,
        reps: Int?,
        difficulty: String?,
        rir: SetRIR? = nil,
        leftWeight: Double?,
        rightWeight: Double?,
        isCompleted: Bool,
        isBilateral: Bool
    ) {
        self.setNumber = setNumber
        self.weight = weight
        self.weightUnit = weightUnit
        self.reps = reps
        self.difficulty = difficulty
        self.rir = rir
        self.leftWeight = leftWeight
        self.rightWeight = rightWeight
        self.isCompleted = isCompleted
        self.isBilateral = isBilateral
    }
}

struct TrainingHistoryDetailAction: Equatable, Sendable {
    let actionID: Int
    let name: String
    let sets: [TrainingHistoryDetailSet]
}

struct TrainingHistoryReadDetail: Equatable, Sendable {
    let history: TrainingHistoryItem
    let actions: [TrainingHistoryDetailAction]
}

enum TrainingHistoryRepositoryError: Error, Equatable {
    case invalidOwnerID
    case invalidHistoryID
    case invalidPage
    case invalidPageSize
    case invalidPlanID
    case invalidDateRange
    case notFoundOrUnauthorized
}

protocol TrainingHistoryRepository: Sendable {
    func trainingDates(ownerID: Int, in range: TrainingHistoryDateRange) throws -> TrainingHistoryDates
    func trainingHistory(_ query: TrainingHistoryListQuery) throws -> TrainingHistoryPage
    func trainingHistoryDetail(id: Int, ownerID: Int) throws -> TrainingHistoryReadDetail
}

final class SQLiteTrainingHistoryRepository: TrainingHistoryRepository, @unchecked Sendable {
    private static let maximumPageSize = 100
    private let connectionProvider: () -> Connection?

    init(connection: Connection) {
        connectionProvider = { connection }
    }

    init(connectionProvider: @escaping () -> Connection? = { DatabaseManager.shared.getConnection() }) {
        self.connectionProvider = connectionProvider
    }

    func trainingDates(ownerID: Int, in range: TrainingHistoryDateRange) throws -> TrainingHistoryDates {
        try validate(ownerID: ownerID, range: range)
        let connection = try connection()

        do {
            let rows = try connection.prepare(
                """
                SELECT DISTINCT DATE(training_date)
                FROM training_history
                WHERE user_id = ? AND DATE(training_date) BETWEEN DATE(?) AND DATE(?)
                ORDER BY DATE(training_date) ASC
                """,
                ownerID,
                range.startDate,
                range.endDate
            )
            let dates = rows.compactMap { $0[0] as? String }
            return TrainingHistoryDates(dates: dates, range: range)
        } catch {
            throw DatabaseError.operationFailed(underlying: error)
        }
    }

    func trainingHistory(_ query: TrainingHistoryListQuery) throws -> TrainingHistoryPage {
        try validate(query)
        let connection = try connection()
        let conditions = conditions(for: query)
        let whereClause = conditions.clauses.joined(separator: " AND ")
        let offset = (query.page.page - 1) * query.page.pageSize

        do {
            let totalRows = try connection.prepare(
                "SELECT COUNT(*) FROM training_history WHERE \(whereClause)",
                conditions.parameters
            )
            let total = totalRows.makeIterator().next().flatMap { int($0[0]) } ?? 0
            let rows = try connection.prepare(
                """
                SELECT id, plan_id, plan_name, training_date, volume, duration, note, created_at
                FROM training_history
                WHERE \(whereClause)
                ORDER BY training_date DESC, created_at DESC
                LIMIT ? OFFSET ?
                """,
                conditions.parameters + [query.page.pageSize, offset]
            )
            let histories = rows.compactMap(history(from:))
            return TrainingHistoryPage(
                histories: histories,
                pagination: TrainingHistoryPagination(
                    page: query.page.page,
                    pageSize: query.page.pageSize,
                    total: total,
                    pageCount: total == 0 ? 0 : (total + query.page.pageSize - 1) / query.page.pageSize
                )
            )
        } catch {
            throw DatabaseError.operationFailed(underlying: error)
        }
    }

    func trainingHistoryDetail(id: Int, ownerID: Int) throws -> TrainingHistoryReadDetail {
        guard id > 0 else { throw TrainingHistoryRepositoryError.invalidHistoryID }
        guard ownerID > 0 else { throw TrainingHistoryRepositoryError.invalidOwnerID }
        let connection = try connection()

        do {
            let historyRows = try connection.prepare(
                """
                SELECT id, plan_id, plan_name, training_date, volume, duration, note, created_at
                FROM training_history
                WHERE id = ? AND user_id = ?
                """,
                id,
                ownerID
            )
            guard let row = historyRows.makeIterator().next(), let history = history(from: row) else {
                throw TrainingHistoryRepositoryError.notFoundOrUnauthorized
            }

            let detailRows = try connection.prepare(
                """
                SELECT thd.action_id, a.name, thd.set_number, thd.weight, thd.weight_unit,
                       thd.reps, thd.difficulty, thd.rir, thd.left_weight, thd.right_weight,
                       thd.is_completed, thd.history_record_bilateral
                FROM training_history_details thd
                LEFT JOIN action a ON a.id = thd.action_id
                WHERE thd.history_id = ?
                ORDER BY thd.action_id ASC, thd.set_number ASC
                """,
                id
            )

            var actions: [TrainingHistoryDetailAction] = []
            for row in detailRows {
                guard
                    let actionID = int(row[0]),
                    let setNumber = int(row[2]),
                    let isCompleted = bool(row[10]),
                    let isBilateral = bool(row[11])
                else { continue }

                let set = TrainingHistoryDetailSet(
                    setNumber: setNumber,
                    weight: double(row[3]),
                    weightUnit: row[4] as? String ?? "kg",
                    reps: int(row[5]),
                    difficulty: row[6] as? String,
                    rir: rir(from: row[7]),
                    leftWeight: double(row[8]),
                    rightWeight: double(row[9]),
                    isCompleted: isCompleted,
                    isBilateral: isBilateral
                )
                if actions.last?.actionID == actionID {
                    actions[actions.count - 1] = TrainingHistoryDetailAction(
                        actionID: actionID,
                        name: actions[actions.count - 1].name,
                        sets: actions[actions.count - 1].sets + [set]
                    )
                } else {
                    actions.append(TrainingHistoryDetailAction(
                        actionID: actionID,
                        name: row[1] as? String ?? "未知动作",
                        sets: [set]
                    ))
                }
            }
            return TrainingHistoryReadDetail(history: history, actions: actions)
        } catch let error as TrainingHistoryRepositoryError {
            throw error
        } catch {
            throw DatabaseError.operationFailed(underlying: error)
        }
    }

    private func connection() throws -> Connection {
        guard let connection = connectionProvider() else {
            throw DatabaseError.notReady
        }
        return connection
    }

    private func validate(ownerID: Int, range: TrainingHistoryDateRange) throws {
        guard ownerID > 0 else { throw TrainingHistoryRepositoryError.invalidOwnerID }
        guard Self.isDateOnly(range.startDate), Self.isDateOnly(range.endDate), range.startDate <= range.endDate else {
            throw TrainingHistoryRepositoryError.invalidDateRange
        }
    }

    private func validate(_ query: TrainingHistoryListQuery) throws {
        guard query.ownerID > 0 else { throw TrainingHistoryRepositoryError.invalidOwnerID }
        guard query.page.page >= 1 else { throw TrainingHistoryRepositoryError.invalidPage }
        guard (1...Self.maximumPageSize).contains(query.page.pageSize) else {
            throw TrainingHistoryRepositoryError.invalidPageSize
        }
        if let planID = query.filter.userPlanID, planID <= 0 {
            throw TrainingHistoryRepositoryError.invalidPlanID
        }
        if let range = query.filter.dateRange {
            try validate(ownerID: query.ownerID, range: range)
        }
    }

    private func conditions(for query: TrainingHistoryListQuery) -> (clauses: [String], parameters: [Binding?]) {
        var clauses = ["user_id = ?"]
        var parameters: [Binding?] = [query.ownerID]
        if let planID = query.filter.userPlanID {
            clauses.append("plan_id = ?")
            parameters.append(planID)
        }
        if let range = query.filter.dateRange {
            clauses.append("DATE(training_date) BETWEEN DATE(?) AND DATE(?)")
            parameters.append(range.startDate)
            parameters.append(range.endDate)
        }
        return (clauses, parameters)
    }

    private func history(from row: Statement.Element) -> TrainingHistoryItem? {
        guard
            let id = int(row[0]),
            let planName = row[2] as? String,
            let trainingDate = row[3] as? String,
            let volume = double(row[4]),
            let duration = int(row[5])
        else { return nil }
        return TrainingHistoryItem(
            id: id,
            plan_id: int(row[1]),
            plan_name: planName,
            training_date: trainingDate,
            volume: volume,
            duration: duration,
            note: row[6] as? String,
            created_at: row[7] as? String
        )
    }

    private static func isDateOnly(_ value: String) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
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

    private func rir(from value: Binding?) -> SetRIR? {
        int(value).flatMap(SetRIR.init(rawValue:))
    }

    private func bool(_ value: Binding?) -> Bool? {
        if let value = value as? Bool { return value }
        return int(value).map { $0 != 0 }
    }
}

import SQLite

enum TrainingHistoryRIRMigration {
    static func apply(to connection: Connection) throws {
        guard !(try hasColumn("rir", in: "training_history_details", connection: connection)) else {
            return
        }
        try connection.run(
            """
            ALTER TABLE training_history_details
            ADD COLUMN rir INTEGER CHECK (rir IS NULL OR rir BETWEEN 0 AND 3)
            """
        )
    }

    static func validate(_ connection: Connection) throws {
        guard try hasColumn("rir", in: "training_history_details", connection: connection) else {
            throw DatabasePreparationFailure(message: "training_history_details 缺少 RIR 列")
        }
    }

    private static func hasColumn(_ name: String, in table: String, connection: Connection) throws -> Bool {
        try connection.prepare("PRAGMA table_info(\(table))").contains { row in
            (row[1] as? String) == name
        }
    }
}

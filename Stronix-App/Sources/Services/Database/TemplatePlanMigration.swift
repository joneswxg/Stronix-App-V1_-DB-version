import SQLite

enum TemplatePlanMigration {
    static func apply(to connection: Connection) throws {
        try createTemplateTables(in: connection)
        try seedTemplatePlans(in: connection)

        guard try hasColumn("is_template", in: "training_plans", connection: connection) else {
            return
        }

        try rebuildUserPlanTables(in: connection)
    }

    static func validate(_ connection: Connection) throws {
        guard !(try hasColumn("is_template", in: "training_plans", connection: connection)) else {
            throw DatabasePreparationFailure(message: "training_plans 仍包含模板标记")
        }
        guard !(try hasColumn("user_id", in: "template_plans", connection: connection)) else {
            throw DatabasePreparationFailure(message: "template_plans 不能包含用户所有权")
        }
        guard try count("SELECT COUNT(*) FROM template_plans", connection: connection) == 2,
              try count("SELECT COUNT(*) FROM template_plan_actions", connection: connection) == 3,
              try count("SELECT COUNT(*) FROM template_plan_sets", connection: connection) == 6 else {
            throw DatabasePreparationFailure(message: "模板计划种子校验失败")
        }
        guard try count("SELECT COUNT(*) FROM training_plans WHERE user_id = 0", connection: connection) == 0 else {
            throw DatabasePreparationFailure(message: "User Plan 不能使用 user_id = 0")
        }
    }

    private static func createTemplateTables(in connection: Connection) throws {
        try connection.run(
            """
            CREATE TABLE IF NOT EXISTS template_plans (
                id INTEGER PRIMARY KEY,
                external_id TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                difficulty TEXT NOT NULL DEFAULT '',
                duration INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        try connection.run(
            """
            CREATE TABLE IF NOT EXISTS template_plan_actions (
                template_plan_id INTEGER NOT NULL,
                action_id INTEGER NOT NULL,
                "order" INTEGER NOT NULL,
                sets INTEGER NOT NULL DEFAULT 0,
                reps TEXT,
                rest INTEGER NOT NULL DEFAULT 60,
                weight REAL NOT NULL DEFAULT 0,
                note TEXT,
                record_bilateral INTEGER NOT NULL DEFAULT 0 CHECK (record_bilateral IN (0, 1)),
                PRIMARY KEY (template_plan_id, action_id),
                UNIQUE (template_plan_id, "order"),
                FOREIGN KEY (template_plan_id) REFERENCES template_plans(id) ON DELETE CASCADE,
                FOREIGN KEY (action_id) REFERENCES action(id)
            ) WITHOUT ROWID
            """
        )
        try connection.run(
            """
            CREATE TABLE IF NOT EXISTS template_plan_sets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                template_plan_id INTEGER NOT NULL,
                action_id INTEGER NOT NULL,
                set_number INTEGER NOT NULL,
                weight REAL NOT NULL DEFAULT 0,
                reps INTEGER NOT NULL DEFAULT 12,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                left_weight REAL NOT NULL DEFAULT 0,
                right_weight REAL NOT NULL DEFAULT 0,
                notes TEXT,
                UNIQUE (template_plan_id, action_id, set_number),
                FOREIGN KEY (template_plan_id, action_id) REFERENCES template_plan_actions(template_plan_id, action_id) ON DELETE CASCADE
            )
            """
        )
        try connection.run("CREATE INDEX IF NOT EXISTS idx_template_plans_external_id ON template_plans(external_id)")
        try connection.run("CREATE INDEX IF NOT EXISTS idx_template_plan_actions_plan_order ON template_plan_actions(template_plan_id, \"order\")")
        try connection.run("CREATE INDEX IF NOT EXISTS idx_template_plan_sets_plan_action ON template_plan_sets(template_plan_id, action_id, set_number)")
    }

    private static func seedTemplatePlans(in connection: Connection) throws {
        try connection.run(
            """
            INSERT INTO template_plans (id, external_id, name, description, difficulty, duration, created_at, updated_at)
            VALUES
                (1, 'starter-upper-body-v1', '上肢入门训练', '适合初学者的上肢力量训练。', 'beginner', 35, '2026-07-21T00:00:00Z', '2026-07-21T00:00:00Z'),
                (2, 'starter-arms-v1', '手臂入门训练', '包含双侧记录的手臂力量训练。', 'beginner', 30, '2026-07-21T00:00:00Z', '2026-07-21T00:00:00Z')
            ON CONFLICT(id) DO NOTHING
            """
        )
        try connection.run(
            """
            INSERT INTO template_plan_actions (template_plan_id, action_id, "order", sets, rest, weight, note, record_bilateral)
            VALUES
                (1, 2, 1, 2, 75, 450, '动作全程保持稳定。', 0),
                (1, 3, 2, 2, 60, 360, '控制离心阶段。', 0),
                (2, 4, 1, 2, 90, 351, '左右两侧独立记录。', 1)
            ON CONFLICT(template_plan_id, action_id) DO NOTHING
            """
        )
        try connection.run(
            """
            INSERT INTO template_plan_sets (
                template_plan_id, action_id, set_number, weight, reps, created_at, left_weight, right_weight, notes
            ) VALUES
                (1, 2, 1, 20, 10, '2026-07-21T00:00:00Z', 0, 0, '热身组'),
                (1, 2, 2, 25, 10, '2026-07-21T00:00:00Z', 0, 0, '工作组'),
                (1, 3, 1, 15, 12, '2026-07-21T00:00:00Z', 0, 0, ''),
                (1, 3, 2, 15, 12, '2026-07-21T00:00:00Z', 0, 0, ''),
                (2, 4, 1, 0, 12, '2026-07-21T00:00:00Z', 7.5, 8, '保持左右平衡'),
                (2, 4, 2, 0, 10, '2026-07-21T00:00:00Z', 8, 8.5, '')
            ON CONFLICT(template_plan_id, action_id, set_number) DO NOTHING
            """
        )
    }

    private static func rebuildUserPlanTables(in connection: Connection) throws {
        try connection.run(
            """
            CREATE TEMP TABLE legacy_training_history_plan_ids AS
            SELECT h.id AS history_id, h.plan_id
            FROM training_history h
            JOIN training_plans p ON p.id = h.plan_id
            WHERE p.is_template = 0 AND p.user_id IS NOT NULL AND p.user_id != 0
            """
        )
        try connection.run(
            """
            CREATE TEMP TABLE legacy_training_session_plan_ids AS
            SELECT s.id AS session_id, s.plan_id
            FROM training_sessions s
            JOIN training_plans p ON p.id = s.plan_id
            WHERE p.is_template = 0 AND p.user_id IS NOT NULL AND p.user_id != 0
            """
        )
        try connection.run(
            """
            CREATE TEMP TABLE legacy_training_plan_executions AS
            SELECT e.*
            FROM training_plan_executions e
            JOIN training_plans p ON p.id = e.plan_id
            WHERE p.is_template = 0 AND p.user_id IS NOT NULL AND p.user_id != 0
            """
        )
        try connection.run(
            """
            CREATE TEMP TABLE legacy_execution_actions AS
            SELECT a.*
            FROM execution_actions a
            JOIN legacy_training_plan_executions e ON e.id = a.execution_id
            """
        )
        try connection.run(
            """
            CREATE TEMP TABLE legacy_execution_sets AS
            SELECT s.*
            FROM execution_sets s
            JOIN legacy_execution_actions a ON a.id = s.execution_action_id
            """
        )

        try connection.run(
            """
            CREATE TABLE new_training_plans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                difficulty TEXT NOT NULL DEFAULT '',
                duration INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                user_id INTEGER NOT NULL,
                source_template_id INTEGER,
                FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE,
                FOREIGN KEY (source_template_id) REFERENCES template_plans(id) ON DELETE SET NULL
            )
            """
        )
        try connection.run(
            """
            INSERT INTO new_training_plans (id, name, description, difficulty, duration, created_at, updated_at, user_id)
            SELECT id, name, description, difficulty, duration, created_at, updated_at, user_id
            FROM training_plans
            WHERE is_template = 0 AND user_id IS NOT NULL AND user_id != 0
            """
        )
        try connection.run(
            """
            CREATE TABLE new_plan_actions (
                plan_id INTEGER NOT NULL,
                action_id INTEGER NOT NULL,
                "order" INTEGER NOT NULL,
                sets INTEGER NOT NULL DEFAULT 0,
                reps TEXT,
                rest INTEGER NOT NULL DEFAULT 60,
                weight REAL NOT NULL DEFAULT 0,
                note TEXT,
                record_bilateral INTEGER NOT NULL DEFAULT 0 CHECK (record_bilateral IN (0, 1)),
                PRIMARY KEY (plan_id, action_id),
                UNIQUE (plan_id, "order"),
                FOREIGN KEY (plan_id) REFERENCES new_training_plans(id) ON DELETE CASCADE,
                FOREIGN KEY (action_id) REFERENCES action(id)
            ) WITHOUT ROWID
            """
        )
        try connection.run(
            """
            INSERT INTO new_plan_actions (plan_id, action_id, "order", sets, reps, rest, weight, note, record_bilateral)
            SELECT pa.plan_id, pa.action_id, pa."order", pa.sets, pa.reps, pa.rest, pa.weight, pa.note, pa.record_bilateral
            FROM plan_actions pa
            JOIN new_training_plans tp ON tp.id = pa.plan_id
            """
        )
        try connection.run(
            """
            CREATE TABLE new_plan_sets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plan_id INTEGER NOT NULL,
                action_id INTEGER NOT NULL,
                set_number INTEGER NOT NULL,
                weight REAL NOT NULL DEFAULT 0,
                reps INTEGER NOT NULL DEFAULT 12,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                left_weight REAL NOT NULL DEFAULT 0,
                right_weight REAL NOT NULL DEFAULT 0,
                notes TEXT,
                UNIQUE (plan_id, action_id, set_number),
                FOREIGN KEY (plan_id, action_id) REFERENCES new_plan_actions(plan_id, action_id) ON DELETE CASCADE
            )
            """
        )
        try connection.run(
            """
            INSERT INTO new_plan_sets (id, plan_id, action_id, set_number, weight, reps, created_at, left_weight, right_weight, notes)
            SELECT ps.id, ps.plan_id, ps.action_id, ps.set_number, ps.weight, ps.reps, ps.created_at, ps.left_weight, ps.right_weight, ps.notes
            FROM plan_sets ps
            JOIN new_plan_actions pa ON pa.plan_id = ps.plan_id AND pa.action_id = ps.action_id
            """
        )

        try connection.run("DROP TABLE plan_sets")
        try connection.run("DROP TABLE plan_actions")
        try connection.run("DROP TABLE training_plans")
        try connection.run("ALTER TABLE new_training_plans RENAME TO training_plans")
        try connection.run("ALTER TABLE new_plan_actions RENAME TO plan_actions")
        try connection.run("ALTER TABLE new_plan_sets RENAME TO plan_sets")
        try connection.run(
            """
            UPDATE training_history
            SET plan_id = (
                SELECT plan_id FROM legacy_training_history_plan_ids legacy
                WHERE legacy.history_id = training_history.id
            )
            WHERE id IN (SELECT history_id FROM legacy_training_history_plan_ids)
            """
        )
        try connection.run(
            """
            UPDATE training_sessions
            SET plan_id = (
                SELECT plan_id FROM legacy_training_session_plan_ids legacy
                WHERE legacy.session_id = training_sessions.id
            )
            WHERE id IN (SELECT session_id FROM legacy_training_session_plan_ids)
            """
        )
        try connection.run("DELETE FROM training_plan_executions")
        try connection.run(
            """
            INSERT INTO training_plan_executions (id, plan_id, plan_name, description, created_at)
            SELECT id, plan_id, plan_name, description, created_at
            FROM legacy_training_plan_executions
            """
        )
        try connection.run("DELETE FROM execution_actions")
        try connection.run(
            """
            INSERT INTO execution_actions (
                id, execution_id, action_id, action_name, order_num, rest, is_bilateral,
                record_bilateral, created_at
            )
            SELECT id, execution_id, action_id, action_name, order_num, rest, is_bilateral,
                   record_bilateral, created_at
            FROM legacy_execution_actions
            """
        )
        try connection.run("DELETE FROM execution_sets")
        try connection.run(
            """
            INSERT INTO execution_sets (
                id, execution_action_id, set_number, planned_weight, planned_left_weight,
                planned_right_weight, planned_reps, actual_weight, actual_left_weight,
                actual_right_weight, actual_reps, is_completed, difficulty, created_at
            )
            SELECT id, execution_action_id, set_number, planned_weight, planned_left_weight,
                   planned_right_weight, planned_reps, actual_weight, actual_left_weight,
                   actual_right_weight, actual_reps, is_completed, difficulty, created_at
            FROM legacy_execution_sets
            """
        )
        try connection.run("DROP TABLE legacy_training_history_plan_ids")
        try connection.run("DROP TABLE legacy_training_session_plan_ids")
        try connection.run("DROP TABLE legacy_training_plan_executions")
        try connection.run("DROP TABLE legacy_execution_actions")
        try connection.run("DROP TABLE legacy_execution_sets")
        try connection.run("CREATE INDEX idx_training_plans_user ON training_plans(user_id)")
        try connection.run("CREATE INDEX idx_training_plans_source_template ON training_plans(source_template_id)")
        try connection.run("CREATE INDEX idx_plan_actions_plan_order ON plan_actions(plan_id, \"order\")")
        try connection.run("CREATE INDEX idx_plan_sets_plan_action ON plan_sets(plan_id, action_id, set_number)")
    }

    private static func hasColumn(
        _ columnName: String,
        in tableName: String,
        connection: Connection
    ) throws -> Bool {
        for row in try connection.prepare("PRAGMA table_info(\(tableName))") {
            if row[1] as? String == columnName {
                return true
            }
        }
        return false
    }

    private static func count(_ query: String, connection: Connection) throws -> Int64 {
        (try connection.scalar(query) as? Int64) ?? 0
    }
}

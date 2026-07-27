import SQLite

enum UsernameUniquenessMigration {
    static func apply(to connection: Connection) throws {
        try connection.run("ALTER TABLE user RENAME TO legacy_user")
        try connection.run(
            """
            CREATE TABLE user (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL,
                email TEXT NOT NULL UNIQUE,
                password_hash TEXT,
                is_admin INTEGER NOT NULL DEFAULT 0 CHECK (is_admin IN (0, 1)),
                role TEXT NOT NULL DEFAULT 'regular',
                gender TEXT,
                height REAL,
                weight REAL,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                account_type TEXT NOT NULL DEFAULT 'email',
                external_id TEXT,
                wechat_open_id TEXT,
                wechat_union_id TEXT,
                apple_id TEXT
            )
            """
        )
        try connection.run(
            """
            INSERT INTO user (
                id, username, email, password_hash, is_admin, role, gender, height, weight,
                created_at, account_type, external_id, wechat_open_id, wechat_union_id, apple_id
            )
            SELECT
                id, username, email, password_hash, is_admin, role, gender, height, weight,
                created_at, account_type, external_id, wechat_open_id, wechat_union_id, apple_id
            FROM legacy_user
            """
        )
        try connection.run("DROP TABLE legacy_user")
        try connection.run("CREATE INDEX idx_user_account_type ON user(account_type)")
        try connection.run("CREATE INDEX idx_user_external_id ON user(external_id)")
        try connection.run("CREATE INDEX idx_user_wechat_open_id ON user(wechat_open_id)")
        try connection.run("CREATE INDEX idx_user_apple_id ON user(apple_id)")
    }

    static func validate(_ connection: Connection) throws {
        let tableDefinition = try connection.scalar(
            "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = 'user'"
        ) as? String
        guard tableDefinition?.contains("username TEXT NOT NULL UNIQUE") == false else {
            throw DatabasePreparationFailure(message: "用户名仍被唯一约束")
        }
        guard try connection.prepare("PRAGMA foreign_key_check").makeIterator().next() == nil else {
            throw DatabasePreparationFailure(message: "用户名迁移破坏了外键")
        }
    }
}

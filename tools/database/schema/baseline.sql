PRAGMA foreign_keys = ON;

CREATE TABLE schema_migrations (
    migration_id TEXT PRIMARY KEY,
    applied_at TEXT NOT NULL
) WITHOUT ROWID;

CREATE TRIGGER schema_migrations_prevent_update
BEFORE UPDATE ON schema_migrations
BEGIN
    SELECT RAISE(ABORT, 'schema_migrations is append-only');
END;

CREATE TRIGGER schema_migrations_prevent_delete
BEFORE DELETE ON schema_migrations
BEGIN
    SELECT RAISE(ABORT, 'schema_migrations is append-only');
END;

CREATE TABLE body_part (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL
);

CREATE TABLE target_muscle (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL
);

CREATE TABLE equipment (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL
);

CREATE TABLE action (
    id INTEGER PRIMARY KEY,
    external_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_en TEXT,
    "gifUrl" TEXT,
    description TEXT,
    description_en TEXT,
    difficulty TEXT,
    bodypart_id INTEGER NOT NULL,
    equipment_id INTEGER,
    is_bilateral INTEGER NOT NULL DEFAULT 0 CHECK (is_bilateral IN (0, 1)),
    FOREIGN KEY (bodypart_id) REFERENCES body_part(id),
    FOREIGN KEY (equipment_id) REFERENCES equipment(id)
);

CREATE TABLE action_target_muscle_link (
    action_id INTEGER NOT NULL,
    target_muscle_id INTEGER NOT NULL,
    PRIMARY KEY (action_id, target_muscle_id),
    FOREIGN KEY (action_id) REFERENCES action(id) ON DELETE CASCADE,
    FOREIGN KEY (target_muscle_id) REFERENCES target_muscle(id)
) WITHOUT ROWID;

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
);

CREATE TABLE template_plans (
    id INTEGER PRIMARY KEY,
    external_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    difficulty TEXT NOT NULL DEFAULT '',
    duration INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE template_plan_actions (
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
) WITHOUT ROWID;

CREATE TABLE template_plan_sets (
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
);

CREATE TABLE training_plans (
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
);

CREATE TABLE plan_actions (
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
    FOREIGN KEY (plan_id) REFERENCES training_plans(id) ON DELETE CASCADE,
    FOREIGN KEY (action_id) REFERENCES action(id)
) WITHOUT ROWID;

CREATE TABLE plan_sets (
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
    FOREIGN KEY (plan_id, action_id) REFERENCES plan_actions(plan_id, action_id) ON DELETE CASCADE
);

CREATE TABLE training_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER,
    user_id INTEGER NOT NULL,
    plan_name TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status TEXT NOT NULL DEFAULT 'in_progress',
    total_volume REAL NOT NULL DEFAULT 0,
    completed_volume REAL NOT NULL DEFAULT 0,
    duration_minutes INTEGER NOT NULL DEFAULT 0,
    completed_at TEXT,
    execution_id INTEGER,
    FOREIGN KEY (plan_id) REFERENCES training_plans(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE
);

CREATE TABLE training_plan_executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL,
    plan_name TEXT NOT NULL,
    description TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (plan_id) REFERENCES training_plans(id) ON DELETE CASCADE
);

CREATE TABLE execution_actions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    execution_id INTEGER NOT NULL,
    action_id INTEGER NOT NULL,
    action_name TEXT NOT NULL,
    order_num INTEGER NOT NULL,
    rest INTEGER,
    is_bilateral INTEGER NOT NULL DEFAULT 0 CHECK (is_bilateral IN (0, 1)),
    record_bilateral INTEGER NOT NULL DEFAULT 0 CHECK (record_bilateral IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (execution_id) REFERENCES training_plan_executions(id) ON DELETE CASCADE,
    FOREIGN KEY (action_id) REFERENCES action(id)
);

CREATE TABLE execution_sets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    execution_action_id INTEGER NOT NULL,
    set_number INTEGER NOT NULL,
    planned_weight REAL,
    planned_left_weight REAL,
    planned_right_weight REAL,
    planned_reps INTEGER NOT NULL,
    actual_weight REAL,
    actual_left_weight REAL,
    actual_right_weight REAL,
    actual_reps INTEGER,
    is_completed INTEGER NOT NULL DEFAULT 0 CHECK (is_completed IN (0, 1)),
    difficulty INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (execution_action_id) REFERENCES execution_actions(id) ON DELETE CASCADE
);

CREATE TABLE training_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    plan_id INTEGER,
    session_id INTEGER NOT NULL,
    plan_name TEXT NOT NULL,
    plan_description TEXT,
    training_date TEXT NOT NULL,
    volume REAL NOT NULL DEFAULT 0,
    duration INTEGER NOT NULL DEFAULT 0,
    note TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE,
    FOREIGN KEY (plan_id) REFERENCES training_plans(id) ON DELETE SET NULL
);

CREATE TABLE training_history_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    history_id INTEGER NOT NULL,
    action_id INTEGER NOT NULL,
    set_number INTEGER NOT NULL,
    weight REAL,
    weight_unit TEXT NOT NULL DEFAULT 'kg',
    reps INTEGER,
    difficulty TEXT,
    left_weight REAL,
    right_weight REAL,
    is_completed INTEGER NOT NULL DEFAULT 0 CHECK (is_completed IN (0, 1)),
    note TEXT,
    history_record_bilateral INTEGER NOT NULL DEFAULT 0 CHECK (history_record_bilateral IN (0, 1)),
    FOREIGN KEY (history_id) REFERENCES training_history(id) ON DELETE CASCADE,
    FOREIGN KEY (action_id) REFERENCES action(id)
);

CREATE TABLE body_measurements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    measurement_timestamp TEXT NOT NULL,
    weight_kg REAL NOT NULL,
    height_cm REAL NOT NULL,
    body_fat_percentage REAL NOT NULL,
    skeletal_muscle_mass_kg REAL NOT NULL,
    visceral_fat_level INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE
);

CREATE TABLE password_reset_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    verification_code TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    is_used INTEGER NOT NULL DEFAULT 0 CHECK (is_used IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    used_at TEXT
);

CREATE TABLE database_version (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT NOT NULL,
    build_number INTEGER NOT NULL,
    update_date TEXT NOT NULL,
    description TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_action_bodypart_id ON action(bodypart_id);
CREATE INDEX idx_action_equipment_id ON action(equipment_id);
CREATE INDEX idx_action_target_muscle_target ON action_target_muscle_link(target_muscle_id, action_id);
CREATE INDEX idx_user_account_type ON user(account_type);
CREATE INDEX idx_user_external_id ON user(external_id);
CREATE INDEX idx_user_wechat_open_id ON user(wechat_open_id);
CREATE INDEX idx_user_apple_id ON user(apple_id);
CREATE INDEX idx_template_plans_external_id ON template_plans(external_id);
CREATE INDEX idx_template_plan_actions_plan_order ON template_plan_actions(template_plan_id, "order");
CREATE INDEX idx_template_plan_sets_plan_action ON template_plan_sets(template_plan_id, action_id, set_number);
CREATE INDEX idx_training_plans_user ON training_plans(user_id);
CREATE INDEX idx_training_plans_source_template ON training_plans(source_template_id);
CREATE INDEX idx_plan_actions_plan_order ON plan_actions(plan_id, "order");
CREATE INDEX idx_plan_sets_plan_action ON plan_sets(plan_id, action_id, set_number);
CREATE INDEX idx_training_sessions_plan_id ON training_sessions(plan_id);
CREATE INDEX idx_training_sessions_user_id ON training_sessions(user_id);
CREATE INDEX idx_training_plan_executions_plan_id ON training_plan_executions(plan_id);
CREATE INDEX idx_execution_actions_execution_order ON execution_actions(execution_id, order_num);
CREATE INDEX idx_execution_sets_action_set ON execution_sets(execution_action_id, set_number);
CREATE INDEX idx_training_history_user_date ON training_history(user_id, training_date);
CREATE INDEX idx_training_history_plan_id ON training_history(plan_id);
CREATE INDEX idx_training_history_session_id ON training_history(session_id);
CREATE INDEX idx_training_history_details_history ON training_history_details(history_id, set_number);
CREATE INDEX idx_training_history_details_action ON training_history_details(action_id);
CREATE INDEX idx_body_measurements_user_timestamp ON body_measurements(user_id, measurement_timestamp);
CREATE INDEX idx_password_reset_codes_email_created ON password_reset_codes(email, created_at);

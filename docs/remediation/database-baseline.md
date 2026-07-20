# SQLite Database Baseline

## Status

- Ticket: 0.2 Export SQLite baseline
- Status: Completed
- Date: 2026-07-20
- Scope: Bundled local SQLite database only
- Database path: `Stronix-App/Resources/Database/database_stronix.db`
- Supabase migrations: Out of scope

## Summary

- `PRAGMA foreign_keys`: `0`
- `PRAGMA integrity_check`: `ok`
- `PRAGMA foreign_key_check`: has violations

The database file is physically intact, but existing foreign key constraints and data do not satisfy a clean foreign key check.

## Tables

```text
action
action_target_muscle_link
article
body_measurements
body_part
bodypart_target_muscle_link
database_version
equipment
execution_actions
execution_sets
password_reset_codes
plan_actions
plan_sets
site_config
sqlite_sequence
target_muscle
training_history
training_history_details
training_plan_executions
training_plans
training_sessions
user
video
```

## Key Row Counts

```text
user                       8
action                     272
training_plans            13
plan_actions              35
plan_sets                 141
training_history          17
training_history_details  315
body_measurements         8
database_version          4
```

## Database Version Rows

```text
1.0.0  build 1  2025-01-27T10:00:00Z  初始数据库版本
1.1.0  build 2  2025-07-12T17:30:00Z  更新图片路径结构 - 按目标肌肉分类存储
1.1.1  build 3  2025-08-02 05:31:42   基本动作库构建完成
1.1.2  build 4  2025-08-02 07:04:55   动作裤基本完成
```

## Foreign Key Violations

Raw `PRAGMA foreign_key_check` output:

```text
plan_actions|24|users|0
plan_actions|24|action|2
plan_actions|25|users|0
plan_actions|26|users|0
plan_actions|27|users|0
plan_actions|28|users|0
plan_actions|29|users|0
plan_actions|30|users|0
plan_actions|30|action|2
plan_actions|73|users|0
plan_actions|74|users|0
plan_actions|94|users|0
plan_actions|95|users|0
plan_actions|96|users|0
plan_actions|97|users|0
plan_actions|98|users|0
plan_actions|106|users|0
plan_actions|107|users|0
plan_actions|108|users|0
plan_actions|109|users|0
plan_actions|110|users|0
plan_actions|121|users|0
plan_actions|122|users|0
plan_actions|123|users|0
plan_actions|124|users|0
plan_actions|137|users|0
plan_actions|138|users|0
plan_actions|139|users|0
plan_actions|140|users|0
plan_actions|141|users|0
plan_actions|142|users|0
plan_actions|143|users|0
plan_actions|144|users|0
plan_actions|145|users|0
plan_actions|146|users|0
plan_actions|147|users|0
plan_actions|148|users|0
plan_sets|1188|action|0
plan_sets|1189|action|0
plan_sets|1190|action|0
plan_sets|1234|action|0
plan_sets|1235|action|0
training_plans|4|user|1
training_plans|5|user|1
```

## Schema Notes For Phase 1

- Long-term table naming should move toward plural table names.
- Current schema still uses singular tables such as `user` and `action`.
- `plan_actions.user_id` references `users(id)`, but the existing user table is `user`.
- `execution_actions.action_id` references `actions(id)`, but the existing action table is `action`.
- `plan_actions` contains an `"order"` column, which should eventually become `sort_order`.
- Mixed field naming exists, including `"gifUrl"` and snake_case fields.
- Template Plan and User Plan should be separated in the long-term model instead of relying on fake users or `user_id = 0`.

## Representative Table Definitions

```sql
CREATE TABLE user (
  id INTEGER NOT NULL,
  username VARCHAR(80) NOT NULL,
  email VARCHAR(120) NOT NULL,
  password_hash VARCHAR(128),
  is_admin BOOLEAN,
  role TEXT DEFAULT "regular",
  gender TEXT,
  height REAL,
  weight REAL,
  created_at TIMESTAMP,
  account_type TEXT DEFAULT 'email',
  external_id TEXT,
  wechat_open_id TEXT,
  wechat_union_id TEXT,
  apple_id TEXT,
  PRIMARY KEY (id),
  UNIQUE (username),
  UNIQUE (email)
);

CREATE TABLE training_plans (
  id INTEGER NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  difficulty VARCHAR(20),
  duration INTEGER,
  created_at DATETIME,
  updated_at DATETIME,
  user_id INTEGER NOT NULL,
  is_template BOOLEAN,
  template_id INTEGER,
  PRIMARY KEY (id),
  FOREIGN KEY(user_id) REFERENCES user (id),
  FOREIGN KEY(template_id) REFERENCES training_plans (id)
);

CREATE TABLE "plan_actions" (
  "plan_id" INTEGER NOT NULL,
  "action_id" INTEGER NOT NULL,
  "order" INTEGER,
  "sets" INTEGER,
  "reps" VARCHAR(50),
  "rest" INTEGER,
  "weight" FLOAT DEFAULT 10,
  "user_id" INTEGER,
  "note" TEXT,
  "record_bilateral" INTEGER DEFAULT 0,
  PRIMARY KEY("plan_id","action_id"),
  FOREIGN KEY("action_id") REFERENCES "action"("id"),
  FOREIGN KEY("plan_id") REFERENCES "training_plans"("id"),
  FOREIGN KEY("user_id") REFERENCES "users"("id")
);
```

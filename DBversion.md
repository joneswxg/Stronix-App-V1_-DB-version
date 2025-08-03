# 数据库版本管理文档

## 概述

本文档描述了Stronix应用数据库版本管理的标准流程和操作方法。

## 数据库版本表结构

```sql
CREATE TABLE database_version (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT NOT NULL,              -- 版本号 (例: 1.1.2)
    build_number INTEGER NOT NULL,      -- 构建号 (整数，必须递增)
    update_date TEXT NOT NULL,          -- 更新时间 (ISO8601格式)
    description TEXT,                   -- 更新描述
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## 1. 查询数据库版本

### 查询当前版本
```sql
-- 查询当前最新版本
SELECT 
    version as '当前版本',
    build_number as '构建号',
    description as '描述',
    update_date as '更新时间',
    created_at as '创建时间'
FROM database_version 
ORDER BY build_number DESC 
LIMIT 1;
```

### 查看版本历史
```sql
-- 查看所有版本历史
SELECT 
    id,
    version,
    build_number,
    description,
    update_date,
    created_at
FROM database_version 
ORDER BY build_number DESC;
```

### 获取下一个构建号
```sql
-- 获取下一个应该使用的构建号
SELECT (MAX(build_number) + 1) as next_build_number 
FROM database_version;
```

## 2. 数据库更新标准流程

### 步骤1：执行数据更新操作
首先执行您的数据库修改操作（INSERT、UPDATE、DELETE等）

### 步骤2：查询当前构建号
```sql
SELECT MAX(build_number) as current_build FROM database_version;
```

### 步骤3：插入新版本记录
```sql
-- 版本更新模板
INSERT INTO database_version (
    version, 
    build_number, 
    update_date, 
    description
) VALUES (
    '1.1.X',                    -- 修改版本号
    [当前构建号+1],              -- 新构建号 (必须比当前最大值大)
    datetime('now'),            -- 当前时间
    '您的更新描述'               -- 修改描述
);
```

### 步骤4：更新代码中的版本配置
修改 `Stronix-App/Sources/Models/Database/VersionControl.swift` 文件：

```swift
static let currentBundleVersion = DatabaseVersion(
    version: "1.1.X",           -- 与数据库中的版本号一致
    buildNumber: X,             -- 与数据库中的构建号一致
    description: "您的更新描述"   -- 与数据库中的描述一致
)
```

### 步骤5：重新编译应用
1. 在Xcode中选择 Product > Clean Build Folder (⇧⌘K)
2. 从模拟器中删除应用
3. 重新编译并运行应用

## 3. 实际操作示例

### 示例：添加新的训练动作

```sql
-- 1. 执行数据更新
INSERT INTO action (external_id, name, gifUrl, bodypart_id, equipment_id) 
VALUES ('1500', '新训练动作', 'Images/abs/exercise_1500.gif', 1, 1);

-- 2. 查询当前构建号
SELECT MAX(build_number) FROM database_version;  -- 假设返回 4

-- 3. 插入新版本记录
INSERT INTO database_version (version, build_number, update_date, description) 
VALUES ('1.1.3', 5, datetime('now'), '添加新的训练动作');

-- 4. 验证版本更新
SELECT * FROM database_version ORDER BY build_number DESC LIMIT 1;
```

## 4. 常用SQL脚本

### 快速版本更新脚本
```sql
-- 一键版本更新 (修改相应参数)
INSERT INTO database_version (version, build_number, update_date, description) 
VALUES ('1.1.X', (SELECT MAX(build_number) + 1 FROM database_version), datetime('now'), '您的更新描述');
```

### 版本检查脚本
```sql
-- 检查版本一致性
SELECT 
    COUNT(*) as total_versions,
    MAX(build_number) as latest_build,
    MAX(version) as latest_version
FROM database_version;
```

### 回滚到指定版本 (仅查看，不建议实际回滚)
```sql
-- 查看指定版本的信息
SELECT * FROM database_version WHERE build_number = [指定构建号];
```

## 5. 注意事项

### ⚠️ 重要提醒
1. **构建号必须递增**：新的build_number必须大于当前最大值
2. **代码同步**：更新数据库版本后必须同步更新VersionControl.swift
3. **备份数据**：重要更新前建议备份数据库
4. **描述清晰**：version description应该清楚描述本次更新的内容

### 版本号命名规范
- **主版本号**：重大功能变更 (例: 1.x.x → 2.x.x)
- **次版本号**：功能增加或修改 (例: 1.1.x → 1.2.x)  
- **修订版本号**：数据更新或Bug修复 (例: 1.1.1 → 1.1.2)

## 6. 故障排除

### 版本不一致问题
如果应用中显示的数据与数据库不符：
1. 检查Bundle中是否包含数据库文件
2. 验证VersionControl.swift中的版本号是否正确
3. 清理项目并重新编译
4. 检查应用沙盒中的数据库版本

### 强制更新命令
```swift
// 在应用代码中强制更新数据库
DatabaseManager.shared.forceDatabaseUpdate()
```

## 7. 版本历史追踪

建议在每次重要更新时记录：
- 更新日期
- 修改内容
- 影响的表和字段
- 更新原因

示例记录：
```
版本 1.1.2 (构建号: 4)
日期: 2025-07-31
内容: 减少action表记录至22条，专注肱三头肌训练
影响: action表
原因: 应用功能调整
``` 
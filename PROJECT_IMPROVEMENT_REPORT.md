# Stronix App 项目优化审查报告

审查范围包括项目结构、代码质量、数据库设计、API/数据流、UI 标准化，以及测试、资源、构建维护等补充建议。

## 1. 总体结论

这个项目已经具备较完整的 iOS 本地应用形态：SwiftUI 页面、ViewModel、本地 SQLite 数据库、训练计划、动作库、训练历史、体测、登录注册等核心模块都已经落地。项目的问题不是“功能缺失”，而是随着功能增长后，架构边界、数据库约束、UI 设计系统、状态管理和可测试性没有同步收敛。

当前最需要优先处理的是：

1. **数据库外键与脏数据问题**：属于数据正确性风险。
2. **整库替换式升级策略**：有覆盖用户数据的严重风险。
3. **View 直接访问 Service/DB、单例过多、大文件过大**：会持续拖慢后续迭代。
4. **UI 缺少统一设计 token**：导致颜色、字体、间距、组件样式不一致。
5. **缺少测试与依赖注入**：核心训练、计划、用户、数据库逻辑难以验证。

---

## 2. 项目结构与代码质量

### 2.1 主要问题

#### 高优先级：模块边界不清晰

当前代码中存在 View、ViewModel、业务逻辑、工具类混放的问题。

典型例子：

- `Stronix-App/Sources/Models/Local/LocalActionModels.swift`
  - 包含 `ActionListViewModel`，但 ViewModel 不应放在 Models 目录下。
- `Stronix-App/Sources/Views/Actions/ActionDetailView.swift`
  - 包含 `ActionDetailViewModel`，导致页面文件同时承担 UI 与状态管理职责。
- `Stronix-App/Sources/Views/BodyMeasurement/NutritionView.swift`
  - 包含 `NutritionCalculator`，业务计算逻辑放在 View 文件中，不利于测试和复用。

建议统一成类似结构：

```text
Sources/
  App/
  Theme/
  Models/
  ViewModels/
  Views/
  Services/
  Repositories/
  UseCases/
  Utilities/
```

每个功能模块也可以再按 feature 分组：

```text
Sources/Features/
  Training/
    Views/
    ViewModels/
    Services/
    Models/
  Plans/
  BodyMeasurement/
  Profile/
```

#### 高优先级：巨型文件过多

当前多个文件已经明显过大：

- `Stronix-App/Sources/Views/Training/TrainingView.swift`：约 1280 行
- `Stronix-App/Sources/Views/Plans/CreatePlanView.swift`：约 1079 行
- `Stronix-App/Sources/Views/Plans/EditPlanView.swift`：约 1098 行
- `Stronix-App/Sources/Services/Local/LocalTrainingHistoryService.swift`：约 1483 行
- `Stronix-App/Sources/Services/Local/LocalUserService.swift`：约 1014 行

这通常说明：

- View 中混入太多业务逻辑
- Service 中承担了查询、转换、校验、组装、错误处理等多重职责
- 缺少 UseCase / Repository / DTO 分层

建议拆分优先级：

1. 先拆 `TrainingView.swift`
   - 训练头部
   - 动作列表
   - 组数记录
   - 休息计时器
   - 完成弹窗
   - 训练状态 ViewModel
2. 再拆 `CreatePlanView.swift` / `EditPlanView.swift`
   - 动作选择
   - 计划表单
   - 周期/日期选择
   - 保存逻辑 ViewModel
3. 最后拆 Service
   - 查询层
   - 写入层
   - DTO 映射层
   - 业务 UseCase

#### 高优先级：全局单例过多

项目中大量使用 `.shared`：

- `DatabaseManager.shared`
- `LocalUserService.shared`
- `LocalPlanService.shared`
- `TrainingSessionManager.shared`
- `NotificationManager.shared`
- `ThemeManager.shared`
- `TrainingHistoryService.shared`

这会带来几个问题：

- View 与底层实现强耦合
- 难以写单元测试
- 难以替换测试数据库
- 状态来源不清晰
- 训练流程、通知、历史保存之间副作用难控

建议逐步改成 protocol + 构造注入：

```swift
protocol PlanServicing {
    func fetchPlans(userId: Int64) async throws -> [TrainingPlan]
    func savePlan(_ plan: PlanDraft) async throws
}

final class PlanViewModel: ObservableObject {
    private let planService: PlanServicing

    init(planService: PlanServicing) {
        self.planService = planService
    }
}
```

短期不需要一次性改完，可先从核心模块开始：

1. `PlanViewModel`
2. `TrainingViewModel`
3. `BodyMeasurementViewModel`
4. `UserSessionViewModel`

#### 中高优先级：ViewModel 生命周期不稳定

`Stronix-App/Sources/Views/MainTabView.swift` 中存在直接创建 `PlanViewModel()` 的情况，而 `PlanViewModel.init()` 会立即 `loadData()`。

风险：

- SwiftUI body 重算时可能创建新的 ViewModel
- 可能触发重复查询
- 状态抖动
- 网络/数据库请求不可控

建议：

- 页面级状态使用 `@StateObject`
- 父级注入共享状态
- ViewModel 初始化时尽量不要自动做重请求，而是在 `.task` 或显式 `load()` 中触发

#### 中优先级：数据层类型不稳

存在大量 `[String: Any]` 和强制类型转换。

典型位置：

- `Stronix-App/Sources/Services/Local/LocalPlanService.swift`
- `Stronix-App/Sources/ViewModels/PlanViewModel.swift`
- `DatabaseManager.executeQuery<T>` 中存在直接 `as!` 强转
- `LocalUserService.login/register` 依赖 SQL 行数据解析

建议：

- 为数据库查询结果定义 DTO
- 禁止 ViewModel 层传递 `[String: Any]`
- 数据库映射集中放在 Mapper 中
- 所有 SQLite row → domain model 的转换应为可失败转换，而不是强转

### 2.2 推荐结构演进

推荐目标结构：

```text
Sources/
  App/
    Stronix_App_V1App.swift
    AppEnvironment.swift

  Core/
    Database/
      DatabaseManager.swift
      DatabaseMigration.swift
      DatabaseError.swift
    Theme/
    Navigation/
    Utilities/

  Features/
    Plans/
      Models/
      Views/
      ViewModels/
      Repositories/
      UseCases/
    Training/
    Actions/
    BodyMeasurement/
    Profile/
```

不建议一开始做“大重构”，建议按功能模块逐步迁移。

---

## 3. 数据库设计审查

### 3.1 高风险问题：外键设计错误

数据库文件：

- `Stronix-App/Resources/Database/database_stronix.db`

审查发现：

- `PRAGMA integrity_check = ok`
- 但 `PRAGMA foreign_key_check` 非空

说明数据库物理结构没有损坏，但存在外键约束问题。

主要问题：

- `plan_actions.user_id` 外键指向 `users(id)`，但实际表名是 `user`
- `execution_actions.action_id` 外键指向 `actions(id)`，但实际表名是 `action`

这是实质性 schema 错误。

#### 建议

统一表名风格，并修复外键：

- 要么全部单数：`user`, `action`, `training_plan`
- 要么全部复数：`users`, `actions`, `training_plans`

更推荐复数表名：

```sql
users
actions
training_plans
plan_actions
training_history
training_history_details
```

### 3.2 高风险问题：已有脏数据

发现已有数据违反约束：

- `training_plans.user_id` 存在 `0`
- `plan_actions.user_id = 0` 多条违规
- `plan_sets.action_id` 存在孤儿记录

风险：

- 用户计划与模板计划边界不清
- 删除动作或用户后，关联数据不可预测
- 后续打开外键检查后可能导致写入失败
- 数据迁移时可能失败

#### 建议

不要用 `0` 表示系统用户或模板数据。

可选方案：

1. `user_id` 改为 nullable
   - `NULL` 表示系统模板
2. 建立系统用户
   - 例如 `user.id = 1` 为 system
3. 模板计划单独建表
   - `template_plans`
   - `template_plan_actions`
   - 与用户计划彻底分离

推荐长期方案：**模板计划与用户计划分表**。

### 3.3 高风险问题：迁移策略可能覆盖用户数据

相关文件：

- `Stronix-App/Sources/Services/Update/UpdateService.swift`
- `Stronix-App/Sources/Models/Database/VersionControl.swift`
- `Stronix-App/Sources/Services/Local/LocalBodyMeasurementService.swift`

当前升级策略偏向：

- 备份旧数据库
- 用 bundle 内的新数据库整体替换
- 部分表运行时创建

这对本地 App 非常危险，因为用户数据可能被覆盖或丢失。

#### 建议

建立事务化增量 migration：

```text
DatabaseMigrations/
  001_initial.sql
  002_add_body_measurements.sql
  003_fix_plan_action_foreign_keys.sql
  004_add_training_history_indexes.sql
```

启动时流程：

1. 打开数据库
2. 读取 `schema_version`
3. 开启事务
4. 按版本顺序执行 migration
5. 更新版本号
6. 提交事务
7. 失败则回滚

禁止对用户数据库做整库覆盖。

### 3.4 中高风险：SQLite 并发与约束配置不足

相关文件：

- `Stronix-App/Sources/Services/Database/DatabaseManager.swift`

当前发现：

- 共享单个 `Connection`
- 未明确看到启动时执行 `PRAGMA foreign_keys = ON`
- 当前数据库 `PRAGMA foreign_keys = 0`
- `journal_mode = delete`
- 未明确看到 `busy_timeout`
- 未明确看到 WAL 配置

#### 建议启动时统一配置

```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
```

同时建议：

- DB 写入集中到串行队列或 actor
- 避免多个 async task 同时写同一连接
- 读写分离时明确连接生命周期

Swift 方向可以考虑：

```swift
actor DatabaseClient {
    private let connection: Connection

    func read<T>(_ block: (Connection) throws -> T) throws -> T
    func write<T>(_ block: (Connection) throws -> T) throws -> T
}
```

### 3.5 中风险：索引不足

建议补充索引：

```sql
CREATE INDEX IF NOT EXISTS idx_training_history_user_date_created
ON training_history(user_id, training_date DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_training_history_details_history_id
ON training_history_details(history_id);

CREATE INDEX IF NOT EXISTS idx_action_target_muscle_target_action
ON action_target_muscle_link(target_muscle_id, action_id);
```

原因：

- 训练历史经常按用户、训练日期、创建时间查询
- 历史详情经常按 `history_id` 查询
- 动作筛选经常按目标肌肉查询

### 3.6 中风险：命名与时间格式不统一

问题包括：

- 表名单复数混用
- 字段名混用 `gifUrl`、`created_at`
- `order` 作为字段名需要转义
- 时间类型混用 `DATETIME`、`TIMESTAMP`、`TEXT`
- `LocalBodyMeasurementService.swift` 需要兼容多种时间格式解析

建议统一：

- 表名：复数
- 字段名：snake_case
- 时间：ISO8601 TEXT 或 Unix timestamp，二选一
- 避免 SQL 关键字，如 `order` 改为 `sort_order`

---

## 4. API / 数据流设计

### 4.1 当前状态

项目主业务已经以本地 SQLite 为主，网络 API 不再是主链。

主要本地服务：

- `Stronix-App/Sources/Services/Database/DatabaseManager.swift`
- `Stronix-App/Sources/Services/Local/LocalPlanService.swift`
- `Stronix-App/Sources/Services/Local/LocalBodyMeasurementService.swift`
- `Stronix-App/Sources/Services/Local/LocalUserService.swift`
- `Stronix-App/Sources/Services/Local/LocalTrainingHistoryService.swift`

真实网络调用主要出现在：

- `Stronix-App/Sources/Services/Email/AliCloudEmailService.swift`

同时仍保留本地 API 配置：

- `Stronix-App/Sources/Utilities/Constants/DBConfig.swift`

其中 localhost API 配置容易误导后续维护者。

### 4.2 高优先级：View 直接访问 DB / Service

典型位置：

- `Stronix-App/Sources/Views/History/ActionHistroyView.swift`
  - 直接 `DatabaseManager.shared.getConnection()` 查询数据库
- `Stronix-App/Sources/Views/Plans/CreatePlanView.swift`
  - 直接调用 `LocalPlanService.shared`
- `Stronix-App/Sources/Views/Plans/EditPlanView.swift`
  - 直接调用 `LocalPlanService.shared`
- `Stronix-App/Sources/Views/Training/TrainingView.swift`
  - 直接调用 `TrainingHistoryService.shared`
  - 还负责组装训练保存流程

风险：

- UI 难以测试
- 数据逻辑分散
- 错误处理不统一
- 页面间行为难复用
- 后续改数据库结构时影响范围过大

建议目标数据流：

```text
View
  ↓ user intent
ViewModel
  ↓ use case
UseCase
  ↓ repository protocol
Repository
  ↓ database client / service
SQLite
```

### 4.3 中优先级：Repository 层缺失

当前 Service 层直接承担：

- SQL 查询
- 数据转换
- 业务规则
- 错误映射
- 缓存
- 状态更新

建议新增 Repository 层：

```swift
protocol PlanRepository {
    func fetchPlans(userId: Int64) async throws -> [TrainingPlan]
    func fetchPlanDetail(id: Int64) async throws -> TrainingPlanDetail
    func save(_ draft: PlanDraft) async throws
}
```

然后业务用例调用 Repository：

```swift
final class SaveTrainingPlanUseCase {
    private let repository: PlanRepository

    func execute(_ draft: PlanDraft) async throws {
        try draft.validate()
        try await repository.save(draft)
    }
}
```

这样可以：

- 减少 ViewModel 对 SQLite 细节的依赖
- 便于单元测试
- 便于未来从本地 DB 切换到远端同步

### 4.4 中优先级：错误处理不一致

当前常见问题：

- Service 中 `print`
- 抛泛化错误，如 `serverError`
- UI 层直接显示 `localizedDescription`
- 数据不存在、权限失败、数据库锁、约束失败没有区分

建议定义业务错误：

```swift
enum AppError: LocalizedError {
    case notLoggedIn
    case notFound(String)
    case validation(String)
    case database(DatabaseError)
    case network(String)
}
```

数据库错误也建议保留：

- SQLite error code
- SQL 操作上下文
- 原始错误信息

### 4.5 中低优先级：缓存策略不明确

当前：

- `LocalBodyMeasurementService` 有轻量内存缓存
- `SettingsView.clearCache()` 为空实现

建议：

- 明确哪些数据需要缓存
- 定义缓存失效时机
- 如果 UI 有“清除缓存”按钮，必须真实清理对应缓存
- 否则删除空实现，避免误导用户

---

## 5. UI 设计与标准化

### 5.1 当前结论

项目已有 `AppTheme.swift`，说明已经有主题化意识。但当前主题系统还不够完整，许多颜色、字体、间距、圆角和组件样式仍散落在各个页面中。

相关文件：

- `Stronix-App/Sources/Theme/AppTheme.swift`
- `Stronix-App/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`

### 5.2 高优先级：颜色和暗色模式不标准

问题：

- `DarkBlueTheme` 中仍使用：
  - `background = Color(white: 0.95)`
  - `surface = .white`
  - `onSurface = .black`
- 这不是真正的暗色主题
- Asset Catalog 中颜色没有充分使用 light/dark variants
- 页面中仍存在颜色硬编码

建议建立语义色 token：

```swift
struct AppColors {
    let background: Color
    let surface: Color
    let primary: Color
    let secondary: Color
    let textPrimary: Color
    let textSecondary: Color
    let border: Color
    let success: Color
    let warning: Color
    let error: Color
}
```

并使用系统 `colorScheme` 或 Asset Catalog 的 Any/Dark 变体。

### 5.3 高优先级：字体、间距、圆角硬编码

审查发现大致存在：

- 大量 `.font(.system(...))`
- 多处固定宽高
- 常见魔法数如 `12/16/20/24/50/120/280`

典型页面：

- `Stronix-App/Sources/Views/Profile/LoginView.swift`
- `Stronix-App/Sources/Views/Profile/RegisterView.swift`
- `Stronix-App/Sources/Views/BodyMeasurement/BodyMeasurementOverview.swift`
- `Stronix-App/Sources/Views/Plans/PlanListView.swift`

建议定义：

```swift
enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum AppRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 20
}

enum AppTypography {
    static let title = Font.system(size: 24, weight: .bold)
    static let body = Font.system(size: 16)
    static let caption = Font.system(size: 12)
}
```

后续所有页面统一引用 token。

### 5.4 高优先级：通用组件复用不足

重复明显的页面：

- `LoginView.swift`
- `RegisterView.swift`
- `PlanListView.swift`
- `BodyMeasurementOverview.swift`

建议抽出组件：

```text
Components/
  AppTextField.swift
  PasswordField.swift
  PrimaryButton.swift
  SecondaryButton.swift
  CardSurface.swift
  EmptyStateView.swift
  SectionHeader.swift
  LoadingStateView.swift
  ErrorStateView.swift
```

收益：

- UI 一致性提升
- 页面文件变短
- 设计调整成本降低
- 可访问性可集中处理

### 5.5 中优先级：导航标准不一致

当前混用：

- `NavigationStack`
- `NavigationView`
- `sheet`
- `fullScreenCover`
- 自定义跳转状态

建议：

- iOS 16+ 项目统一 `NavigationStack`
- 定义页面跳转规范：
  - 主流程 push
  - 创建/编辑 modal
  - 登录 fullScreenCover 或独立 auth flow
  - destructive 操作用 confirmation dialog

### 5.6 高优先级：可访问性不足

问题：

- 几乎没有 `accessibilityLabel`
- 图标按钮语义不明确
- 动态字体支持不足
- 固定尺寸可能影响大字号用户
- 状态变化缺少朗读

典型位置：

- `MainTabView`
- `PlanListView`
- `BodyMeasurementOverview`
- 登录/退出按钮
- 图标按钮

建议：

```swift
Button {
    logout()
} label: {
    Image(systemName: "rectangle.portrait.and.arrow.right")
}
.accessibilityLabel("退出登录")
.accessibilityHint("退出当前账号并返回登录页面")
```

### 5.7 高优先级：响应式布局问题

典型问题：

- `ActionListView.swift` 使用固定 0.25 / 0.75 分栏
- 多处 `width: 120`, `height: 50`
- `TrainingView.swift` 使用 `offset(y: -110)`
- `CreatePlanView.swift` 使用键盘占位 `height: 280`

建议：

- 用 `safeAreaInset`
- 用 `GeometryReader` 时避免魔法比例
- 使用 size class
- 使用 `LazyVGrid` 自适应布局
- 避免用 offset 修布局

### 5.8 高优先级：本地化缺失

当前未发现 `.strings` 或 `.xcstrings`。

项目中大量中文直写：

```swift
Text("登录")
Text("训练计划")
Text("保存")
```

建议建立：

```text
Resources/Localization/Localizable.xcstrings
```

先抽：

- Tab 名称
- 页面标题
- 按钮
- 错误提示
- 空态文案
- 表单 placeholder

---

## 6. 资源与工程配置

### 6.1 资源目录需清理

发现：

- `Resources` 下存在大量 `.DS_Store`
- 图片文件数量很大
- 动作图片约上千个
- `loadLocalActionImage` 依赖硬编码目录遍历

建议：

- 从仓库中移除 `.DS_Store`
- `.gitignore` 加入 `.DS_Store`
- 统一资源命名规则
- 为动作图片建立 manifest，例如：

```json
{
  "exercise_1088": {
    "muscleGroup": "abductors",
    "file": "abductors/exercise_1088.gif"
  }
}
```

避免运行时靠目录扫描和字符串拼接猜路径。

### 6.2 AppIcon / Logo 资源不完整

发现：

- `StronixLogo.imageset` 仅配置 1x 文件
- `AppIcon` 的 dark/tinted 槽未完整落图

建议：

- 补齐 1x/2x/3x
- 检查 iOS 18 dark/tinted icon 配置
- 用统一命名，如 `logo_primary`, `logo_mark`, `app_icon`

---

## 7. 测试与质量保障

### 7.1 当前问题

审查中未看到明显测试覆盖。

当前项目的高风险逻辑包括：

- 登录注册
- 本地用户状态
- 训练计划创建/编辑
- 训练历史保存
- SQLite migration
- 体测记录
- 动作筛选
- 数据库版本升级

这些都不适合完全依赖手动测试。

### 7.2 建议测试优先级

第一阶段：数据层测试

- Database migration 测试
- 外键约束测试
- 训练计划保存/读取测试
- 训练历史保存/读取测试
- 用户注册/登录测试

第二阶段：ViewModel 测试

- `PlanViewModel`
- `BodyMeasurementViewModel`
- `TrainingViewModel`
- 登录注册 ViewModel

第三阶段：UI 快照/流程测试

- 登录
- 创建计划
- 开始训练
- 保存训练
- 查看历史
- 新增体测

---

## 8. 安全与隐私建议

### 8.1 本地用户密码风险

如果 `LocalUserService` 直接本地存储用户密码或弱 hash，需要重点检查。

建议：

- 密码不要明文存 SQLite
- 使用 CryptoKit 做强 hash + salt
- 更推荐本地认证使用 Keychain
- 如果只是单机 App，可考虑 Apple 登录/本地 Keychain token

### 8.2 邮件服务密钥风险

相关文件：

- `Stronix-App/Sources/Services/Email/AliCloudEmailService.swift`

如果其中包含 AccessKey、Secret、签名密钥等敏感信息，不应打包到客户端。

建议：

- 客户端不要持有云服务密钥
- 邮件验证码应由服务端发送
- 如果当前只是本地版本，至少用 build config 区分测试/生产，避免真实密钥进入仓库

---

## 9. 优先级路线图

### P0：必须优先处理

1. 修复数据库外键错误
   - `users/actions` 表名引用错误
   - `foreign_key_check` 非空
2. 清理已有脏数据
   - `user_id = 0`
   - 孤儿 `action_id`
3. 禁止整库覆盖式升级
   - 改为 migration
4. SQLite 启动配置
   - `foreign_keys = ON`
   - `WAL`
   - `busy_timeout`
5. 把 View 直连 DB 的代码移出
   - 尤其 `ActionHistroyView.swift`

### P1：短期优化

1. 拆分巨型 View
   - `TrainingView.swift`
   - `CreatePlanView.swift`
   - `EditPlanView.swift`
2. 建立 ViewModel 边界
   - View 只负责渲染和触发 intent
3. 建立 Repository protocol
   - Plans
   - TrainingHistory
   - User
   - BodyMeasurement
4. 消除 `[String: Any]`
   - 改强类型 DTO
5. 统一错误模型
   - `AppError`
   - `DatabaseError`

### P2：中期优化

1. 建立设计系统
   - Colors
   - Typography
   - Spacing
   - Radius
   - Components
2. 统一导航到 `NavigationStack`
3. 补可访问性
4. 建立本地化文件
5. 优化动作图片资源加载
6. 清理重复服务
   - `WechatLoginService` 重复文件
7. 清理 `.DS_Store`

### P3：长期优化

1. 建立完整测试体系
2. 建立数据库迁移测试
3. 引入 CI
   - build
   - test
   - lint
4. 引入代码规范
   - SwiftLint
   - SwiftFormat
5. 进一步模块化 Feature
6. 为未来云同步预留 Repository 抽象

---

## 10. 建议的第一轮落地任务

如果后续直接开始优化，建议第一轮不要做大重构，而是先做一组低风险、高收益的基础修复：

1. **数据库安全修复**
   - 增加 `PRAGMA foreign_keys = ON`
   - 增加 `busy_timeout`
   - 评估 WAL
   - 输出外键修复 migration 方案
2. **清理 View 直连 DB**
   - 从 `ActionHistroyView.swift` 移出数据库查询
3. **修复 MainTabView 的 ViewModel 生命周期**
   - 避免 body 重建触发重复加载
4. **建立基础设计 token**
   - `AppSpacing`
   - `AppRadius`
   - `AppTypography`
5. **抽一个通用按钮和空态组件**
   - 先从重复最高的登录/注册/空态入手

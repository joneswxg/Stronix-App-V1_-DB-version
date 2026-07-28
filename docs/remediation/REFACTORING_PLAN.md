# Stronix App 代码整改计划

## 1. 背景与结论

当前项目不建议重新开发一个全新项目，建议基于现有项目进行分阶段整改。

原因是项目已经沉淀了大量可复用资产，包括：

- 本地 SQLite 数据库：`Stronix-App/Resources/Database/database_stronix.db`
- 动作图片和资源库：`Stronix-App/Resources/Images`
- Theme / 主题体系
- Local Service 层
- 训练、计划、体测、用户等核心业务模型
- 已经跑通的训练计划、训练记录、动作库、体测等业务流程

当前主要问题集中在代码边界和数据底座，而不是业务方向错误。因此更适合通过渐进式整改解决，而不是整体重写。

## 2. 为什么不建议整体重写

整体重写看起来可以让代码结构更干净，但实际风险更高：

1. **业务规则会被重新实现一遍**
   - 训练计划、动作选择、训练历史、体测记录等流程已经有大量细节。
   - 重写容易遗漏隐含规则。

2. **数据库问题不会因为重写自动消失**
   - 当前数据库存在外键、迁移、升级策略等风险。
   - 新项目仍然需要处理历史数据兼容、迁移和用户数据保留。

3. **资源资产迁移成本高**
   - 项目中有大量动作 GIF、图片、数据库资源。
   - 重写项目仍然要重新组织、引用和验证这些资源。

4. **回归测试成本高**
   - 重新开发意味着登录、计划、训练、历史、体测、动作库都要重新测试。
   - 在没有完整自动化测试的情况下，整体重写风险很大。

5. **当前问题大多可以渐进修复**
   - 巨型文件可以拆分。
   - View 直连 Service/DB 可以收敛到 ViewModel / Repository。
   - 单例可以逐步通过协议和依赖注入替换。
   - `[String: Any]` 可以逐步改成强类型 DTO。

## 3. 总体整改策略

采用三阶段整改路线：

```text
阶段 1：先止血，稳定数据库和状态生命周期
阶段 2：拆计划域，建立清晰架构边界
阶段 3：按业务域持续收敛，补 UI 标准化和测试
```

目标依赖方向：

```text
View
  ↓
ViewModel
  ↓
UseCase
  ↓
Repository Protocol
  ↓
Local Service / Database Client
  ↓
SQLite
```

---

## 4. 阶段 1：先止血，稳定底座

### 4.1 目标

优先处理最容易造成数据丢失、状态异常和重复加载的问题。

重点包括：

- 修复数据库升级策略风险
- 修复 SQLite 连接配置风险
- 修复 ViewModel 生命周期问题
- 切断最明显的 View 直连 DB

### 4.2 重点文件

- `Stronix-App/Sources/Services/Database/DatabaseManager.swift`
- `Stronix-App/Sources/Services/Update/UpdateService.swift`
- `Stronix-App/Sources/Views/MainTabView.swift`
- `Stronix-App/Sources/ViewModels/PlanViewModel.swift`
- `Stronix-App/Sources/Views/History/ActionHistroyView.swift`

### 4.3 具体整改项

#### 4.3.1 修复数据库初始化配置

在数据库连接建立后明确配置：

```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
```

目标：

- 开启外键约束
- 提高读写并发稳定性
- 降低数据库锁冲突概率

#### 4.3.2 停止整库覆盖式升级

当前 `UpdateService.swift` 存在备份当前 DB、删除 Documents DB、复制 Bundle DB 的升级方式。

应逐步改成 migration 模式：

```text
DatabaseMigrations/
  001_initial.sql
  002_fix_foreign_keys.sql
  003_add_indexes.sql
  004_add_body_measurement_fields.sql
```

升级流程建议：

1. 读取当前数据库版本
2. 对比 bundle 或 app 内置 schema 版本
3. 在事务中按顺序执行 migration
4. 成功后更新版本表
5. 失败则回滚

#### 4.3.3 修复 MainTabView 中 ViewModel 创建方式

当前 `MainTabView.swift` 中存在类似问题：

```swift
TrainingView(plan: currentPlan, viewModel: PlanViewModel())
```

如果 `PlanViewModel.init()` 会触发数据加载，就可能导致 SwiftUI 重建时重复加载。

建议：

- 使用 `@StateObject` 持有页面级 ViewModel
- 或由父级统一注入 ViewModel
- 避免在 `body` 中直接 new ViewModel

#### 4.3.4 移除 View 直连数据库

优先处理：

- `Stronix-App/Sources/Views/History/ActionHistroyView.swift`

目标：

- View 不直接调用 `DatabaseManager.shared.getConnection()`
- 查询逻辑迁移到 ViewModel 或 Service
- View 只负责展示状态和触发用户行为

### 4.4 阶段收益

- 降低用户数据丢失风险
- 降低重复加载和状态抖动风险
- 为后续拆分模块建立稳定基础

### 4.5 验证方式

- 启动 App，确认数据库可正常初始化
- 创建计划、编辑计划、开始训练、完成训练、查看历史
- 确认用户数据不会因为数据库升级被覆盖
- 观察主 Tab 切换时不会重复触发异常加载

---

## 5. 阶段 2：拆计划域，建立清晰边界

### 5.1 目标

计划模块是当前最适合作为第一批架构整改的业务域。

它连接：

- 主 Tab
- 计划列表
- 创建计划
- 编辑计划
- 训练入口
- 本地数据库

整改计划域可以为后续训练域、历史域、体测域提供模板。

### 5.2 重点文件

- `Stronix-App/Sources/Views/Plans/CreatePlanView.swift`
- `Stronix-App/Sources/Views/Plans/EditPlanView.swift`
- `Stronix-App/Sources/ViewModels/PlanViewModel.swift`
- `Stronix-App/Sources/Services/Local/LocalPlanService.swift`
- `Stronix-App/Sources/Models/Local/LocalPlanModels.swift`

### 5.3 具体整改项

#### 5.3.1 拆分 CreatePlanView

当前 `CreatePlanView.swift` 文件较大，并包含大量状态、UI 和保存逻辑。

建议拆分为：

```text
CreatePlanView.swift
CreatePlanViewModel.swift
PlanNameSection.swift
PlanActionListSection.swift
PlanSetEditorView.swift
PlanSaveUseCase.swift
```

View 只保留：

- 页面布局
- 状态绑定
- 用户交互入口

保存、校验、数据组装迁移到 ViewModel / UseCase。

#### 5.3.2 拆分 EditPlanView

`EditPlanView.swift` 与 `CreatePlanView.swift` 有大量相似逻辑。

建议复用：

- 动作列表组件
- 组数编辑组件
- 计划表单模型
- 保存 UseCase

避免创建和编辑两套逻辑长期分叉。

#### 5.3.3 引入 PlanRepository 协议

建议建立协议边界：

```swift
protocol PlanRepository {
    func fetchPlans(userId: Int64) async throws -> [TrainingPlan]
    func fetchPlanDetail(id: Int64) async throws -> TrainingPlanDetail
    func createPlan(_ draft: PlanDraft) async throws
    func updatePlan(_ draft: PlanDraft) async throws
}
```

短期实现：

```swift
final class SQLitePlanRepository: PlanRepository {
    private let localPlanService: LocalPlanService
}
```

这样可以继续复用 `LocalPlanService`，同时让 ViewModel 不再直接依赖单例。

#### 5.3.4 消除计划链路中的 `[String: Any]`

将计划保存和读取中的字典结构逐步改成强类型：

```swift
struct PlanDraft {
    let name: String
    let note: String?
    let actions: [PlanActionDraft]
}

struct PlanActionDraft {
    let actionId: Int64
    let orderIndex: Int
    let sets: [PlanSetDraft]
}

struct PlanSetDraft {
    let weight: Double
    let reps: Int
    let restTime: Int
}
```

目标：

- 减少运行时类型错误
- 降低保存逻辑复杂度
- 让测试更容易编写

### 5.4 阶段收益

- 计划模块文件变小
- 数据流更清晰
- 创建/编辑逻辑可复用
- 为后续训练模块重构建立样板

### 5.5 验证方式

- 创建新计划
- 编辑已有计划
- 添加/删除动作
- 修改组数、重量、次数、休息时间
- 从计划进入训练
- 退出再进入，确认计划数据正常保存和读取

---

## 6. 阶段 3：按业务域持续收敛

### 6.1 目标

在数据库和计划域稳定后，继续按业务域推进整改。

优先顺序建议：

```text
训练域 → 历史域 → 用户/登录域 → 体测域 → UI 设计系统
```

### 6.2 训练域整改

重点文件：

- `Stronix-App/Sources/Views/Training/TrainingView.swift`
- `Stronix-App/Sources/Services/Local/LocalTrainingHistoryService.swift`

目标：

- 拆分 `TrainingView.swift`
- 建立 `TrainingViewModel`
- 将训练完成、历史写入、计划回写逻辑移出 View
- 减少对 `TrainingSessionManager.shared` 的直接依赖

### 6.3 历史域整改

目标：

- 历史列表和历史详情统一走 ViewModel
- 查询逻辑不出现在 View 中
- 为训练历史查询补充索引和分页能力

### 6.4 用户/登录域整改

重点文件：

- `Stronix-App/Sources/Services/Local/LocalUserService.swift`
- `Stronix-App/Sources/Views/Profile/LoginView.swift`
- `Stronix-App/Sources/Views/Profile/RegisterView.swift`

目标：

- 抽出 `AuthViewModel`
- 登录态统一管理
- 检查密码存储方式
- 登录/注册 UI 组件复用

### 6.5 UI 设计系统整改

重点文件：

- `Stronix-App/Sources/Theme/AppTheme.swift`
- `Stronix-App/Sources/Views/Profile/LoginView.swift`
- `Stronix-App/Sources/Views/Profile/RegisterView.swift`
- `Stronix-App/Sources/Views/Plans/PlanListView.swift`
- `Stronix-App/Sources/Views/BodyMeasurement/BodyMeasurementOverview.swift`

建议建立：

```text
Components/
  PrimaryButton.swift
  SecondaryButton.swift
  AppTextField.swift
  CardSurface.swift
  EmptyStateView.swift
  SectionHeader.swift

Theme/
  AppColors.swift
  AppTypography.swift
  AppSpacing.swift
  AppRadius.swift
```

目标：

- 统一颜色、字体、间距、圆角
- 减少硬编码
- 提升暗色模式和可访问性支持

### 6.6 阶段收益

- 项目结构逐步可维护
- 新功能开发成本下降
- 测试覆盖更容易补齐
- UI 风格逐步统一

---

## 7. 如果未来需要局部重写

如果后续发现某个模块确实难以继续维护，不建议整体重写 App，而应采用局部重写策略。

优先局部重写对象：**计划域**。

原因：

- 它连接主流程，收益明显
- 问题集中，边界清晰
- 可以保留数据库、Theme、动作资源、体测模块等资产
- 重写范围可控

边界建议：

```text
旧 View / Service
  ↓
PlanRepository Protocol
  ↓
新的计划域实现
```

通过协议边界替换实现，而不是新开整个项目。

---

## 8. 推荐第一轮执行清单

第一轮建议控制范围，不做大重构。

### Task 1：数据库初始化安全加固

- 在数据库连接后配置 foreign_keys
- 配置 busy_timeout
- 评估启用 WAL
- 增加数据库状态检查日志

### Task 2：调整数据库升级策略

- 停止直接删除 Documents DB
- 设计 migration 入口
- 保留当前 UpdateService 作为兼容过渡

### Task 3：修复 MainTabView 的 ViewModel 生命周期

- 避免在 body 中直接创建 `PlanViewModel()`
- 使用 `@StateObject` 或父级注入

### Task 4：移除 ActionHistroyView 直连 DB

- 新建或复用历史 ViewModel / Service 方法
- View 只展示查询结果

### Task 5：开始拆 CreatePlanView

- 先抽 ViewModel
- 再抽动作列表和组数编辑组件
- 保存逻辑迁移到 ViewModel / UseCase

---

## 9. 验证计划

每轮整改后至少验证以下路径：

1. App 正常启动
2. 登录/退出正常
3. 创建训练计划正常
4. 编辑训练计划正常
5. 开始训练正常
6. 完成训练并保存历史正常
7. 历史记录可查看
8. 体测数据可查看和新增
9. 数据库升级后用户数据不丢失
10. 主 Tab 切换无明显状态抖动或重复加载

---

## 10. 最终目标

整改完成后的目标不是“代码看起来更漂亮”，而是达到以下状态：

- 数据库升级安全，不覆盖用户数据
- View 不直接访问 DB
- ViewModel 生命周期稳定
- 核心业务逻辑可测试
- Service / Repository 边界清晰
- 巨型文件明显减少
- UI token 和通用组件统一
- 后续新增功能可以按模块自然扩展
